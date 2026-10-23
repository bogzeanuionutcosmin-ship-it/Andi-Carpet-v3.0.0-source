import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/expenses/expense_document_create.dart';

Map<String, dynamic> payload() => {
  'teamId': 'team-a', 'settlementId': 'settlement-1', 'category': 'Combustibil',
  'description': 'Carburant', 'amount': 25.5, 'date': DateTime.utc(2026, 10, 20),
  'documentType': 'fiscalReceipt', 'documentNumber': 'B-12', 'supplier': 'Station',
  'liters': 10.0, 'pricePerLiter': 2.55, 'documentImageBase64': '',
  'imageFingerprint': 'sha256:fingerprint', 'ocrRawText': '', 'ocrConfidence': 0.9,
  'confirmed': true, 'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 23)),
};

void main() {
  test('new ID returns create payload and exact replay is a no-op', () {
    final incoming = payload();
    expect(expenseDocumentCreateWrite(incoming: incoming, current: {}, exists: false), incoming);
    final current = Map<String, dynamic>.of(incoming)
      ..['date'] = Timestamp.fromDate(DateTime.utc(2026, 10, 20))
      ..['updatedAt'] = Timestamp.fromDate(DateTime.utc(2026, 10, 21));
    expect(expenseDocumentCreateWrite(incoming: incoming, current: current, exists: true), isNull);
  });

  test('conflicting payload under the same ID fails closed', () {
    for (final change in <String, dynamic>{'amount': 99, 'supplier': 'Other', 'unexpected': true}.entries) {
      final current = payload()..[change.key] = change.value;
      expect(() => expenseDocumentCreateWrite(incoming: payload(), current: current, exists: true), throwsStateError);
    }
  });

  test('lost create acknowledgement tolerates later confirmation without downgrading', () {
    final pending = payload()..['confirmed'] = false;
    final confirmed = payload();
    expect(expenseDocumentCreateWrite(incoming: pending, current: confirmed, exists: true), isNull);
    expect(confirmed['confirmed'], isTrue);
    final changed = payload()..['amount'] = 99;
    expect(() => expenseDocumentCreateWrite(incoming: pending, current: changed, exists: true), throwsStateError);
    // A create retry must never be used to perform the confirmation itself.
    expect(() => expenseDocumentCreateWrite(incoming: confirmed, current: pending, exists: true), throwsStateError);
  });

  test('confirmation only writes its state and timestamp, preserving original payload', () {
    final incoming = payload();
    final current = payload()
      ..['confirmed'] = false
      ..['date'] = Timestamp.fromDate(DateTime.utc(2026, 10, 20))
      ..['updatedAt'] = Timestamp.fromDate(DateTime.utc(2026, 10, 21))
      ..['serverMetadata'] = {'version': 1};
    final before = Map<String, dynamic>.of(current);
    final update = expenseDocumentConfirmationWrite(incoming: incoming, current: current, exists: true)!;
    expect(update, {'confirmed': true, 'updatedAt': incoming['updatedAt']});
    expect(current, before);
    expect(update.containsKey('amount'), isFalse);
    expect(update.containsKey('documentImageBase64'), isFalse);
  });

  test('confirmation replay is an idempotent no-op', () {
    final current = payload()..['updatedAt'] = Timestamp.fromDate(DateTime.utc(2026, 10, 21));
    expect(expenseDocumentConfirmationWrite(incoming: payload(), current: current, exists: true), isNull);
  });

  test('confirmation rejects deleted or changed financial and identity data', () {
    expect(() => expenseDocumentConfirmationWrite(incoming: payload(), current: {}, exists: false), throwsStateError);
    for (final change in <String, dynamic>{
      'teamId': 'team-b', 'settlementId': 'other-settlement', 'amount': 99,
      'date': DateTime.utc(2026, 10, 21), 'supplier': 'Other',
      'documentNumber': 'changed', 'confirmed': 'invalid',
    }.entries) {
      final current = payload()..['confirmed'] = false;
      current[change.key] = change.value;
      expect(() => expenseDocumentConfirmationWrite(incoming: payload(), current: current, exists: true), throwsStateError);
    }
  });

  test('confirmation supports sparse legacy defaults without writing them back', () {
    final current = <String, dynamic>{
      'teamId': 'team-a', 'amount': 25.5, 'date': DateTime.utc(2026, 10, 20), 'confirmed': false,
    };
    final incoming = payload()
      ..['settlementId'] = null
      ..['category'] = 'Alte cheltuieli'
      ..['description'] = ''
      ..['documentNumber'] = ''
      ..['supplier'] = ''
      ..['liters'] = null
      ..['pricePerLiter'] = null
      ..['imageFingerprint'] = ''
      ..['ocrConfidence'] = 0;
    expect(expenseDocumentConfirmationWrite(incoming: incoming, current: current, exists: true),
      {'confirmed': true, 'updatedAt': incoming['updatedAt']});
    expect(current.keys, unorderedEquals(['teamId', 'amount', 'date', 'confirmed']));
    final incomplete = Map<String, dynamic>.of(incoming)..remove('amount');
    expect(() => expenseDocumentConfirmationWrite(incoming: incomplete, current: current, exists: true), throwsStateError);
  });

  test('private image or OCR payload is refused', () {
    for (final field in ['documentImageBase64', 'ocrRawText']) {
      final incoming = payload()..[field] = 'private';
      expect(() => expenseDocumentCreateWrite(incoming: incoming, current: {}, exists: false), throwsStateError);
      final current = payload()..[field] = 'legacy private data';
      expect(() => expenseDocumentCreateWrite(incoming: payload(), current: current, exists: true), throwsStateError);
    }
  });
}
