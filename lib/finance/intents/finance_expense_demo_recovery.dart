import 'package:flutter/material.dart';
import 'finance_expense_demo_adapter.dart';

// Demo-only wrapper around the ORIGINAL ExpensePage. Listens to explicit
// operations; mounting/rebuilding performs no database reads or retries.
class FinanceExpenseDemoRecovery extends StatelessWidget {
  final FinanceExpenseDemoAdapter adapter;
  final Widget child;
  const FinanceExpenseDemoRecovery({super.key,required this.adapter,required this.child});
  @override Widget build(BuildContext context)=>AnimatedBuilder(animation:adapter,builder:(context,_)=>
    Column(children:[
      TextButton(onPressed:adapter.recoveryBusy||!adapter.scope.sessionIsCurrent()?null:
        ()async{await adapter.loadPendingForReviewExplicitly();},
        child:const Text('Verifică operațiile în așteptare')),
      if(adapter.recoveryCode!=null)const Text('Operațiile locale nu pot fi verificate acum.'),
      for(final pending in adapter.pendingCodes.entries)
        MaterialBanner(content:Text(switch(pending.value){
          'finance_revision_conflict'||'finance_evidence_mismatch'=>'Datele au fost modificate. Salvarea necesită verificare.',
          'finance_pending'=>'Salvare în curs.',
          _=>'Rezultatul salvării nu este încă confirmat.',
        }),actions:[TextButton(
          onPressed:adapter.isBusy(pending.key)||!adapter.scope.sessionIsCurrent()?null:
            () async {await adapter.reconcileExplicitly(pending.key);},
          child:const Text('Verifică salvarea'))]),
      Expanded(child:child),
    ]));
}
