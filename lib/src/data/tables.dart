import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// 生成主键。
///
/// 必须是**公开**的顶层函数：`database.g.dart` 是 `database.dart` 的 part，
/// 引用不到本文件的私有成员，`_uuid` 会让生成代码报 undefined_identifier。
String newId() => const Uuid().v4();

/// 屙屎人。
///
/// **注意 [archivedAt] 而不是真删**：删人 = 归档。
/// 早期设计里 pooper 删除走外键 CASCADE，会把这个人几百条历史记录一起静默抹掉，
/// 那是不可接受的数据丢失。见 `docs/design-system.md` §9d。
@DataClassName('Pooper')
class Poopers extends Table {
  TextColumn get id => text().clientDefault(newId)();

  TextColumn get name => text().withLength(min: 1, max: 40)();

  /// 内置 Lucide 图标名（如 `dog`）。与 [avatarBlob] 二选一，都为 null 时用姓名首字。
  TextColumn get iconKey => text().nullable()();

  /// 上传头像的 96px 缩略图，**直接入库**。
  ///
  /// 不存文件路径：重装 App 或换机恢复后路径会失效，头像集体变默认，
  /// 用户会以为数据丢了。几十 KB 一张，几百个人也才几 MB。
  BlobColumn get avatarBlob => blob().nullable()();

  /// 备注，如"起床后、午饭后各一次"。
  TextColumn get remark => text().nullable()();

  /// 全局最多一个为 true。由 `ux_default_pooper` 部分唯一索引强制。
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  /// 有值 = 已归档。历史记录原样保留，但不再出现在选择器里。
  DateTimeColumn get archivedAt => dateTime().nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {id};
}

/// 一次拉屎。
@DataClassName('PoopRecord')
class PoopRecords extends Table {
  TextColumn get id => text().clientDefault(newId)();

  /// ⚠ **故意不用 `KeyAction.cascade`。**
  ///
  /// 用 `restrict`：万一有人写了 `DELETE FROM poopers`，数据库会直接报错，
  /// 而不是把历史记录一起悄悄删掉。数据丢失应该是响亮的失败，不是静默的成功。
  /// 真要彻底删除，走设置页的「危险操作」，它会先明确删掉记录再删人。
  TextColumn get pooperId =>
      text().references(Poopers, #id, onDelete: KeyAction.restrict)();

  /// 开始时间。**必填**，也是这条记录归属哪一天的依据（跨零点按开始时间归属）。
  DateTimeColumn get startedAt => dateTime()();

  /// 结束时间。**非必填** —— 这是需求里明确要求的。
  ///
  /// 但"没有结束时间"**不等于**"正在屙"，见 [endUnknown]。
  DateTimeColumn get endedAt => dateTime().nullable()();

  /// 用户明确表示"没记结束时间"。
  ///
  /// 不加这个字段的话，"没有结束时间"会被当成"还在进行中"，
  /// 于是忘点一次结束，那条记录就永远挂着，还会被唯一索引挡住下一次记录。
  ///
  /// 不变式：`endedAt != null ⇒ endUnknown == false`。
  BoolColumn get endUnknown => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {id};
}

/// 一条备注（自带时刻）。
///
/// 需求原文：「可以给每次拉屎添加备注，可以是多条备注，备注也有实时的时间和备注信息」。
/// 所以备注是**独立成表**的带时刻实体，不是在记录上挂一个 JSON 数组 ——
/// 独立成表才能单独增删改、单独排序、将来做备注级统计。
@DataClassName('PoopNote')
class PoopNotes extends Table {
  TextColumn get id => text().clientDefault(newId)();

  /// 备注**属于**记录，记录没了备注也没意义，所以这里用 CASCADE 是对的。
  TextColumn get recordId =>
      text().references(PoopRecords, #id, onDelete: KeyAction.cascade)();

  TextColumn get content => text()();

  /// 这条备注写下的时刻（"实时的时间"）。
  DateTimeColumn get notedAt => dateTime()();

  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {id};
}

/// 默认备注模板（"拉肚子""很顺畅"…）。
@DataClassName('NoteTemplate')
class NoteTemplates extends Table {
  TextColumn get id => text().clientDefault(newId)();

  TextColumn get content => text()();

  /// 用过几次。用来排序和显示"常用"。
  IntColumn get useCount => integer().withDefault(const Constant(0))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {id};
}

/// 中国法定节假日 / 调休上班日。打包进 APK，只读。
///
/// 三态：休（[isOffDay] = true）/ 班（[isOffDay] = false）/ 无记录（普通日子）。
/// 注意 `isOffDay = false` 的那批恰恰是**周末补班**，视觉上是蓝色「班」角标。
@DataClassName('Holiday')
class Holidays extends Table {
  /// `YYYY-MM-DD`
  TextColumn get date => text()();

  TextColumn get name => text().nullable()();

  BoolColumn get isOffDay => boolean()();

  @override
  Set<Column> get primaryKey => {date};
}
