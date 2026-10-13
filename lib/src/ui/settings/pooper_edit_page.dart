import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/database.dart';
import '../../data/pooper_actions.dart';
import '../../providers.dart';
import '../../state/calendar_data.dart';
import '../../theme/pooper_icons.dart';
import '../../theme/tokens.dart';
import '../widgets/pooper_avatar.dart';
import '../widgets/settings_widgets.dart';

/// 新增 / 编辑屙屎人（视觉稿 ⑫）。
///
/// [pooper] 为 null 时是新增。
///
/// **照片头像还没做** —— 数据结构（`Pooper.avatarBlob`）和渲染都已经支持了
/// （[PooperAvatar] 会优先用 blob），缺的是选图入口。
/// 那需要加 `image_picker` 依赖并处理缩略图压缩，单独一轮做更稳。
class PooperEditPage extends ConsumerStatefulWidget {
  const PooperEditPage({super.key, this.pooper});

  final Pooper? pooper;

  @override
  ConsumerState<PooperEditPage> createState() => _PooperEditPageState();
}

class _PooperEditPageState extends ConsumerState<PooperEditPage> {
  late final TextEditingController _name =
      TextEditingController(text: widget.pooper?.name ?? '');
  late final TextEditingController _remark =
      TextEditingController(text: widget.pooper?.remark ?? '');

  /// 选中的内置图标 key。null = 用姓名首字兜底。
  late String? _iconKey = widget.pooper?.iconKey;

  bool _makeDefault = false;
  bool _saving = false;

  bool get _isNew => widget.pooper == null;

  @override
  void dispose() {
    _name.dispose();
    _remark.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return SettingsScaffold(
      title: _isNew ? '新增屙屎人' : '编辑屙屎人',
      actions: [
        TextButton(
          onPressed: _canSave ? _save : null,
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
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          // ---------------- 预览 ----------------
          const SizedBox(height: 8),
          Center(
            child: Column(
              children: [
                // 用一个临时 Pooper 渲染预览 —— 这样"选了什么图标"
                // 和列表/日历里长什么样是同一套代码，不会出现预览和实际不一致。
                PooperAvatar(
                  pooper: Pooper(
                    id: widget.pooper?.id ?? 'preview',
                    name: _name.text.trim().isEmpty ? '?' : _name.text.trim(),
                    iconKey: _iconKey,
                    avatarBlob: widget.pooper?.avatarBlob,
                    remark: null,
                    isDefault: false,
                    archivedAt: null,
                    sortOrder: 0,
                    createdAt: DateTime.now(),
                  ),
                  size: 84,
                  radius: 28,
                  iconSize: 40,
                ),
                const SizedBox(height: 10),
                Text(
                  _iconKey == null ? '用姓名首字做头像' : '已选图标',
                  style: TextStyle(fontSize: 11.5, color: t.ink3),
                ),
              ],
            ),
          ),

          // ---------------- 名称 ----------------
          const SettingsSectionLabel('名称'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _name,
              maxLength: 20,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              style: TextStyle(fontSize: 15, color: t.ink),
              decoration: _inputDecoration(t, '比如：我、阿狗、咪咪'),
            ),
          ),

          // ---------------- 头像 ----------------
          SettingsSectionLabel('头像 ${_iconKey == null ? '· 当前用首字' : ''}'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // 「用首字」也做成一个可选项，而不是让用户猜怎么取消图标
                _IconOption(
                  selected: _iconKey == null,
                  label: '首字',
                  child: Text(
                    _name.text.trim().isEmpty
                        ? '?'
                        : initialOf(_name.text.trim()),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: t.ink2,
                    ),
                  ),
                  onTap: () => setState(() => _iconKey = null),
                ),
                for (final opt in kPooperIcons)
                  _IconOption(
                    selected: _iconKey == opt.key,
                    label: opt.key,
                    child: Icon(
                      opt.icon,
                      size: 20,
                      color: _iconKey == opt.key ? t.brandInk : t.ink2,
                    ),
                    onTap: () => setState(() => _iconKey = opt.key),
                  ),
              ],
            ),
          ),

          // ---------------- 备注 ----------------
          const SettingsSectionLabel('备注'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _remark,
              maxLines: 3,
              minLines: 2,
              maxLength: 80,
              style: TextStyle(fontSize: 14, height: 1.5, color: t.ink),
              decoration: _inputDecoration(t, '比如：起床后、午饭后各一次'),
            ),
          ),

          // ---------------- 默认 ----------------
          const SettingsSectionLabel('默认'),
          if (_isNew)
            SettingsCard(
              children: [
                SettingsRow(
                  title: '设为默认屙屎人',
                  subtitle: '「现在开屙」会记在他头上。'
                      '第一个添加的人会自动成为默认',
                  trailing: SettingsSwitch(
                    value: _makeDefault,
                    onChanged: (v) => setState(() => _makeDefault = v),
                  ),
                ),
              ],
            )
          else
            _ExistingPooperActions(
              pooper: widget.pooper!,
              onChanged: () => Navigator.of(context).pop(),
            ),
        ],
      ),
    );
  }

  bool get _canSave => _name.text.trim().isNotEmpty && !_saving;

  InputDecoration _inputDecoration(PoopTokens t, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13.5, color: t.ink3),
      filled: true,
      fillColor: t.surface,
      counterText: '',
      contentPadding: const EdgeInsets.all(13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: t.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: t.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: t.brandInk, width: 1.5),
      ),
    );
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
          iconKey: _iconKey,
          remark: remark.isEmpty ? null : remark,
          makeDefault: _makeDefault,
        );
      } else {
        await db.updatePooper(
          widget.pooper!.id,
          name: name,
          iconKey: _iconKey,
          clearIcon: _iconKey == null,
          remark: remark,
          clearRemark: remark.isEmpty,
        );
        // 这个开关只在新增时用；编辑时靠列表里的「设为默认」，
        // 所以这里不动 isDefault。
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

/// 编辑已有屙屎人时才出现的：设为默认 / 归档。
class _ExistingPooperActions extends ConsumerWidget {
  const _ExistingPooperActions({required this.pooper, required this.onChanged});

  final Pooper pooper;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final db = ref.read(databaseProvider);

    return Column(
      children: [
        SettingsCard(
          children: [
            SettingsRow(
              leading: LucideIcons.star,
              leadingColor: pooper.isDefault ? t.brandInk : t.ink3,
              leadingBackground: pooper.isDefault ? t.brandSoft : t.paperDeep,
              title: pooper.isDefault ? '当前就是默认' : '设为默认',
              subtitle: pooper.isDefault ? '「现在开屙」记在他头上' : null,
              trailing: pooper.isDefault ? null : const SettingsChevron(),
              onTap: pooper.isDefault
                  ? null
                  : () async {
                      await db.setDefaultPooper(pooper.id);
                      _PooperEditPageState._refresh(ref);
                      onChanged();
                    },
            ),
            SettingsRow(
              leading: LucideIcons.trash2,
              leadingColor: t.ink2,
              title: '归档',
              subtitle: '不再出现在「谁在屙」里，历史记录一条都不会少',
              trailing: const SettingsChevron(),
              onTap: () => _confirmArchive(context, ref),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
          child: Text(
            '这里刻意没有「删除」。删人会把他的历史记录一起抹掉 —— '
            '归档能达到同样的效果，而且不丢数据。',
            style: TextStyle(fontSize: 11.5, color: t.ink3, height: 1.6),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmArchive(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('归档「${pooper.name}」？'),
        content: const Text('他不再出现在「谁在屙」里，但历史记录和日历次数都保留。随时可以恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('归档'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    await ref.read(databaseProvider).archivePooper(pooper.id);
    _PooperEditPageState._refresh(ref);
    if (context.mounted) Navigator.of(context).pop();
  }
}

/// 图标选项。
class _IconOption extends StatelessWidget {
  const _IconOption({
    required this.selected,
    required this.label,
    required this.child,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      label: label,
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: selected ? t.brandSoft : t.surface,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected ? t.brandInk : t.lineSoft,
              width: selected ? 1.5 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}
