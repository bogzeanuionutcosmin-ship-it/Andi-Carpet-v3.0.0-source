import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/expenses/expense_save_journal.dart';
import 'package:andi_carpeta/models/app_data_models.dart';
import 'package:andi_carpeta/models/app_enums_permissions.dart';

void main() {
  ExpenseSaveIntent intent({String user = 'user-a', String team = 'team-a', String id = 'expense-1', double amount = 12}) =>
      ExpenseSaveIntent(userId: user, teamId: team, expense: Expense(
        id: id, teamId: team, settlementId: 'settlement-1', category: 'Alte cheltuieli',
        description: 'Masa', amount: amount, date: DateTime.utc(2026, 10, 20),
        documentType: ExpenseDocumentType.fiscalReceipt, supplier: 'Magazin',
        documentImageBase64: '', imageFingerprint: 'sha256:fingerprint', ocrRawText: '',
        ocrConfidence: 0.8, confirmed: true,
      ));

  test('persists a privacy-minimal intent and exact replay succeeds after restart', () async {
    final storage = <String, String>{};
    ExpenseSaveJournal journal() => ExpenseSaveJournal(
      read: (key) async => storage[key], write: (key, value) async { storage[key] = value; },
      remove: (key) async { storage.remove(key); },
    );
    final candidate = intent();
    var attempts = 0;
    await expectLater(journal().run(candidate: candidate, send: (_) async {
      attempts++;
      throw StateError('acknowledgement lost');
    }), throwsStateError);
    expect(storage, hasLength(1));
    final serialized = storage.values.single;
    expect(serialized, contains('imageFingerprint'));
    expect(serialized, isNot(contains('documentImageBase64')));
    expect(serialized, isNot(contains('ocrRawText')));
    expect(serialized, isNot(contains('private raw OCR')));

    final recovered = await journal().pending(userId: 'user-a', teamId: 'team-a');
    expect(recovered, isNotNull);
    expect(recovered!.expense.documentImageBase64, isEmpty);
    expect(recovered.expense.ocrRawText, isEmpty);
    await journal().run(candidate: recovered, send: (_) async { attempts++; });
    expect(attempts, 2);
    expect(storage, isEmpty);
  });

  test('same pending ID with a different payload fails closed', () async {
    final storage = <String, String>{};
    final journal = ExpenseSaveJournal(
      read: (key) async => storage[key], write: (key, value) async { storage[key] = value; },
      remove: (key) async { storage.remove(key); },
    );
    await journal.persist(intent());
    var sent = false;
    await expectLater(journal.run(candidate: intent(amount: 99), send: (_) async { sent = true; }), throwsStateError);
    expect(sent, isFalse);
    expect((await journal.pending(userId: 'user-a', teamId: 'team-a'))!.expense.amount, 12);
  });

  test('corrupt storage and storage failures never send or erase the journal', () async {
    final storage = <String, String>{};
    final base = ExpenseSaveJournal(
      read: (key) async => storage[key], write: (key, value) async { storage[key] = value; },
      remove: (key) async { storage.remove(key); },
    );
    await base.persist(intent());
    final key = storage.keys.single;
    storage[key] = '{broken';
    var sent = false;
    await expectLater(base.run(candidate: intent(), send: (_) async { sent = true; }), throwsStateError);
    expect(sent, isFalse);
    expect(storage[key], '{broken');

    final failing = ExpenseSaveJournal(
      read: (_) async => null, write: (_, __) async => throw StateError('secure storage unavailable'),
      remove: (_) async {},
    );
    await expectLater(failing.run(candidate: intent(id: 'new'), send: (_) async { sent = true; }), throwsStateError);
    expect(sent, isFalse);

    final failingRead = ExpenseSaveJournal(
      read: (_) async => throw StateError('secure storage unavailable'),
      write: (_, __) async {}, remove: (_) async {},
    );
    await expectLater(failingRead.run(candidate: intent(id: 'read-failure'), send: (_) async { sent = true; }), throwsStateError);
    expect(sent, isFalse);
  });

  test('journal scopes are isolated by user and team', () async {
    final storage = <String, String>{};
    final journal = ExpenseSaveJournal(
      read: (key) async => storage[key], write: (key, value) async { storage[key] = value; },
      remove: (key) async { storage.remove(key); },
    );
    await journal.persist(intent());
    await journal.persist(intent(user: 'user-b', id: 'expense-2'));
    await journal.persist(intent(team: 'team-b', id: 'expense-3'));
    expect(storage, hasLength(3));
    expect((await journal.pending(userId: 'user-a', teamId: 'team-a'))!.expense.id, 'expense-1');
    expect((await journal.pending(userId: 'user-b', teamId: 'team-a'))!.expense.id, 'expense-2');
    expect((await journal.pending(userId: 'user-a', teamId: 'team-b'))!.expense.id, 'expense-3');
  });
}
