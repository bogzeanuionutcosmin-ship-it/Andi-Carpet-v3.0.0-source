part of '../main.dart';

class ExpensePage extends StatefulWidget {
  final AppUser currentUser;
  final List<Team> teams;
  final List<AppUser> users;
  final List<Expense> expenses;
  final List<PerDiemEntry> perDiems;
  final List<TeamFinance> finances;
  final List<TravelSettlement> settlements;
  final AppSettings settings;
  final bool Function(String) canEditTeam;
  final bool isAdmin;
  final bool canEditOwnDecont;
  final bool canViewOtherDecont;
  final VoidCallback onChanged;
  final void Function(String,String,String) notifyUser;
  final void Function(String,String) log;
  final Future<void> Function(Expense) saveExpense;
  final Future<void> Function(PerDiemEntry) savePerDiem;
  final Future<void> Function(TeamFinance) saveFinance;
  final Future<void> Function(TravelSettlement) saveSettlement;
  final Future<XFile?> Function({bool allowNoImage})? pickDocumentImage;
  final Future<String> Function(Uint8List, {String? path})? recognizeExpenseText;
  const ExpensePage({super.key,required this.currentUser,required this.teams,required this.users,required this.expenses,required this.perDiems,required this.finances,required this.settlements,required this.settings,required this.canEditTeam,required this.isAdmin,required this.canEditOwnDecont,required this.canViewOtherDecont,required this.onChanged,required this.notifyUser,required this.log,required this.saveExpense,required this.savePerDiem,required this.saveFinance,required this.saveSettlement,this.pickDocumentImage,this.recognizeExpenseText});
  @override State<ExpensePage> createState()=>_ExpensePageState();
}

class _ExpensePageState extends State<ExpensePage> {
  static const String _legacySettlementKey = '__legacy__';
  int teamIndex = 0;
  String? selectedSettlementId;
  bool exporting = false;
  bool scanning = false;
  final Set<String> _savingPerDiemIds = <String>{};
  final ImagePicker _imagePicker = ImagePicker();

  List<Team> get visibleTeams => (widget.isAdmin || widget.canViewOtherDecont)
      ? widget.teams
      : widget.teams.where((t) => t.members.contains(widget.currentUser.id)).toList();
  Team get team => visibleTeams[teamIndex.clamp(0, visibleTeams.length - 1)];
  List<String> get visibleTeamMemberIds {
    final visible = widget.users.map((u) => u.id).toSet();
    return team.members.where(visible.contains).toList();
  }
  String name(String id) => widget.users.firstWhere((u) => u.id == id, orElse: () => AppUser(id: id, name: 'Membru', role: UserRole.member)).name;

  TeamFinance get finance {
    final found = widget.finances.where((f) => f.teamId == team.id);
    if (found.isNotEmpty) return found.first;
    final created = TeamFinance(teamId: team.id, managerId: team.financialManagerId, perDiemRate: widget.settings.defaultPerDiem);
    widget.finances.add(created);
    return created;
  }

  List<TravelSettlement> get teamSettlements => widget.settlements.where((s) => s.teamId == team.id).toList()
    ..sort((a, b) {
      if (a.closed != b.closed) return a.closed ? 1 : -1;
      return b.startDate.compareTo(a.startDate);
    });

  bool get hasLegacyData => widget.expenses.any((e) => e.teamId == team.id && (e.settlementId == null || e.settlementId!.isEmpty))
      || widget.perDiems.any((e) => e.teamId == team.id && (e.settlementId == null || e.settlementId!.isEmpty))
      || finance.receivedDeparture != 0
      || finance.receivedDuring != 0;

  String? _resolvedSettlementId() =>
      resolveExpenseSettlementId<TravelSettlement>(
        orderedSettlements: teamSettlements,
        selectedSettlementId: selectedSettlementId,
        hasLegacyData: () => hasLegacyData,
        legacySettlementKey: _legacySettlementKey,
        idOf: (settlement) => settlement.id,
        isClosed: (settlement) => settlement.closed,
      );

  TravelSettlement? get settlement {
    final id = _resolvedSettlementId();
    if (id == null || id == _legacySettlementKey) return null;
    for (final s in teamSettlements) {
      if (s.id == id) return s;
    }
    return null;
  }

  bool get isLegacy => _resolvedSettlementId() == _legacySettlementKey;
  bool get hasSelectedDecont => _resolvedSettlementId() != null;
  bool get selectedClosed => settlement?.closed == true;
  String? get managerId => settlement?.managerId ?? finance.managerId ?? team.financialManagerId;
  double get perDiemRate => settlement?.perDiemRate ?? finance.perDiemRate;
  double get received => settlement?.totalReceived ?? finance.totalReceived;
  bool get can => widget.canEditOwnDecont && widget.canEditTeam(team.id) && hasSelectedDecont && !selectedClosed;
  bool get isManager => widget.isAdmin || (widget.canEditOwnDecont && managerId == widget.currentUser.id);

  bool _belongsToSelected(String? settlementId) {
    final id = _resolvedSettlementId();
    if (id == null) return false;
    if (id == _legacySettlementKey) return settlementId == null || settlementId.isEmpty;
    return settlementId == id;
  }

  List<Expense> get allEx => widget.expenses.where((e) => e.teamId == team.id && _belongsToSelected(e.settlementId)).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  List<Expense> get ex => allEx.where((e) => e.confirmed).toList();
  List<PerDiemEntry> get di => widget.perDiems.where((e) => e.teamId == team.id && _belongsToSelected(e.settlementId)).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  List<PerDiemEntry> get pendingOwnPerDiems => widget.perDiems
      .where((e) => e.memberId == widget.currentUser.id && e.status == PerDiemStatus.awaitingConfirmation && e.actualReceivedAmount == null)
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  // Sold informativ pe toate deplasările, inclusiv cele închise.
  // Diferențele contestate nu sunt compensate automat.
  int _perDiemDifferenceBani(String beneficiaryId, String distributorId) =>
      calculateLegacyPerDiemDifferenceBani<PerDiemEntry>(
        entries: widget.perDiems,
        beneficiaryId: beneficiaryId,
        distributorId: distributorId,
        memberId: (entry) => entry.memberId,
        distributedBy: (entry) => entry.distributedBy,
        isConfirmed: (entry) => entry.status == PerDiemStatus.confirmed,
        actualReceivedAmount: (entry) => entry.actualReceivedAmount,
        declaredAmount: (entry) => entry.amount,
        supplementaryFor: (entry) => entry.supplementaryFor,
      );

  double _perDiemDifference(String beneficiaryId, String distributorId) =>
      _perDiemDifferenceBani(beneficiaryId, distributorId) / 100;

  Widget _perDiemCarryoverCard() {
    // Soldurile urmează persoanele, nu echipa sau decontul selectat.
    // Grupăm separat fiecare pereche distribuitor-beneficiar, pentru a nu
    // amesteca obligațiile a doi distribuitori diferiți.
    final pairs = <String, MapEntry<String, String>>{};
    for (final entry in widget.perDiems) {
      final distributor = entry.distributedBy;
      if (distributor == null || distributor.isEmpty) continue;
      if (!widget.isAdmin && entry.memberId != widget.currentUser.id &&
          distributor != widget.currentUser.id) continue;
      pairs['$distributor|${entry.memberId}'] = MapEntry(distributor, entry.memberId);
    }
    final rows = <Widget>[];
    for (final pair in pairs.values) {
      final difference = _perDiemDifference(pair.value, pair.key);
      // Solicitările încă neconfirmate NU sunt datorii sau avansuri
      // validate. Le afișăm separat pentru a nu induce în eroare.
      final pending = widget.perDiems.where((entry) =>
        entry.memberId == pair.value &&
        entry.distributedBy == pair.key &&
        entry.status == PerDiemStatus.awaitingConfirmation &&
        entry.actualReceivedAmount == null).toList();
      if (difference.abs() >= 0.01) {
        rows.add(Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('${name(pair.key)} → ${name(pair.value)}: '
            '${difference > 0 ? 'diferență de achitat' : 'avans de verificat'} '
            '${difference.abs().toStringAsFixed(2)} lei (confirmat)'),
        ));
      }
      if (pending.isNotEmpty) {
        final pendingAmount = pending.fold<double>(0, (sum, entry) => sum + entry.amount);
        rows.add(Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('${name(pair.key)} → ${name(pair.value)}: '
            '${pending.length} ${pending.length == 1 ? 'distribuire neconfirmată' : 'distribuiri neconfirmate'} '
            '(${pendingAmount.toStringAsFixed(2)} lei declarați; nu intră în sold)'),
        ));
      }
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Solduri reportate între deconturi și echipe', style: TextStyle(fontWeight: FontWeight.bold)),
        ...rows,
        const SizedBox(height: 6),
        const Text('Sold informativ doar din încasări confirmate. Distribuirile în așteptare '
          'sunt afișate separat și nu se compensează automat. Contestațiile necesită reconciliere.'),
      ],
    )));
  }

  double get spent => ex.fold<double>(0, (a, b) => a + b.amount) + di.fold<double>(0, (a, d) => a + (d.status == PerDiemStatus.confirmed && d.received == true ? (d.actualReceivedAmount ?? 0.0) : 0.0));
  double get balance => received - spent;
  double get liters => ex.where((e) => e.category == 'Combustibil').fold<double>(0, (a, b) => a + (b.liters ?? 0));
  double get fuel => ex.where((e) => e.category == 'Combustibil').fold<double>(0, (a, b) => a + b.amount);
  List<ReceivedMoneyEntry> get receivedEntries => settlement?.receivedEntries ?? finance.receivedEntries;

  @override
  Widget build(BuildContext context) {
    if (visibleTeams.isEmpty) {
      // Confirmările rămân accesibile și după mutarea membrului în altă echipă
      // sau eliminarea temporară din echipe. Nu depind de decontul selectat.
      final pending = pendingOwnPerDiems;
      return _Page(
        title: 'Decont',
        subtitle: 'Diurne de confirmat',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (pending.isNotEmpty) ...[
            const Text('Diurne care așteaptă confirmarea ta',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...pending.map(_pendingPerDiemCard),
            const SizedBox(height: 12),
          ],
          const _InfoCard(
            icon: Icons.groups_outlined,
            title: 'Fără echipă activă',
            text: 'Nu ești atribuit unei echipe în acest moment. Confirmările de diurnă existente rămân accesibile.'),
        ]),
      );
    }
    if (teamIndex >= visibleTeams.length) teamIndex = 0;
    final resolved = _resolvedSettlementId();
    if (selectedSettlementId != resolved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && selectedSettlementId != resolved) setState(() => selectedSettlementId = resolved);
      });
    }

    return _Page(
      title: 'Decont',
      subtitle: 'Separat pe deplasări · documente, diurne și sold',
      actions: [
        OutlinedButton.icon(
          onPressed: _showGeneralCalculations,
          icon: const Icon(Icons.calculate_outlined),
          label: const Text('Calcule generale'),
        ),
        FilledButton.icon(
          onPressed: !hasSelectedDecont || exporting ? null : _pdf,
          icon: exporting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.picture_as_pdf),
          label: Text(exporting ? 'Se generează...' : 'Generează PDF'),
        ),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (widget.isAdmin || widget.canViewOtherDecont)
          _TeamSelector(teams: visibleTeams, selected: teamIndex, onChanged: (v) => setState(() { teamIndex = v; selectedSettlementId = null; }))
        else
          Text('Echipă: ${team.name}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _settlementSelector(),
        if (pendingOwnPerDiems.isNotEmpty) ...[
          const SizedBox(height: 14),
          ...pendingOwnPerDiems.map(_pendingPerDiemCard),
        ],
        const SizedBox(height: 14),
        if (!hasSelectedDecont) ...[
          const _Empty(icon: Icons.luggage_outlined, text: 'Nu există încă nicio deplasare. Creează prima deplasare pentru a separa corect bugetele și documentele.'),
          if (widget.canEditOwnDecont && widget.canEditTeam(team.id)) ...[
            const SizedBox(height: 10),
            FilledButton.icon(onPressed: _createSettlement, icon: const Icon(Icons.add), label: const Text('Creează deplasare')),
          ],
        ] else ...[
          if (selectedClosed)
            const _InfoCard(icon: Icons.lock_outline, title: 'Decont închis', text: 'Deplasarea este închisă. Datele rămân vizibile, dar nu se mai adaugă cheltuieli sau diurne până la redeschidere.'),
          const SizedBox(height: 10),
          Wrap(spacing: 12, runSpacing: 12, children: [
            _MoneyCard(title: 'Primit la plecare', value: settlement?.departureTotal ?? finance.departureTotal, onTap: isManager && !selectedClosed ? () => _money(true) : null),
            _MoneyCard(title: 'Primit în timpul deplasării', value: settlement?.duringTotal ?? finance.duringTotal, onTap: isManager && !selectedClosed ? () => _money(false) : null),
            _MoneyCard(title: 'Total primit', value: received),
            _MoneyCard(title: 'Total cheltuieli', value: spent),
            _MoneyCard(title: 'Buget rămas', value: balance),
          ]),
          if (receivedEntries.isNotEmpty) ...[
            const SizedBox(height:10),
            Card(child:ExpansionTile(
              leading:const Icon(Icons.account_balance_wallet_outlined),
              title:const Text('Desfășurător sume primite',style:TextStyle(fontWeight:FontWeight.w800)),
              subtitle:Text('${receivedEntries.length} tranșe'),
              children:(<ReceivedMoneyEntry>[...receivedEntries]..sort((a,b)=>a.date.compareTo(b.date))).map((e)=>ListTile(
                dense:true,
                leading:Icon(e.method=='Transfer'?Icons.account_balance_outlined:Icons.payments_outlined),
                title:Text('${e.amount.toStringAsFixed(2)} lei · ${e.method}'),
                subtitle:Text('${e.kind=='departure'?'La plecare':'În timpul deplasării'} · de la ${e.fromName} · ${two(e.date.day)}.${two(e.date.month)}.${e.date.year}'),
              )).toList(),
            )),
          ],
          if (balance < 0) ...[
            const SizedBox(height: 10),
            _InfoCard(icon: Icons.warning_amber_rounded, title: 'Sumă de primit', text: 'Cheltuielile depășesc banii primiți cu ${balance.abs().toStringAsFixed(2)} lei. Firma trebuie să restituie această diferență.'),
          ],
          const SizedBox(height: 16),
          Card(child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.manage_accounts)),
            title: const Text('Gestionar financiar'),
            subtitle: Text(managerId == null ? 'Nesetat' : name(managerId!)),
            trailing: widget.isAdmin && !selectedClosed ? TextButton(onPressed: _manager, child: const Text('Schimbă')) : null,
          )),
          const SizedBox(height: 18),
          Row(children: [
            const Expanded(child: Text('Diurnă', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
            TextButton(onPressed: isManager && !selectedClosed ? _perDiemRate : null, child: Text('${perDiemRate.toStringAsFixed(2)} lei/zi')),
          ]),
          if (isManager && !selectedClosed) Wrap(spacing: 8, children: [
            FilledButton.icon(onPressed: _distribute, icon: const Icon(Icons.payments), label: const Text('Distribuie diurnă')),
            OutlinedButton.icon(onPressed: _supplementaryPayment, icon: const Icon(Icons.add_card), label: const Text('Plată suplimentară')),
          ]),
          _perDiemCarryoverCard(),
          const SizedBox(height: 12),
          if (di.any((d) => d.supplementaryFor == null && d.status == PerDiemStatus.confirmed && d.actualReceivedAmount != null && (d.amount - d.actualReceivedAmount!).abs() >= 0.01))
            Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Diferențe diurne declarate / primite', style: TextStyle(fontWeight: FontWeight.bold)),
              ...di.where((d) => d.supplementaryFor == null && d.status == PerDiemStatus.confirmed && d.actualReceivedAmount != null && (d.amount - d.actualReceivedAmount!).abs() >= 0.01).map((d) {
                final difference = d.amount - d.actualReceivedAmount!;
                return Text('${name(d.memberId)}: ${difference > 0 ? 'Diferență neachitată' : 'Avans declarat'} ${difference.abs().toStringAsFixed(2)} lei');
              }),
              ...di.where((d) => d.supplementaryFor == null && d.status == PerDiemStatus.confirmed && d.actualReceivedAmount != null && (d.amount - d.actualReceivedAmount!).abs() >= 0.01).map(_perDiemDisputeActions),
              const Text('Diferențele sunt informative până la reconcilierea soldurilor între deconturi.'),
            ]))),
          ...di.map((d) => ListTile(
            leading: Icon(d.received == false ? Icons.report_outlined : d.status == PerDiemStatus.confirmed ? Icons.check_circle : Icons.schedule, color: d.received == false ? Colors.red : d.status == PerDiemStatus.confirmed ? Colors.green : Colors.orange),
            title: Text('${d.supplementaryFor == null ? 'Diurnă' : 'Plată suplimentară'} · ${name(d.memberId)} · ${formatDate(d.date)}'),
            subtitle: Text('${d.amount.toStringAsFixed(2)} lei declarați · ${d.actualReceivedAmount == null ? d.status.label : '${d.actualReceivedAmount!.toStringAsFixed(2)} lei primiți${d.actualReceivedAmount == 0 ? ' (neprimită)' : ''}'} · ${d.method?.label ?? ''}'),
            trailing: d.memberId == widget.currentUser.id && d.status == PerDiemStatus.awaitingConfirmation && d.actualReceivedAmount == null
              ? IconButton(tooltip: 'Confirmă primirea', icon: const Icon(Icons.fact_check_outlined), onPressed: () => _confirmPerDiemAmount(d)) : null,
          )),
          const Divider(height: 32),
          Wrap(spacing: 10, runSpacing: 8, children: [
            FilledButton.icon(onPressed: can && !scanning ? _scan : null, icon: scanning ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.document_scanner), label: Text(scanning ? 'Se citește...' : 'Scanează bon / factură')),
            OutlinedButton.icon(onPressed: can ? _manual : null, icon: const Icon(Icons.add), label: const Text('Introducere manuală')),
          ]),
          const SizedBox(height: 16),
          _InfoCard(icon: Icons.local_gas_station, title: 'Combustibil', text: '${fuel.toStringAsFixed(2)} lei · ${liters.toStringAsFixed(2)} L · preț mediu ${liters > 0 ? (fuel / liters).toStringAsFixed(2) : '0.00'} lei/L'),
          const SizedBox(height: 10),
          ..._groupedExpenses(),
          const SizedBox(height: 12),
          const _InfoCard(icon: Icons.picture_as_pdf, title: 'PDF Decont', text: 'PDF-ul folosește doar deplasarea selectată. Ordine: combustibil → facturi → diurne → alte cheltuieli. Un document ocupă un singur rând; fotografiile nu sunt salvate.'),
        ],
      ]),
    );
  }

  Widget _settlementSelector() {
    final items = <DropdownMenuItem<String>>[];
    for (final s in teamSettlements) {
      items.add(DropdownMenuItem(value: s.id, child: Text('${s.name} · ${_shortDate(s.startDate)}${s.closed ? ' · închisă' : ''}')));
    }
    if (hasLegacyData) items.add(const DropdownMenuItem(value: _legacySettlementKey, child: Text('Istoric anterior · date fără deplasare')));
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
        ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.event), title: const Text('Data început'), subtitle: Text(_shortDate(start)), trailing: TextButton(onPressed: () async { final x = await showDatePicker(context: d, firs…8308 tokens truncated…etodă'), items: const [DropdownMenuItem(value: 'Numerar', child: Text('Numerar')), DropdownMenuItem(value: 'Transfer bancar', child: Text('Transfer bancar'))], onChanged: (v) { if (v != null) setD(() => method = v); })]), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Anulează')), FilledButton(onPressed: beneficiary == null ? null : () { final bani = parsePerDiemBani(amount.text, allowZero: false);
      if (bani == null) { showErrorMessage(d, 'Suma trebuie să fie pozitivă și să aibă maximum două zecimale.'); return; }
      if (beneficiary == managerId) { showErrorMessage(d, 'Distribuitorul nu poate fi propriul beneficiar.'); return; }
      final value = bani / 100;
      Navigator.pop(d, PerDiemEntry(id: idNow(), teamId: team.id, settlementId: settlement?.id, memberId: beneficiary!, date: DateTime.now(), amount: value, status: PerDiemStatus.awaitingConfirmation, method: method == 'Numerar' ? PerDiemPaymentMethod.cash : PerDiemPaymentMethod.bankTransfer, distributedBy: managerId, distributedAt: DateTime.now())); }, child: const Text('Distribuie'))])));
    amount.dispose(); if (r == null) return;
    if (r.distributedBy == r.memberId || r.amount <= 0 || !r.amount.isFinite ||
        (r.amount * 100 - (r.amount * 100).round()).abs() > 0.000001) {
      if (mounted) showErrorMessage(context, 'Distribuirea nu este validă.');
      return;
    }
    final carryover = _perDiemDifference(r.memberId, managerId!);
    if (carryover.abs() >= 0.01) {
      final proceed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
        title: Text(carryover < 0 ? 'Atenție: avans existent' : 'Atenție: diferență restantă'),
        content: Text('${name(r.memberId)} are ${carryover.abs().toStringAsFixed(2)} lei '
          '${carryover < 0 ? 'avans înregistrat' : 'diferență de achitat'} '
          'din confirmări anterioare. Verifică soldul înainte de o nouă distribuire. '
          'Noua distribuire nu va compensa automat această diferență.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Anulează')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Continuă')),
        ],
      )) ?? false;
      if (!proceed) return;
    }
    try { await widget.savePerDiem(r); widget.notifyUser(r.memberId, 'Diurnă de confirmat', 'Ai primit ${r.amount.toStringAsFixed(2)} lei diurnă pentru ${settlement?.name ?? 'decontul anterior'}.'); widget.log('Diurnă distribuită', '${name(r.memberId)} · ${settlement?.name ?? 'istoric anterior'}'); }
    catch (e) { if (mounted) showErrorMessage(context, 'Nu s-a putut salva diurna: $e'); }
  }

  Future<XFile?> _pickDocumentImage({bool allowNoImage = false}) {
    final injectedPicker = widget.pickDocumentImage;
    if (injectedPicker != null) return injectedPicker(allowNoImage: allowNoImage);
    return pickExpenseDocumentImage(
        context: context,
        allowNoImage: allowNoImage,
        requestImage: (source, {
          required imageQuality,
          required maxWidth,
          required maxHeight,
        }) => _imagePicker.pickImage(
          source: source,
          imageQuality: imageQuality,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        ),
        onError: (error) {
          if (mounted) {
            showErrorMessage(context, 'Imaginea nu a putut fi deschisă: $error');
          }
        },
      );
  }

  Future<String> _recognizeExpenseText(Uint8List bytes, {String? path}) =>
      widget.recognizeExpenseText?.call(bytes, path: path) ??
      recognizeTextFromImage(bytes, path: path);

  Expense? _duplicateOf(Expense candidate) =>
      findPotentialExpenseDuplicate<Expense>(
        existing: widget.expenses,
        candidate: candidate,
        teamId: (expense) => expense.teamId,
        settlementId: (expense) => expense.settlementId,
        imageFingerprint: (expense) => expense.imageFingerprint,
        documentNumber: (expense) => expense.documentNumber,
        date: (expense) => expense.date,
        amount: (expense) => expense.amount,
      );

  Future<bool> _duplicateAllowed(Expense candidate) async {
    final learning = widget.settings.learning['conflicts'];
    final decision = decideExpenseDuplicate<Expense>(
      conflictsEnabled: learning?.enabled == true,
      automatic: learning?.mode == LearningMode.automatic,
      findDuplicate: () => _duplicateOf(candidate),
    );
    if (decision.kind == ExpenseDuplicateDecisionKind.allow) return true;

    final duplicate = decision.duplicate!;
    if (decision.kind == ExpenseDuplicateDecisionKind.block) {
      if (mounted) showErrorMessage(context, 'Document duplicat blocat automat: ${duplicate.documentNumber.isEmpty ? duplicate.description : duplicate.documentNumber}.');
      widget.log('Duplicat financiar blocat', candidate.documentNumber);
      return false;
    }
    return await showDialog<bool>(context: context, builder: (d) => AlertDialog(title: const Text('Posibil document duplicat'), content: Text('Există deja un document foarte asemănător: ${duplicate.documentNumber.isEmpty ? 'fără număr' : duplicate.documentNumber}, ${duplicate.amount.toStringAsFixed(2)} lei, ${formatDate(duplicate.date)}.\n\nSalvezi totuși?'), actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Nu, oprește')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Da, salvează'))])) ?? false;
  }

  Future<void> _manual() async {
    final picked = await _pickDocumentImage(allowNoImage: true);
    if (!mounted) return;
    Uint8List? raw;
    FiscalOcrData? parsed;
    if (picked != null) {
      raw = await picked.readAsBytes();
      if (!mounted) return;
      final ocrSetting = widget.settings.learning['ocr'];
      final shouldRunAutomaticOcr = shouldRunOptionalAutomaticExpenseOcr(
        imageBytes: raw,
        enabled: ocrSetting?.enabled == true,
        automaticMode: ocrSetting?.mode == LearningMode.automatic,
      );
      if (shouldRunAutomaticOcr) {
        setState(() => scanning = true);
        try {
          final result = await scanOptionalAutomaticExpenseOcr(
            raw,
            path: picked.path,
            enabled: ocrSetting?.enabled == true,
            automaticMode: ocrSetting?.mode == LearningMode.automatic,
            recognize: _recognizeExpenseText,
            parse: parseFiscalOcr,
          );
          if (!mounted) return;
          if (result != null && result.error == null) {
            parsed = result.data;
            widget.log('OCR automat la atașare', '${team.name} · încredere ${(parsed.confidence * 100).round()}%');
          }
        } catch (_) {
          // În modul automat, eșecul OCR nu blochează introducerea manuală.
        } finally {
          if (mounted) setState(() => scanning = false);
        }
      }
    }
    if (!mounted) return;
    final e = await _expenseDialog(ocr: parsed, imageBytes: raw);
    if (mounted && e != null) await _saveNewExpense(e);
  }

  Future<void> _scan() async {
    final ocrSetting = widget.settings.learning['ocr'];
    if (ocrSetting?.enabled != true) { if (mounted) showErrorMessage(context, 'OCR financiar este dezactivat din Learning Center.'); return; }
    final picked = await _pickDocumentImage();
    if (!mounted || picked == null) return;
    final raw = await picked.readAsBytes();
    if (!mounted || raw.isEmpty) return;
    setState(() => scanning = true);
    late final FiscalOcrData parsed;
    try {
      final result = await scanExpenseDocumentOcr(
        raw,
        path: picked.path,
        recognize: _recognizeExpenseText,
        parse: parseFiscalOcr,
        onSuccess: (data) {
          if (mounted) widget.log('OCR document procesat',
            '${team.name} · încredere ${(data.confidence * 100).round()}%');
        },
      );
      if (!mounted) return;
      parsed = result.data;
      if (result.error != null && mounted) {
        showErrorMessage(context, 'OCR-ul nu a putut citi documentul. Poți completa manual; fotografia nu se salvează în baza de date. Detalii: ${result.error}');
      }
    } finally {
      if (mounted) setState(() => scanning = false);
    }
    if (!mounted) return;
    final expense = await _expenseDialog(ocr: parsed, imageBytes: raw);
    if (mounted && expense != null) await _saveNewExpense(expense);
  }

  Future<Expense?> _expenseDialog({FiscalOcrData? ocr, Uint8List? imageBytes}) async {
    final formKey = GlobalKey<FormState>();
    final prefill = expenseOcrPrefill(ocr, now: DateTime.now());
    final number = TextEditingController(text: prefill.documentNumber);
    final amount = TextEditingController(text: prefill.amountText);
    final supplier = TextEditingController(text: prefill.supplier);
    final desc = TextEditingController();
    final litersC = TextEditingController(text: prefill.litersText);
    final priceC = TextEditingController(text: prefill.pricePerLiterText);
    String cat = prefill.category;
    ExpenseDocumentType docType = prefill.documentType;
    DateTime docDate = prefill.date;
    Uint8List? compressed;
    if(imageBytes!=null){
      try{compressed=compressExpenseDocumentImage(imageBytes);}catch(e){if(mounted)showErrorMessage(context,'Fotografia nu a putut fi comprimată și nu va fi atașată: $e');}
    }
    // Fotografia este utilizată numai în memorie pentru OCR/previzualizare.
    // În Firestore salvăm doar un fingerprint mic pentru deduplicare.
    const photoBase64 = '';
    final fingerprint = imageBytes == null ? '' : fingerprintExpenseDocumentImage(imageBytes);

    final result = await showDialog<Expense>(context: context, builder: (d) => StatefulBuilder(builder: (d, setD) => AlertDialog(
      title: Text(ocr == null ? 'Introducere document' : 'Verifică datele citite prin OCR'),
      content: SizedBox(width: 620, child: Form(key: formKey, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (compressed != null) ...[
          ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(compressed, height: 180, fit: BoxFit.contain)),
          const SizedBox(height: 8),
        ],
        if (ocr != null) ...[
          _InfoCard(icon: Icons.document_scanner, title: 'OCR ${(ocr.confidence * 100).round()}%', text: ocr.rawText.isEmpty ? 'Textul nu a putut fi extras. Completează manual.' : 'Datele au fost completate automat. Verifică-le înainte de salvare. Fotografia este temporară și nu va fi salvată.'),
          const SizedBox(height: 8),
        ],
        DropdownButtonFormField<ExpenseDocumentType>(initialValue: docType, decoration: const InputDecoration(labelText: 'Tip document'), items: const [DropdownMenuItem(value: ExpenseDocumentType.fiscalReceipt, child: Text('Bon Fiscal')), DropdownMenuItem(value: ExpenseDocumentType.invoice, child: Text('Factură'))], onChanged: (v) { if (v != null) setD(() { docType = v; if (v == ExpenseDocumentType.invoice && cat == 'Alte cheltuieli') cat = 'Facturi'; if (v == ExpenseDocumentType.fiscalReceipt && cat == 'Facturi') cat = 'Alte cheltuieli'; }); }),
        const SizedBox(height: 8),
        TextFormField(controller: number, decoration: InputDecoration(labelText: docType == ExpenseDocumentType.fiscalReceipt ? 'Nr. bon' : 'Nr. factură'), validator: expenseDocumentNumberValidationError),
        const SizedBox(height: 8),
        TextFormField(controller: supplier, decoration: const InputDecoration(labelText: 'Furnizor / comerciant')),
        const SizedBox(height: 8),
        TextFormField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Sumă', suffixText: 'lei'), validator: (v) => expenseAmountValidationError(parseExpenseAmountBani(v ?? ''))),
        const SizedBox(height: 8),
        ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.event), title: const Text('Data documentului'), subtitle: Text(_shortDate(docDate)), trailing: TextButton(onPressed: () async { final x = await showDatePicker(context: d, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: docDate); if (x != null) setD(() => docDate = x); }, child: const Text('Alege'))),
        DropdownButtonFormField<String>(initialValue: cat, decoration: const InputDecoration(labelText: 'Categorie'), items: const [DropdownMenuItem(value: 'Combustibil', child: Text('Combustibil')), DropdownMenuItem(value: 'Facturi', child: Text('Facturi')), DropdownMenuItem(value: 'Alte cheltuieli', child: Text('Alte cheltuieli'))], onChanged: (v) { if (v != null) setD(() => cat = v); }),
        if (cat == 'Combustibil') ...[
          const SizedBox(height: 8),
          Row(children: [Expanded(child: TextFormField(controller: litersC, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Litri'))), const SizedBox(width: 8), Expanded(child: TextFormField(controller: priceC, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Preț / litru')))]),
        ],
        const SizedBox(height: 8),
        TextField(controller: desc, decoration: const InputDecoration(labelText: 'Specificație / descriere (opțional)')),
        if (ocr != null && ocr.rawText.isNotEmpty) ExpansionTile(title: const Text('Text OCR brut'), children: [Padding(padding: const EdgeInsets.all(8), child: SelectableText(ocr.rawText, style: const TextStyle(fontSize: 11)))]),
      ])))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Anulează')),
        FilledButton(onPressed: () {
          if (!(formKey.currentState?.validate() ?? false)) return;
          if (expenseDateExceedsFutureAllowance(docDate, DateTime.now())) {
            ScaffoldMessenger.of(d).showSnackBar(const SnackBar(content: Text('Data documentului nu poate fi în viitor.')));
            return;
          }
          final bani = parseExpenseAmountBani(amount.text);
          if (bani == null) return;
          final value = bani / 100.0;
          Navigator.pop(d, Expense(
            id: idNow(), teamId: team.id, settlementId: settlement?.id, category: cat,
            description: desc.text.trim().isEmpty ? cat : desc.text.trim(), amount: value, date: docDate,
            documentType: docType, documentNumber: number.text.trim(), supplier: supplier.text.trim(),
            liters: double.tryParse(litersC.text.replaceAll(',', '.')), pricePerLiter: double.tryParse(priceC.text.replaceAll(',', '.')),
            documentImageBase64: photoBase64, imageFingerprint: fingerprint, ocrRawText: '', ocrConfidence: ocr?.confidence ?? 0,
            confirmed: isManager,
          ));
        }, child: Text(isManager ? 'Confirmă' : 'Trimite spre confirmare')),
      ],
    )));
    // Keep controllers alive through the closing dialog animation.
    return result;
  }

  Future<void> _saveNewExpense(Expense e) async {
    if (!mounted || !await _duplicateAllowed(e) || !mounted) return;
    try {
      await widget.saveExpense(e);
      widget.log('${e.documentType == ExpenseDocumentType.fiscalReceipt ? 'Bon Fiscal' : 'Factură'} introdus', '${e.category} · ${settlement?.name ?? 'istoric anterior'}');
      if (mounted) showSuccessMessage(context, e.confirmed ? 'Documentul a fost salvat.' : 'Documentul a fost trimis gestionarului pentru confirmare.');
    } catch (err) { if (mounted) showErrorMessage(context, 'Nu s-a putut salva documentul: $err'); }
  }

  List<Widget> _groupedExpenses() {
    const groups = ['Combustibil', 'Facturi', 'Alte cheltuieli'];
    final out = <Widget>[];
    for (final g in groups) {
      final items = allEx.where((e) => e.category == g).toList();
      if (items.isEmpty) continue;
      out.add(Padding(padding: const EdgeInsets.only(top: 10, bottom: 6), child: Text(g, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))));
      out.addAll(items.map((e) => Card(child: ListTile(
        leading: e.hasImage ? InkWell(onTap: () => _showExpenseImage(e), child: ClipRRect(borderRadius: BorderRadius.circular(7), child: Image.memory(base64Decode(e.documentImageBase64), width: 48, height: 48, fit: BoxFit.cover))) : const CircleAvatar(child: Icon(Icons.receipt_long)),
        title: Text('${e.documentType == ExpenseDocumentType.fiscalReceipt ? 'Bon Fiscal' : 'Factură'} nr ${e.documentNumber.isEmpty ? '—' : e.documentNumber}'),
        subtitle: Text('${formatDate(e.date)} · ${e.amount.toStringAsFixed(2)} lei${e.supplier.isEmpty ? '' : ' · ${e.supplier}'}${e.description == g ? '' : '\n${e.description}'}${e.ocrRawText.isEmpty ? '' : ' · OCR ${(e.ocrConfidence * 100).round()}%'}'),
        isThreeLine: e.description != g,
        trailing: e.confirmed ? const Chip(label: Text('Confirmat')) : isManager ? FilledButton(onPressed: () => _confirmExpense(e), child: const Text('Confirmă')) : const Chip(label: Text('În așteptare')),
      ))));
    }
    return out;
  }

  Future<void> _showExpenseImage(Expense e) async {
    if (!e.hasImage) return;
    Uint8List? bytes;
    try { bytes = base64Decode(e.documentImageBase64); } catch (_) {}
    if (bytes == null) return;
    await showDialog<void>(context: context, builder: (d) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900, maxHeight: 800), child: Column(mainAxisSize: MainAxisSize.min, children: [AppBar(title: Text(e.documentNumber.isEmpty ? 'Document' : e.documentNumber), automaticallyImplyLeading: false, actions: [IconButton(onPressed: () => Navigator.pop(d), icon: const Icon(Icons.close))]), Flexible(child: InteractiveViewer(minScale: .5, maxScale: 5, child: Image.memory(bytes!, fit: BoxFit.contain)))]))));
  }

  Future<void> _confirmExpense(Expense e) async {
    e.confirmed = true;
    try { await widget.saveExpense(e); widget.log('Cheltuială confirmată', e.documentNumber); }
    catch (err) { e.confirmed = false; if (mounted) showErrorMessage(context, 'Confirmarea a eșuat: $err'); }
  }

  Future<void> _pdf() async {
    setState(() => exporting = true);
    try {
      await downloadDecontPdf(team: team, users: widget.users, expenses: widget.expenses, perDiems: widget.perDiems, finance: finance, settlement: settlement, legacyOnly: isLegacy);
      if (mounted) showSuccessMessage(context, 'PDF generat. Descărcarea a fost pornită.');
    } catch (e) { if (mounted) showErrorMessage(context, 'Eroare PDF: $e'); }
    finally { if (mounted) setState(() => exporting = false); }
  }
}




