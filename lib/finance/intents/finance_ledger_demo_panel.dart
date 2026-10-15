import 'package:flutter/material.dart';
import 'finance_ledger.dart';

// Manual review only; retains ONE bounded page and never starts a request from
// mount/rebuild. No monetary values, actor IDs or operation IDs in diagnostics.
class FinanceLedgerDemoPanel extends StatefulWidget {
  final FinanceLedgerReader reader;
  final String targetPath;
  const FinanceLedgerDemoPanel({super.key,required this.reader,required this.targetPath});
  @override State<FinanceLedgerDemoPanel> createState()=>_LedgerPanelState();
}
class _LedgerPanelState extends State<FinanceLedgerDemoPanel> {
  FinanceLedgerPage? page;
  bool busy=false,failed=false;
  int generation=0;
  @override void didUpdateWidget(covariant FinanceLedgerDemoPanel old){
    super.didUpdateWidget(old);
    if(!identical(old.reader,widget.reader)||old.targetPath!=widget.targetPath){
      if(!identical(old.reader,widget.reader)){old.reader.dispose();}else{old.reader.invalidate();}
      generation++;page=null;busy=false;failed=false;
    }
  }
  @override void dispose(){generation++;widget.reader.dispose();super.dispose();}
  Future<void> run(bool next)async{
    if(busy||!widget.reader.sessionIsCurrent())return;
    final epoch=generation,reader=widget.reader,path=widget.targetPath,cursor=page?.next;
    if(next&&cursor==null)return;
    setState((){busy=true;failed=false;});
    try {
      final result=next?await reader.nextExplicitly(cursor!):await reader.firstExplicitly(path);
      if(mounted&&epoch==generation&&reader.sessionIsCurrent())setState(()=>page=result);
    } catch(_) {
      if(mounted&&epoch==generation&&reader.sessionIsCurrent())setState(()=>failed=true);
    } finally {
      if(mounted&&epoch==generation)setState(()=>busy=false);
    }
  }
  @override Widget build(BuildContext context)=>Column(children:[
    Wrap(children:[
      TextButton(onPressed:busy?null:()=>run(false),child:const Text('Deschide registrul operațiilor')),
      TextButton(onPressed:busy||page?.next==null?null:()=>run(true),child:const Text('Pagina următoare')),
    ]),
    if(failed)const Text('Registrul nu poate fi verificat acum.'),
    if(page!=null)Text('Revizie analizată: ${page!.upperRevision}'),
    Expanded(child:ListView(children:[
      for(final row in page?.rows??<FinanceLedgerRow>[])
        ListTile(title:Text('${switch(row.data['kind']){
          'receipt'=>'Încasare','create'=>'Creare','close'=>'Închidere',_=>'Modificare'}} · revizia ${row.data['revision']}')),
    ])),
  ]);
}
