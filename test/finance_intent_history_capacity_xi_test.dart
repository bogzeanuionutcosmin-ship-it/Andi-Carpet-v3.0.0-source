import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/finance/intents/finance_intent.dart';
import 'package:andi_carpeta/finance/intents/finance_capacity.dart';

void main() {
  test('XI exact UTF8 canonical JSON measurement is separate from Firestore formula', () {
    for (final count in [1000, 7300, 21900]) {
      Map<String,Object?> data(String payer) => {'teamId':'team','receivedEntries':List.generate(count,
        (n)=><String,Object?>{'id':n.toRadixString(16).padLeft(32,'0'),'kind':'departure',
          'amount':200,'method':'Cash','fromName':payer,'date':FinanceTimestamp(1790812800,123456789)})};
      final ascii=data('a'*64),unicode=data('ă'*64);
      final a=utf8.encode(canonicalFinanceJson(ascii)).length;
      final u=utf8.encode(canonicalFinanceJson(unicode)).length;
      expect(u-a, count*64,reason:'Exact UTF8 difference, not a 1KiB/receipt assumption');
      final formula=estimateFinanceDocumentBytes('settlements/trip',unicode);
      expect(formula,greaterThan(count*128));
      if(count>=7300)expect(formula,greaterThan(financeDocumentLimitBytes));
      print('XI_CAPACITY count=$count canonicalJsonAsciiBytes=$a canonicalJsonUnicodeBytes=$u firestoreFormulaBytes=$formula');
    }
  });
  test('XI timestamp nanosecond differences change exact JSON but not Firestore value size', () {
    final a=<String,Object?>{'date':FinanceTimestamp(1790812800,123456789)};
    final b=<String,Object?>{'date':FinanceTimestamp(1790812800,123456790)};
    expect(canonicalFinanceJson(a),isNot(canonicalFinanceJson(b)));
    expect(estimateFinanceDocumentBytes('n/x',a),estimateFinanceDocumentBytes('n/x',b));
    expect(utf8.encode(canonicalFinanceJson(a)).length,utf8.encode(canonicalFinanceJson(b)).length);
  });
  test('XI synthetic 20 receipts per day at 1KiB crosses reserve after 25 full days', () {
    const initial=4096, perDay=20*1024, reserve=512*1024;
    expect((reserve-initial)~/perDay,25);
    expect(initial+25*perDay,lessThanOrEqualTo(reserve));
    expect(initial+26*perDay,greaterThan(reserve));
    expect(initial+365*perDay,greaterThan(financeDocumentLimitBytes));
  });
}
