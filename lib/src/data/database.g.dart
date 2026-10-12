// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $PoopersTable extends Poopers with TableInfo<$PoopersTable, Pooper> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PoopersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: newId,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 40,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconKeyMeta = const VerificationMeta(
    'iconKey',
  );
  @override
  late final GeneratedColumn<String> iconKey = GeneratedColumn<String>(
    'icon_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _avatarBlobMeta = const VerificationMeta(
    'avatarBlob',
  );
  @override
  late final GeneratedColumn<Uint8List> avatarBlob = GeneratedColumn<Uint8List>(
    'avatar_blob',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remarkMeta = const VerificationMeta('remark');
  @override
  late final GeneratedColumn<String> remark = GeneratedColumn<String>(
    'remark',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    iconKey,
    avatarBlob,
    remark,
    isDefault,
    archivedAt,
    sortOrder,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'poopers';
  @override
  VerificationContext validateIntegrity(
    Insertable<Pooper> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('icon_key')) {
      context.handle(
        _iconKeyMeta,
        iconKey.isAcceptableOrUnknown(data['icon_key']!, _iconKeyMeta),
      );
    }
    if (data.containsKey('avatar_blob')) {
      context.handle(
        _avatarBlobMeta,
        avatarBlob.isAcceptableOrUnknown(data['avatar_blob']!, _avatarBlobMeta),
      );
    }
    if (data.containsKey('remark')) {
      context.handle(
        _remarkMeta,
        remark.isAcceptableOrUnknown(data['remark']!, _remarkMeta),
      );
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Pooper map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Pooper(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      iconKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_key'],
      ),
      avatarBlob: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}avatar_blob'],
      ),
      remark: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remark'],
      ),
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PoopersTable createAlias(String alias) {
    return $PoopersTable(attachedDatabase, alias);
  }
}

class Pooper extends DataClass implements Insertable<Pooper> {
  final String id;
  final String name;

  /// 内置 Lucide 图标名（如 `dog`）。与 [avatarBlob] 二选一，都为 null 时用姓名首字。
  final String? iconKey;

  /// 上传头像的 96px 缩略图，**直接入库**。
  ///
  /// 不存文件路径：重装 App 或换机恢复后路径会失效，头像集体变默认，
  /// 用户会以为数据丢了。几十 KB 一张，几百个人也才几 MB。
  final Uint8List? avatarBlob;

  /// 备注，如"起床后、午饭后各一次"。
  final String? remark;

  /// 全局最多一个为 true。由 `ux_default_pooper` 部分唯一索引强制。
  final bool isDefault;

  /// 有值 = 已归档。历史记录原样保留，但不再出现在选择器里。
  final DateTime? archivedAt;
  final int sortOrder;
  final DateTime createdAt;
  const Pooper({
    required this.id,
    required this.name,
    this.iconKey,
    this.avatarBlob,
    this.remark,
    required this.isDefault,
    this.archivedAt,
    required this.sortOrder,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || iconKey != null) {
      map['icon_key'] = Variable<String>(iconKey);
    }
    if (!nullToAbsent || avatarBlob != null) {
      map['avatar_blob'] = Variable<Uint8List>(avatarBlob);
    }
    if (!nullToAbsent || remark != null) {
      map['remark'] = Variable<String>(remark);
    }
    map['is_default'] = Variable<bool>(isDefault);
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PoopersCompanion toCompanion(bool nullToAbsent) {
    return PoopersCompanion(
      id: Value(id),
      name: Value(name),
      iconKey: iconKey == null && nullToAbsent
          ? const Value.absent()
          : Value(iconKey),
      avatarBlob: avatarBlob == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarBlob),
      remark: remark == null && nullToAbsent
          ? const Value.absent()
          : Value(remark),
      isDefault: Value(isDefault),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
    );
  }

  factory Pooper.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Pooper(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      iconKey: serializer.fromJson<String?>(json['iconKey']),
      avatarBlob: serializer.fromJson<Uint8List?>(json['avatarBlob']),
      remark: serializer.fromJson<String?>(json['remark']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'iconKey': serializer.toJson<String?>(iconKey),
      'avatarBlob': serializer.toJson<Uint8List?>(avatarBlob),
      'remark': serializer.toJson<String?>(remark),
      'isDefault': serializer.toJson<bool>(isDefault),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Pooper copyWith({
    String? id,
    String? name,
    Value<String?> iconKey = const Value.absent(),
    Value<Uint8List?> avatarBlob = const Value.absent(),
    Value<String?> remark = const Value.absent(),
    bool? isDefault,
    Value<DateTime?> archivedAt = const Value.absent(),
    int? sortOrder,
    DateTime? createdAt,
  }) => Pooper(
    id: id ?? this.id,
    name: name ?? this.name,
    iconKey: iconKey.present ? iconKey.value : this.iconKey,
    avatarBlob: avatarBlob.present ? avatarBlob.value : this.avatarBlob,
    remark: remark.present ? remark.value : this.remark,
    isDefault: isDefault ?? this.isDefault,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
  );
  Pooper copyWithCompanion(PoopersCompanion data) {
    return Pooper(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      iconKey: data.iconKey.present ? data.iconKey.value : this.iconKey,
      avatarBlob: data.avatarBlob.present
          ? data.avatarBlob.value
          : this.avatarBlob,
      remark: data.remark.present ? data.remark.value : this.remark,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Pooper(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('iconKey: $iconKey, ')
          ..write('avatarBlob: $avatarBlob, ')
          ..write('remark: $remark, ')
          ..write('isDefault: $isDefault, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    iconKey,
    $driftBlobEquality.hash(avatarBlob),
    remark,
    isDefault,
    archivedAt,
    sortOrder,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Pooper &&
          other.id == this.id &&
          other.name == this.name &&
          other.iconKey == this.iconKey &&
          $driftBlobEquality.equals(other.avatarBlob, this.avatarBlob) &&
          other.remark == this.remark &&
          other.isDefault == this.isDefault &&
          other.archivedAt == this.archivedAt &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt);
}

class PoopersCompanion extends UpdateCompanion<Pooper> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> iconKey;
  final Value<Uint8List?> avatarBlob;
  final Value<String?> remark;
  final Value<bool> isDefault;
  final Value<DateTime?> archivedAt;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const PoopersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.iconKey = const Value.absent(),
    this.avatarBlob = const Value.absent(),
    this.remark = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PoopersCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.iconKey = const Value.absent(),
    this.avatarBlob = const Value.absent(),
    this.remark = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Pooper> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? iconKey,
    Expression<Uint8List>? avatarBlob,
    Expression<String>? remark,
    Expression<bool>? isDefault,
    Expression<DateTime>? archivedAt,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (iconKey != null) 'icon_key': iconKey,
      if (avatarBlob != null) 'avatar_blob': avatarBlob,
      if (remark != null) 'remark': remark,
      if (isDefault != null) 'is_default': isDefault,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PoopersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? iconKey,
    Value<Uint8List?>? avatarBlob,
    Value<String?>? remark,
    Value<bool>? isDefault,
    Value<DateTime?>? archivedAt,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return PoopersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
      avatarBlob: avatarBlob ?? this.avatarBlob,
      remark: remark ?? this.remark,
      isDefault: isDefault ?? this.isDefault,
      archivedAt: archivedAt ?? this.archivedAt,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (iconKey.present) {
      map['icon_key'] = Variable<String>(iconKey.value);
    }
    if (avatarBlob.present) {
      map['avatar_blob'] = Variable<Uint8List>(avatarBlob.value);
    }
    if (remark.present) {
      map['remark'] = Variable<String>(remark.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PoopersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('iconKey: $iconKey, ')
          ..write('avatarBlob: $avatarBlob, ')
          ..write('remark: $remark, ')
          ..write('isDefault: $isDefault, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PoopRecordsTable extends PoopRecords
    with TableInfo<$PoopRecordsTable, PoopRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PoopRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: newId,
  );
  static const VerificationMeta _pooperIdMeta = const VerificationMeta(
    'pooperId',
  );
  @override
  late final GeneratedColumn<String> pooperId = GeneratedColumn<String>(
    'pooper_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES poopers (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endUnknownMeta = const VerificationMeta(
    'endUnknown',
  );
  @override
  late final GeneratedColumn<bool> endUnknown = GeneratedColumn<bool>(
    'end_unknown',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("end_unknown" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    pooperId,
    startedAt,
    endedAt,
    endUnknown,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'poop_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<PoopRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('pooper_id')) {
      context.handle(
        _pooperIdMeta,
        pooperId.isAcceptableOrUnknown(data['pooper_id']!, _pooperIdMeta),
      );
    } else if (isInserting) {
      context.missing(_pooperIdMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('end_unknown')) {
      context.handle(
        _endUnknownMeta,
        endUnknown.isAcceptableOrUnknown(data['end_unknown']!, _endUnknownMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PoopRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PoopRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      pooperId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pooper_id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
      endUnknown: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}end_unknown'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PoopRecordsTable createAlias(String alias) {
    return $PoopRecordsTable(attachedDatabase, alias);
  }
}

class PoopRecord extends DataClass implements Insertable<PoopRecord> {
  final String id;

  /// ⚠ **故意不用 `KeyAction.cascade`。**
  ///
  /// 用 `restrict`：万一有人写了 `DELETE FROM poopers`，数据库会直接报错，
  /// 而不是把历史记录一起悄悄删掉。数据丢失应该是响亮的失败，不是静默的成功。
  /// 真要彻底删除，走设置页的「危险操作」，它会先明确删掉记录再删人。
  final String pooperId;

  /// 开始时间。**必填**，也是这条记录归属哪一天的依据（跨零点按开始时间归属）。
  final DateTime startedAt;

  /// 结束时间。**非必填** —— 这是需求里明确要求的。
  ///
  /// 但"没有结束时间"**不等于**"正在屙"，见 [endUnknown]。
  final DateTime? endedAt;

  /// 用户明确表示"没记结束时间"。
  ///
  /// 不加这个字段的话，"没有结束时间"会被当成"还在进行中"，
  /// 于是忘点一次结束，那条记录就永远挂着，还会被唯一索引挡住下一次记录。
  ///
  /// 不变式：`endedAt != null ⇒ endUnknown == false`。
  final bool endUnknown;
  final DateTime createdAt;
  const PoopRecord({
    required this.id,
    required this.pooperId,
    required this.startedAt,
    this.endedAt,
    required this.endUnknown,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['pooper_id'] = Variable<String>(pooperId);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    map['end_unknown'] = Variable<bool>(endUnknown);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PoopRecordsCompanion toCompanion(bool nullToAbsent) {
    return PoopRecordsCompanion(
      id: Value(id),
      pooperId: Value(pooperId),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      endUnknown: Value(endUnknown),
      createdAt: Value(createdAt),
    );
  }

  factory PoopRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PoopRecord(
      id: serializer.fromJson<String>(json['id']),
      pooperId: serializer.fromJson<String>(json['pooperId']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      endUnknown: serializer.fromJson<bool>(json['endUnknown']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'pooperId': serializer.toJson<String>(pooperId),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'endUnknown': serializer.toJson<bool>(endUnknown),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PoopRecord copyWith({
    String? id,
    String? pooperId,
    DateTime? startedAt,
    Value<DateTime?> endedAt = const Value.absent(),
    bool? endUnknown,
    DateTime? createdAt,
  }) => PoopRecord(
    id: id ?? this.id,
    pooperId: pooperId ?? this.pooperId,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    endUnknown: endUnknown ?? this.endUnknown,
    createdAt: createdAt ?? this.createdAt,
  );
  PoopRecord copyWithCompanion(PoopRecordsCompanion data) {
    return PoopRecord(
      id: data.id.present ? data.id.value : this.id,
      pooperId: data.pooperId.present ? data.pooperId.value : this.pooperId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      endUnknown: data.endUnknown.present
          ? data.endUnknown.value
          : this.endUnknown,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PoopRecord(')
          ..write('id: $id, ')
          ..write('pooperId: $pooperId, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('endUnknown: $endUnknown, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, pooperId, startedAt, endedAt, endUnknown, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PoopRecord &&
          other.id == this.id &&
          other.pooperId == this.pooperId &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.endUnknown == this.endUnknown &&
          other.createdAt == this.createdAt);
}

class PoopRecordsCompanion extends UpdateCompanion<PoopRecord> {
  final Value<String> id;
  final Value<String> pooperId;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<bool> endUnknown;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const PoopRecordsCompanion({
    this.id = const Value.absent(),
    this.pooperId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.endUnknown = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PoopRecordsCompanion.insert({
    this.id = const Value.absent(),
    required String pooperId,
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    this.endUnknown = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : pooperId = Value(pooperId),
       startedAt = Value(startedAt);
  static Insertable<PoopRecord> custom({
    Expression<String>? id,
    Expression<String>? pooperId,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<bool>? endUnknown,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (pooperId != null) 'pooper_id': pooperId,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (endUnknown != null) 'end_unknown': endUnknown,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PoopRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? pooperId,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endedAt,
    Value<bool>? endUnknown,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return PoopRecordsCompanion(
      id: id ?? this.id,
      pooperId: pooperId ?? this.pooperId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      endUnknown: endUnknown ?? this.endUnknown,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (pooperId.present) {
      map['pooper_id'] = Variable<String>(pooperId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (endUnknown.present) {
      map['end_unknown'] = Variable<bool>(endUnknown.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PoopRecordsCompanion(')
          ..write('id: $id, ')
          ..write('pooperId: $pooperId, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('endUnknown: $endUnknown, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PoopNotesTable extends PoopNotes
    with TableInfo<$PoopNotesTable, PoopNote> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PoopNotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: newId,
  );
  static const VerificationMeta _recordIdMeta = const VerificationMeta(
    'recordId',
  );
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
    'record_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES poop_records (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notedAtMeta = const VerificationMeta(
    'notedAt',
  );
  @override
  late final GeneratedColumn<DateTime> notedAt = GeneratedColumn<DateTime>(
    'noted_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    recordId,
    content,
    notedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'poop_notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<PoopNote> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('record_id')) {
      context.handle(
        _recordIdMeta,
        recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta),
      );
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('noted_at')) {
      context.handle(
        _notedAtMeta,
        notedAt.isAcceptableOrUnknown(data['noted_at']!, _notedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_notedAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PoopNote map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PoopNote(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      recordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_id'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      notedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}noted_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PoopNotesTable createAlias(String alias) {
    return $PoopNotesTable(attachedDatabase, alias);
  }
}

class PoopNote extends DataClass implements Insertable<PoopNote> {
  final String id;

  /// 备注**属于**记录，记录没了备注也没意义，所以这里用 CASCADE 是对的。
  final String recordId;
  final String content;

  /// 这条备注写下的时刻（"实时的时间"）。
  final DateTime notedAt;
  final DateTime createdAt;
  const PoopNote({
    required this.id,
    required this.recordId,
    required this.content,
    required this.notedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['record_id'] = Variable<String>(recordId);
    map['content'] = Variable<String>(content);
    map['noted_at'] = Variable<DateTime>(notedAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PoopNotesCompanion toCompanion(bool nullToAbsent) {
    return PoopNotesCompanion(
      id: Value(id),
      recordId: Value(recordId),
      content: Value(content),
      notedAt: Value(notedAt),
      createdAt: Value(createdAt),
    );
  }

  factory PoopNote.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PoopNote(
      id: serializer.fromJson<String>(json['id']),
      recordId: serializer.fromJson<String>(json['recordId']),
      content: serializer.fromJson<String>(json['content']),
      notedAt: serializer.fromJson<DateTime>(json['notedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'recordId': serializer.toJson<String>(recordId),
      'content': serializer.toJson<String>(content),
      'notedAt': serializer.toJson<DateTime>(notedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PoopNote copyWith({
    String? id,
    String? recordId,
    String? content,
    DateTime? notedAt,
    DateTime? createdAt,
  }) => PoopNote(
    id: id ?? this.id,
    recordId: recordId ?? this.recordId,
    content: content ?? this.content,
    notedAt: notedAt ?? this.notedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  PoopNote copyWithCompanion(PoopNotesCompanion data) {
    return PoopNote(
      id: data.id.present ? data.id.value : this.id,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      content: data.content.present ? data.content.value : this.content,
      notedAt: data.notedAt.present ? data.notedAt.value : this.notedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PoopNote(')
          ..write('id: $id, ')
          ..write('recordId: $recordId, ')
          ..write('content: $content, ')
          ..write('notedAt: $notedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, recordId, content, notedAt, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PoopNote &&
          other.id == this.id &&
          other.recordId == this.recordId &&
          other.content == this.content &&
          other.notedAt == this.notedAt &&
          other.createdAt == this.createdAt);
}

class PoopNotesCompanion extends UpdateCompanion<PoopNote> {
  final Value<String> id;
  final Value<String> recordId;
  final Value<String> content;
  final Value<DateTime> notedAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const PoopNotesCompanion({
    this.id = const Value.absent(),
    this.recordId = const Value.absent(),
    this.content = const Value.absent(),
    this.notedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PoopNotesCompanion.insert({
    this.id = const Value.absent(),
    required String recordId,
    required String content,
    required DateTime notedAt,
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : recordId = Value(recordId),
       content = Value(content),
       notedAt = Value(notedAt);
  static Insertable<PoopNote> custom({
    Expression<String>? id,
    Expression<String>? recordId,
    Expression<String>? content,
    Expression<DateTime>? notedAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (recordId != null) 'record_id': recordId,
      if (content != null) 'content': content,
      if (notedAt != null) 'noted_at': notedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PoopNotesCompanion copyWith({
    Value<String>? id,
    Value<String>? recordId,
    Value<String>? content,
    Value<DateTime>? notedAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return PoopNotesCompanion(
      id: id ?? this.id,
      recordId: recordId ?? this.recordId,
      content: content ?? this.content,
      notedAt: notedAt ?? this.notedAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (notedAt.present) {
      map['noted_at'] = Variable<DateTime>(notedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PoopNotesCompanion(')
          ..write('id: $id, ')
          ..write('recordId: $recordId, ')
          ..write('content: $content, ')
          ..write('notedAt: $notedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NoteTemplatesTable extends NoteTemplates
    with TableInfo<$NoteTemplatesTable, NoteTemplate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteTemplatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: newId,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _useCountMeta = const VerificationMeta(
    'useCount',
  );
  @override
  late final GeneratedColumn<int> useCount = GeneratedColumn<int>(
    'use_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    content,
    useCount,
    sortOrder,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_templates';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoteTemplate> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('use_count')) {
      context.handle(
        _useCountMeta,
        useCount.isAcceptableOrUnknown(data['use_count']!, _useCountMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NoteTemplate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteTemplate(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      useCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}use_count'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $NoteTemplatesTable createAlias(String alias) {
    return $NoteTemplatesTable(attachedDatabase, alias);
  }
}

class NoteTemplate extends DataClass implements Insertable<NoteTemplate> {
  final String id;
  final String content;

  /// 用过几次。用来排序和显示"常用"。
  final int useCount;
  final int sortOrder;
  final DateTime createdAt;
  const NoteTemplate({
    required this.id,
    required this.content,
    required this.useCount,
    required this.sortOrder,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['content'] = Variable<String>(content);
    map['use_count'] = Variable<int>(useCount);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  NoteTemplatesCompanion toCompanion(bool nullToAbsent) {
    return NoteTemplatesCompanion(
      id: Value(id),
      content: Value(content),
      useCount: Value(useCount),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
    );
  }

  factory NoteTemplate.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteTemplate(
      id: serializer.fromJson<String>(json['id']),
      content: serializer.fromJson<String>(json['content']),
      useCount: serializer.fromJson<int>(json['useCount']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'content': serializer.toJson<String>(content),
      'useCount': serializer.toJson<int>(useCount),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  NoteTemplate copyWith({
    String? id,
    String? content,
    int? useCount,
    int? sortOrder,
    DateTime? createdAt,
  }) => NoteTemplate(
    id: id ?? this.id,
    content: content ?? this.content,
    useCount: useCount ?? this.useCount,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
  );
  NoteTemplate copyWithCompanion(NoteTemplatesCompanion data) {
    return NoteTemplate(
      id: data.id.present ? data.id.value : this.id,
      content: data.content.present ? data.content.value : this.content,
      useCount: data.useCount.present ? data.useCount.value : this.useCount,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteTemplate(')
          ..write('id: $id, ')
          ..write('content: $content, ')
          ..write('useCount: $useCount, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, content, useCount, sortOrder, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteTemplate &&
          other.id == this.id &&
          other.content == this.content &&
          other.useCount == this.useCount &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt);
}

class NoteTemplatesCompanion extends UpdateCompanion<NoteTemplate> {
  final Value<String> id;
  final Value<String> content;
  final Value<int> useCount;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const NoteTemplatesCompanion({
    this.id = const Value.absent(),
    this.content = const Value.absent(),
    this.useCount = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NoteTemplatesCompanion.insert({
    this.id = const Value.absent(),
    required String content,
    this.useCount = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : content = Value(content);
  static Insertable<NoteTemplate> custom({
    Expression<String>? id,
    Expression<String>? content,
    Expression<int>? useCount,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (content != null) 'content': content,
      if (useCount != null) 'use_count': useCount,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NoteTemplatesCompanion copyWith({
    Value<String>? id,
    Value<String>? content,
    Value<int>? useCount,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return NoteTemplatesCompanion(
      id: id ?? this.id,
      content: content ?? this.content,
      useCount: useCount ?? this.useCount,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (useCount.present) {
      map['use_count'] = Variable<int>(useCount.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteTemplatesCompanion(')
          ..write('id: $id, ')
          ..write('content: $content, ')
          ..write('useCount: $useCount, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HolidaysTable extends Holidays with TableInfo<$HolidaysTable, Holiday> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HolidaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isOffDayMeta = const VerificationMeta(
    'isOffDay',
  );
  @override
  late final GeneratedColumn<bool> isOffDay = GeneratedColumn<bool>(
    'is_off_day',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_off_day" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [date, name, isOffDay];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'holidays';
  @override
  VerificationContext validateIntegrity(
    Insertable<Holiday> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('is_off_day')) {
      context.handle(
        _isOffDayMeta,
        isOffDay.isAcceptableOrUnknown(data['is_off_day']!, _isOffDayMeta),
      );
    } else if (isInserting) {
      context.missing(_isOffDayMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {date};
  @override
  Holiday map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Holiday(
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      isOffDay: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_off_day'],
      )!,
    );
  }

  @override
  $HolidaysTable createAlias(String alias) {
    return $HolidaysTable(attachedDatabase, alias);
  }
}

class Holiday extends DataClass implements Insertable<Holiday> {
  /// `YYYY-MM-DD`
  final String date;
  final String? name;
  final bool isOffDay;
  const Holiday({required this.date, this.name, required this.isOffDay});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date'] = Variable<String>(date);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    map['is_off_day'] = Variable<bool>(isOffDay);
    return map;
  }

  HolidaysCompanion toCompanion(bool nullToAbsent) {
    return HolidaysCompanion(
      date: Value(date),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      isOffDay: Value(isOffDay),
    );
  }

  factory Holiday.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Holiday(
      date: serializer.fromJson<String>(json['date']),
      name: serializer.fromJson<String?>(json['name']),
      isOffDay: serializer.fromJson<bool>(json['isOffDay']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'date': serializer.toJson<String>(date),
      'name': serializer.toJson<String?>(name),
      'isOffDay': serializer.toJson<bool>(isOffDay),
    };
  }

  Holiday copyWith({
    String? date,
    Value<String?> name = const Value.absent(),
    bool? isOffDay,
  }) => Holiday(
    date: date ?? this.date,
    name: name.present ? name.value : this.name,
    isOffDay: isOffDay ?? this.isOffDay,
  );
  Holiday copyWithCompanion(HolidaysCompanion data) {
    return Holiday(
      date: data.date.present ? data.date.value : this.date,
      name: data.name.present ? data.name.value : this.name,
      isOffDay: data.isOffDay.present ? data.isOffDay.value : this.isOffDay,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Holiday(')
          ..write('date: $date, ')
          ..write('name: $name, ')
          ..write('isOffDay: $isOffDay')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(date, name, isOffDay);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Holiday &&
          other.date == this.date &&
          other.name == this.name &&
          other.isOffDay == this.isOffDay);
}

class HolidaysCompanion extends UpdateCompanion<Holiday> {
  final Value<String> date;
  final Value<String?> name;
  final Value<bool> isOffDay;
  final Value<int> rowid;
  const HolidaysCompanion({
    this.date = const Value.absent(),
    this.name = const Value.absent(),
    this.isOffDay = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HolidaysCompanion.insert({
    required String date,
    this.name = const Value.absent(),
    required bool isOffDay,
    this.rowid = const Value.absent(),
  }) : date = Value(date),
       isOffDay = Value(isOffDay);
  static Insertable<Holiday> custom({
    Expression<String>? date,
    Expression<String>? name,
    Expression<bool>? isOffDay,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (date != null) 'date': date,
      if (name != null) 'name': name,
      if (isOffDay != null) 'is_off_day': isOffDay,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HolidaysCompanion copyWith({
    Value<String>? date,
    Value<String?>? name,
    Value<bool>? isOffDay,
    Value<int>? rowid,
  }) {
    return HolidaysCompanion(
      date: date ?? this.date,
      name: name ?? this.name,
      isOffDay: isOffDay ?? this.isOffDay,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isOffDay.present) {
      map['is_off_day'] = Variable<bool>(isOffDay.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HolidaysCompanion(')
          ..write('date: $date, ')
          ..write('name: $name, ')
          ..write('isOffDay: $isOffDay, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PoopersTable poopers = $PoopersTable(this);
  late final $PoopRecordsTable poopRecords = $PoopRecordsTable(this);
  late final $PoopNotesTable poopNotes = $PoopNotesTable(this);
  late final $NoteTemplatesTable noteTemplates = $NoteTemplatesTable(this);
  late final $HolidaysTable holidays = $HolidaysTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    poopers,
    poopRecords,
    poopNotes,
    noteTemplates,
    holidays,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'poop_records',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('poop_notes', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$PoopersTableCreateCompanionBuilder =
    PoopersCompanion Function({
      Value<String> id,
      required String name,
      Value<String?> iconKey,
      Value<Uint8List?> avatarBlob,
      Value<String?> remark,
      Value<bool> isDefault,
      Value<DateTime?> archivedAt,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$PoopersTableUpdateCompanionBuilder =
    PoopersCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> iconKey,
      Value<Uint8List?> avatarBlob,
      Value<String?> remark,
      Value<bool> isDefault,
      Value<DateTime?> archivedAt,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$PoopersTableReferences
    extends BaseReferences<_$AppDatabase, $PoopersTable, Pooper> {
  $$PoopersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PoopRecordsTable, List<PoopRecord>>
  _poopRecordsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.poopRecords,
    aliasName: 'poopers__id__poop_records__pooper_id',
  );

  $$PoopRecordsTableProcessedTableManager get poopRecordsRefs {
    final manager = $$PoopRecordsTableTableManager(
      $_db,
      $_db.poopRecords,
    ).filter((f) => f.pooperId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_poopRecordsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PoopersTableFilterComposer
    extends Composer<_$AppDatabase, $PoopersTable> {
  $$PoopersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconKey => $composableBuilder(
    column: $table.iconKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get avatarBlob => $composableBuilder(
    column: $table.avatarBlob,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remark => $composableBuilder(
    column: $table.remark,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> poopRecordsRefs(
    Expression<bool> Function($$PoopRecordsTableFilterComposer f) f,
  ) {
    final $$PoopRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.poopRecords,
      getReferencedColumn: (t) => t.pooperId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoopRecordsTableFilterComposer(
            $db: $db,
            $table: $db.poopRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PoopersTableOrderingComposer
    extends Composer<_$AppDatabase, $PoopersTable> {
  $$PoopersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconKey => $composableBuilder(
    column: $table.iconKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get avatarBlob => $composableBuilder(
    column: $table.avatarBlob,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remark => $composableBuilder(
    column: $table.remark,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PoopersTableAnnotationComposer
    extends Composer<_$AppDatabase, $PoopersTable> {
  $$PoopersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get iconKey =>
      $composableBuilder(column: $table.iconKey, builder: (column) => column);

  GeneratedColumn<Uint8List> get avatarBlob => $composableBuilder(
    column: $table.avatarBlob,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remark =>
      $composableBuilder(column: $table.remark, builder: (column) => column);

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> poopRecordsRefs<T extends Object>(
    Expression<T> Function($$PoopRecordsTableAnnotationComposer a) f,
  ) {
    final $$PoopRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.poopRecords,
      getReferencedColumn: (t) => t.pooperId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoopRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.poopRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PoopersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PoopersTable,
          Pooper,
          $$PoopersTableFilterComposer,
          $$PoopersTableOrderingComposer,
          $$PoopersTableAnnotationComposer,
          $$PoopersTableCreateCompanionBuilder,
          $$PoopersTableUpdateCompanionBuilder,
          (Pooper, $$PoopersTableReferences),
          Pooper,
          PrefetchHooks Function({bool poopRecordsRefs})
        > {
  $$PoopersTableTableManager(_$AppDatabase db, $PoopersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PoopersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PoopersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PoopersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> iconKey = const Value.absent(),
                Value<Uint8List?> avatarBlob = const Value.absent(),
                Value<String?> remark = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PoopersCompanion(
                id: id,
                name: name,
                iconKey: iconKey,
                avatarBlob: avatarBlob,
                remark: remark,
                isDefault: isDefault,
                archivedAt: archivedAt,
                sortOrder: sortOrder,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                required String name,
                Value<String?> iconKey = const Value.absent(),
                Value<Uint8List?> avatarBlob = const Value.absent(),
                Value<String?> remark = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PoopersCompanion.insert(
                id: id,
                name: name,
                iconKey: iconKey,
                avatarBlob: avatarBlob,
                remark: remark,
                isDefault: isDefault,
                archivedAt: archivedAt,
                sortOrder: sortOrder,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PoopersTable, Pooper>(table),
                  $$PoopersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({poopRecordsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (poopRecordsRefs) db.poopRecords],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (poopRecordsRefs)
                    await $_getPrefetchedData<
                      Pooper,
                      $PoopersTable,
                      PoopRecord
                    >(
                      currentTable: table,
                      referencedTable: $$PoopersTableReferences
                          ._poopRecordsRefsTable(db),
                      managerFromTypedResult: (p0) => $$PoopersTableReferences(
                        db,
                        table,
                        p0,
                      ).poopRecordsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.pooperId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PoopersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PoopersTable,
      Pooper,
      $$PoopersTableFilterComposer,
      $$PoopersTableOrderingComposer,
      $$PoopersTableAnnotationComposer,
      $$PoopersTableCreateCompanionBuilder,
      $$PoopersTableUpdateCompanionBuilder,
      (Pooper, $$PoopersTableReferences),
      Pooper,
      PrefetchHooks Function({bool poopRecordsRefs})
    >;
typedef $$PoopRecordsTableCreateCompanionBuilder =
    PoopRecordsCompanion Function({
      Value<String> id,
      required String pooperId,
      required DateTime startedAt,
      Value<DateTime?> endedAt,
      Value<bool> endUnknown,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$PoopRecordsTableUpdateCompanionBuilder =
    PoopRecordsCompanion Function({
      Value<String> id,
      Value<String> pooperId,
      Value<DateTime> startedAt,
      Value<DateTime?> endedAt,
      Value<bool> endUnknown,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$PoopRecordsTableReferences
    extends BaseReferences<_$AppDatabase, $PoopRecordsTable, PoopRecord> {
  $$PoopRecordsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PoopersTable _pooperIdTable(_$AppDatabase db) =>
      db.poopers.createAlias('poop_records__pooper_id__poopers__id');

  $$PoopersTableProcessedTableManager get pooperId {
    final $_column = $_itemColumn<String>('pooper_id')!;

    final manager = $$PoopersTableTableManager(
      $_db,
      $_db.poopers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_pooperIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$PoopNotesTable, List<PoopNote>>
  _poopNotesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.poopNotes,
    aliasName: 'poop_records__id__poop_notes__record_id',
  );

  $$PoopNotesTableProcessedTableManager get poopNotesRefs {
    final manager = $$PoopNotesTableTableManager(
      $_db,
      $_db.poopNotes,
    ).filter((f) => f.recordId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_poopNotesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PoopRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $PoopRecordsTable> {
  $$PoopRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get endUnknown => $composableBuilder(
    column: $table.endUnknown,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PoopersTableFilterComposer get pooperId {
    final $$PoopersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pooperId,
      referencedTable: $db.poopers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoopersTableFilterComposer(
            $db: $db,
            $table: $db.poopers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> poopNotesRefs(
    Expression<bool> Function($$PoopNotesTableFilterComposer f) f,
  ) {
    final $$PoopNotesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.poopNotes,
      getReferencedColumn: (t) => t.recordId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoopNotesTableFilterComposer(
            $db: $db,
            $table: $db.poopNotes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PoopRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $PoopRecordsTable> {
  $$PoopRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get endUnknown => $composableBuilder(
    column: $table.endUnknown,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PoopersTableOrderingComposer get pooperId {
    final $$PoopersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pooperId,
      referencedTable: $db.poopers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoopersTableOrderingComposer(
            $db: $db,
            $table: $db.poopers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PoopRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PoopRecordsTable> {
  $$PoopRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<bool> get endUnknown => $composableBuilder(
    column: $table.endUnknown,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$PoopersTableAnnotationComposer get pooperId {
    final $$PoopersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pooperId,
      referencedTable: $db.poopers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoopersTableAnnotationComposer(
            $db: $db,
            $table: $db.poopers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> poopNotesRefs<T extends Object>(
    Expression<T> Function($$PoopNotesTableAnnotationComposer a) f,
  ) {
    final $$PoopNotesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.poopNotes,
      getReferencedColumn: (t) => t.recordId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoopNotesTableAnnotationComposer(
            $db: $db,
            $table: $db.poopNotes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PoopRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PoopRecordsTable,
          PoopRecord,
          $$PoopRecordsTableFilterComposer,
          $$PoopRecordsTableOrderingComposer,
          $$PoopRecordsTableAnnotationComposer,
          $$PoopRecordsTableCreateCompanionBuilder,
          $$PoopRecordsTableUpdateCompanionBuilder,
          (PoopRecord, $$PoopRecordsTableReferences),
          PoopRecord,
          PrefetchHooks Function({bool pooperId, bool poopNotesRefs})
        > {
  $$PoopRecordsTableTableManager(_$AppDatabase db, $PoopRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PoopRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PoopRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PoopRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> pooperId = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<bool> endUnknown = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PoopRecordsCompanion(
                id: id,
                pooperId: pooperId,
                startedAt: startedAt,
                endedAt: endedAt,
                endUnknown: endUnknown,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                required String pooperId,
                required DateTime startedAt,
                Value<DateTime?> endedAt = const Value.absent(),
                Value<bool> endUnknown = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PoopRecordsCompanion.insert(
                id: id,
                pooperId: pooperId,
                startedAt: startedAt,
                endedAt: endedAt,
                endUnknown: endUnknown,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PoopRecordsTable, PoopRecord>(table),
                  $$PoopRecordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({pooperId = false, poopNotesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (poopNotesRefs) db.poopNotes],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (pooperId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.pooperId,
                                referencedTable: $$PoopRecordsTableReferences
                                    ._pooperIdTable(db),
                                referencedColumn: $$PoopRecordsTableReferences
                                    ._pooperIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (poopNotesRefs)
                    await $_getPrefetchedData<
                      PoopRecord,
                      $PoopRecordsTable,
                      PoopNote
                    >(
                      currentTable: table,
                      referencedTable: $$PoopRecordsTableReferences
                          ._poopNotesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$PoopRecordsTableReferences(
                            db,
                            table,
                            p0,
                          ).poopNotesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.recordId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PoopRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PoopRecordsTable,
      PoopRecord,
      $$PoopRecordsTableFilterComposer,
      $$PoopRecordsTableOrderingComposer,
      $$PoopRecordsTableAnnotationComposer,
      $$PoopRecordsTableCreateCompanionBuilder,
      $$PoopRecordsTableUpdateCompanionBuilder,
      (PoopRecord, $$PoopRecordsTableReferences),
      PoopRecord,
      PrefetchHooks Function({bool pooperId, bool poopNotesRefs})
    >;
typedef $$PoopNotesTableCreateCompanionBuilder =
    PoopNotesCompanion Function({
      Value<String> id,
      required String recordId,
      required String content,
      required DateTime notedAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$PoopNotesTableUpdateCompanionBuilder =
    PoopNotesCompanion Function({
      Value<String> id,
      Value<String> recordId,
      Value<String> content,
      Value<DateTime> notedAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$PoopNotesTableReferences
    extends BaseReferences<_$AppDatabase, $PoopNotesTable, PoopNote> {
  $$PoopNotesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PoopRecordsTable _recordIdTable(_$AppDatabase db) =>
      db.poopRecords.createAlias('poop_notes__record_id__poop_records__id');

  $$PoopRecordsTableProcessedTableManager get recordId {
    final $_column = $_itemColumn<String>('record_id')!;

    final manager = $$PoopRecordsTableTableManager(
      $_db,
      $_db.poopRecords,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_recordIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PoopNotesTableFilterComposer
    extends Composer<_$AppDatabase, $PoopNotesTable> {
  $$PoopNotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get notedAt => $composableBuilder(
    column: $table.notedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PoopRecordsTableFilterComposer get recordId {
    final $$PoopRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordId,
      referencedTable: $db.poopRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoopRecordsTableFilterComposer(
            $db: $db,
            $table: $db.poopRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PoopNotesTableOrderingComposer
    extends Composer<_$AppDatabase, $PoopNotesTable> {
  $$PoopNotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get notedAt => $composableBuilder(
    column: $table.notedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PoopRecordsTableOrderingComposer get recordId {
    final $$PoopRecordsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordId,
      referencedTable: $db.poopRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoopRecordsTableOrderingComposer(
            $db: $db,
            $table: $db.poopRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PoopNotesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PoopNotesTable> {
  $$PoopNotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<DateTime> get notedAt =>
      $composableBuilder(column: $table.notedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$PoopRecordsTableAnnotationComposer get recordId {
    final $$PoopRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordId,
      referencedTable: $db.poopRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoopRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.poopRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PoopNotesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PoopNotesTable,
          PoopNote,
          $$PoopNotesTableFilterComposer,
          $$PoopNotesTableOrderingComposer,
          $$PoopNotesTableAnnotationComposer,
          $$PoopNotesTableCreateCompanionBuilder,
          $$PoopNotesTableUpdateCompanionBuilder,
          (PoopNote, $$PoopNotesTableReferences),
          PoopNote,
          PrefetchHooks Function({bool recordId})
        > {
  $$PoopNotesTableTableManager(_$AppDatabase db, $PoopNotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PoopNotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PoopNotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PoopNotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> recordId = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<DateTime> notedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PoopNotesCompanion(
                id: id,
                recordId: recordId,
                content: content,
                notedAt: notedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                required String recordId,
                required String content,
                required DateTime notedAt,
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PoopNotesCompanion.insert(
                id: id,
                recordId: recordId,
                content: content,
                notedAt: notedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PoopNotesTable, PoopNote>(table),
                  $$PoopNotesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({recordId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (recordId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.recordId,
                                referencedTable: $$PoopNotesTableReferences
                                    ._recordIdTable(db),
                                referencedColumn: $$PoopNotesTableReferences
                                    ._recordIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PoopNotesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PoopNotesTable,
      PoopNote,
      $$PoopNotesTableFilterComposer,
      $$PoopNotesTableOrderingComposer,
      $$PoopNotesTableAnnotationComposer,
      $$PoopNotesTableCreateCompanionBuilder,
      $$PoopNotesTableUpdateCompanionBuilder,
      (PoopNote, $$PoopNotesTableReferences),
      PoopNote,
      PrefetchHooks Function({bool recordId})
    >;
typedef $$NoteTemplatesTableCreateCompanionBuilder =
    NoteTemplatesCompanion Function({
      Value<String> id,
      required String content,
      Value<int> useCount,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$NoteTemplatesTableUpdateCompanionBuilder =
    NoteTemplatesCompanion Function({
      Value<String> id,
      Value<String> content,
      Value<int> useCount,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$NoteTemplatesTableFilterComposer
    extends Composer<_$AppDatabase, $NoteTemplatesTable> {
  $$NoteTemplatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get useCount => $composableBuilder(
    column: $table.useCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NoteTemplatesTableOrderingComposer
    extends Composer<_$AppDatabase, $NoteTemplatesTable> {
  $$NoteTemplatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get useCount => $composableBuilder(
    column: $table.useCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NoteTemplatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $NoteTemplatesTable> {
  $$NoteTemplatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<int> get useCount =>
      $composableBuilder(column: $table.useCount, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$NoteTemplatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NoteTemplatesTable,
          NoteTemplate,
          $$NoteTemplatesTableFilterComposer,
          $$NoteTemplatesTableOrderingComposer,
          $$NoteTemplatesTableAnnotationComposer,
          $$NoteTemplatesTableCreateCompanionBuilder,
          $$NoteTemplatesTableUpdateCompanionBuilder,
          (
            NoteTemplate,
            BaseReferences<_$AppDatabase, $NoteTemplatesTable, NoteTemplate>,
          ),
          NoteTemplate,
          PrefetchHooks Function()
        > {
  $$NoteTemplatesTableTableManager(_$AppDatabase db, $NoteTemplatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NoteTemplatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NoteTemplatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NoteTemplatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<int> useCount = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteTemplatesCompanion(
                id: id,
                content: content,
                useCount: useCount,
                sortOrder: sortOrder,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                required String content,
                Value<int> useCount = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteTemplatesCompanion.insert(
                id: id,
                content: content,
                useCount: useCount,
                sortOrder: sortOrder,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NoteTemplatesTable, NoteTemplate>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $NoteTemplatesTable,
                    NoteTemplate
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NoteTemplatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NoteTemplatesTable,
      NoteTemplate,
      $$NoteTemplatesTableFilterComposer,
      $$NoteTemplatesTableOrderingComposer,
      $$NoteTemplatesTableAnnotationComposer,
      $$NoteTemplatesTableCreateCompanionBuilder,
      $$NoteTemplatesTableUpdateCompanionBuilder,
      (
        NoteTemplate,
        BaseReferences<_$AppDatabase, $NoteTemplatesTable, NoteTemplate>,
      ),
      NoteTemplate,
      PrefetchHooks Function()
    >;
typedef $$HolidaysTableCreateCompanionBuilder =
    HolidaysCompanion Function({
      required String date,
      Value<String?> name,
      required bool isOffDay,
      Value<int> rowid,
    });
typedef $$HolidaysTableUpdateCompanionBuilder =
    HolidaysCompanion Function({
      Value<String> date,
      Value<String?> name,
      Value<bool> isOffDay,
      Value<int> rowid,
    });

class $$HolidaysTableFilterComposer
    extends Composer<_$AppDatabase, $HolidaysTable> {
  $$HolidaysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isOffDay => $composableBuilder(
    column: $table.isOffDay,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HolidaysTableOrderingComposer
    extends Composer<_$AppDatabase, $HolidaysTable> {
  $$HolidaysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isOffDay => $composableBuilder(
    column: $table.isOffDay,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HolidaysTableAnnotationComposer
    extends Composer<_$AppDatabase, $HolidaysTable> {
  $$HolidaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get isOffDay =>
      $composableBuilder(column: $table.isOffDay, builder: (column) => column);
}

class $$HolidaysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HolidaysTable,
          Holiday,
          $$HolidaysTableFilterComposer,
          $$HolidaysTableOrderingComposer,
          $$HolidaysTableAnnotationComposer,
          $$HolidaysTableCreateCompanionBuilder,
          $$HolidaysTableUpdateCompanionBuilder,
          (Holiday, BaseReferences<_$AppDatabase, $HolidaysTable, Holiday>),
          Holiday,
          PrefetchHooks Function()
        > {
  $$HolidaysTableTableManager(_$AppDatabase db, $HolidaysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HolidaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HolidaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HolidaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> date = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<bool> isOffDay = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HolidaysCompanion(
                date: date,
                name: name,
                isOffDay: isOffDay,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String date,
                Value<String?> name = const Value.absent(),
                required bool isOffDay,
                Value<int> rowid = const Value.absent(),
              }) => HolidaysCompanion.insert(
                date: date,
                name: name,
                isOffDay: isOffDay,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$HolidaysTable, Holiday>(table),
                  BaseReferences<_$AppDatabase, $HolidaysTable, Holiday>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HolidaysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HolidaysTable,
      Holiday,
      $$HolidaysTableFilterComposer,
      $$HolidaysTableOrderingComposer,
      $$HolidaysTableAnnotationComposer,
      $$HolidaysTableCreateCompanionBuilder,
      $$HolidaysTableUpdateCompanionBuilder,
      (Holiday, BaseReferences<_$AppDatabase, $HolidaysTable, Holiday>),
      Holiday,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PoopersTableTableManager get poopers =>
      $$PoopersTableTableManager(_db, _db.poopers);
  $$PoopRecordsTableTableManager get poopRecords =>
      $$PoopRecordsTableTableManager(_db, _db.poopRecords);
  $$PoopNotesTableTableManager get poopNotes =>
      $$PoopNotesTableTableManager(_db, _db.poopNotes);
  $$NoteTemplatesTableTableManager get noteTemplates =>
      $$NoteTemplatesTableTableManager(_db, _db.noteTemplates);
  $$HolidaysTableTableManager get holidays =>
      $$HolidaysTableTableManager(_db, _db.holidays);
}
