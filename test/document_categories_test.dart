import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/documents/document_categories.dart';

void main() {
  test('PV Million introdus istoric la alte documente se afișează la PV', () {
    expect(
      isProtocolDocument(title: 'PV MILLION', category: 'Alte documente'),
      isTrue,
    );
    expect(
      isProtocolDocument(
        title: 'Proces verbal Million Games',
        category: 'Alte documente',
      ),
      isTrue,
    );
    expect(
      documentDisplayGroup(title: 'PV de la Million', category: 'Alte documente'),
      'Procese verbale',
    );
  });

  test('Categoria explicită Proces verbal are prioritate', () {
    expect(isProtocolDocument(title: 'Document 2026', category: 'Proces verbal'), isTrue);
  });

  test('Contractul Million nu este clasificat greșit ca PV', () {
    expect(isProtocolDocument(title: 'Contract MILLION', category: 'Contract'), isFalse);
    expect(isProtocolDocument(title: 'Anexă PV', category: 'Anexă'), isFalse);
    expect(isProtocolDocument(title: 'Contract MILLION', category: 'Alte documente'), isFalse);
  });

  test('Numele obișnuite nu sunt confundate cu abrevierea PV', () {
    expect(isProtocolDocument(title: 'Pavilion 123', category: 'Alte documente'), isFalse);
    expect(isProtocolDocument(title: '', category: 'Alte documente'), isFalse);
  });
}
