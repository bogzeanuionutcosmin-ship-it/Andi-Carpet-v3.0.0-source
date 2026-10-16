part of '../main.dart';

extension _ExpenseSettlementActions on _ExpensePageState {
  Widget _settlementSelector() {
    final items = <DropdownMenuItem<String>>[];
    for (final s in teamSettlements) {
      items.add(DropdownMenuItem(value: s.id, child: Text('${s.name} · ${_shortDate(s.startDate)}${s.closed ? ' · închisă' : ''}')));
    }
    if (hasLegacyData) items.add(const DropdownMenuItem(value: _ExpensePageState._legacySettlementKey, child: Text('Istoric anterior · date fără deplasare')));
    final value = _resolvedSettlementId();
    return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(child: Text('Deplasare / Decont', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        if (widget.canEditOwnDecont && widget.canEditTeam(team.id))
          FilledButton.tonalIcon(onPressed: _createSettlement, icon: const Icon(Icons.add), label: const Text('Nouă')),
      ]),
      const SizedBox(height: 8),
      if (items.isNotEmpty)
        DropdownButtonFormField<String>(
          value: value,
          decoration: const InputDecoration(labelText: 'Selectează deplasarea'),
          items: items,
          onChanged: (v) => setState(() => selectedSettlementId = v),
        )
      else
        const Text('Nu există deplasări.'),
      if (settlement != null) ...[
        const SizedBox(height: 8),
        Text('Perioadă: ${_shortDate(settlement!.startDate)}${settlement!.endDate == null ? '' : ' – ${_shortDate(settlement!.endDate!)}'} · ${settlement!.closed ? 'Închisă' : 'Activă'}'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (isManager || widget.isAdmin) OutlinedButton.icon(onPressed: _editSettlement, icon: const Icon(Icons.edit_outlined), label: const Text('Editează deplasarea')),
          if (isManager || widget.isAdmin) OutlinedButton.icon(onPressed: _toggleSettlementClosed, icon: Icon(settlement!.closed ? Icons.lock_open : Icons.lock_outline), label: Text(settlement!.closed ? 'Redeschide' : 'Închide decontul')),
        ]),
      ],
      if (isLegacy) ...[
        const SizedBox(height: 8),
        const Text('Aceste date au fost create înainte de separarea pe deplasări. Rămân intacte și pot fi exportate separat.', style: TextStyle(fontSize: 12)),
      ],
    ])));
  }

  String _shortDate(DateTime d) => '${two(d.day)}.${two(d.month)}.${d.year}';

  Future<void> _createSettlement() async {
    var start = DateTime.now();
    DateTime? end;
    final nameC = TextEditingController(text: 'Deplasare ${_shortDate(start)}');
    final result = await showDialog<TravelSettlement>(context: context, builder: (d) => StatefulBuilder(builder: (d, setD) => AlertDialog(
      title: const Text('Deplasare nouă'),
      content: SizedBox(width: 520, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Denumire')), const SizedBox(height: 10),
        ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.event), title: const Text('Data început'), subtitle: Text(_shortDate(start)), trailing: TextButton(onPressed: () async { final x = await showDatePicker(context: d, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: start); if (x != null) setD(() { start = x; if (end != null && end!.isBefore(start)) end = start; }); }, child: const Text('Alege'))),
        ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.event_available), title: const Text('Data final (opțional)'), subtitle: Text(end == null ? 'Nesetată' : _shortDate(end!)), trailing: TextButton(onPressed: () async { final x = await showDatePicker(context: d, firstDate: start, lastDate: DateTime(2100), initialDate: end ?? start); if (x != null) setD(() => end = x); }, child: const Text('Alege'))),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Anulează')), FilledButton(onPressed: () { final n = nameC.text.trim(); if (n.isEmpty) return; Navigator.pop(d, TravelSettlement(id: idNow(), teamId: team.id, name: n, startDate: start, endDate: end, managerId: finance.managerId ?? team.financialManagerId ?? (team.members.contains(widget.currentUser.id) ? widget.currentUser.id : null), perDiemRate: finance.perDiemRate)); }, child: const Text('Creează'))],
    )));
    nameC.dispose();
    if (result == null) return;
    try {
      await widget.saveSettlement(result);
      widget.log('Deplasare creată', '${team.name} · ${result.name}');
      if (mounted) setState(() => selectedSettlementId = result.id);
    } catch (e) { if (mounted) showErrorMessage(context, 'Deplasarea nu a putut fi creată: $e'); }
  }

  Future<void> _editSettlement() async {
    final s = settlement; if (s == null) return;
    var start = s.startDate; var end = s.endDate;
    final nameC = TextEditingController(text: s.name);
    final ok = await showDialog<bool>(context: context, builder: (d) => StatefulBuilder(builder: (d, setD) => AlertDialog(
      title: const Text('Editează deplasarea'),
      content: SizedBox(width: 520, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Denumire')), const SizedBox(height: 8),
        ListTile(contentPadding: EdgeInsets.zero, title: const Text('Început'), subtitle: Text(_shortDate(start)), trailing: TextButton(onPressed: () async { final x = await showDatePicker(context: d, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: start); if (x != null) setD(() => start = x); }, child: const Text('Alege'))),
        ListTile(contentPadding: EdgeInsets.zero, title: const Text('Final'), subtitle: Text(end == null ? 'Nesetat' : _shortDate(end!)), trailing: Wrap(children: [TextButton(onPressed: () async { final x = await showDatePicker(context: d, firstDate: start, lastDate: DateTime(2100), initialDate: end ?? start); if (x != null) setD(() => end = x); }, child: const Text('Alege')), if (end != null) IconButton(onPressed: () => setD(() => end = null), icon: const Icon(Icons.clear))])),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Anulează')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Salvează'))],
    )));
    if (ok == true) {
      s.name = nameC.text.trim().isEmpty ? s.name : nameC.text.trim(); s.startDate = start; s.endDate = end;
      try { await widget.saveSettlement(s); widget.log('Deplasare modificată', s.name); } catch (e) { if (mounted) showErrorMessage(context, 'Nu s-a putut salva: $e'); }
    }
    nameC.dispose();
  }

  Future<void> _toggleSettlementClosed() async {
    final s = settlement; if (s == null) return;
    final next = !s.closed;
    if (next) {
      final ok = await showDialog<bool>(context: context, builder: (d) => AlertDialog(title: const Text('Închizi decontul?'), content: const Text('Nu se vor mai putea adăuga documente sau diurne până la redeschidere.'), actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Anulează')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Închide'))])) ?? false;
      if (!ok) return;
    }
    s.closed = next;
    if (next && s.endDate == null) s.endDate = DateTime.now();
    try { await widget.saveSettlement(s); widget.log(next ? 'Decont închis' : 'Decont redeschis', s.name); if (mounted) setState(() {}); } catch (e) { s.closed = !next; if (mounted) showErrorMessage(context, 'Nu s-a putut salva: $e'); }
  }

  Future<void> _showGeneralCalculations() async {
    final years=<int>{};
    for(final e in widget.expenses.where((x)=>x.teamId==team.id)){years.add(e.date.year);}
    for(final d in widget.perDiems.where((x)=>x.teamId==team.id)){years.add((d.confirmedAt ?? d.date).year);}
    for(final st in widget.settlements.where((x)=>x.teamId==team.id)){years.add(st.startDate.year);}
    final orderedYears=years.toList()..sort((a,b)=>b.compareTo(a));
    int? selectedYear=orderedYears.isEmpty?DateTime.now().year:orderedYears.first;
    bool allTime=false;

    Map<String,double> calculate(){
      bool dateOk(DateTime d)=>allTime||d.year==selectedYear;
      final expenseIds=<String>{};
      final teamExpenses=widget.expenses.where((e)=>e.teamId==team.id&&e.confirmed&&
          e.amount.isFinite&&e.amount>=0&&dateOk(e.date)&&expenseIds.add(e.id)).toList();
      final paymentIds=<String>{};
      final teamPerDiems=widget.perDiems.where((d)=>d.teamId==team.id&&
          d.status==PerDiemStatus.confirmed&&d.received==true&&
          d.actualReceivedAmount!=null&&d.actualReceivedAmount!.isFinite&&
          d.actualReceivedAmount!>=0&&dateOk(d.confirmedAt??d.date)&&paymentIds.add(d.id)).toList();
      final fuelTotal=teamExpenses.where((e)=>e.category=='Combustibil').fold<double>(0,(a,b)=>a+b.amount);
      final invoiceTotal=teamExpenses.where((e)=>e.category!='Combustibil'&&(e.documentType==ExpenseDocumentType.invoice||e.category=='Facturi')).fold<double>(0,(a,b)=>a+b.amount);
      final otherTotal=teamExpenses.where((e)=>e.category!='Combustibil'&&e.documentType!=ExpenseDocumentType.invoice&&e.category!='Facturi').fold<double>(0,(a,b)=>a+b.amount);
      final perDiemTotal=teamPerDiems.fold<double>(0,(a,b)=>a+b.actualReceivedAmount!);

      // Deduplicate individual transfers across legacy team finances and
      // settlement records. Historical aggregate-only records have no transfer
      // identifiers and therefore cannot be safely deduplicated.
      double receivedTotal=0;
      final seenTransferIds=<String>{};
      void addTransfers(List<ReceivedMoneyEntry> transfers){
        for(final transfer in transfers){
          if(!dateOk(transfer.date) || !transfer.amount.isFinite || transfer.amount < 0) continue;
          if(!seenTransferIds.add(transfer.id)) continue;
          receivedTotal+=transfer.amount;
        }
      }
      for(final st in widget.settlements.where((x)=>x.teamId==team.id)){
        if(st.receivedEntries.isNotEmpty){
          addTransfers(st.receivedEntries);
        }else if(dateOk(st.startDate)){
          receivedTotal+=st.totalReceived;
        }
      }
      final f=widget.finances.where((x)=>x.teamId==team.id).toList();
      if(f.isNotEmpty){
        final tf=f.first;
        if(tf.receivedEntries.isNotEmpty){
          addTransfers(tf.receivedEntries);
        }else if(allTime){
          // Legacy totals without dates appear only in the all-time report.
          receivedTotal+=tf.totalReceived;
        }
      }
      final totalSpent=fuelTotal+invoiceTotal+otherTotal+perDiemTotal;
      return {
        'fuel':fuelTotal,'invoice':invoiceTotal,'perDiem':perDiemTotal,'other':otherTotal,
        'spent':totalSpent,'received':receivedTotal,
        'budget':(receivedTotal-totalSpent).clamp(0,double.infinity).toDouble(),
        'due':(totalSpent-receivedTotal).clamp(0,double.infinity).toDouble(),
      };
    }

    await showDialog<void>(context:context,builder:(d)=>StatefulBuilder(builder:(d,setD){
      final c=calculate();
      Widget row(String label,double value,{bool strong=false})=>Padding(
        padding:const EdgeInsets.symmetric(vertical:4),
        child:Row(children:[
          Expanded(child:Text(label,style:TextStyle(fontWeight:strong?FontWeight.w900:FontWeight.w600))),
          Text('${value.toStringAsFixed(2)} lei',style:TextStyle(fontWeight:strong?FontWeight.w900:FontWeight.w700)),
        ]),
      );
      return AlertDialog(
        title:const Text('Calcule generale'),
        content:SizedBox(width:520,child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          SegmentedButton<bool>(
            segments:const[
              ButtonSegment(value:false,label:Text('Anual'),icon:Icon(Icons.calendar_month)),
              ButtonSegment(value:true,label:Text('Total general'),icon:Icon(Icons.all_inclusive)),
            ],
            selected:<bool>{allTime},
            onSelectionChanged:(v)=>setD(()=>allTime=v.first),
          ),
          if(!allTime)...[
            const SizedBox(height:12),
            DropdownButtonFormField<int>(
              value:selectedYear,
              decoration:const InputDecoration(labelText:'An'),
              items:(orderedYears.isEmpty?<int>[DateTime.now().year]:orderedYears).map((y)=>DropdownMenuItem(value:y,child:Text('$y'))).toList(),
              onChanged:(v){if(v!=null)setD(()=>selectedYear=v);},
            ),
          ],
          const SizedBox(height:16),
          Text('${team.name} · ${allTime?'toată perioada':selectedYear}',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:17)),
          const Divider(),
          row('Combustibil',c['fuel']!),
          row('Facturi',c['invoice']!),
          row('Diurne',c['perDiem']!),
          row('Alte cheltuieli',c['other']!),
          const Divider(),
          row('Total primit',c['received']!,strong:true),
          row('Total cheltuit',c['spent']!,strong:true),
          row('Buget rămas',c['budget']!,strong:true),
          row('Sumă de primit',c['due']!,strong:true),
          if(!allTime&&widget.finances.any((f)=>f.teamId==team.id&&f.receivedEntries.isEmpty&&f.totalReceived!=0))
            const Padding(padding:EdgeInsets.only(top:10),child:Text('Notă: sumele legacy fără dată sunt incluse doar în „Total general”.',style:TextStyle(fontSize:12))),
        ]))),
        actions:[FilledButton(onPressed:()=>Navigator.pop(d),child:const Text('Închide'))],
      );
    }));
  }

  Future<void> _money(bool departure) async {
    final amountC=TextEditingController();
    final fromC=TextEditingController();
    String method='Cash';
    final now=DateTime.now();
    final result=await showDialog<ReceivedMoneyEntry>(
      context:context,
      builder:(d)=>StatefulBuilder(builder:(d,setD)=>AlertDialog(
        title:Text(departure?'Adaugă sumă primită la plecare':'Adaugă sumă primită în timpul deplasării'),
        content:SizedBox(width:480,child:Column(mainAxisSize:MainAxisSize.min,children:[
          TextField(
            controller:amountC,
            autofocus:true,
            keyboardType:const TextInputType.numberWithOptions(decimal:true),
            decoration:const InputDecoration(labelText:'Valoare',suffixText:'lei'),
          ),
          const SizedBox(height:10),
          DropdownButtonFormField<String>(
            value:method,
            decoration:const InputDecoration(labelText:'Metodă'),
            items:const[
              DropdownMenuItem(value:'Cash',child:Text('Cash')),
              DropdownMenuItem(value:'Transfer',child:Text('Transfer')),
            ],
            onChanged:(v){if(v!=null)setD(()=>method=v);},
          ),
          const SizedBox(height:10),
          TextField(controller:fromC,textCapitalization:TextCapitalization.words,decoration:const InputDecoration(labelText:'De la cine')),
          const SizedBox(height:10),
          ListTile(
            contentPadding:EdgeInsets.zero,
            leading:const Icon(Icons.event_outlined),
            title:const Text('Data'),
            subtitle:Text('${two(now.day)}.${two(now.month)}.${now.year} · completată automat'),
          ),
        ])),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Anulează')),
          FilledButton(onPressed:(){
            final amount=double.tryParse(amountC.text.trim().replaceAll(',','.'));
            final from=fromC.text.trim();
            if(amount==null||amount<=0||from.isEmpty)return;
            Navigator.pop(d,ReceivedMoneyEntry(
              id:idNow(),
              kind:departure?'departure':'during',
              amount:amount,
              method:method,
              fromName:from,
              date:now,
            ));
          },child:const Text('Adaugă')),
        ],
      )),
    );
    amountC.dispose();fromC.dispose();
    if(result==null)return;
    try{
      if(settlement!=null){
        settlement!.receivedEntries.add(result);
        settlement!.receivedDeparture=settlement!.departureTotal;
        settlement!.receivedDuring=settlement!.duringTotal;
        await widget.saveSettlement(settlement!);
        widget.log('Sumă primită adăugată','${settlement!.name} · ${result.amount.toStringAsFixed(2)} lei · ${result.fromName} · ${result.method}');
      }else{
        finance.receivedEntries.add(result);
        finance.receivedDeparture=finance.departureTotal;
        finance.receivedDuring=finance.duringTotal;
        await widget.saveFinance(finance);
        widget.log('Sumă primită adăugată','${team.name} · ${result.amount.toStringAsFixed(2)} lei · ${result.fromName} · ${result.method}');
      }
      if(mounted){setState((){});showSuccessMessage(context,'Suma primită a fost adăugată.');}
    }catch(e){if (_visionSessionActive) VisionErrorTelemetry.report(area: 'finance', code: 'received_amount_save_failed'); if(mounted)showErrorMessage(context,'Nu s-a putut salva suma: $e');}
  }


}
