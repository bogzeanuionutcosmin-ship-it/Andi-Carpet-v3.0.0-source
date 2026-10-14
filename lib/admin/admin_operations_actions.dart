part of '../main.dart';

// Work schedules, completed records and finance admin operations.
mixin _AdminOperationsActions on State<AdminPanelPage> {
  List<WorkSchedule> get schedules;
  List<CentralizerRecord> get records;
  List<Expense> get expenses;
  AppSettings get settings;
  int get section;
  set section(int value);
  String _safeTeam(String id);

Future<void> _setScheduleClosed(WorkSchedule schedule, bool closed) async {
   try {
     await FirebaseFirestore.instance.collection('schedules').doc(schedule.id).update({
       'closed': closed,
       'active': !closed,
       'updatedAt': FieldValue.serverTimestamp(),
     });
     widget.log(closed ? 'Grafic/zi închisă de Admin' : 'Grafic/zi redeschisă de Admin', '${_safeTeam(schedule.teamId)} · ${formatDate(schedule.date)}');
   } catch (e) {
     if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Modificarea graficului a eșuat: $e')));
   }
 }

 Future<void> _deleteSchedulePermanently(WorkSchedule schedule) async {
   final graphId = schedule.graphId.trim().isEmpty ? schedule.id : schedule.graphId;
   final related = schedules.where((s) => s.teamId == schedule.teamId && (s.graphId.trim().isEmpty ? s.id : s.graphId) == graphId).toList();
   final deleteWholeGraph = related.length > 1;
   final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
     title: Text(deleteWholeGraph ? 'Ștergi definitiv graficul?' : 'Ștergi definitiv graficul/ziua?'),
     content: Text(
       deleteWholeGraph
           ? '${schedule.graphName} are ${related.length} zile. Toate zilele graficului vor fi șterse definitiv, indiferent dacă sunt deschise sau închise. Istoricul execuțiilor din Centralizator rămâne păstrat.'
           : '${schedule.graphName} · ${formatDate(schedule.date)} va fi șters definitiv. Istoricul execuțiilor din Centralizator rămâne păstrat.'
     ),
     actions: [
       TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Anulează')),
       FilledButton.icon(onPressed: () => Navigator.pop(c, true), icon: const Icon(Icons.delete_forever), label: const Text('Șterge definitiv')),
     ],
   )) ?? false;
   if (!ok) return;
   try {
     final db = FirebaseFirestore.instance;
     final batch = db.batch();
     for (final item in related) {
       batch.delete(db.collection('schedules').doc(item.id));
     }
     await batch.commit();
     widget.log('Grafic șters definitiv de Admin', '${schedule.graphName} · ${related.length} zile');
     if (mounted) showSuccessMessage(context, deleteWholeGraph ? 'Graficul ${schedule.graphName} a fost șters definitiv.' : 'Graficul/ziua a fost șters(ă) definitiv.');
   } catch (e) {
     if (mounted) showErrorMessage(context, 'Graficul nu a putut fi șters: $e');
   }
 }

 Future<void> _deleteRecord(CentralizerRecord record) async {
   final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
     title: const Text('Ștergi execuția?'),
     content: Text('${record.locationNameSnapshot} va fi eliminată din Centralizator. Operația intră în Audit.'),
     actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Anulează')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Șterge'))],
   )) ?? false;
   if (!ok) return;
   try {
     await FirebaseFirestore.instance.collection('records').doc(record.id).delete();
     widget.log('Execuție ștearsă de Admin', record.locationNameSnapshot);
   } catch (e) {
     if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ștergerea execuției a eșuat: $e')));
   }
 }

 Future<void> _deleteExpense(Expense expense) async {
   final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
     title: const Text('Ștergi documentul financiar?'),
     content: Text('${expense.documentType == ExpenseDocumentType.fiscalReceipt ? 'Bon Fiscal' : 'Factură'} nr ${expense.documentNumber} va fi eliminat. Operația intră în Audit.'),
     actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Anulează')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Șterge'))],
   )) ?? false;
   if (!ok) return;
   try {
     await FirebaseFirestore.instance.collection('expenses').doc(expense.id).delete();
     widget.log('Document financiar șters de Admin', expense.documentNumber);
   } catch (e) {
     if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ștergerea documentului a eșuat: $e')));
   }
 }

 Widget _programs() {
   final grouped = <String,List<WorkSchedule>>{};
   for (final s in schedules) {
     final graphId = s.graphId.trim().isEmpty ? s.id : s.graphId;
     grouped.putIfAbsent('${s.teamId}|$graphId', () => <WorkSchedule>[]).add(s);
   }
   final groups = grouped.values.toList()
     ..forEach((days) => days.sort((a,b) => a.date.compareTo(b.date)))
     ..sort((a,b) => b.first.date.compareTo(a.first.date));
   return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
     Row(children:[const Expanded(child:Text('Grafice de lucru',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold))),IconButton(tooltip:'Setări Grafice',onPressed:()=>setState(()=>section=15),icon:const Icon(Icons.settings_outlined))]),
     const SizedBox(height:6),
     const Text('Adminul poate închide/redeschide zilele unui grafic sau poate șterge definitiv întregul grafic, indiferent dacă este deschis ori închis. Istoricul execuțiilor din Centralizator rămâne păstrat.'),
     const SizedBox(height:10),
     if(groups.isEmpty)const _Empty(icon:Icons.calendar_month,text:'Nu există grafice de lucru.'),
     ...groups.map((days){
       final first=days.first;
       final openCount=days.where((s)=>!s.closed).length;
       final closedCount=days.length-openCount;
       return Card(child:ExpansionTile(
         leading:const Icon(Icons.calendar_month),
         title:Text('${first.graphName} · ${_safeTeam(first.teamId)}',style:const TextStyle(fontWeight:FontWeight.w800)),
         subtitle:Text('${days.length} zile · $openCount deschise · $closedCount închise'),
         trailing:IconButton(tooltip:'Șterge definitiv întregul grafic',onPressed:()=>_deleteSchedulePermanently(first),icon:const Icon(Icons.delete_forever,color:Colors.redAccent)),
         children:days.map((s)=>ListTile(
           title:Text(formatDate(s.date)),
           subtitle:Text('${s.items.length} locații · ${s.closed?'închis':'activ'}'),
           trailing:Switch(value:s.closed,onChanged:(v)=>_setScheduleClosed(s,v)),
         )).toList(),
       ));
     }),
   ]);
 }
 Widget _records() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
   const Text('Centralizator / istoric execuții', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
   ...records.map((r) => Card(child: ListTile(
     title: Text(r.locationNameSnapshot),
     subtitle: Text('${_safeTeam(r.teamId)} · ${formatDate(r.finishedAt ?? r.startedAt ?? DateTime.now())} · ${timeText(r.startedAt)}–${timeText(r.finishedAt)} · ${r.status.name}'),
     trailing: IconButton(tooltip: 'Șterge execuția', onPressed: () => _deleteRecord(r), icon: const Icon(Icons.delete_forever)),
   )))
 ]);
 Widget _finance() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
   Row(children:[const Expanded(child:Text('Decont & Financiar',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold))),IconButton(tooltip:'Setări financiare',onPressed:()=>showDialog<void>(context:context,builder:(c)=>AlertDialog(title:const Text('Setări financiare'),content:Text('Diurna implicită este ${settings.defaultPerDiem.toStringAsFixed(2)} lei/zi. Modificările generale se fac din Setări sistem.'))),icon:const Icon(Icons.settings_outlined))]),
   const SizedBox(height: 8),
   Text('Documente confirmate: ${expenses.where((e) => e.confirmed).length}'),
   ...expenses.map((e) => Card(child: ListTile(
     title: Text('${e.documentType == ExpenseDocumentType.fiscalReceipt ? 'Bon Fiscal' : 'Factură'} nr ${e.documentNumber}'),
     subtitle: Text('data ${formatDate(e.date)} · suma ${e.amount.toStringAsFixed(2)} lei · ${e.category}'),
     trailing: IconButton(tooltip: 'Șterge documentul', onPressed: () => _deleteExpense(e), icon: const Icon(Icons.delete_forever)),
   )))
 ]);
  }
