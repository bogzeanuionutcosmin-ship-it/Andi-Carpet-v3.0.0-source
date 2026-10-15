import 'package:flutter/material.dart';
import 'finance_coordinator.dart';
import 'finance_intent.dart';
import 'finance_journal.dart';
import 'finance_repository.dart';

// Explicit harness composition. Never constructed by production Home/ExpensePage.
// Pass the actual AuthGate ownership closure, not UID equality alone.
class FinanceDemoScope {
  final String ownerUid;
  final bool Function() _ownerIsCurrent;
  bool _open=true;
  bool sessionIsCurrent()=>_open && _ownerIsCurrent();
  void dispose(){_open=false;}
  late final FinanceIntentCoordinator coordinator;
  FinanceDemoScope({required this.ownerUid, required bool Function() sessionIsCurrent,
    required FinanceAtomicPort port, required FinanceJournalStorage storage})
      : _ownerIsCurrent=sessionIsCurrent {
    coordinator=FinanceIntentCoordinator(
      repository:FinanceRepository(port:port,ownerUid:ownerUid,sessionIsCurrent:this.sessionIsCurrent),
      journal:FinanceIntentJournal(storage:storage,ownerUid:ownerUid,sessionIsCurrent:this.sessionIsCurrent));
  }
}

// A single durable request is injected once per operator action. Rebuilds and
// double taps never generate another ID; reopening does not submit anything.
class FinanceIntentDemoPanel extends StatefulWidget {
  final FinanceDemoScope scope;
  final FinanceIntent intent;
  const FinanceIntentDemoPanel({super.key,required this.scope,required this.intent});
  @override State<FinanceIntentDemoPanel> createState()=>_FinanceIntentDemoPanelState();
}
class _FinanceIntentDemoPanelState extends State<FinanceIntentDemoPanel> {
  bool busy=false,completed=false;
  String code='finance_ready';
  int generation=0;
  @override void didUpdateWidget(covariant FinanceIntentDemoPanel old) {
    super.didUpdateWidget(old);
    if (!identical(old.scope,widget.scope) || old.intent.digest!=widget.intent.digest) {
      if(!identical(old.scope,widget.scope))old.scope.dispose();
      generation++;busy=false;completed=false;code='finance_ready';
    }
  }
  @override void dispose() {generation++;widget.scope.dispose();super.dispose();}
  Future<void> run(bool reconcile) async {
    if(busy || completed || !widget.scope.sessionIsCurrent() ||
        widget.intent.actorUid!=widget.scope.ownerUid) return;
    final scope=widget.scope,intent=widget.intent,epoch=generation;
    setState(()=>busy=true);
    final result=reconcile ? await scope.coordinator.reconcileExplicitly(intent) :
      await scope.coordinator.executeExplicitly(intent);
    if(!mounted || epoch!=generation || !identical(scope,widget.scope) ||
        !scope.sessionIsCurrent()) return;
    setState(() {
      busy=false;code=result.result.code;
      completed=result.result.status==FinanceIntentStatus.confirmed;
    });
  }
  @override Widget build(BuildContext context)=>Column(mainAxisSize:MainAxisSize.min,children:[
    const Text('Test financiar demo'),
    Text(code,key:const ValueKey('finance-demo-status')),
    FilledButton(onPressed:busy||completed?null:()=>run(false),child:const Text('Execută intenția')),
    OutlinedButton(onPressed:busy||completed?null:()=>run(true),child:const Text('Verifică pe server')),
  ]);
}
