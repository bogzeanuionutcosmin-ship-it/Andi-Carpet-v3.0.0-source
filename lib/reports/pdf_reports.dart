part of '../main.dart';

Future<void> downloadWorkGraphPdf({
  required Team team,
  required List<WorkSchedule> days,
  required List<Location> locations,
  required Car? car,
}) async {
  if (days.isEmpty) return;
  final theme = await _buildPdfTheme();
  final orderedDays = [...days]..sort((a, b) => a.date.compareTo(b.date));
  final first = orderedDays.first;
  final roadKm = await estimateGraphRoadDistanceKm(orderedDays, locations);
  final km = roadKm ?? estimateGraphDistanceKm(orderedDays, locations);
  final liters = car != null && car.averageConsumption > 0 ? km * car.averageConsumption / 100 : 0.0;
  final fuelCost = car != null && car.fuelPricePerLiter > 0 ? liters * car.fuelPricePerLiter : 0.0;
  final doc = pw.Document(theme: theme);
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(28),
    build: (_) => [
      pw.Text(first.graphName, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      pw.Text('Echipa: ${team.name}'),
      pw.Text('Perioada: ${_pdfDate(orderedDays.first.date)} - ${_pdfDate(orderedDays.last.date)}'),
      pw.SizedBox(height: 10),
      pw.Wrap(spacing: 16, runSpacing: 6, children: [
        pw.Text('Zile: ${orderedDays.length}'),
        pw.Text('Locatii: ${orderedDays.fold<int>(0, (a, b) => a + b.items.length)}'),
        if (first.departureName.isNotEmpty) pw.Text('Plecare: ${first.departureName}'),
        if (first.returnName.isNotEmpty) pw.Text('Intoarcere: ${first.returnName}'),
        pw.Text('Km traseu complet: ${!graphRoutePoints(orderedDays, locations).complete ? 'GPS incomplet' : roadKm != null ? '${km.toStringAsFixed(1)} km rutieri' : '${km.toStringAsFixed(1)} km in linie dreapta (rutare indisponibila)'}'),
        if (car != null) pw.Text('Masina: ${car.plate} ${car.makeModel}'),
        if (car != null && car.averageConsumption > 0) pw.Text('Consum: ${car.averageConsumption.toStringAsFixed(1)} l/100 km'),
        if (liters > 0) pw.Text('Carburant estimat: ${liters.toStringAsFixed(1)} l'),
        if (fuelCost > 0) pw.Text('Cost carburant estimat: ${fuelCost.toStringAsFixed(2)} lei'),
      ]),
      pw.SizedBox(height: 14),
      ...orderedDays.asMap().entries.expand((entry) {
        final dayIndex = entry.key;
        final day = entry.value;
        final orderedItems = [...day.items]..sort((a, b) => a.order.compareTo(b.order));
        return <pw.Widget>[
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 10, bottom: 4),
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            decoration: pw.BoxDecoration(color: PdfColors.grey200, borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Text('Ziua ${dayIndex + 1} - ${_pdfDate(day.date)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          ),
          ...orderedItems.asMap().entries.map((x) => pw.Padding(
            padding: const pw.EdgeInsets.only(left: 8, top: 2, bottom: 2),
            child: pw.Text('${x.key + 1}. ${x.value.locationNameSnapshot} - ${x.value.addressSnapshot}'),
          )),
        ];
      }),
      pw.SizedBox(height: 14),
      pw.Text('Nota: traseul include plecarea, toate locatiile si intoarcerea. Cand rutarea nu este disponibila, distanta este in linie dreapta si consumul/costul sunt doar valori minime orientative.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
    ],
  ));
  await downloadFile(await doc.save(), 'grafic_${_safeFilePart(first.graphName)}.pdf', mimeType: 'application/pdf');
}

Future<void> downloadCentralizerPdf({
  required LocationType type,
  required List<Location> locations,
  required List<Team> teams,
  required List<WorkSchedule> schedules,
  required List<CentralizerRecord> records,
  String? teamId,
  DateTime? from,
  DateTime? to,
  String search = '',
  WorkAttemptStatus? statusFilter,
  String? teamLabel,
}) async {
  final theme = await _buildPdfTheme();
  final doc = pw.Document();
  final q = search.trim().toLowerCase();
  final start = from == null ? null : DateTime(from.year, from.month, from.day);
  final finish = to == null ? null : DateTime(to.year, to.month, to.day, 23, 59, 59, 999);
  bool dateAllowed(DateTime d) => (start == null || !d.isBefore(start)) && (finish == null || !d.isAfter(finish));
  bool textAllowed(String name, String address) => q.isEmpty || name.toLowerCase().contains(q) || address.toLowerCase().contains(q);

  final filteredRecords = records.where((r) {
    if (r.type != type) return false;
    if (teamId != null && teamId.isNotEmpty && r.teamId != teamId) return false;
    if (statusFilter != null && r.status != statusFilter) return false;
    final when = recordEventTime(r);
    if (!dateAllowed(when)) return false;
    if (!textAllowed(r.locationNameSnapshot, r.addressSnapshot)) return false;
    return true;
  }).toList()..sort((a,b)=>recordEventTime(a).compareTo(recordEventTime(b)));

  final rowsByLocation = <String,List<Map<String,dynamic>>>{};
  for (final r in filteredRecords) {
    rowsByLocation.putIfAbsent(r.locationId, () => <Map<String,dynamic>>[]).add({'record':r,'date':recordEventTime(r)});
  }

  // Fără filtru explicit de stare includem și toate sălile din grafice, chiar dacă nu există execuție.
  if (statusFilter == null) {
    for (final schedule in schedules) {
      if (teamId != null && teamId.isNotEmpty && schedule.teamId != teamId) continue;
      if (!dateAllowed(schedule.date)) continue;
      for (final item in schedule.items) {
        if (item.typeSnapshot != type || !textAllowed(item.locationNameSnapshot, item.addressSnapshot)) continue;
        final sameDayRecords = records.where((r) => r.locationId == item.locationId && r.teamId == schedule.teamId && recordBelongsToWorkDate(r, schedule.date)).toList();
        if (sameDayRecords.isNotEmpty) continue;
        Location? location;
        for (final l in locations) { if (l.id == item.locationId) { location = l; break; } }
        String state;
        if (item.transferred) {
          state = 'Transferată';
        } else if (location?.status == LocationStatus.temporarilyClosed) {
          state = 'Închisă temporar';
        } else if (location?.status == LocationStatus.permanentlyClosed) {
          state = 'Închisă permanent';
        } else if (schedule.date.isAfter(DateTime.now())) {
          state = 'Programată';
        } else {
          state = 'Neexecutată';
        }
        rowsByLocation.putIfAbsent(item.locationId, () => <Map<String,dynamic>>[]).add({
          'record': null,
          'date': schedule.date,
          'statusText': state,
          'teamId': schedule.teamId,
          'name': item.locationNameSnapshot,
          'address': item.addressSnapshot,
        });
      }
    }
  }

  final locationById = <String,Location>{for(final l in locations) l.id:l};
  final orderedIds = rowsByLocation.keys.toList()..sort((a,b){
    final an=locationById[a]?.name ?? rowsByLocation[a]!.first['name']?.toString() ?? a;
    final bn=locationById[b]?.name ?? rowsByLocation[b]!.first['name']?.toString() ?? b;
    return an.toLowerCase().compareTo(bn.toLowerCase());
  });
  final filters=<String>[];
  if(from!=null||to!=null)filters.add('Perioadă: ${from==null?'—':_pdfDate(from)} – ${to==null?'—':_pdfDate(to)}');
  if((teamLabel??'').isNotEmpty)filters.add('Echipă: $teamLabel');
  if(q.isNotEmpty)filters.add('Căutare: $search');
  if(statusFilter!=null)filters.add('Stare: ${statusFilter.name}');

  // PDF: distinguish planned facade work from work actually completed.
  // X = completed; P = planned but not completed; empty = not planned.
  pw.Widget facadeBox({required bool planned, required bool done}) => pw.Container(
    width: 12,
    height: 12,
    alignment: pw.Alignment.center,
    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey700, width: .7)),
    child: done || planned
        ? pw.Text(done ? 'X' : 'P', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))
        : null,
  );

  pw.Widget headerCell(String text, {pw.Alignment alignment = pw.Alignment.centerLeft}) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
    alignment: alignment,
    color: PdfColors.grey200,
    child: pw.Text(text, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
  );

  pw.Widget valueCell(String text, {pw.Alignment alignment = pw.Alignment.centerLeft}) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
    alignment: alignment,
    child: pw.Text(text, style: const pw.TextStyle(fontSize: 8)),
  );

  pw.Widget interventionTable(List<Map<String,dynamic>> sourceRows, Location? location) {
    final rows=[...sourceRows]..sort((a,b)=>(a['date'] as DateTime).compareTo(b['date'] as DateTime));
    return pw.Table(
      border: pw.TableBorder(
        horizontalInside: const pw.BorderSide(color: PdfColors.grey300, width: .45),
        verticalInside: const pw.BorderSide(color: PdfColors.grey300, width: .45),
      ),
      columnWidths: const {
        0: pw.FixedColumnWidth(78),
        1: pw.FixedColumnWidth(50),
        2: pw.FixedColumnWidth(50),
        3: pw.FixedColumnWidth(72),
        4: pw.FixedColumnWidth(48),
      },
      children: rows.map((row) {
        final record=row['record'] is CentralizerRecord ? row['record'] as CentralizerRecord : null;
        final date=row['date'] as DateTime;
        final surface=location!=null && location.surfaceM2>0
            ? '${location.surfaceM2.toStringAsFixed(location.surfaceM2%1==0?0:1)} m²'
            : '—';
        return pw.TableRow(children:[
          valueCell(record==null ? '${_pdfDate(date)}\n${row['statusText'] ?? 'Neexecutată'}' : _pdfDate(date)),
          valueCell(record==null?'—':timeText(record.startedAt),alignment:pw.Alignment.center),
          valueCell(record==null?'—':timeText(record.finishedAt),alignment:pw.Alignment.center),
          valueCell(surface,alignment:pw.Alignment.centerRight),
          pw.Container(padding:const pw.EdgeInsets.symmetric(vertical:4),alignment:pw.Alignment.center,child:facadeBox(planned:record?.facadePlanned==true,done:record?.facadeDone==true)),
        ]);
      }).toList(),
    );
  }

  final tableHeader=pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey500,width:.6),
    columnWidths: const {0: pw.FixedColumnWidth(190),1: pw.FlexColumnWidth()},
    children:[pw.TableRow(children:[
      headerCell('LOCAȚIE / ADRESĂ'),
      pw.Table(
        border: const pw.TableBorder(verticalInside: pw.BorderSide(color: PdfColors.grey500,width:.6)),
        columnWidths: const {
          0: pw.FixedColumnWidth(78),
          1: pw.FixedColumnWidth(50),
          2: pw.FixedColumnWidth(50),
          3: pw.FixedColumnWidth(72),
          4: pw.FixedColumnWidth(48),
        },
        children:[pw.TableRow(children:[
          headerCell('DATA'),
          headerCell('START',alignment:pw.Alignment.center),
          headerCell('FINAL',alignment:pw.Alignment.center),
          headerCell('SUPRAFAȚĂ',alignment:pw.Alignment.centerRight),
          headerCell('FAȚADĂ',alignment:pw.Alignment.center),
        ])],
      ),
    ])],
  );

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    theme: theme,
    margin: const pw.EdgeInsets.all(24),
    header: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Row(children:[
        pw.Expanded(child:pw.Text('CENTRALIZATOR ${type.label.toUpperCase()}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
        pw.Text('Generat: ${_pdfDate(DateTime.now())}',style:const pw.TextStyle(fontSize:8)),
      ]),
      if(filters.isNotEmpty)pw.Text(filters.join(' | '),style:const pw.TextStyle(fontSize:8)),
      pw.Text('Fațadă: X = realizată, P = planificată (nerealizată), gol = neplanificată', style: const pw.TextStyle(fontSize: 7)),
      pw.SizedBox(height:6),
      tableHeader,
      pw.SizedBox(height:3),
    ]),
    build: (_) => [
      if (orderedIds.isEmpty) pw.Padding(padding: const pw.EdgeInsets.only(top: 20), child: pw.Text('Nu există săli pentru filtrele selectate.')),
      for(final id in orderedIds) ...[
        pw.Table(
          border: pw.TableBorder.all(color:PdfColors.grey500,width:.55),
          columnWidths: const {0: pw.FixedColumnWidth(190),1: pw.FlexColumnWidth()},
          children:[pw.TableRow(children:[
            pw.Container(
              padding:const pw.EdgeInsets.all(6),
              child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[
                pw.Text(locationById[id]?.name ?? rowsByLocation[id]!.first['name']?.toString() ?? id,style:pw.TextStyle(fontSize:9,fontWeight:pw.FontWeight.bold)),
                pw.SizedBox(height:2),
                pw.Text(locationById[id]?.address ?? rowsByLocation[id]!.first['address']?.toString() ?? '',style:const pw.TextStyle(fontSize:7.5,color:PdfColors.grey700)),
              ]),
            ),
            interventionTable(rowsByLocation[id]!,locationById[id]),
          ])],
        ),
        pw.SizedBox(height:3),
      ],
    ],
  ));
  final bytes=await doc.save();
  final filename='centralizator_${_safeFilePart(type.label)}_${DateTime.now().year}${two(DateTime.now().month)}${two(DateTime.now().day)}.pdf';
  await downloadFile(bytes,filename,mimeType:'application/pdf');
}

Future<void> downloadDecontPdf({
  required Team team,
  required List<AppUser> users,
  required List<Expense> expenses,
  required List<PerDiemEntry> perDiems,
  required TeamFinance finance,
  TravelSettlement? settlement,
  bool legacyOnly = false,
}) async {
  final theme = await _buildPdfTheme();
  final doc = pw.Document();
  bool matchesSettlement(String? id) {
    if (settlement != null) return id == settlement.id;
    if (legacyOnly) return id == null || id.isEmpty;
    return true;
  }

  // Reconcile by immutable document/transfer IDs before exporting totals.
  // A repeated Firestore snapshot must not duplicate an expense or payment.
  final expenseIds = <String>{};
  final confirmedExpenses = expenses.where((e) =>
      e.teamId == team.id && e.confirmed && e.amount.isFinite && e.amount >= 0 &&
      matchesSettlement(e.settlementId) && expenseIds.add(e.id)).toList()
    ..sort((a,b)=>a.date.compareTo(b.date));
  final paymentIds = <String>{};
  final confirmedPerDiems = perDiems.where((d) =>
      d.teamId == team.id && d.status == PerDiemStatus.confirmed &&
      d.received == true && d.actualReceivedAmount != null &&
      d.actualReceivedAmount!.isFinite && d.actualReceivedAmount! >= 0 &&
      matchesSettlement(d.settlementId) && paymentIds.add(d.id)).toList()
    ..sort((a,b)=>a.date.compareTo(b.date));
  String userName(String id) => users.firstWhere((u) => u.id == id, orElse: () => AppUser(id: id, name: id, role: UserRole.member)).name;

  final fuelReceipts = confirmedExpenses.where((e) => e.category == 'Combustibil').toList();
  final invoices = confirmedExpenses.where((e) => e.category != 'Combustibil' && (e.documentType == ExpenseDocumentType.invoice || e.category == 'Facturi')).toList();
  final otherReceipts = confirmedExpenses.where((e) => e.category != 'Combustibil' && e.documentType != ExpenseDocumentType.invoice && e.category != 'Facturi').toList();
  final spentExpenses = confirmedExpenses.fold<double>(0, (a,b)=>a+b.amount);
  final spentPerDiem = confirmedPerDiems.fold<double>(0, (a,b)=>a+b.actualReceivedAmount!);
  final spent = spentExpenses + spentPerDiem;
  // Derive received totals from the same unique transfers shown in the PDF.
  // Legacy aggregate-only records retain their historical stored totals.
  final rawReceipts = settlement?.receivedEntries ?? finance.receivedEntries;
  final uniqueReceiptIds = <String>{};
  final uniqueReceipts = rawReceipts.where((e) => e.amount.isFinite && e.amount >= 0 &&
      uniqueReceiptIds.add(e.id)).toList();
  final receivedDeparture = rawReceipts.isEmpty
      ? (settlement?.departureTotal ?? finance.departureTotal)
      : uniqueReceipts.where((e)=>e.kind=='departure').fold<double>(0,(a,e)=>a+e.amount);
  final receivedDuring = rawReceipts.isEmpty
      ? (settlement?.duringTotal ?? finance.duringTotal)
      : uniqueReceipts.where((e)=>e.kind=='during').fold<double>(0,(a,e)=>a+e.amount);
  final totalReceived = receivedDeparture + receivedDuring;
  final budgetRemaining = math.max(0.0, totalReceived - spent).toDouble();
  final amountDue = math.max(0.0, spent - totalReceived).toDouble();
  final titleSuffix = settlement?.name ?? (legacyOnly ? 'Istoric anterior' : team.name);
  final rawEntries = settlement?.receivedEntries ?? finance.receivedEntries;
  final receiptIds = <String>{};
  final entries = rawEntries.where((e) => e.amount.isFinite && e.amount >= 0 &&
      receiptIds.add(e.id)).toList();
  final duringEntries = entries.where((e)=>e.kind=='during').toList()..sort((a,b)=>a.date.compareTo(b.date));

  String money(double value) => '${value.toStringAsFixed(2)} lei';
  String documentLabel(Expense e) => '${e.documentType == ExpenseDocumentType.invoice ? 'Factura' : 'Bon fiscal'} nr. ${e.documentNumber.trim().isEmpty ? '—' : e.documentNumber.trim()}';
  String duringSummary() {
    if (duringEntries.length <= 1) return money(receivedDuring);
    final parts = duringEntries.map((e)=>e.amount.toStringAsFixed(e.amount == e.amount.roundToDouble() ? 0 : 2)).toList();
    return '${parts.join(' + ')} = ${money(receivedDuring)}';
  }

  pw.Widget sectionTitle(String text) => pw.Container(
    width: double.infinity,
    margin: const pw.EdgeInsets.only(top: 9, bottom: 3),
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    color: PdfColors.grey200,
    child: pw.Text(text, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
  );

  pw.Widget documentTable(List<Expense> items) {
    final rows = <List<String>>[
      ['DOCUMENT', 'DATA', 'VALOARE'],
      ...items.map((e)=>[documentLabel(e), _pdfDate(e.date), money(e.amount)]),
    ];
    if (items.isEmpty) rows.add(['—', '—', '—']);
    final total = items.fold<double>(0,(a,b)=>a+b.amount);
    rows.add(['TOTAL', '', money(total)]);
    return pw.Table.fromTextArray(
      headers: null,
      data: rows,
      border: pw.TableBorder.all(color: PdfColors.grey400, width: .5),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      cellStyle: const pw.TextStyle(fontSize: 8),
      columnWidths: const {0: pw.FlexColumnWidth(3.8), 1: pw.FlexColumnWidth(1.5), 2: pw.FlexColumnWidth(1.6)},
      cellAlignments: const {0: pw.Alignment.centerLeft, 1: pw.Alignment.center, 2: pw.Alignment.centerRight},
      rowDecoration: const pw.BoxDecoration(),
    );
  }

  final perMember = <String,List<PerDiemEntry>>{};
  for(final d in confirmedPerDiems) {
    (perMember[d.memberId] ??= <PerDiemEntry>[]).add(d);
  }
  final perDiemRows = <List<String>>[['MEMBRU', 'PLĂȚI', 'LEI / ZI', 'PRIMIT EFECTIV']];
  for(final entry in perMember.entries) {
    final list=entry.value;
    final total=list.fold<double>(0,(a,b)=>a+b.actualReceivedAmount!);
    final rate = settlement?.perDiemRate ?? finance.perDiemRate;
    perDiemRows.add([userName(entry.key), '${list.length}', money(rate), money(total)]);
  }
  if(perMember.isEmpty) perDiemRows.add(['—','—','—','—']);
  perDiemRows.add(['TOTAL DIURNE PRIMITE','','',money(spentPerDiem)]);

  final summaryRows=<List<String>>[
    ['Primit la plecare', money(receivedDeparture)],
    ['Primit în timpul deplasării', duringSummary()],
    ['Total primit', money(totalReceived)],
    ['Total cheltuit', money(spent)],
    ['Buget rămas', money(budgetRemaining)],
    ['Sumă de primit', money(amountDue)],
  ];

  final breakdownRows=<List<String>>[['TIP','DATA','DE LA CINE','METODĂ','VALOARE']];
  if(entries.isNotEmpty) {
    final sorted=[...entries]..sort((a,b)=>a.date.compareTo(b.date));
    for(final e in sorted) {
      breakdownRows.add([
        e.kind=='departure' ? 'La plecare' : 'În timpul deplasării',
        _pdfDate(e.date),
        e.fromName.trim().isEmpty ? '—' : e.fromName.trim(),
        e.method.trim().isEmpty ? '—' : e.method.trim(),
        money(e.amount),
      ]);
    }
  } else {
    if(receivedDeparture>0) breakdownRows.add(['La plecare','—','Date vechi','—',money(receivedDeparture)]);
    if(receivedDuring>0) breakdownRows.add(['În timpul deplasării','—','Date vechi','—',money(receivedDuring)]);
    if(receivedDeparture<=0 && receivedDuring<=0) breakdownRows.add(['—','—','—','—','—']);
  }

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    theme: theme,
    margin: const pw.EdgeInsets.all(24),
    header: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Row(children:[
        pw.Expanded(child:pw.Text('DECONT · ${team.name}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
        pw.Text('Generat: ${_pdfDate(DateTime.now())}',style:const pw.TextStyle(fontSize:8)),
      ]),
      pw.Text(titleSuffix, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      if (settlement != null) pw.Text('Perioada: ${_pdfDate(settlement.startDate)}${settlement.endDate == null ? '' : ' - ${_pdfDate(settlement.endDate!)}'}',style:const pw.TextStyle(fontSize:8)),
      pw.SizedBox(height:5),
    ]),
    build: (_) => [
      sectionTitle('1. BONURI COMBUSTIBIL'),
      documentTable(fuelReceipts),
      sectionTitle('2. FACTURI'),
      documentTable(invoices),
      sectionTitle('3. DIURNE'),
      pw.Table.fromTextArray(
        headers:null,
        data:perDiemRows,
        border:pw.TableBorder.all(color:PdfColors.grey400,width:.5),
        cellPadding:const pw.EdgeInsets.symmetric(horizontal:5,vertical:3),
        cellStyle:const pw.TextStyle(fontSize:8),
        columnWidths:const {0:pw.FlexColumnWidth(3),1:pw.FlexColumnWidth(1.2),2:pw.FlexColumnWidth(1.4),3:pw.FlexColumnWidth(1.5)},
        cellAlignments:const {0:pw.Alignment.centerLeft,1:pw.Alignment.center,2:pw.Alignment.centerRight,3:pw.Alignment.centerRight},
      ),
      sectionTitle('4. ALTE CHELTUIELI'),
      documentTable(otherReceipts),
      sectionTitle('REZUMAT'),
      pw.Table.fromTextArray(
        headers:null,
        data:summaryRows,
        border:pw.TableBorder.all(color:PdfColors.grey400,width:.5),
        cellPadding:const pw.EdgeInsets.symmetric(horizontal:5,vertical:3.5),
        cellStyle:const pw.TextStyle(fontSize:8.5),
        columnWidths:const {0:pw.FlexColumnWidth(2.7),1:pw.FlexColumnWidth(3.3)},
        cellAlignments:const {0:pw.Alignment.centerLeft,1:pw.Alignment.centerRight},
      ),
      sectionTitle('DESFĂȘURĂTOR SUME PRIMITE'),
      pw.Table.fromTextArray(
        headers:null,
        data:breakdownRows,
        border:pw.TableBorder.all(color:PdfColors.grey400,width:.5),
        cellPadding:const pw.EdgeInsets.symmetric(horizontal:4,vertical:3),
        cellStyle:const pw.TextStyle(fontSize:7.5),
        columnWidths:const {0:pw.FlexColumnWidth(2),1:pw.FlexColumnWidth(1.3),2:pw.FlexColumnWidth(2.3),3:pw.FlexColumnWidth(1.3),4:pw.FlexColumnWidth(1.5)},
        cellAlignments:const {0:pw.Alignment.centerLeft,1:pw.Alignment.center,2:pw.Alignment.centerLeft,3:pw.Alignment.center,4:pw.Alignment.centerRight},
      ),
      pw.SizedBox(height:6),
      pw.Text('Notă: fotografiile bonurilor și facturilor nu sunt păstrate în decont; OCR-ul salvează numai datele structurate necesare.',style:const pw.TextStyle(fontSize:7,color:PdfColors.grey700)),
    ],
  ));
  final bytes = await doc.save();
  final filename = 'decont_${_safeFilePart(team.name)}_${_safeFilePart(titleSuffix)}_${DateTime.now().year}${two(DateTime.now().month)}${two(DateTime.now().day)}.pdf';
  await downloadFile(bytes, filename, mimeType: 'application/pdf');
}

Future<void> downloadAuditPdf(List<AuditEntry> audit) async {
  final theme = await _buildPdfTheme();
  final doc = pw.Document();
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    theme: theme,
    margin: const pw.EdgeInsets.all(28),
    header: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text('RAPORT AUDIT', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.Text('Generat: ${_pdfDate(DateTime.now())}'),
      pw.Divider(),
    ]),
    build: (_) => [
      for (final a in audit)
        pw.Padding(padding: const pw.EdgeInsets.only(bottom: 5), child: pw.Text('${formatDate(a.at)} ${timeText(a.at)} · ${a.actor} · ${a.action} · ${a.target}', style: const pw.TextStyle(fontSize: 8))),
    ],
  ));
  await downloadFile(await doc.save(), 'audit_${DateTime.now().year}${two(DateTime.now().month)}${two(DateTime.now().day)}.pdf', mimeType: 'application/pdf');
}

Future<void> downloadFinancialSummaryPdf({
  required List<Team> teams,
  required List<Expense> expenses,
  required List<PerDiemEntry> perDiems,
  required List<TeamFinance> finances,
  required List<TravelSettlement> settlements,
}) async {
  final theme = await _buildPdfTheme();
  final doc = pw.Document();
  TeamFinance financeFor(String teamId) => finances.firstWhere((f) => f.teamId == teamId, orElse: () => TeamFinance(teamId: teamId));
  pw.Widget financeRow(Team team) {
    final ex = expenses.where((e) => e.teamId == team.id && e.confirmed).fold<double>(0, (a,b)=>a+b.amount);
    final di = perDiems.where((d) => d.teamId == team.id && d.status == PerDiemStatus.confirmed && d.received == true && d.actualReceivedAmount != null).fold<double>(0, (a,b)=>a+b.actualReceivedAmount!);
    final f = financeFor(team.id);
    final tripReceived = settlements.where((x) => x.teamId == team.id).fold<double>(0, (a,b) => a + b.totalReceived);
    final totalReceived = f.totalReceived + tripReceived;
    return pw.Text('Primit ${totalReceived.toStringAsFixed(2)} lei · Cheltuieli ${(ex+di).toStringAsFixed(2)} lei · Sold ${(totalReceived-ex-di).toStringAsFixed(2)} lei · ${settlements.where((x)=>x.teamId==team.id).length} deplasări', style: const pw.TextStyle(fontSize: 9));
  }
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    theme: theme,
    margin: const pw.EdgeInsets.all(28),
    header: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text('RAPORT FINANCIAR GENERAL', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.Text('Generat: ${_pdfDate(DateTime.now())}'),
      pw.Divider(),
    ]),
    build: (_) => [
      for (final team in teams) ...[
        pw.SizedBox(height: 10),
        pw.Text(team.name, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        financeRow(team),
      ],
    ],
  ));
  await downloadFile(await doc.save(), 'raport_financiar_${DateTime.now().year}${two(DateTime.now().month)}${two(DateTime.now().day)}.pdf', mimeType: 'application/pdf');
}

