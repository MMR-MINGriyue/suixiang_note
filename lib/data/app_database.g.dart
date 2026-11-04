// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $FoldersTable extends Folders with TableInfo<$FoldersTable, Folder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('folder'),
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('#4C6FFF'),
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
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    icon,
    color,
    sortOrder,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<Folder> instance, {
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
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
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
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Folder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Folder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $FoldersTable createAlias(String alias) {
    return $FoldersTable(attachedDatabase, alias);
  }
}

class Folder extends DataClass implements Insertable<Folder> {
  final int id;
  final String name;
  final String icon;
  final String color;
  final int sortOrder;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  const Folder({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['icon'] = Variable<String>(icon);
    map['color'] = Variable<String>(color);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  FoldersCompanion toCompanion(bool nullToAbsent) {
    return FoldersCompanion(
      id: Value(id),
      name: Value(name),
      icon: Value(icon),
      color: Value(color),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Folder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Folder(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      icon: serializer.fromJson<String>(json['icon']),
      color: serializer.fromJson<String>(json['color']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'icon': serializer.toJson<String>(icon),
      'color': serializer.toJson<String>(color),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  Folder copyWith({
    int? id,
    String? name,
    String? icon,
    String? color,
    int? sortOrder,
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
  }) => Folder(
    id: id ?? this.id,
    name: name ?? this.name,
    icon: icon ?? this.icon,
    color: color ?? this.color,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Folder copyWithCompanion(FoldersCompanion data) {
    return Folder(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      icon: data.icon.present ? data.icon.value : this.icon,
      color: data.color.present ? data.color.value : this.color,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Folder(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    icon,
    color,
    sortOrder,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Folder &&
          other.id == this.id &&
          other.name == this.name &&
          other.icon == this.icon &&
          other.color == this.color &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class FoldersCompanion extends UpdateCompanion<Folder> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> icon;
  final Value<String> color;
  final Value<int> sortOrder;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  const FoldersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.icon = const Value.absent(),
    this.color = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  FoldersCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.icon = const Value.absent(),
    this.color = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
  }) : name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Folder> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? icon,
    Expression<String>? color,
    Expression<int>? sortOrder,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (icon != null) 'icon': icon,
      if (color != null) 'color': color,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  FoldersCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? icon,
    Value<String>? color,
    Value<int>? sortOrder,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
  }) {
    return FoldersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoldersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

class $StagesTable extends Stages with TableInfo<$StagesTable, Stage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<double> position = GeneratedColumn<double>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isSystemMeta = const VerificationMeta(
    'isSystem',
  );
  @override
  late final GeneratedColumn<bool> isSystem = GeneratedColumn<bool>(
    'is_system',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_system" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    kind,
    color,
    position,
    isSystem,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stages';
  @override
  VerificationContext validateIntegrity(
    Insertable<Stage> instance, {
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
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('is_system')) {
      context.handle(
        _isSystemMeta,
        isSystem.isAcceptableOrUnknown(data['is_system']!, _isSystemMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Stage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Stage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}position'],
      )!,
      isSystem: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_system'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $StagesTable createAlias(String alias) {
    return $StagesTable(attachedDatabase, alias);
  }
}

class Stage extends DataClass implements Insertable<Stage> {
  final int id;
  final String name;
  final String kind;
  final String color;
  final double position;
  final bool isSystem;
  final int createdAt;
  const Stage({
    required this.id,
    required this.name,
    required this.kind,
    required this.color,
    required this.position,
    required this.isSystem,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['kind'] = Variable<String>(kind);
    map['color'] = Variable<String>(color);
    map['position'] = Variable<double>(position);
    map['is_system'] = Variable<bool>(isSystem);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  StagesCompanion toCompanion(bool nullToAbsent) {
    return StagesCompanion(
      id: Value(id),
      name: Value(name),
      kind: Value(kind),
      color: Value(color),
      position: Value(position),
      isSystem: Value(isSystem),
      createdAt: Value(createdAt),
    );
  }

  factory Stage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Stage(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      kind: serializer.fromJson<String>(json['kind']),
      color: serializer.fromJson<String>(json['color']),
      position: serializer.fromJson<double>(json['position']),
      isSystem: serializer.fromJson<bool>(json['isSystem']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<String>(kind),
      'color': serializer.toJson<String>(color),
      'position': serializer.toJson<double>(position),
      'isSystem': serializer.toJson<bool>(isSystem),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  Stage copyWith({
    int? id,
    String? name,
    String? kind,
    String? color,
    double? position,
    bool? isSystem,
    int? createdAt,
  }) => Stage(
    id: id ?? this.id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    color: color ?? this.color,
    position: position ?? this.position,
    isSystem: isSystem ?? this.isSystem,
    createdAt: createdAt ?? this.createdAt,
  );
  Stage copyWithCompanion(StagesCompanion data) {
    return Stage(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      color: data.color.present ? data.color.value : this.color,
      position: data.position.present ? data.position.value : this.position,
      isSystem: data.isSystem.present ? data.isSystem.value : this.isSystem,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Stage(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('color: $color, ')
          ..write('position: $position, ')
          ..write('isSystem: $isSystem, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, kind, color, position, isSystem, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Stage &&
          other.id == this.id &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.color == this.color &&
          other.position == this.position &&
          other.isSystem == this.isSystem &&
          other.createdAt == this.createdAt);
}

class StagesCompanion extends UpdateCompanion<Stage> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> kind;
  final Value<String> color;
  final Value<double> position;
  final Value<bool> isSystem;
  final Value<int> createdAt;
  const StagesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.color = const Value.absent(),
    this.position = const Value.absent(),
    this.isSystem = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  StagesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String kind,
    required String color,
    required double position,
    this.isSystem = const Value.absent(),
    required int createdAt,
  }) : name = Value(name),
       kind = Value(kind),
       color = Value(color),
       position = Value(position),
       createdAt = Value(createdAt);
  static Insertable<Stage> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<String>? color,
    Expression<double>? position,
    Expression<bool>? isSystem,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (color != null) 'color': color,
      if (position != null) 'position': position,
      if (isSystem != null) 'is_system': isSystem,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  StagesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? kind,
    Value<String>? color,
    Value<double>? position,
    Value<bool>? isSystem,
    Value<int>? createdAt,
  }) {
    return StagesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      color: color ?? this.color,
      position: position ?? this.position,
      isSystem: isSystem ?? this.isSystem,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (position.present) {
      map['position'] = Variable<double>(position.value);
    }
    if (isSystem.present) {
      map['is_system'] = Variable<bool>(isSystem.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StagesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('color: $color, ')
          ..write('position: $position, ')
          ..write('isSystem: $isSystem, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ThoughtsTable extends Thoughts with TableInfo<$ThoughtsTable, Thought> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ThoughtsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
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
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<int> folderId = GeneratedColumn<int>(
    'folder_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stageIdMeta = const VerificationMeta(
    'stageId',
  );
  @override
  late final GeneratedColumn<int> stageId = GeneratedColumn<int>(
    'stage_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isPinnedMeta = const VerificationMeta(
    'isPinned',
  );
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
    'is_pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _pinnedAtMeta = const VerificationMeta(
    'pinnedAt',
  );
  @override
  late final GeneratedColumn<int> pinnedAt = GeneratedColumn<int>(
    'pinned_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('app'),
  );
  static const VerificationMeta _wordCountMeta = const VerificationMeta(
    'wordCount',
  );
  @override
  late final GeneratedColumn<int> wordCount = GeneratedColumn<int>(
    'word_count',
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
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<int> completedAt = GeneratedColumn<int>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stageChangedAtMeta = const VerificationMeta(
    'stageChangedAt',
  );
  @override
  late final GeneratedColumn<int> stageChangedAt = GeneratedColumn<int>(
    'stage_changed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uuid,
    title,
    content,
    folderId,
    stageId,
    isPinned,
    pinnedAt,
    isArchived,
    source,
    wordCount,
    createdAt,
    updatedAt,
    completedAt,
    stageChangedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'thoughts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Thought> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    }
    if (data.containsKey('stage_id')) {
      context.handle(
        _stageIdMeta,
        stageId.isAcceptableOrUnknown(data['stage_id']!, _stageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_stageIdMeta);
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('pinned_at')) {
      context.handle(
        _pinnedAtMeta,
        pinnedAt.isAcceptableOrUnknown(data['pinned_at']!, _pinnedAtMeta),
      );
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('word_count')) {
      context.handle(
        _wordCountMeta,
        wordCount.isAcceptableOrUnknown(data['word_count']!, _wordCountMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('stage_changed_at')) {
      context.handle(
        _stageChangedAtMeta,
        stageChangedAt.isAcceptableOrUnknown(
          data['stage_changed_at']!,
          _stageChangedAtMeta,
        ),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Thought map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Thought(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}folder_id'],
      ),
      stageId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stage_id'],
      )!,
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      pinnedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pinned_at'],
      ),
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      wordCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}word_count'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at'],
      ),
      stageChangedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stage_changed_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $ThoughtsTable createAlias(String alias) {
    return $ThoughtsTable(attachedDatabase, alias);
  }
}

class Thought extends DataClass implements Insertable<Thought> {
  final int id;
  final String uuid;
  final String title;
  final String content;
  final int? folderId;
  final int stageId;
  final bool isPinned;
  final int? pinnedAt;
  final bool isArchived;
  final String source;
  final int wordCount;
  final int createdAt;
  final int updatedAt;
  final int? completedAt;
  final int? stageChangedAt;
  final int? deletedAt;
  const Thought({
    required this.id,
    required this.uuid,
    required this.title,
    required this.content,
    this.folderId,
    required this.stageId,
    required this.isPinned,
    this.pinnedAt,
    required this.isArchived,
    required this.source,
    required this.wordCount,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.stageChangedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['title'] = Variable<String>(title);
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || folderId != null) {
      map['folder_id'] = Variable<int>(folderId);
    }
    map['stage_id'] = Variable<int>(stageId);
    map['is_pinned'] = Variable<bool>(isPinned);
    if (!nullToAbsent || pinnedAt != null) {
      map['pinned_at'] = Variable<int>(pinnedAt);
    }
    map['is_archived'] = Variable<bool>(isArchived);
    map['source'] = Variable<String>(source);
    map['word_count'] = Variable<int>(wordCount);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<int>(completedAt);
    }
    if (!nullToAbsent || stageChangedAt != null) {
      map['stage_changed_at'] = Variable<int>(stageChangedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  ThoughtsCompanion toCompanion(bool nullToAbsent) {
    return ThoughtsCompanion(
      id: Value(id),
      uuid: Value(uuid),
      title: Value(title),
      content: Value(content),
      folderId: folderId == null && nullToAbsent
          ? const Value.absent()
          : Value(folderId),
      stageId: Value(stageId),
      isPinned: Value(isPinned),
      pinnedAt: pinnedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(pinnedAt),
      isArchived: Value(isArchived),
      source: Value(source),
      wordCount: Value(wordCount),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      stageChangedAt: stageChangedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(stageChangedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Thought.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Thought(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      title: serializer.fromJson<String>(json['title']),
      content: serializer.fromJson<String>(json['content']),
      folderId: serializer.fromJson<int?>(json['folderId']),
      stageId: serializer.fromJson<int>(json['stageId']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      pinnedAt: serializer.fromJson<int?>(json['pinnedAt']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      source: serializer.fromJson<String>(json['source']),
      wordCount: serializer.fromJson<int>(json['wordCount']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      completedAt: serializer.fromJson<int?>(json['completedAt']),
      stageChangedAt: serializer.fromJson<int?>(json['stageChangedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'title': serializer.toJson<String>(title),
      'content': serializer.toJson<String>(content),
      'folderId': serializer.toJson<int?>(folderId),
      'stageId': serializer.toJson<int>(stageId),
      'isPinned': serializer.toJson<bool>(isPinned),
      'pinnedAt': serializer.toJson<int?>(pinnedAt),
      'isArchived': serializer.toJson<bool>(isArchived),
      'source': serializer.toJson<String>(source),
      'wordCount': serializer.toJson<int>(wordCount),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'completedAt': serializer.toJson<int?>(completedAt),
      'stageChangedAt': serializer.toJson<int?>(stageChangedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  Thought copyWith({
    int? id,
    String? uuid,
    String? title,
    String? content,
    Value<int?> folderId = const Value.absent(),
    int? stageId,
    bool? isPinned,
    Value<int?> pinnedAt = const Value.absent(),
    bool? isArchived,
    String? source,
    int? wordCount,
    int? createdAt,
    int? updatedAt,
    Value<int?> completedAt = const Value.absent(),
    Value<int?> stageChangedAt = const Value.absent(),
    Value<int?> deletedAt = const Value.absent(),
  }) => Thought(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    title: title ?? this.title,
    content: content ?? this.content,
    folderId: folderId.present ? folderId.value : this.folderId,
    stageId: stageId ?? this.stageId,
    isPinned: isPinned ?? this.isPinned,
    pinnedAt: pinnedAt.present ? pinnedAt.value : this.pinnedAt,
    isArchived: isArchived ?? this.isArchived,
    source: source ?? this.source,
    wordCount: wordCount ?? this.wordCount,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    stageChangedAt: stageChangedAt.present
        ? stageChangedAt.value
        : this.stageChangedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Thought copyWithCompanion(ThoughtsCompanion data) {
    return Thought(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      title: data.title.present ? data.title.value : this.title,
      content: data.content.present ? data.content.value : this.content,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      stageId: data.stageId.present ? data.stageId.value : this.stageId,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      pinnedAt: data.pinnedAt.present ? data.pinnedAt.value : this.pinnedAt,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
      source: data.source.present ? data.source.value : this.source,
      wordCount: data.wordCount.present ? data.wordCount.value : this.wordCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      stageChangedAt: data.stageChangedAt.present
          ? data.stageChangedAt.value
          : this.stageChangedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Thought(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('folderId: $folderId, ')
          ..write('stageId: $stageId, ')
          ..write('isPinned: $isPinned, ')
          ..write('pinnedAt: $pinnedAt, ')
          ..write('isArchived: $isArchived, ')
          ..write('source: $source, ')
          ..write('wordCount: $wordCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('stageChangedAt: $stageChangedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    title,
    content,
    folderId,
    stageId,
    isPinned,
    pinnedAt,
    isArchived,
    source,
    wordCount,
    createdAt,
    updatedAt,
    completedAt,
    stageChangedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Thought &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.title == this.title &&
          other.content == this.content &&
          other.folderId == this.folderId &&
          other.stageId == this.stageId &&
          other.isPinned == this.isPinned &&
          other.pinnedAt == this.pinnedAt &&
          other.isArchived == this.isArchived &&
          other.source == this.source &&
          other.wordCount == this.wordCount &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.completedAt == this.completedAt &&
          other.stageChangedAt == this.stageChangedAt &&
          other.deletedAt == this.deletedAt);
}

class ThoughtsCompanion extends UpdateCompanion<Thought> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<String> title;
  final Value<String> content;
  final Value<int?> folderId;
  final Value<int> stageId;
  final Value<bool> isPinned;
  final Value<int?> pinnedAt;
  final Value<bool> isArchived;
  final Value<String> source;
  final Value<int> wordCount;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> completedAt;
  final Value<int?> stageChangedAt;
  final Value<int?> deletedAt;
  const ThoughtsCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.folderId = const Value.absent(),
    this.stageId = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.pinnedAt = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.source = const Value.absent(),
    this.wordCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.stageChangedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  ThoughtsCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.folderId = const Value.absent(),
    required int stageId,
    this.isPinned = const Value.absent(),
    this.pinnedAt = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.source = const Value.absent(),
    this.wordCount = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.completedAt = const Value.absent(),
    this.stageChangedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  }) : uuid = Value(uuid),
       stageId = Value(stageId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Thought> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? title,
    Expression<String>? content,
    Expression<int>? folderId,
    Expression<int>? stageId,
    Expression<bool>? isPinned,
    Expression<int>? pinnedAt,
    Expression<bool>? isArchived,
    Expression<String>? source,
    Expression<int>? wordCount,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? completedAt,
    Expression<int>? stageChangedAt,
    Expression<int>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (folderId != null) 'folder_id': folderId,
      if (stageId != null) 'stage_id': stageId,
      if (isPinned != null) 'is_pinned': isPinned,
      if (pinnedAt != null) 'pinned_at': pinnedAt,
      if (isArchived != null) 'is_archived': isArchived,
      if (source != null) 'source': source,
      if (wordCount != null) 'word_count': wordCount,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (stageChangedAt != null) 'stage_changed_at': stageChangedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  ThoughtsCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<String>? title,
    Value<String>? content,
    Value<int?>? folderId,
    Value<int>? stageId,
    Value<bool>? isPinned,
    Value<int?>? pinnedAt,
    Value<bool>? isArchived,
    Value<String>? source,
    Value<int>? wordCount,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? completedAt,
    Value<int?>? stageChangedAt,
    Value<int?>? deletedAt,
  }) {
    return ThoughtsCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      title: title ?? this.title,
      content: content ?? this.content,
      folderId: folderId ?? this.folderId,
      stageId: stageId ?? this.stageId,
      isPinned: isPinned ?? this.isPinned,
      pinnedAt: pinnedAt ?? this.pinnedAt,
      isArchived: isArchived ?? this.isArchived,
      source: source ?? this.source,
      wordCount: wordCount ?? this.wordCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      stageChangedAt: stageChangedAt ?? this.stageChangedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<int>(folderId.value);
    }
    if (stageId.present) {
      map['stage_id'] = Variable<int>(stageId.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (pinnedAt.present) {
      map['pinned_at'] = Variable<int>(pinnedAt.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (wordCount.present) {
      map['word_count'] = Variable<int>(wordCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<int>(completedAt.value);
    }
    if (stageChangedAt.present) {
      map['stage_changed_at'] = Variable<int>(stageChangedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ThoughtsCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('folderId: $folderId, ')
          ..write('stageId: $stageId, ')
          ..write('isPinned: $isPinned, ')
          ..write('pinnedAt: $pinnedAt, ')
          ..write('isArchived: $isArchived, ')
          ..write('source: $source, ')
          ..write('wordCount: $wordCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('stageChangedAt: $stageChangedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

class $TagsTable extends Tags with TableInfo<$TagsTable, Tag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('#4C6FFF'),
  );
  static const VerificationMeta _sortWeightMeta = const VerificationMeta(
    'sortWeight',
  );
  @override
  late final GeneratedColumn<int> sortWeight = GeneratedColumn<int>(
    'sort_weight',
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
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    color,
    sortWeight,
    createdAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<Tag> instance, {
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
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('sort_weight')) {
      context.handle(
        _sortWeightMeta,
        sortWeight.isAcceptableOrUnknown(data['sort_weight']!, _sortWeightMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Tag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tag(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      )!,
      sortWeight: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_weight'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $TagsTable createAlias(String alias) {
    return $TagsTable(attachedDatabase, alias);
  }
}

class Tag extends DataClass implements Insertable<Tag> {
  final int id;
  final String name;
  final String color;
  final int sortWeight;
  final int createdAt;
  final int? deletedAt;
  const Tag({
    required this.id,
    required this.name,
    required this.color,
    required this.sortWeight,
    required this.createdAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['color'] = Variable<String>(color);
    map['sort_weight'] = Variable<int>(sortWeight);
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(
      id: Value(id),
      name: Value(name),
      color: Value(color),
      sortWeight: Value(sortWeight),
      createdAt: Value(createdAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Tag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Tag(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<String>(json['color']),
      sortWeight: serializer.fromJson<int>(json['sortWeight']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<String>(color),
      'sortWeight': serializer.toJson<int>(sortWeight),
      'createdAt': serializer.toJson<int>(createdAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  Tag copyWith({
    int? id,
    String? name,
    String? color,
    int? sortWeight,
    int? createdAt,
    Value<int?> deletedAt = const Value.absent(),
  }) => Tag(
    id: id ?? this.id,
    name: name ?? this.name,
    color: color ?? this.color,
    sortWeight: sortWeight ?? this.sortWeight,
    createdAt: createdAt ?? this.createdAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Tag copyWithCompanion(TagsCompanion data) {
    return Tag(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      sortWeight: data.sortWeight.present
          ? data.sortWeight.value
          : this.sortWeight,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Tag(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('sortWeight: $sortWeight, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, color, sortWeight, createdAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Tag &&
          other.id == this.id &&
          other.name == this.name &&
          other.color == this.color &&
          other.sortWeight == this.sortWeight &&
          other.createdAt == this.createdAt &&
          other.deletedAt == this.deletedAt);
}

class TagsCompanion extends UpdateCompanion<Tag> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> color;
  final Value<int> sortWeight;
  final Value<int> createdAt;
  final Value<int?> deletedAt;
  const TagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.sortWeight = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  TagsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.color = const Value.absent(),
    this.sortWeight = const Value.absent(),
    required int createdAt,
    this.deletedAt = const Value.absent(),
  }) : name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<Tag> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? color,
    Expression<int>? sortWeight,
    Expression<int>? createdAt,
    Expression<int>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (sortWeight != null) 'sort_weight': sortWeight,
      if (createdAt != null) 'created_at': createdAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  TagsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? color,
    Value<int>? sortWeight,
    Value<int>? createdAt,
    Value<int?>? deletedAt,
  }) {
    return TagsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      sortWeight: sortWeight ?? this.sortWeight,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (sortWeight.present) {
      map['sort_weight'] = Variable<int>(sortWeight.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('sortWeight: $sortWeight, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

class $ThoughtTagsTable extends ThoughtTags
    with TableInfo<$ThoughtTagsTable, ThoughtTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ThoughtTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _thoughtIdMeta = const VerificationMeta(
    'thoughtId',
  );
  @override
  late final GeneratedColumn<int> thoughtId = GeneratedColumn<int>(
    'thought_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<int> tagId = GeneratedColumn<int>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [thoughtId, tagId, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'thought_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<ThoughtTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('thought_id')) {
      context.handle(
        _thoughtIdMeta,
        thoughtId.isAcceptableOrUnknown(data['thought_id']!, _thoughtIdMeta),
      );
    } else if (isInserting) {
      context.missing(_thoughtIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {thoughtId, tagId};
  @override
  ThoughtTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ThoughtTag(
      thoughtId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}thought_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tag_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ThoughtTagsTable createAlias(String alias) {
    return $ThoughtTagsTable(attachedDatabase, alias);
  }
}

class ThoughtTag extends DataClass implements Insertable<ThoughtTag> {
  final int thoughtId;
  final int tagId;
  final int createdAt;
  const ThoughtTag({
    required this.thoughtId,
    required this.tagId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['thought_id'] = Variable<int>(thoughtId);
    map['tag_id'] = Variable<int>(tagId);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  ThoughtTagsCompanion toCompanion(bool nullToAbsent) {
    return ThoughtTagsCompanion(
      thoughtId: Value(thoughtId),
      tagId: Value(tagId),
      createdAt: Value(createdAt),
    );
  }

  factory ThoughtTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ThoughtTag(
      thoughtId: serializer.fromJson<int>(json['thoughtId']),
      tagId: serializer.fromJson<int>(json['tagId']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'thoughtId': serializer.toJson<int>(thoughtId),
      'tagId': serializer.toJson<int>(tagId),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  ThoughtTag copyWith({int? thoughtId, int? tagId, int? createdAt}) =>
      ThoughtTag(
        thoughtId: thoughtId ?? this.thoughtId,
        tagId: tagId ?? this.tagId,
        createdAt: createdAt ?? this.createdAt,
      );
  ThoughtTag copyWithCompanion(ThoughtTagsCompanion data) {
    return ThoughtTag(
      thoughtId: data.thoughtId.present ? data.thoughtId.value : this.thoughtId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ThoughtTag(')
          ..write('thoughtId: $thoughtId, ')
          ..write('tagId: $tagId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(thoughtId, tagId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ThoughtTag &&
          other.thoughtId == this.thoughtId &&
          other.tagId == this.tagId &&
          other.createdAt == this.createdAt);
}

class ThoughtTagsCompanion extends UpdateCompanion<ThoughtTag> {
  final Value<int> thoughtId;
  final Value<int> tagId;
  final Value<int> createdAt;
  final Value<int> rowid;
  const ThoughtTagsCompanion({
    this.thoughtId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ThoughtTagsCompanion.insert({
    required int thoughtId,
    required int tagId,
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : thoughtId = Value(thoughtId),
       tagId = Value(tagId),
       createdAt = Value(createdAt);
  static Insertable<ThoughtTag> custom({
    Expression<int>? thoughtId,
    Expression<int>? tagId,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (thoughtId != null) 'thought_id': thoughtId,
      if (tagId != null) 'tag_id': tagId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ThoughtTagsCompanion copyWith({
    Value<int>? thoughtId,
    Value<int>? tagId,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return ThoughtTagsCompanion(
      thoughtId: thoughtId ?? this.thoughtId,
      tagId: tagId ?? this.tagId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (thoughtId.present) {
      map['thought_id'] = Variable<int>(thoughtId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<int>(tagId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ThoughtTagsCompanion(')
          ..write('thoughtId: $thoughtId, ')
          ..write('tagId: $tagId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RemindersTable extends Reminders
    with TableInfo<$RemindersTable, Reminder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RemindersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _thoughtIdMeta = const VerificationMeta(
    'thoughtId',
  );
  @override
  late final GeneratedColumn<int> thoughtId = GeneratedColumn<int>(
    'thought_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remindAtMeta = const VerificationMeta(
    'remindAt',
  );
  @override
  late final GeneratedColumn<int> remindAt = GeneratedColumn<int>(
    'remind_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repeatRuleMeta = const VerificationMeta(
    'repeatRule',
  );
  @override
  late final GeneratedColumn<String> repeatRule = GeneratedColumn<String>(
    'repeat_rule',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('once'),
  );
  static const VerificationMeta _repeatIntervalMeta = const VerificationMeta(
    'repeatInterval',
  );
  @override
  late final GeneratedColumn<int> repeatInterval = GeneratedColumn<int>(
    'repeat_interval',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _repeatUnitMeta = const VerificationMeta(
    'repeatUnit',
  );
  @override
  late final GeneratedColumn<String> repeatUnit = GeneratedColumn<String>(
    'repeat_unit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  static const VerificationMeta _lastFiredAtMeta = const VerificationMeta(
    'lastFiredAt',
  );
  @override
  late final GeneratedColumn<int> lastFiredAt = GeneratedColumn<int>(
    'last_fired_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    thoughtId,
    remindAt,
    repeatRule,
    repeatInterval,
    repeatUnit,
    status,
    lastFiredAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reminders';
  @override
  VerificationContext validateIntegrity(
    Insertable<Reminder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('thought_id')) {
      context.handle(
        _thoughtIdMeta,
        thoughtId.isAcceptableOrUnknown(data['thought_id']!, _thoughtIdMeta),
      );
    } else if (isInserting) {
      context.missing(_thoughtIdMeta);
    }
    if (data.containsKey('remind_at')) {
      context.handle(
        _remindAtMeta,
        remindAt.isAcceptableOrUnknown(data['remind_at']!, _remindAtMeta),
      );
    } else if (isInserting) {
      context.missing(_remindAtMeta);
    }
    if (data.containsKey('repeat_rule')) {
      context.handle(
        _repeatRuleMeta,
        repeatRule.isAcceptableOrUnknown(data['repeat_rule']!, _repeatRuleMeta),
      );
    }
    if (data.containsKey('repeat_interval')) {
      context.handle(
        _repeatIntervalMeta,
        repeatInterval.isAcceptableOrUnknown(
          data['repeat_interval']!,
          _repeatIntervalMeta,
        ),
      );
    }
    if (data.containsKey('repeat_unit')) {
      context.handle(
        _repeatUnitMeta,
        repeatUnit.isAcceptableOrUnknown(data['repeat_unit']!, _repeatUnitMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('last_fired_at')) {
      context.handle(
        _lastFiredAtMeta,
        lastFiredAt.isAcceptableOrUnknown(
          data['last_fired_at']!,
          _lastFiredAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Reminder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Reminder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      thoughtId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}thought_id'],
      )!,
      remindAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remind_at'],
      )!,
      repeatRule: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repeat_rule'],
      )!,
      repeatInterval: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}repeat_interval'],
      ),
      repeatUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repeat_unit'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      lastFiredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_fired_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $RemindersTable createAlias(String alias) {
    return $RemindersTable(attachedDatabase, alias);
  }
}

class Reminder extends DataClass implements Insertable<Reminder> {
  final int id;
  final int thoughtId;
  final int remindAt;
  final String repeatRule;
  final int? repeatInterval;
  final String? repeatUnit;
  final String status;
  final int? lastFiredAt;
  final int createdAt;
  const Reminder({
    required this.id,
    required this.thoughtId,
    required this.remindAt,
    required this.repeatRule,
    this.repeatInterval,
    this.repeatUnit,
    required this.status,
    this.lastFiredAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['thought_id'] = Variable<int>(thoughtId);
    map['remind_at'] = Variable<int>(remindAt);
    map['repeat_rule'] = Variable<String>(repeatRule);
    if (!nullToAbsent || repeatInterval != null) {
      map['repeat_interval'] = Variable<int>(repeatInterval);
    }
    if (!nullToAbsent || repeatUnit != null) {
      map['repeat_unit'] = Variable<String>(repeatUnit);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || lastFiredAt != null) {
      map['last_fired_at'] = Variable<int>(lastFiredAt);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  RemindersCompanion toCompanion(bool nullToAbsent) {
    return RemindersCompanion(
      id: Value(id),
      thoughtId: Value(thoughtId),
      remindAt: Value(remindAt),
      repeatRule: Value(repeatRule),
      repeatInterval: repeatInterval == null && nullToAbsent
          ? const Value.absent()
          : Value(repeatInterval),
      repeatUnit: repeatUnit == null && nullToAbsent
          ? const Value.absent()
          : Value(repeatUnit),
      status: Value(status),
      lastFiredAt: lastFiredAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastFiredAt),
      createdAt: Value(createdAt),
    );
  }

  factory Reminder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Reminder(
      id: serializer.fromJson<int>(json['id']),
      thoughtId: serializer.fromJson<int>(json['thoughtId']),
      remindAt: serializer.fromJson<int>(json['remindAt']),
      repeatRule: serializer.fromJson<String>(json['repeatRule']),
      repeatInterval: serializer.fromJson<int?>(json['repeatInterval']),
      repeatUnit: serializer.fromJson<String?>(json['repeatUnit']),
      status: serializer.fromJson<String>(json['status']),
      lastFiredAt: serializer.fromJson<int?>(json['lastFiredAt']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'thoughtId': serializer.toJson<int>(thoughtId),
      'remindAt': serializer.toJson<int>(remindAt),
      'repeatRule': serializer.toJson<String>(repeatRule),
      'repeatInterval': serializer.toJson<int?>(repeatInterval),
      'repeatUnit': serializer.toJson<String?>(repeatUnit),
      'status': serializer.toJson<String>(status),
      'lastFiredAt': serializer.toJson<int?>(lastFiredAt),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  Reminder copyWith({
    int? id,
    int? thoughtId,
    int? remindAt,
    String? repeatRule,
    Value<int?> repeatInterval = const Value.absent(),
    Value<String?> repeatUnit = const Value.absent(),
    String? status,
    Value<int?> lastFiredAt = const Value.absent(),
    int? createdAt,
  }) => Reminder(
    id: id ?? this.id,
    thoughtId: thoughtId ?? this.thoughtId,
    remindAt: remindAt ?? this.remindAt,
    repeatRule: repeatRule ?? this.repeatRule,
    repeatInterval: repeatInterval.present
        ? repeatInterval.value
        : this.repeatInterval,
    repeatUnit: repeatUnit.present ? repeatUnit.value : this.repeatUnit,
    status: status ?? this.status,
    lastFiredAt: lastFiredAt.present ? lastFiredAt.value : this.lastFiredAt,
    createdAt: createdAt ?? this.createdAt,
  );
  Reminder copyWithCompanion(RemindersCompanion data) {
    return Reminder(
      id: data.id.present ? data.id.value : this.id,
      thoughtId: data.thoughtId.present ? data.thoughtId.value : this.thoughtId,
      remindAt: data.remindAt.present ? data.remindAt.value : this.remindAt,
      repeatRule: data.repeatRule.present
          ? data.repeatRule.value
          : this.repeatRule,
      repeatInterval: data.repeatInterval.present
          ? data.repeatInterval.value
          : this.repeatInterval,
      repeatUnit: data.repeatUnit.present
          ? data.repeatUnit.value
          : this.repeatUnit,
      status: data.status.present ? data.status.value : this.status,
      lastFiredAt: data.lastFiredAt.present
          ? data.lastFiredAt.value
          : this.lastFiredAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Reminder(')
          ..write('id: $id, ')
          ..write('thoughtId: $thoughtId, ')
          ..write('remindAt: $remindAt, ')
          ..write('repeatRule: $repeatRule, ')
          ..write('repeatInterval: $repeatInterval, ')
          ..write('repeatUnit: $repeatUnit, ')
          ..write('status: $status, ')
          ..write('lastFiredAt: $lastFiredAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    thoughtId,
    remindAt,
    repeatRule,
    repeatInterval,
    repeatUnit,
    status,
    lastFiredAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Reminder &&
          other.id == this.id &&
          other.thoughtId == this.thoughtId &&
          other.remindAt == this.remindAt &&
          other.repeatRule == this.repeatRule &&
          other.repeatInterval == this.repeatInterval &&
          other.repeatUnit == this.repeatUnit &&
          other.status == this.status &&
          other.lastFiredAt == this.lastFiredAt &&
          other.createdAt == this.createdAt);
}

class RemindersCompanion extends UpdateCompanion<Reminder> {
  final Value<int> id;
  final Value<int> thoughtId;
  final Value<int> remindAt;
  final Value<String> repeatRule;
  final Value<int?> repeatInterval;
  final Value<String?> repeatUnit;
  final Value<String> status;
  final Value<int?> lastFiredAt;
  final Value<int> createdAt;
  const RemindersCompanion({
    this.id = const Value.absent(),
    this.thoughtId = const Value.absent(),
    this.remindAt = const Value.absent(),
    this.repeatRule = const Value.absent(),
    this.repeatInterval = const Value.absent(),
    this.repeatUnit = const Value.absent(),
    this.status = const Value.absent(),
    this.lastFiredAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  RemindersCompanion.insert({
    this.id = const Value.absent(),
    required int thoughtId,
    required int remindAt,
    this.repeatRule = const Value.absent(),
    this.repeatInterval = const Value.absent(),
    this.repeatUnit = const Value.absent(),
    this.status = const Value.absent(),
    this.lastFiredAt = const Value.absent(),
    required int createdAt,
  }) : thoughtId = Value(thoughtId),
       remindAt = Value(remindAt),
       createdAt = Value(createdAt);
  static Insertable<Reminder> custom({
    Expression<int>? id,
    Expression<int>? thoughtId,
    Expression<int>? remindAt,
    Expression<String>? repeatRule,
    Expression<int>? repeatInterval,
    Expression<String>? repeatUnit,
    Expression<String>? status,
    Expression<int>? lastFiredAt,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (thoughtId != null) 'thought_id': thoughtId,
      if (remindAt != null) 'remind_at': remindAt,
      if (repeatRule != null) 'repeat_rule': repeatRule,
      if (repeatInterval != null) 'repeat_interval': repeatInterval,
      if (repeatUnit != null) 'repeat_unit': repeatUnit,
      if (status != null) 'status': status,
      if (lastFiredAt != null) 'last_fired_at': lastFiredAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  RemindersCompanion copyWith({
    Value<int>? id,
    Value<int>? thoughtId,
    Value<int>? remindAt,
    Value<String>? repeatRule,
    Value<int?>? repeatInterval,
    Value<String?>? repeatUnit,
    Value<String>? status,
    Value<int?>? lastFiredAt,
    Value<int>? createdAt,
  }) {
    return RemindersCompanion(
      id: id ?? this.id,
      thoughtId: thoughtId ?? this.thoughtId,
      remindAt: remindAt ?? this.remindAt,
      repeatRule: repeatRule ?? this.repeatRule,
      repeatInterval: repeatInterval ?? this.repeatInterval,
      repeatUnit: repeatUnit ?? this.repeatUnit,
      status: status ?? this.status,
      lastFiredAt: lastFiredAt ?? this.lastFiredAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (thoughtId.present) {
      map['thought_id'] = Variable<int>(thoughtId.value);
    }
    if (remindAt.present) {
      map['remind_at'] = Variable<int>(remindAt.value);
    }
    if (repeatRule.present) {
      map['repeat_rule'] = Variable<String>(repeatRule.value);
    }
    if (repeatInterval.present) {
      map['repeat_interval'] = Variable<int>(repeatInterval.value);
    }
    if (repeatUnit.present) {
      map['repeat_unit'] = Variable<String>(repeatUnit.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (lastFiredAt.present) {
      map['last_fired_at'] = Variable<int>(lastFiredAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RemindersCompanion(')
          ..write('id: $id, ')
          ..write('thoughtId: $thoughtId, ')
          ..write('remindAt: $remindAt, ')
          ..write('repeatRule: $repeatRule, ')
          ..write('repeatInterval: $repeatInterval, ')
          ..write('repeatUnit: $repeatUnit, ')
          ..write('status: $status, ')
          ..write('lastFiredAt: $lastFiredAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $AttachmentsTable extends Attachments
    with TableInfo<$AttachmentsTable, Attachment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttachmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _thoughtIdMeta = const VerificationMeta(
    'thoughtId',
  );
  @override
  late final GeneratedColumn<int> thoughtId = GeneratedColumn<int>(
    'thought_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    thoughtId,
    type,
    filePath,
    durationMs,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attachments';
  @override
  VerificationContext validateIntegrity(
    Insertable<Attachment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('thought_id')) {
      context.handle(
        _thoughtIdMeta,
        thoughtId.isAcceptableOrUnknown(data['thought_id']!, _thoughtIdMeta),
      );
    } else if (isInserting) {
      context.missing(_thoughtIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Attachment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Attachment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      thoughtId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}thought_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AttachmentsTable createAlias(String alias) {
    return $AttachmentsTable(attachedDatabase, alias);
  }
}

class Attachment extends DataClass implements Insertable<Attachment> {
  final int id;
  final int thoughtId;
  final String type;
  final String filePath;
  final int? durationMs;
  final int createdAt;
  const Attachment({
    required this.id,
    required this.thoughtId,
    required this.type,
    required this.filePath,
    this.durationMs,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['thought_id'] = Variable<int>(thoughtId);
    map['type'] = Variable<String>(type);
    map['file_path'] = Variable<String>(filePath);
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  AttachmentsCompanion toCompanion(bool nullToAbsent) {
    return AttachmentsCompanion(
      id: Value(id),
      thoughtId: Value(thoughtId),
      type: Value(type),
      filePath: Value(filePath),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      createdAt: Value(createdAt),
    );
  }

  factory Attachment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Attachment(
      id: serializer.fromJson<int>(json['id']),
      thoughtId: serializer.fromJson<int>(json['thoughtId']),
      type: serializer.fromJson<String>(json['type']),
      filePath: serializer.fromJson<String>(json['filePath']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'thoughtId': serializer.toJson<int>(thoughtId),
      'type': serializer.toJson<String>(type),
      'filePath': serializer.toJson<String>(filePath),
      'durationMs': serializer.toJson<int?>(durationMs),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  Attachment copyWith({
    int? id,
    int? thoughtId,
    String? type,
    String? filePath,
    Value<int?> durationMs = const Value.absent(),
    int? createdAt,
  }) => Attachment(
    id: id ?? this.id,
    thoughtId: thoughtId ?? this.thoughtId,
    type: type ?? this.type,
    filePath: filePath ?? this.filePath,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    createdAt: createdAt ?? this.createdAt,
  );
  Attachment copyWithCompanion(AttachmentsCompanion data) {
    return Attachment(
      id: data.id.present ? data.id.value : this.id,
      thoughtId: data.thoughtId.present ? data.thoughtId.value : this.thoughtId,
      type: data.type.present ? data.type.value : this.type,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Attachment(')
          ..write('id: $id, ')
          ..write('thoughtId: $thoughtId, ')
          ..write('type: $type, ')
          ..write('filePath: $filePath, ')
          ..write('durationMs: $durationMs, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, thoughtId, type, filePath, durationMs, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Attachment &&
          other.id == this.id &&
          other.thoughtId == this.thoughtId &&
          other.type == this.type &&
          other.filePath == this.filePath &&
          other.durationMs == this.durationMs &&
          other.createdAt == this.createdAt);
}

class AttachmentsCompanion extends UpdateCompanion<Attachment> {
  final Value<int> id;
  final Value<int> thoughtId;
  final Value<String> type;
  final Value<String> filePath;
  final Value<int?> durationMs;
  final Value<int> createdAt;
  const AttachmentsCompanion({
    this.id = const Value.absent(),
    this.thoughtId = const Value.absent(),
    this.type = const Value.absent(),
    this.filePath = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  AttachmentsCompanion.insert({
    this.id = const Value.absent(),
    required int thoughtId,
    required String type,
    required String filePath,
    this.durationMs = const Value.absent(),
    required int createdAt,
  }) : thoughtId = Value(thoughtId),
       type = Value(type),
       filePath = Value(filePath),
       createdAt = Value(createdAt);
  static Insertable<Attachment> custom({
    Expression<int>? id,
    Expression<int>? thoughtId,
    Expression<String>? type,
    Expression<String>? filePath,
    Expression<int>? durationMs,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (thoughtId != null) 'thought_id': thoughtId,
      if (type != null) 'type': type,
      if (filePath != null) 'file_path': filePath,
      if (durationMs != null) 'duration_ms': durationMs,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  AttachmentsCompanion copyWith({
    Value<int>? id,
    Value<int>? thoughtId,
    Value<String>? type,
    Value<String>? filePath,
    Value<int?>? durationMs,
    Value<int>? createdAt,
  }) {
    return AttachmentsCompanion(
      id: id ?? this.id,
      thoughtId: thoughtId ?? this.thoughtId,
      type: type ?? this.type,
      filePath: filePath ?? this.filePath,
      durationMs: durationMs ?? this.durationMs,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (thoughtId.present) {
      map['thought_id'] = Variable<int>(thoughtId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentsCompanion(')
          ..write('id: $id, ')
          ..write('thoughtId: $thoughtId, ')
          ..write('type: $type, ')
          ..write('filePath: $filePath, ')
          ..write('durationMs: $durationMs, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      ),
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String? value;
  const Setting({required this.key, this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      key: Value(key),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
    );
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String?>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String?>(value),
    };
  }

  Setting copyWith({
    String? key,
    Value<String?> value = const Value.absent(),
  }) => Setting(
    key: key ?? this.key,
    value: value.present ? value.value : this.value,
  );
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String?> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String?>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ThoughtLinksTable extends ThoughtLinks
    with TableInfo<$ThoughtLinksTable, ThoughtLink> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ThoughtLinksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _fromIdMeta = const VerificationMeta('fromId');
  @override
  late final GeneratedColumn<int> fromId = GeneratedColumn<int>(
    'from_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toIdMeta = const VerificationMeta('toId');
  @override
  late final GeneratedColumn<int> toId = GeneratedColumn<int>(
    'to_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('related'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    fromId,
    toId,
    kind,
    createdAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'thought_links';
  @override
  VerificationContext validateIntegrity(
    Insertable<ThoughtLink> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('from_id')) {
      context.handle(
        _fromIdMeta,
        fromId.isAcceptableOrUnknown(data['from_id']!, _fromIdMeta),
      );
    } else if (isInserting) {
      context.missing(_fromIdMeta);
    }
    if (data.containsKey('to_id')) {
      context.handle(
        _toIdMeta,
        toId.isAcceptableOrUnknown(data['to_id']!, _toIdMeta),
      );
    } else if (isInserting) {
      context.missing(_toIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ThoughtLink map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ThoughtLink(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      fromId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}from_id'],
      )!,
      toId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}to_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $ThoughtLinksTable createAlias(String alias) {
    return $ThoughtLinksTable(attachedDatabase, alias);
  }
}

class ThoughtLink extends DataClass implements Insertable<ThoughtLink> {
  final int id;
  final int fromId;
  final int toId;
  final String kind;
  final int createdAt;
  final int? deletedAt;
  const ThoughtLink({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.kind,
    required this.createdAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['from_id'] = Variable<int>(fromId);
    map['to_id'] = Variable<int>(toId);
    map['kind'] = Variable<String>(kind);
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  ThoughtLinksCompanion toCompanion(bool nullToAbsent) {
    return ThoughtLinksCompanion(
      id: Value(id),
      fromId: Value(fromId),
      toId: Value(toId),
      kind: Value(kind),
      createdAt: Value(createdAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory ThoughtLink.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ThoughtLink(
      id: serializer.fromJson<int>(json['id']),
      fromId: serializer.fromJson<int>(json['fromId']),
      toId: serializer.fromJson<int>(json['toId']),
      kind: serializer.fromJson<String>(json['kind']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'fromId': serializer.toJson<int>(fromId),
      'toId': serializer.toJson<int>(toId),
      'kind': serializer.toJson<String>(kind),
      'createdAt': serializer.toJson<int>(createdAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  ThoughtLink copyWith({
    int? id,
    int? fromId,
    int? toId,
    String? kind,
    int? createdAt,
    Value<int?> deletedAt = const Value.absent(),
  }) => ThoughtLink(
    id: id ?? this.id,
    fromId: fromId ?? this.fromId,
    toId: toId ?? this.toId,
    kind: kind ?? this.kind,
    createdAt: createdAt ?? this.createdAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  ThoughtLink copyWithCompanion(ThoughtLinksCompanion data) {
    return ThoughtLink(
      id: data.id.present ? data.id.value : this.id,
      fromId: data.fromId.present ? data.fromId.value : this.fromId,
      toId: data.toId.present ? data.toId.value : this.toId,
      kind: data.kind.present ? data.kind.value : this.kind,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ThoughtLink(')
          ..write('id: $id, ')
          ..write('fromId: $fromId, ')
          ..write('toId: $toId, ')
          ..write('kind: $kind, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, fromId, toId, kind, createdAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ThoughtLink &&
          other.id == this.id &&
          other.fromId == this.fromId &&
          other.toId == this.toId &&
          other.kind == this.kind &&
          other.createdAt == this.createdAt &&
          other.deletedAt == this.deletedAt);
}

class ThoughtLinksCompanion extends UpdateCompanion<ThoughtLink> {
  final Value<int> id;
  final Value<int> fromId;
  final Value<int> toId;
  final Value<String> kind;
  final Value<int> createdAt;
  final Value<int?> deletedAt;
  const ThoughtLinksCompanion({
    this.id = const Value.absent(),
    this.fromId = const Value.absent(),
    this.toId = const Value.absent(),
    this.kind = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  ThoughtLinksCompanion.insert({
    this.id = const Value.absent(),
    required int fromId,
    required int toId,
    this.kind = const Value.absent(),
    required int createdAt,
    this.deletedAt = const Value.absent(),
  }) : fromId = Value(fromId),
       toId = Value(toId),
       createdAt = Value(createdAt);
  static Insertable<ThoughtLink> custom({
    Expression<int>? id,
    Expression<int>? fromId,
    Expression<int>? toId,
    Expression<String>? kind,
    Expression<int>? createdAt,
    Expression<int>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fromId != null) 'from_id': fromId,
      if (toId != null) 'to_id': toId,
      if (kind != null) 'kind': kind,
      if (createdAt != null) 'created_at': createdAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  ThoughtLinksCompanion copyWith({
    Value<int>? id,
    Value<int>? fromId,
    Value<int>? toId,
    Value<String>? kind,
    Value<int>? createdAt,
    Value<int?>? deletedAt,
  }) {
    return ThoughtLinksCompanion(
      id: id ?? this.id,
      fromId: fromId ?? this.fromId,
      toId: toId ?? this.toId,
      kind: kind ?? this.kind,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (fromId.present) {
      map['from_id'] = Variable<int>(fromId.value);
    }
    if (toId.present) {
      map['to_id'] = Variable<int>(toId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ThoughtLinksCompanion(')
          ..write('id: $id, ')
          ..write('fromId: $fromId, ')
          ..write('toId: $toId, ')
          ..write('kind: $kind, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $FoldersTable folders = $FoldersTable(this);
  late final $StagesTable stages = $StagesTable(this);
  late final $ThoughtsTable thoughts = $ThoughtsTable(this);
  late final $TagsTable tags = $TagsTable(this);
  late final $ThoughtTagsTable thoughtTags = $ThoughtTagsTable(this);
  late final $RemindersTable reminders = $RemindersTable(this);
  late final $AttachmentsTable attachments = $AttachmentsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $ThoughtLinksTable thoughtLinks = $ThoughtLinksTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    folders,
    stages,
    thoughts,
    tags,
    thoughtTags,
    reminders,
    attachments,
    settings,
    thoughtLinks,
  ];
}

typedef $$FoldersTableCreateCompanionBuilder =
    FoldersCompanion Function({
      Value<int> id,
      required String name,
      Value<String> icon,
      Value<String> color,
      Value<int> sortOrder,
      required int createdAt,
      required int updatedAt,
      Value<int?> deletedAt,
    });
typedef $$FoldersTableUpdateCompanionBuilder =
    FoldersCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> icon,
      Value<String> color,
      Value<int> sortOrder,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> deletedAt,
    });

class $$FoldersTableFilterComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FoldersTableOrderingComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FoldersTableAnnotationComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$FoldersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FoldersTable,
          Folder,
          $$FoldersTableFilterComposer,
          $$FoldersTableOrderingComposer,
          $$FoldersTableAnnotationComposer,
          $$FoldersTableCreateCompanionBuilder,
          $$FoldersTableUpdateCompanionBuilder,
          (Folder, BaseReferences<_$AppDatabase, $FoldersTable, Folder>),
          Folder,
          PrefetchHooks Function()
        > {
  $$FoldersTableTableManager(_$AppDatabase db, $FoldersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> icon = const Value.absent(),
                Value<String> color = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
              }) => FoldersCompanion(
                id: id,
                name: name,
                icon: icon,
                color: color,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String> icon = const Value.absent(),
                Value<String> color = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
              }) => FoldersCompanion.insert(
                id: id,
                name: name,
                icon: icon,
                color: color,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FoldersTable,
      Folder,
      $$FoldersTableFilterComposer,
      $$FoldersTableOrderingComposer,
      $$FoldersTableAnnotationComposer,
      $$FoldersTableCreateCompanionBuilder,
      $$FoldersTableUpdateCompanionBuilder,
      (Folder, BaseReferences<_$AppDatabase, $FoldersTable, Folder>),
      Folder,
      PrefetchHooks Function()
    >;
typedef $$StagesTableCreateCompanionBuilder =
    StagesCompanion Function({
      Value<int> id,
      required String name,
      required String kind,
      required String color,
      required double position,
      Value<bool> isSystem,
      required int createdAt,
    });
typedef $$StagesTableUpdateCompanionBuilder =
    StagesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> kind,
      Value<String> color,
      Value<double> position,
      Value<bool> isSystem,
      Value<int> createdAt,
    });

class $$StagesTableFilterComposer
    extends Composer<_$AppDatabase, $StagesTable> {
  $$StagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSystem => $composableBuilder(
    column: $table.isSystem,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StagesTableOrderingComposer
    extends Composer<_$AppDatabase, $StagesTable> {
  $$StagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSystem => $composableBuilder(
    column: $table.isSystem,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $StagesTable> {
  $$StagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<double> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<bool> get isSystem =>
      $composableBuilder(column: $table.isSystem, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$StagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StagesTable,
          Stage,
          $$StagesTableFilterComposer,
          $$StagesTableOrderingComposer,
          $$StagesTableAnnotationComposer,
          $$StagesTableCreateCompanionBuilder,
          $$StagesTableUpdateCompanionBuilder,
          (Stage, BaseReferences<_$AppDatabase, $StagesTable, Stage>),
          Stage,
          PrefetchHooks Function()
        > {
  $$StagesTableTableManager(_$AppDatabase db, $StagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> color = const Value.absent(),
                Value<double> position = const Value.absent(),
                Value<bool> isSystem = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
              }) => StagesCompanion(
                id: id,
                name: name,
                kind: kind,
                color: color,
                position: position,
                isSystem: isSystem,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String kind,
                required String color,
                required double position,
                Value<bool> isSystem = const Value.absent(),
                required int createdAt,
              }) => StagesCompanion.insert(
                id: id,
                name: name,
                kind: kind,
                color: color,
                position: position,
                isSystem: isSystem,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StagesTable,
      Stage,
      $$StagesTableFilterComposer,
      $$StagesTableOrderingComposer,
      $$StagesTableAnnotationComposer,
      $$StagesTableCreateCompanionBuilder,
      $$StagesTableUpdateCompanionBuilder,
      (Stage, BaseReferences<_$AppDatabase, $StagesTable, Stage>),
      Stage,
      PrefetchHooks Function()
    >;
typedef $$ThoughtsTableCreateCompanionBuilder =
    ThoughtsCompanion Function({
      Value<int> id,
      required String uuid,
      Value<String> title,
      Value<String> content,
      Value<int?> folderId,
      required int stageId,
      Value<bool> isPinned,
      Value<int?> pinnedAt,
      Value<bool> isArchived,
      Value<String> source,
      Value<int> wordCount,
      required int createdAt,
      required int updatedAt,
      Value<int?> completedAt,
      Value<int?> stageChangedAt,
      Value<int?> deletedAt,
    });
typedef $$ThoughtsTableUpdateCompanionBuilder =
    ThoughtsCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<String> title,
      Value<String> content,
      Value<int?> folderId,
      Value<int> stageId,
      Value<bool> isPinned,
      Value<int?> pinnedAt,
      Value<bool> isArchived,
      Value<String> source,
      Value<int> wordCount,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> completedAt,
      Value<int?> stageChangedAt,
      Value<int?> deletedAt,
    });

class $$ThoughtsTableFilterComposer
    extends Composer<_$AppDatabase, $ThoughtsTable> {
  $$ThoughtsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stageId => $composableBuilder(
    column: $table.stageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pinnedAt => $composableBuilder(
    column: $table.pinnedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wordCount => $composableBuilder(
    column: $table.wordCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stageChangedAt => $composableBuilder(
    column: $table.stageChangedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ThoughtsTableOrderingComposer
    extends Composer<_$AppDatabase, $ThoughtsTable> {
  $$ThoughtsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stageId => $composableBuilder(
    column: $table.stageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pinnedAt => $composableBuilder(
    column: $table.pinnedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wordCount => $composableBuilder(
    column: $table.wordCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stageChangedAt => $composableBuilder(
    column: $table.stageChangedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ThoughtsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ThoughtsTable> {
  $$ThoughtsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<int> get folderId =>
      $composableBuilder(column: $table.folderId, builder: (column) => column);

  GeneratedColumn<int> get stageId =>
      $composableBuilder(column: $table.stageId, builder: (column) => column);

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<int> get pinnedAt =>
      $composableBuilder(column: $table.pinnedAt, builder: (column) => column);

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get wordCount =>
      $composableBuilder(column: $table.wordCount, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get stageChangedAt => $composableBuilder(
    column: $table.stageChangedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$ThoughtsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ThoughtsTable,
          Thought,
          $$ThoughtsTableFilterComposer,
          $$ThoughtsTableOrderingComposer,
          $$ThoughtsTableAnnotationComposer,
          $$ThoughtsTableCreateCompanionBuilder,
          $$ThoughtsTableUpdateCompanionBuilder,
          (Thought, BaseReferences<_$AppDatabase, $ThoughtsTable, Thought>),
          Thought,
          PrefetchHooks Function()
        > {
  $$ThoughtsTableTableManager(_$AppDatabase db, $ThoughtsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ThoughtsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ThoughtsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ThoughtsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<int?> folderId = const Value.absent(),
                Value<int> stageId = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<int?> pinnedAt = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<int> wordCount = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> completedAt = const Value.absent(),
                Value<int?> stageChangedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
              }) => ThoughtsCompanion(
                id: id,
                uuid: uuid,
                title: title,
                content: content,
                folderId: folderId,
                stageId: stageId,
                isPinned: isPinned,
                pinnedAt: pinnedAt,
                isArchived: isArchived,
                source: source,
                wordCount: wordCount,
                createdAt: createdAt,
                updatedAt: updatedAt,
                completedAt: completedAt,
                stageChangedAt: stageChangedAt,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uuid,
                Value<String> title = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<int?> folderId = const Value.absent(),
                required int stageId,
                Value<bool> isPinned = const Value.absent(),
                Value<int?> pinnedAt = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<int> wordCount = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> completedAt = const Value.absent(),
                Value<int?> stageChangedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
              }) => ThoughtsCompanion.insert(
                id: id,
                uuid: uuid,
                title: title,
                content: content,
                folderId: folderId,
                stageId: stageId,
                isPinned: isPinned,
                pinnedAt: pinnedAt,
                isArchived: isArchived,
                source: source,
                wordCount: wordCount,
                createdAt: createdAt,
                updatedAt: updatedAt,
                completedAt: completedAt,
                stageChangedAt: stageChangedAt,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ThoughtsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ThoughtsTable,
      Thought,
      $$ThoughtsTableFilterComposer,
      $$ThoughtsTableOrderingComposer,
      $$ThoughtsTableAnnotationComposer,
      $$ThoughtsTableCreateCompanionBuilder,
      $$ThoughtsTableUpdateCompanionBuilder,
      (Thought, BaseReferences<_$AppDatabase, $ThoughtsTable, Thought>),
      Thought,
      PrefetchHooks Function()
    >;
typedef $$TagsTableCreateCompanionBuilder =
    TagsCompanion Function({
      Value<int> id,
      required String name,
      Value<String> color,
      Value<int> sortWeight,
      required int createdAt,
      Value<int?> deletedAt,
    });
typedef $$TagsTableUpdateCompanionBuilder =
    TagsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> color,
      Value<int> sortWeight,
      Value<int> createdAt,
      Value<int?> deletedAt,
    });

class $$TagsTableFilterComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortWeight => $composableBuilder(
    column: $table.sortWeight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TagsTableOrderingComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortWeight => $composableBuilder(
    column: $table.sortWeight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get sortWeight => $composableBuilder(
    column: $table.sortWeight,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$TagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TagsTable,
          Tag,
          $$TagsTableFilterComposer,
          $$TagsTableOrderingComposer,
          $$TagsTableAnnotationComposer,
          $$TagsTableCreateCompanionBuilder,
          $$TagsTableUpdateCompanionBuilder,
          (Tag, BaseReferences<_$AppDatabase, $TagsTable, Tag>),
          Tag,
          PrefetchHooks Function()
        > {
  $$TagsTableTableManager(_$AppDatabase db, $TagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> color = const Value.absent(),
                Value<int> sortWeight = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
              }) => TagsCompanion(
                id: id,
                name: name,
                color: color,
                sortWeight: sortWeight,
                createdAt: createdAt,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String> color = const Value.absent(),
                Value<int> sortWeight = const Value.absent(),
                required int createdAt,
                Value<int?> deletedAt = const Value.absent(),
              }) => TagsCompanion.insert(
                id: id,
                name: name,
                color: color,
                sortWeight: sortWeight,
                createdAt: createdAt,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TagsTable,
      Tag,
      $$TagsTableFilterComposer,
      $$TagsTableOrderingComposer,
      $$TagsTableAnnotationComposer,
      $$TagsTableCreateCompanionBuilder,
      $$TagsTableUpdateCompanionBuilder,
      (Tag, BaseReferences<_$AppDatabase, $TagsTable, Tag>),
      Tag,
      PrefetchHooks Function()
    >;
typedef $$ThoughtTagsTableCreateCompanionBuilder =
    ThoughtTagsCompanion Function({
      required int thoughtId,
      required int tagId,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$ThoughtTagsTableUpdateCompanionBuilder =
    ThoughtTagsCompanion Function({
      Value<int> thoughtId,
      Value<int> tagId,
      Value<int> createdAt,
      Value<int> rowid,
    });

class $$ThoughtTagsTableFilterComposer
    extends Composer<_$AppDatabase, $ThoughtTagsTable> {
  $$ThoughtTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get thoughtId => $composableBuilder(
    column: $table.thoughtId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tagId => $composableBuilder(
    column: $table.tagId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ThoughtTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $ThoughtTagsTable> {
  $$ThoughtTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get thoughtId => $composableBuilder(
    column: $table.thoughtId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tagId => $composableBuilder(
    column: $table.tagId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ThoughtTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ThoughtTagsTable> {
  $$ThoughtTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get thoughtId =>
      $composableBuilder(column: $table.thoughtId, builder: (column) => column);

  GeneratedColumn<int> get tagId =>
      $composableBuilder(column: $table.tagId, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ThoughtTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ThoughtTagsTable,
          ThoughtTag,
          $$ThoughtTagsTableFilterComposer,
          $$ThoughtTagsTableOrderingComposer,
          $$ThoughtTagsTableAnnotationComposer,
          $$ThoughtTagsTableCreateCompanionBuilder,
          $$ThoughtTagsTableUpdateCompanionBuilder,
          (
            ThoughtTag,
            BaseReferences<_$AppDatabase, $ThoughtTagsTable, ThoughtTag>,
          ),
          ThoughtTag,
          PrefetchHooks Function()
        > {
  $$ThoughtTagsTableTableManager(_$AppDatabase db, $ThoughtTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ThoughtTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ThoughtTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ThoughtTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> thoughtId = const Value.absent(),
                Value<int> tagId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ThoughtTagsCompanion(
                thoughtId: thoughtId,
                tagId: tagId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int thoughtId,
                required int tagId,
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ThoughtTagsCompanion.insert(
                thoughtId: thoughtId,
                tagId: tagId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ThoughtTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ThoughtTagsTable,
      ThoughtTag,
      $$ThoughtTagsTableFilterComposer,
      $$ThoughtTagsTableOrderingComposer,
      $$ThoughtTagsTableAnnotationComposer,
      $$ThoughtTagsTableCreateCompanionBuilder,
      $$ThoughtTagsTableUpdateCompanionBuilder,
      (
        ThoughtTag,
        BaseReferences<_$AppDatabase, $ThoughtTagsTable, ThoughtTag>,
      ),
      ThoughtTag,
      PrefetchHooks Function()
    >;
typedef $$RemindersTableCreateCompanionBuilder =
    RemindersCompanion Function({
      Value<int> id,
      required int thoughtId,
      required int remindAt,
      Value<String> repeatRule,
      Value<int?> repeatInterval,
      Value<String?> repeatUnit,
      Value<String> status,
      Value<int?> lastFiredAt,
      required int createdAt,
    });
typedef $$RemindersTableUpdateCompanionBuilder =
    RemindersCompanion Function({
      Value<int> id,
      Value<int> thoughtId,
      Value<int> remindAt,
      Value<String> repeatRule,
      Value<int?> repeatInterval,
      Value<String?> repeatUnit,
      Value<String> status,
      Value<int?> lastFiredAt,
      Value<int> createdAt,
    });

class $$RemindersTableFilterComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get thoughtId => $composableBuilder(
    column: $table.thoughtId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remindAt => $composableBuilder(
    column: $table.remindAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repeatRule => $composableBuilder(
    column: $table.repeatRule,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get repeatInterval => $composableBuilder(
    column: $table.repeatInterval,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repeatUnit => $composableBuilder(
    column: $table.repeatUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastFiredAt => $composableBuilder(
    column: $table.lastFiredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RemindersTableOrderingComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get thoughtId => $composableBuilder(
    column: $table.thoughtId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remindAt => $composableBuilder(
    column: $table.remindAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repeatRule => $composableBuilder(
    column: $table.repeatRule,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get repeatInterval => $composableBuilder(
    column: $table.repeatInterval,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repeatUnit => $composableBuilder(
    column: $table.repeatUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastFiredAt => $composableBuilder(
    column: $table.lastFiredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RemindersTableAnnotationComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get thoughtId =>
      $composableBuilder(column: $table.thoughtId, builder: (column) => column);

  GeneratedColumn<int> get remindAt =>
      $composableBuilder(column: $table.remindAt, builder: (column) => column);

  GeneratedColumn<String> get repeatRule => $composableBuilder(
    column: $table.repeatRule,
    builder: (column) => column,
  );

  GeneratedColumn<int> get repeatInterval => $composableBuilder(
    column: $table.repeatInterval,
    builder: (column) => column,
  );

  GeneratedColumn<String> get repeatUnit => $composableBuilder(
    column: $table.repeatUnit,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get lastFiredAt => $composableBuilder(
    column: $table.lastFiredAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$RemindersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RemindersTable,
          Reminder,
          $$RemindersTableFilterComposer,
          $$RemindersTableOrderingComposer,
          $$RemindersTableAnnotationComposer,
          $$RemindersTableCreateCompanionBuilder,
          $$RemindersTableUpdateCompanionBuilder,
          (Reminder, BaseReferences<_$AppDatabase, $RemindersTable, Reminder>),
          Reminder,
          PrefetchHooks Function()
        > {
  $$RemindersTableTableManager(_$AppDatabase db, $RemindersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RemindersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RemindersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RemindersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> thoughtId = const Value.absent(),
                Value<int> remindAt = const Value.absent(),
                Value<String> repeatRule = const Value.absent(),
                Value<int?> repeatInterval = const Value.absent(),
                Value<String?> repeatUnit = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int?> lastFiredAt = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
              }) => RemindersCompanion(
                id: id,
                thoughtId: thoughtId,
                remindAt: remindAt,
                repeatRule: repeatRule,
                repeatInterval: repeatInterval,
                repeatUnit: repeatUnit,
                status: status,
                lastFiredAt: lastFiredAt,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int thoughtId,
                required int remindAt,
                Value<String> repeatRule = const Value.absent(),
                Value<int?> repeatInterval = const Value.absent(),
                Value<String?> repeatUnit = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int?> lastFiredAt = const Value.absent(),
                required int createdAt,
              }) => RemindersCompanion.insert(
                id: id,
                thoughtId: thoughtId,
                remindAt: remindAt,
                repeatRule: repeatRule,
                repeatInterval: repeatInterval,
                repeatUnit: repeatUnit,
                status: status,
                lastFiredAt: lastFiredAt,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RemindersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RemindersTable,
      Reminder,
      $$RemindersTableFilterComposer,
      $$RemindersTableOrderingComposer,
      $$RemindersTableAnnotationComposer,
      $$RemindersTableCreateCompanionBuilder,
      $$RemindersTableUpdateCompanionBuilder,
      (Reminder, BaseReferences<_$AppDatabase, $RemindersTable, Reminder>),
      Reminder,
      PrefetchHooks Function()
    >;
typedef $$AttachmentsTableCreateCompanionBuilder =
    AttachmentsCompanion Function({
      Value<int> id,
      required int thoughtId,
      required String type,
      required String filePath,
      Value<int?> durationMs,
      required int createdAt,
    });
typedef $$AttachmentsTableUpdateCompanionBuilder =
    AttachmentsCompanion Function({
      Value<int> id,
      Value<int> thoughtId,
      Value<String> type,
      Value<String> filePath,
      Value<int?> durationMs,
      Value<int> createdAt,
    });

class $$AttachmentsTableFilterComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get thoughtId => $composableBuilder(
    column: $table.thoughtId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AttachmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get thoughtId => $composableBuilder(
    column: $table.thoughtId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AttachmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get thoughtId =>
      $composableBuilder(column: $table.thoughtId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AttachmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AttachmentsTable,
          Attachment,
          $$AttachmentsTableFilterComposer,
          $$AttachmentsTableOrderingComposer,
          $$AttachmentsTableAnnotationComposer,
          $$AttachmentsTableCreateCompanionBuilder,
          $$AttachmentsTableUpdateCompanionBuilder,
          (
            Attachment,
            BaseReferences<_$AppDatabase, $AttachmentsTable, Attachment>,
          ),
          Attachment,
          PrefetchHooks Function()
        > {
  $$AttachmentsTableTableManager(_$AppDatabase db, $AttachmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttachmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttachmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttachmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> thoughtId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
              }) => AttachmentsCompanion(
                id: id,
                thoughtId: thoughtId,
                type: type,
                filePath: filePath,
                durationMs: durationMs,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int thoughtId,
                required String type,
                required String filePath,
                Value<int?> durationMs = const Value.absent(),
                required int createdAt,
              }) => AttachmentsCompanion.insert(
                id: id,
                thoughtId: thoughtId,
                type: type,
                filePath: filePath,
                durationMs: durationMs,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AttachmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AttachmentsTable,
      Attachment,
      $$AttachmentsTableFilterComposer,
      $$AttachmentsTableOrderingComposer,
      $$AttachmentsTableAnnotationComposer,
      $$AttachmentsTableCreateCompanionBuilder,
      $$AttachmentsTableUpdateCompanionBuilder,
      (
        Attachment,
        BaseReferences<_$AppDatabase, $AttachmentsTable, Attachment>,
      ),
      Attachment,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      required String key,
      Value<String?> value,
      Value<int> rowid,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<String> key,
      Value<String?> value,
      Value<int> rowid,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                Value<String?> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;
typedef $$ThoughtLinksTableCreateCompanionBuilder =
    ThoughtLinksCompanion Function({
      Value<int> id,
      required int fromId,
      required int toId,
      Value<String> kind,
      required int createdAt,
      Value<int?> deletedAt,
    });
typedef $$ThoughtLinksTableUpdateCompanionBuilder =
    ThoughtLinksCompanion Function({
      Value<int> id,
      Value<int> fromId,
      Value<int> toId,
      Value<String> kind,
      Value<int> createdAt,
      Value<int?> deletedAt,
    });

class $$ThoughtLinksTableFilterComposer
    extends Composer<_$AppDatabase, $ThoughtLinksTable> {
  $$ThoughtLinksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fromId => $composableBuilder(
    column: $table.fromId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get toId => $composableBuilder(
    column: $table.toId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ThoughtLinksTableOrderingComposer
    extends Composer<_$AppDatabase, $ThoughtLinksTable> {
  $$ThoughtLinksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fromId => $composableBuilder(
    column: $table.fromId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get toId => $composableBuilder(
    column: $table.toId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ThoughtLinksTableAnnotationComposer
    extends Composer<_$AppDatabase, $ThoughtLinksTable> {
  $$ThoughtLinksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get fromId =>
      $composableBuilder(column: $table.fromId, builder: (column) => column);

  GeneratedColumn<int> get toId =>
      $composableBuilder(column: $table.toId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$ThoughtLinksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ThoughtLinksTable,
          ThoughtLink,
          $$ThoughtLinksTableFilterComposer,
          $$ThoughtLinksTableOrderingComposer,
          $$ThoughtLinksTableAnnotationComposer,
          $$ThoughtLinksTableCreateCompanionBuilder,
          $$ThoughtLinksTableUpdateCompanionBuilder,
          (
            ThoughtLink,
            BaseReferences<_$AppDatabase, $ThoughtLinksTable, ThoughtLink>,
          ),
          ThoughtLink,
          PrefetchHooks Function()
        > {
  $$ThoughtLinksTableTableManager(_$AppDatabase db, $ThoughtLinksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ThoughtLinksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ThoughtLinksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ThoughtLinksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> fromId = const Value.absent(),
                Value<int> toId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
              }) => ThoughtLinksCompanion(
                id: id,
                fromId: fromId,
                toId: toId,
                kind: kind,
                createdAt: createdAt,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int fromId,
                required int toId,
                Value<String> kind = const Value.absent(),
                required int createdAt,
                Value<int?> deletedAt = const Value.absent(),
              }) => ThoughtLinksCompanion.insert(
                id: id,
                fromId: fromId,
                toId: toId,
                kind: kind,
                createdAt: createdAt,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ThoughtLinksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ThoughtLinksTable,
      ThoughtLink,
      $$ThoughtLinksTableFilterComposer,
      $$ThoughtLinksTableOrderingComposer,
      $$ThoughtLinksTableAnnotationComposer,
      $$ThoughtLinksTableCreateCompanionBuilder,
      $$ThoughtLinksTableUpdateCompanionBuilder,
      (
        ThoughtLink,
        BaseReferences<_$AppDatabase, $ThoughtLinksTable, ThoughtLink>,
      ),
      ThoughtLink,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$FoldersTableTableManager get folders =>
      $$FoldersTableTableManager(_db, _db.folders);
  $$StagesTableTableManager get stages =>
      $$StagesTableTableManager(_db, _db.stages);
  $$ThoughtsTableTableManager get thoughts =>
      $$ThoughtsTableTableManager(_db, _db.thoughts);
  $$TagsTableTableManager get tags => $$TagsTableTableManager(_db, _db.tags);
  $$ThoughtTagsTableTableManager get thoughtTags =>
      $$ThoughtTagsTableTableManager(_db, _db.thoughtTags);
  $$RemindersTableTableManager get reminders =>
      $$RemindersTableTableManager(_db, _db.reminders);
  $$AttachmentsTableTableManager get attachments =>
      $$AttachmentsTableTableManager(_db, _db.attachments);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$ThoughtLinksTableTableManager get thoughtLinks =>
      $$ThoughtLinksTableTableManager(_db, _db.thoughtLinks);
}
