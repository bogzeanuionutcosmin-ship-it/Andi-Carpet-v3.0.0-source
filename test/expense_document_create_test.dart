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

  test('private image or OCR payload is refused', () {
    for (final field in ['documentImageBase64', 'ocrRawText']) {
      final incoming = payload()..[field] = 'private';
      expect(() => expenseDocumentCreateWrite(incoming: incoming, current: {}, exists: false), throwsStateError);
      final current = payload()..[field] = 'legacy private data';
      expect(() => expenseDocumentCreateWrite(incoming: payload(), current: current, exists: true), throwsStateError);
    }
  });
}
