import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/finance/journal_v2/browser_journal.dart';
import 'package:andi_carpeta/finance/intents/finance_repository.dart';
void main(){
 test('V2 non-web composition fails closed without a verified native backend',(){
  expect(()=>createBrowserHistoryV2Journal(ownerUid:'a',teamId:'team',sessionIsCurrent:()=>true),
   throwsA(isA<FinanceRefusal>().having((e)=>e.code,'code','journal_v2_native_platform_blocked')));
 },skip:kIsWeb?'Native factory denial is a VM check; no native guarantee inferred from Chrome':false);
}
