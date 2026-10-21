import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/expenses/received_money_dialog.dart';
import 'package:andi_carpeta/models/app_data_models.dart';
void main(){
  testWidgets('invalid monetary text remains in the dialog; corrected comma amount saves exactly', (tester)async{
    ReceivedMoneyEntry? saved;
    await tester.pumpWidget(MaterialApp(home:Builder(builder:(context)=>Scaffold(body:TextButton(
      onPressed:()async{saved=await showDialog<ReceivedMoneyEntry>(context:context,builder:(_)=>ReceivedMoneyDialog(departure:true,now:DateTime(2026,10,21),newId:()=>'intent'));},child:const Text('Open'))))));
    await tester.tap(find.text('Open'));await tester.pumpAndSettle();
    for(final invalid in ['NaN','Infinity','1e6','1.001','-1','0']){
      await tester.enterText(find.byType(TextFormField).first,invalid);await tester.enterText(find.byType(TextFormField).last,'Source');
      await tester.tap(find.text('Adaugă'));await tester.pumpAndSettle();expect(saved,isNull);expect(find.byType(ReceivedMoneyDialog),findsOneWidget);
    }
    await tester.enterText(find.byType(TextFormField).first,'12,34');await tester.tap(find.text('Adaugă'));
    await tester.pump(const Duration(milliseconds:50));expect(tester.takeException(),isNull);
    await tester.pumpAndSettle();expect(saved!.amount,12.34);expect(saved!.id,'intent');expect(saved!.fromName,'Source');
  });
}
