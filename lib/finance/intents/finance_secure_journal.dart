import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'finance_journal.dart';

// No logging, export, account crossover, timer or automatic replay. Kept out of
// production construction until platform storage + journal lifecycle acceptance.
class FinanceSecureJournalStorage implements FinanceJournalStorage {
  final FlutterSecureStorage storage;
  const FinanceSecureJournalStorage(this.storage);
  @override Future<String?> read(String key)=>storage.read(key:key);
  @override Future<void> write(String key,String value)=>storage.write(key:key,value:value);
}
