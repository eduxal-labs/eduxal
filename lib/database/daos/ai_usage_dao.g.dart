// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_usage_dao.dart';

// ignore_for_file: type=lint
mixin _$AiUsageDaoMixin on DatabaseAccessor<AppDatabase> {
  $SchoolsTable get schools => attachedDatabase.schools;
  $AiUsageTable get aiUsage => attachedDatabase.aiUsage;
  AiUsageDaoManager get managers => AiUsageDaoManager(this);
}

class AiUsageDaoManager {
  final _$AiUsageDaoMixin _db;
  AiUsageDaoManager(this._db);
  $$SchoolsTableTableManager get schools =>
      $$SchoolsTableTableManager(_db.attachedDatabase, _db.schools);
  $$AiUsageTableTableManager get aiUsage =>
      $$AiUsageTableTableManager(_db.attachedDatabase, _db.aiUsage);
}
