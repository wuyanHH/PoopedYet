import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:drift/drift.dart';

import '../widget/widget_binding.dart';
import '../widget/widget_snapshot_service.dart';
import 'database.dart';

/// 屙屎人的增删改。
///
/// 和 `database.dart` 里的生命周期方法（ensureDefaultPooper / archivePooper /
/// purgePooper / setDefaultPooper）是互补的：那些管"保证始终有可用的人"，
/// 这里管"用户在管理页上做的具体操作"。
extension PooperActions on AppDatabase {
  /// 新建一个屙屎人。
  ///
  /// 两种情况会自动成为默认，用户不用额外点一下：
  ///   - [makeDefault] 为 true
  ///   - **这是第一个活人**（否则新建完没有任何人是默认，FAB 不知道该记给谁）
  Future<Pooper> createPooper({
    required String name,
    String? iconKey,
    Uint8List? avatarBlob,
    String? remark,
    bool makeDefault = false,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('屙屎人名字不能为空');
    }

    final res = await transaction(() async {
      final alive = await activePoopers();
      final shouldBeDefault = makeDefault || alive.isEmpty;

      if (shouldBeDefault && alive.isNotEmpty) {
        // 先清空再设，否则会撞 ux_default_pooper 部分唯一索引。
        await update(poopers).write(const PoopersCompanion(isDefault: Value(false)));
      }

      final nextSort = alive.isEmpty
          ? 0
          : alive.map((p) => p.sortOrder).reduce(math.max) + 1;

      return into(poopers).insertReturning(
        PoopersCompanion.insert(
          name: trimmed,
          iconKey: Value(iconKey),
          avatarBlob: Value(avatarBlob),
          remark: Value(remark),
          isDefault: Value(shouldBeDefault),
          sortOrder: Value(nextSort),
        ),
      );
    });
    unawaited(WidgetSyncManager.sync(this));
    return res;
  }

  /// 改资料。只改传进来的字段，没传的保持原样。
  ///
  /// [clearIcon] / [clearAvatar] / [clearRemark] 是显式的"清空"开关 ——
  /// 只靠传 null 区分不了"不改"和"改成空"，这是 nullable 字段更新的老问题。
  Future<void> updatePooper(
    String id, {
    String? name,
    String? iconKey,
    Uint8List? avatarBlob,
    String? remark,
    bool clearIcon = false,
    bool clearAvatar = false,
    bool clearRemark = false,
  }) async {
    final companion = PoopersCompanion(
      name: name == null ? const Value.absent() : Value(name.trim()),
      iconKey: clearIcon
          ? const Value(null)
          : (iconKey == null ? const Value.absent() : Value(iconKey)),
      avatarBlob: clearAvatar
          ? const Value(null)
          : (avatarBlob == null ? const Value.absent() : Value(avatarBlob)),
      remark: clearRemark
          ? const Value(null)
          : (remark == null ? const Value.absent() : Value(remark.trim())),
    );
    await (update(poopers)..where((t) => t.id.equals(id))).write(companion);
    unawaited(WidgetSyncManager.sync(this));
  }

  /// 按给定顺序重排（拖拽排序落库）。
  ///
  /// 一次事务写全部，避免中途失败留下半套顺序。
  Future<void> reorderPoopers(List<String> idsInOrder) async {
    await transaction(() async {
      for (var i = 0; i < idsInOrder.length; i++) {
        await (update(poopers)..where((t) => t.id.equals(idsInOrder[i])))
            .write(PoopersCompanion(sortOrder: Value(i)));
      }
    });
    unawaited(WidgetSyncManager.sync(this));
  }

  /// 名字是否已经被别人用了（管理页用来提示，不强制阻止）。
  ///
  /// **不阻止**重名：一家人里叫"宝宝"的可能真有两个，
  /// 而且强行阻止会让用户卡在保存按钮上不知道为什么。提示一下就够。
  Future<bool> isNameTaken(String name, {String? exceptId}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    final q = select(poopers)..where((t) => t.name.equals(trimmed));
    final rows = await q.get();
    return rows.any((p) => p.id != exceptId);
  }

  // ─────────────────── 需要连带处理小组件绑定的生命周期操作 ───────────────────
  //
  // 归档 / 删除本身在 database.dart 里，是纯粹的数据操作。但凡是要经过
  // 「成员从可用列表里消失」这条路的管理动作，都得顺带把指向 TA 的小组件
  // 绑定收掉 —— 否则组件会静默显示成默认成员，用户只会看到「头像不对」。
  // 所以这里包一层，UI 一律调这两个，不要直接调 database.dart 的裸方法。

  /// 归档一个人，并解除所有指向 TA 的小组件绑定。
  Future<void> archivePooperAndDetachWidgets(String id) async {
    await archivePooper(id);
    await const WidgetBindingService().clearBindingsFor(id);
    // 绑定收干净之后再同步一次快照，让桌面拿到的是
    // 「人已归档 + 绑定已收回」的最终状态，而不是中间态。
    await WidgetSyncManager.sync(this);
  }

  /// **危险操作**：彻底删除一个人（连同其全部记录），并解除小组件绑定。
  ///
  /// 返回被删掉的记录条数，供 UI 告知用户实际损失。
  Future<int> purgePooperAndDetachWidgets(String id) async {
    // 先解绑再删：删完之后快照里就没有这个人了，
    // 再想找出「哪些组件绑着 TA」只能靠残留的绑定键，容易漏。
    await const WidgetBindingService().clearBindingsFor(id);
    final deleted = await purgePooper(id);
    await WidgetSyncManager.sync(this);
    return deleted;
  }
}
