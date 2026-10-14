import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/database.dart';
import '../../data/pooper_actions.dart';
import '../../providers.dart';
import '../../state/calendar_data.dart';
import '../../theme/pooper_icons.dart';
import '../../theme/tokens.dart';
import '../widgets/avatar_cropper_page.dart';
import '../widgets/pooper_avatar.dart';
import '../widgets/settings_widgets.dart';
import '../widgets/smooth_page_route.dart';

/// 新增 / 编辑屙屎人（视觉稿 ⑫）。
///
/// [pooper] 为 null 时是新增。
/// 支持自定义照片头像（相册选取 + 原生裁剪编辑器截取）以及内置图标与文字首字。
class PooperEditPage extends ConsumerStatefulWidget {
  const PooperEditPage({super.key, this.pooper});

  final Pooper? pooper;

  @override
  ConsumerState<PooperEditPage> createState() => _PooperEditPageState();
}

enum _AvatarType {
  custom,
  initial,
  icon,
}

class _PooperEditPageState extends ConsumerState<PooperEditPage> {
  late final TextEditingController _name =
      TextEditingController(text: widget.pooper?.name ?? '');
  late final TextEditingController _remark =
      TextEditingController(text: widget.pooper?.remark ?? '');

  /// 自定义上传的照片头像缓存（无论切换到首字还是图标均永久保留，支持随时切回）。
  late Uint8List? _customAvatarBlob = widget.pooper?.avatarBlob;

  /// 选中的内置图标 key。
  late String? _iconKey = widget.pooper?.iconKey;

  /// 当前选择使用的头像类型。
  late _AvatarType _avatarType = widget.pooper?.avatarBlob != null
      ? _AvatarType.custom
      : (widget.pooper?.iconKey != null ? _AvatarType.icon : _AvatarType.initial);

  late bool _makeDefault = widget.pooper?.isDefault ?? false;
  bool _saving = false;

  bool get _isNew => widget.pooper == null;

  Uint8List? get _effectiveAvatarBlob =>
      _avatarType == _AvatarType.custom ? _customAvatarBlob : null;

  String? get _effectiveIconKey =>
      _avatarType == _AvatarType.icon ? (_iconKey ?? kPooperIcons.first.key) : null;

  @override
  void dispose() {
    _name.dispose();
    _remark.dispose();
    super.dispose();
  }

  /// 从相册选取图片并调起截取编辑界面（支持取消后重新回到相册选图）
  Future<void> _pickAndCropAvatar() async {
    try {
      final picker = ImagePicker();
      while (mounted) {
        final XFile? file = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 2048,
          maxHeight: 2048,
          imageQuality: 95,
        );
        // 用户在相册界面取消，退出整个选图流程
        if (file == null || !mounted) break;

        final rawBytes = await file.readAsBytes();
        if (!mounted) break;

        final CropResult? result = await Navigator.of(context).push<CropResult>(
          smoothPageRoute(AvatarCropperPage(imageBytes: rawBytes)),
        );

        if (result == null || !mounted || result.action == CropExitAction.cancel) {
          break;
        } else if (result.action == CropExitAction.repick) {
          // 在裁切界面取消或点击重选，循环跳回上一层相册继续选图
          continue;
        } else if (result.action == CropExitAction.confirm &&
            result.croppedBytes != null) {
          setState(() {
            _customAvatarBlob = result.croppedBytes;
            _avatarType = _AvatarType.custom;
          });
          break;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SettingsScaffold(
      title: _isNew ? '新增成员' : '编辑成员',
      actions: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 设为默认打卡人星标
            IconButton(
              icon: Icon(
                LucideIcons.star,
                size: 20,
                color: _makeDefault ? const Color(0xFFF59E0B) : t.ink4,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              tooltip: _makeDefault ? '当前已是默认打卡人' : '设为默认打卡人（点击立即生效）',
              onPressed: _toggleOrSetDefault,
            ),
            if (!_isNew) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(LucideIcons.archive, size: 19, color: t.ink3),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                tooltip: '归档此成员',
                onPressed: () => _confirmArchive(context, ref),
              ),
            ],
            const SizedBox(width: 4),
            // 保存按钮（紧凑贴合，解决顶栏操作隔得太开的问题）
            TextButton(
              onPressed: _canSave ? _save : null,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                '保存',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: _canSave ? t.brandInk : t.ink4,
                ),
              ),
            ),
          ],
        ),
      ],
      child: ListView(
        padding: EdgeInsets.fromLTRB(0, 0, 0, 24 + bottomInset),
        children: [
          // ---------------- 顶部头像预览 ----------------
          const SizedBox(height: 8),
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickAndCropAvatar,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      PooperAvatar(
                        pooper: Pooper(
                          id: widget.pooper?.id ?? 'preview',
                          name: _name.text.trim().isEmpty ? '?' : _name.text.trim(),
                          iconKey: _effectiveIconKey,
                          avatarBlob: _effectiveAvatarBlob,
                          remark: null,
                          isDefault: _makeDefault,
                          archivedAt: null,
                          sortOrder: 0,
                          createdAt: DateTime.now(),
                        ),
                        size: 84,
                        radius: 28,
                        iconSize: 40,
                      ),
                      Positioned(
                        right: -3,
                        bottom: -3,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: t.brandFill,
                            shape: BoxShape.circle,
                            border: Border.all(color: t.paper, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 4,
                                offset: const Offset(0, 1.5),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            LucideIcons.camera,
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 20,
                  child: Center(
                    child: Text(
                      _avatarType == _AvatarType.custom
                          ? '当前使用：自定义照片头像（点击可更换）'
                          : (_avatarType == _AvatarType.initial
                              ? '当前使用：文字首字头像'
                              : '当前使用：${(kPooperIcons.where((e) => e.key == _effectiveIconKey).firstOrNull?.label ?? '专属图标').split('/').first} 图标'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: t.brandInk,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ---------------- 基础信息 ----------------
          const SettingsSectionLabel('基础信息'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SettingsCard(
              children: [
                // 成员称谓
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: TextField(
                    controller: _name,
                    maxLength: 20,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(fontSize: 15, color: t.ink),
                    decoration: InputDecoration(
                      hintText: '成员称谓（比如：我、宝子、咪咪）',
                      hintStyle: TextStyle(fontSize: 13.5, color: t.ink3),
                      border: InputBorder.none,
                      isDense: true,
                      counterText: '',
                    ),
                  ),
                ),
                Divider(height: 1, color: t.lineSoft),
                // 日常习惯备注（合并在卡片内，告别冗余占位与多余空白）
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: TextField(
                    controller: _remark,
                    maxLines: 2,
                    minLines: 1,
                    maxLength: 60,
                    style: TextStyle(fontSize: 14, height: 1.45, color: t.ink),
                    decoration: InputDecoration(
                      hintText: '日常习惯备注（可选，如：习惯晨起如厕、每天约1~2次等）',
                      hintStyle: TextStyle(fontSize: 13, color: t.ink3),
                      border: InputBorder.none,
                      isDense: true,
                      counterText: '',
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ---------------- 头像风格 ----------------
          const SettingsSectionLabel('头像风格'),
          SettingsCard(
            children: [
              // 1. 自定义照片头像选项行
              InkWell(
                onTap: () {
                  if (_customAvatarBlob != null) {
                    setState(() => _avatarType = _AvatarType.custom);
                  } else {
                    _pickAndCropAvatar();
                  }
                },
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(PoopRadii.card),
                ),
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _customAvatarBlob != null ? t.brandFill : t.paperDeep,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          clipBehavior: Clip.antiAlias,
                          alignment: Alignment.center,
                          child: _customAvatarBlob != null
                              ? Image.memory(
                                  _customAvatarBlob!,
                                  width: 36,
                                  height: 36,
                                  fit: BoxFit.cover,
                                )
                              : Icon(
                                  LucideIcons.image,
                                  size: 18,
                                  color: t.ink2,
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '自定义照片头像',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: t.ink,
                                ),
                              ),
                              const SizedBox(height: 1.5),
                              Text(
                                _customAvatarBlob != null
                                    ? (_avatarType == _AvatarType.custom
                                        ? '当前使用中 · 点击可重新裁切更换'
                                        : '已存有自定义照片 · 点击立即选用')
                                    : '从手机相册挑选照片并裁切截取',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: _avatarType == _AvatarType.custom
                                      ? t.brandInk
                                      : t.ink3,
                                  fontWeight: _avatarType == _AvatarType.custom
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_customAvatarBlob != null) ...[
                          IconButton(
                            icon: Icon(
                              LucideIcons.imagePlus,
                              size: 17,
                              color: t.brandInk,
                            ),
                            tooltip: '重新选择并裁切照片',
                            onPressed: _pickAndCropAvatar,
                          ),
                          IconButton(
                            icon: Icon(
                              LucideIcons.trash2,
                              size: 16,
                              color: t.danger,
                            ),
                            tooltip: '移除照片',
                            onPressed: () => setState(() {
                              _customAvatarBlob = null;
                              if (_avatarType == _AvatarType.custom) {
                                _avatarType = _AvatarType.initial;
                              }
                            }),
                          ),
                          Icon(
                            _avatarType == _AvatarType.custom
                                ? LucideIcons.circleCheck
                                : LucideIcons.circle,
                            size: 18,
                            color: _avatarType == _AvatarType.custom
                                ? t.brandInk
                                : t.lineSoft,
                          ),
                        ] else ...[
                          Icon(
                            LucideIcons.circle,
                            size: 18,
                            color: t.lineSoft,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // 2. 首字头像选项行
                InkWell(
                  onTap: () => setState(() => _avatarType = _AvatarType.initial),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _avatarType == _AvatarType.initial
                                ? t.brandFill
                                : t.paperDeep,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _name.text.trim().isEmpty
                                ? '字'
                                : initialOf(_name.text.trim()),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _avatarType == _AvatarType.initial
                                  ? Colors.white
                                  : t.ink2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '使用姓名首字',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: t.ink,
                                ),
                              ),
                              const SizedBox(height: 1.5),
                              Text(
                                '自动以名称第一个字作为极简头像',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: t.ink3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          _avatarType == _AvatarType.initial
                              ? LucideIcons.circleCheck
                              : LucideIcons.circle,
                          size: 18,
                          color: _avatarType == _AvatarType.initial
                              ? t.brandInk
                              : t.lineSoft,
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(height: 1, color: t.lineSoft),
                // 3. 精选专属图标网格（紧凑排列，消除下方多余空白）
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 2, bottom: 6),
                        child: Text(
                          '精选专属图标',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: t.ink3,
                          ),
                        ),
                      ),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: kPooperIcons.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 0.98,
                        ),
                        itemBuilder: (context, i) {
                          final opt = kPooperIcons[i];
                          final isSelected =
                              _avatarType == _AvatarType.icon &&
                              _effectiveIconKey == opt.key;
                          return _IconTile(
                            icon: opt.icon,
                            label: opt.label,
                            selected: isSelected,
                            onTap: () => setState(() {
                              _iconKey = opt.key;
                              _avatarType = _AvatarType.icon;
                            }),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

  bool get _canSave => _name.text.trim().isNotEmpty && !_saving;

  Future<void> _toggleOrSetDefault() async {
    if (_isNew) {
      setState(() => _makeDefault = !_makeDefault);
      HapticFeedback.selectionClick();
      return;
    }

    final p = widget.pooper;
    if (p == null) return;

    if (_makeDefault) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('「${p.name}」当前已是默认打卡人，系统须始终保留一个默认成员'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      return;
    }

    HapticFeedback.mediumImpact();
    final db = ref.read(databaseProvider);
    await db.setDefaultPooper(p.id);
    _refresh(ref);
    if (!mounted) return;
    setState(() => _makeDefault = true);

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('已将「${p.name}」设为默认打卡人（已实时生效）'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _confirmArchive(BuildContext context, WidgetRef ref) async {
    final p = widget.pooper;
    if (p == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('归档「${p.name}」？'),
        content: const Text('归档后不再出现在新建选择列表中，但日历历史记录与统计照常保留，可随时在列表下方恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('确认归档', style: TextStyle(color: context.tokens.danger)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    await ref.read(databaseProvider).archivePooper(p.id);
    _refresh(ref);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final remark = _remark.text.trim();

    try {
      if (_isNew) {
        await db.createPooper(
          name: name,
          iconKey: _effectiveIconKey,
          avatarBlob: _effectiveAvatarBlob,
          remark: remark.isEmpty ? null : remark,
          makeDefault: _makeDefault,
        );
      } else {
        await db.updatePooper(
          widget.pooper!.id,
          name: name,
          iconKey: _effectiveIconKey,
          clearIcon: _effectiveIconKey == null,
          avatarBlob: _effectiveAvatarBlob,
          clearAvatar: _effectiveAvatarBlob == null,
          remark: remark,
          clearRemark: remark.isEmpty,
        );
        // 如果在顶部被设为默认且之前不是默认，则更新默认状态
        if (_makeDefault && !widget.pooper!.isDefault) {
          await db.setDefaultPooper(widget.pooper!.id);
        }
      }

      _refresh(ref);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static void _refresh(WidgetRef ref) {
    ref.invalidate(allPoopersProvider);
    ref.invalidate(activePoopersProvider);
    ref.invalidate(monthBadgesProvider);
    ref.invalidate(weekBadgesProvider);
    ref.invalidate(dayRecordsProvider);
  }
}

/// 精选专属图标单元格项。
class _IconTile extends StatefulWidget {
  const _IconTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_IconTile> createState() => _IconTileState();
}

class _IconTileState extends State<_IconTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final selected = widget.selected;
    final shortName = widget.label.split('/').first;

    return Semantics(
      label: shortName,
      selected: selected,
      button: true,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1.0,
          duration: PoopMotions.pressDuration,
          curve: PoopMotions.pressCurve,
          child: AnimatedContainer(
            duration: PoopMotions.colorDuration,
            curve: PoopMotions.colorCurve,
            decoration: BoxDecoration(
              color: selected ? t.brandSoft : t.paperDeep,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? t.brandInk : Colors.transparent,
                width: 1.5,
              ),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Color(0x24A85F29),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.icon,
                  size: 20,
                  color: selected ? t.brandInk : t.ink,
                ),
                const SizedBox(height: 3),
                Text(
                  shortName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? t.brandInk : t.ink3,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
