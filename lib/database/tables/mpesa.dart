import 'package:drift/drift.dart';
import 'schools.dart';

/// M-Pesa environment mode.
enum MpesaEnv {
  sandbox, // 0
  production, // 1
}

class MpesaEnvConverter extends TypeConverter<MpesaEnv, int> {
  const MpesaEnvConverter();
  @override
  MpesaEnv fromSql(int fromDb) => MpesaEnv.values[fromDb];
  @override
  int toSql(MpesaEnv value) => value.index;
}

/// Per-school M-Pesa Daraja API integration configuration.
class Mpesa extends Table {
  @override
  String get tableName => 'mpesa';

  TextColumn get school =>
      text().references(Schools, #id, onDelete: KeyAction.cascade)();
  TextColumn get consumerKey => text()();
  TextColumn get consumerSecret => text()();
  TextColumn get passkey => text()();
  TextColumn get shortcode => text()();
  IntColumn get env =>
      integer().map(const MpesaEnvConverter()).withDefault(const Constant(0))();
  Int64Column get created => int64()();
  Int64Column get updated => int64()();

  @override
  Set<Column> get primaryKey => {school};
}
