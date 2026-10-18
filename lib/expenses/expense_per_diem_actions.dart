part of '../main.dart';

extension _ExpensePerDiemActions on _ExpensePageState {
  Widget _pendingPerDiemCard(PerDiemEntry entry) {
    final source = entry.distributedBy == null ? 'Gestionar financiar' : name(entry.distributedBy!);
    final method = entry.method?.label ?? 'Metodă nespecificată';
    final alreadyReportedMissing = entry.received == false;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.payments_outlined, color: Colors.orange),
            const SizedBox(width: 10),
            Expanded(child: Text('Confirmare diurnă', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 8),
          Text('${entry.amount.toStringAsFixed(2)} lei · $method · de la $source'),
          Text('Data distribuirii: ${formatDate(entry.distributedAt ?? entry.date)}'),
          if (alreadyReportedMissing) ...[
            const SizedBox(height: 6),
            const Text('Ai raportat că nu ai primit banii. Solicitarea rămâne deschisă; confirmă suma doar după încasare.', style: TextStyle(fontWeight: FontWeight.w700)),
          ] else ...[
            const SizedBox(height: 6),
            const Text('Confirmă dacă ai primit efectiv suma.', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
              onPressed: () => _confirmPerDiemAmount(entry),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Confirmă suma primită'),
            ),
            if (!alreadyReportedMissing)
              OutlinedButton.icon(
                onPressed: () => _answerPerDiem(entry, 0),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Nu am primit'),
              ),
          ]),
        ]),
      ),
    );
  }

  Future<void> _confirmPerDiemAmount(PerDiemEntry entry) async {
    // O confirmare trebuie să reflecte suma verificată de beneficiar, nu o valoare precompletată.
    final controller = TextEditingController();
    final value = await showDialog<double>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Confirmare sumă primită'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Distribuitorul a declarat ${entry.amount.toStringAsFixed(2)} lei.'),
        const SizedBox(height: 12),
        TextField(controller: controller, autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Suma primită efectiv', hintText: 'Introdu suma numărată', suffixText: 'lei')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Anulează')),
        FilledButton(onPressed: () {
          final bani = parsePerDiemBani(controller.text);
          if (bani == null) {
            showErrorMessage(dialogContext, 'Introdu o sumă validă, cu maximum două zecimale.');
            return;
          }
          Navigator.pop(dialogContext, bani / 100);
        }, child: const Text('Confirmă')),
      ],
    ));
    controller.dispose();
    if (value == null) return;
    // Diferențele sunt confirmate explicit pentru a evita greșelile de tastare.
    if ((value - entry.amount).abs() >= 0.01) {
      if (!mounted) return;
      final difference = value - entry.amount;
      final accepted = await showDialog<bool>(context: context, builder: (d) => AlertDialog(
        title: Text(difference > 0 ? 'Atenție: plată în avans' : 'Atenție: sumă incompletă'),
        content: Text(difference > 0
          ? 'Ai introdus ${value.toStringAsFixed(2)} lei, cu ${difference.toStringAsFixed(2)} lei peste suma declarată. Diferența va apărea ca avans de verificat.'
          : 'Ai introdus ${value.toStringAsFixed(2)} lei, cu ${difference.abs().toStringAsFixed(2)} lei sub suma declarată. Diferența va apărea ca restanță de verificat.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Corectează')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Confirmă diferența')),
        ],
      )) ?? false;
      if (!accepted) return;
    }
    await _answerPerDiem(entry, value);
  }

  Future<void> _answerPerDiem(PerDiemEntry entry, double amountReceived) async {
    // Previne confirmări duble și rescrierea unei plăți deja confirmate.
    if (entry.memberId != widget.currentUser.id ||
        entry.status != PerDiemStatus.awaitingConfirmation ||
        entry.actualReceivedAmount != null ||
        _savingPerDiemIds.contains(entry.id)) {
      if (mounted) showErrorMessage(context, 'Această diurnă nu mai poate fi confirmată din contul curent.');
      return;
    }
    if (!amountReceived.isFinite || amountReceived < 0 || amountReceived > 100000000 || (amountReceived * 100 - (amountReceived * 100).round()).abs() > 0.000001) return;
    if (amountReceived == 0 && entry.received == false) {
      if (mounted) showErrorMessage(context, 'Neprimirea a fost deja declarată. Poți confirma ulterior suma încasată.');
      return;
    }
    _savingPerDiemIds.add(entry.id);
    final previousReceived = entry.received;
    final previousStatus = entry.status;
    final previousConfirmedAt = entry.confirmedAt;
    final previousAmount = entry.actualReceivedAmount;
    // Zero lei este un refuz, nu o confirmare definitivă: solicitarea
    // rămâne deschisă și poate fi confirmată după plata efectivă.
    // Nu marcăm zero ca sumă încasată, pentru a nu bloca plata ulterioară.
    entry.actualReceivedAmount = amountReceived == 0 ? null : amountReceived;
    entry.received = amountReceived > 0;
    entry.status = amountReceived == 0
        ? PerDiemStatus.awaitingConfirmation
        : PerDiemStatus.confirmed;
    entry.confirmedAt = amountReceived == 0 ? null : DateTime.now();
    final difference = entry.amount - amountReceived;
    try {
      await widget.savePerDiem(entry);
      widget.log(amountReceived == 0 ? 'Diurnă: primire refuzată' : 'Diurnă: sumă efectiv primită',
        '${name(entry.memberId)} · declarat ${entry.amount.toStringAsFixed(2)} lei · primit ${amountReceived.toStringAsFixed(2)} lei · diferență ${difference.toStringAsFixed(2)} lei');
      if (entry.distributedBy != null && (amountReceived == 0 || difference.abs() >= 0.01)) {
        final title = amountReceived == 0 ? 'Diurnă declarată neprimită' : 'Diferență diurnă';
        final detail = amountReceived == 0
            ? '${name(entry.memberId)} a declarat că nu a primit diurna de ${entry.amount.toStringAsFixed(2)} lei. Solicitarea rămâne deschisă.'
            : '${name(entry.memberId)} a confirmat ${amountReceived.toStringAsFixed(2)} lei față de ${entry.amount.toStringAsFixed(2)} lei declarați. ${difference > 0 ? 'Diferență de plată' : 'Posibil avans'}: ${difference.abs().toStringAsFixed(2)} lei. Verifică situația în Decont.';
        widget.notifyUser(entry.distributedBy!, title, detail);
      }
      widget.onChanged();
      if (mounted) {
        setState(() {});
        showSuccessMessage(context, difference.abs() < 0.01
          ? 'Diurna a fost confirmată integral.'
          : amountReceived == 0
            ? 'Neprimirea diurnei a fost înregistrată. Distribuitorul a fost notificat.'
            : 'Suma efectiv primită a fost salvată. Diferența a fost semnalată.');
      }
    } catch (e) {
      entry.received = previousReceived;
      entry.status = previousStatus;
      entry.confirmedAt = previousConfirmedAt;
      entry.actualReceivedAmount = previousAmount;
      if (mounted) {
        setState(() {});
        showErrorMessage(context, 'Nu s-a putut salva confirmarea diurnei: $e');
      }
    } finally {
      _savingPerDiemIds.remove(entry.id);
    }
  }

  Future<void> _manager() async {
    String? selected = managerId;
    final r = await showDialog<String>(context: context, builder: (d) => StatefulBuilder(builder: (d, setD) => AlertDialog(title: const Text('Gestionar financiar'), content: Column(mainAxisSize: MainAxisSize.min, children: visibleTeamMemberIds.map((id) => RadioListTile<String>(value: id, groupValue: selected, title: Text(name(id)), onChanged: (v) => setD(() => selected = v))).toList()), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Anulează')), FilledButton(onPressed: selected == null ? null : () => Navigator.pop(d, selected), child: const Text('Salvează'))])));
    if (r == null) return;
    if (settlement != null) {
      settlement!.managerId = r;
      try { await widget.saveSettlement(settlement!); widget.log('Gestionar financiar schimbat', '${settlement!.name} · ${name(r)}'); } catch (e) { if (mounted) showErrorMessage(context, 'Nu s-a putut salva: $e'); }
    } else {
      finance.managerId = r; team.financialManagerId = r; await _saveFinance(finance, 'Gestionar financiar schimbat'); widget.onChanged();
    }
  }

  Future<void> _perDiemRate() async {
    final c = TextEditingController(text: perDiemRate.toStringAsFixed(2));
    final r = await showDialog<double>(context: context, builder: (d) => AlertDialog(title: const Text('Valoare diurnă'), content: TextField(controller: c, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(suffixText: 'lei/zi')), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Anulează')), FilledButton(onPressed: () => Navigator.pop(d, double.tryParse(c.text.replaceAll(',', '.'))), child: const Text('Salvează'))]));
    c.dispose(); if (r == null || r < 0) return;
    if (settlement != null) {
      settlement!.perDiemRate = r;
      try { await widget.saveSettlement(settlement!); widget.log('Valoare diurnă modificată', settlement!.name); } catch (e) { if (mounted) showErrorMessage(context, 'Nu s-a putut salva: $e'); }
    } else { finance.perDiemRate = r; await _saveFinance(finance, 'Valoare diurnă modificată'); }
  }

  Future<void> _saveFinance(TeamFinance value, String auditAction) async {
    try { await widget.saveFinance(value); widget.log(auditAction, team.name); if (mounted) setState(() {}); }
    catch (e) { if (mounted) showErrorMessage(context, 'Nu s-a putut salva: $e'); }
  }

  Future<void> _respondToPerDiemDifference(PerDiemEntry entry, {required bool dispute}) async {
    if (entry.distributedBy != widget.currentUser.id && !widget.isAdmin) return;
    if (entry.supplementaryFor != null || entry.status != PerDiemStatus.confirmed ||
        entry.actualReceivedAmount == null ||
        (entry.amount - entry.actualReceivedAmount!).abs() < 0.01) return;
    String reason = '';
    if (dispute) {
      final controller = TextEditingController();
      final response = await showDialog<String>(context: context, builder: (d) => AlertDialog(
        title: const Text('Contestă diferența de diurnă'),
        content: TextField(controller: controller, maxLines: 3,
          decoration: const InputDecoration(labelText: 'Motiv obligatoriu')),
        actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Anulează')),
          FilledButton(onPressed: () {
            if (controller.text.trim().isEmpty) {
              showErrorMessage(d, 'Motivul este obligatoriu.'); return;
            }
            Navigator.pop(d, controller.text.trim());
          }, child: const Text('Contestă'))]));
      controller.dispose();
      if (response == null) return;
      reason = response;
    }
    final ref = FirebaseFirestore.instance.collection('perDiemDisputes').doc(entry.id);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final previous = await tx.get(ref);
        if (previous.exists) throw StateError('Diferența are deja o decizie sau contestație.');
        tx.set(ref, {
          'perDiemId': entry.id,
          'distributorId': entry.distributedBy,
          'beneficiaryId': entry.memberId,
          'declaredBani': parsePerDiemBani(entry.amount.toString()),
          'receivedBani': parsePerDiemBani(entry.actualReceivedAmount!.toString()),
          'status': dispute ? 'disputed' : 'accepted',
          'reason': reason,
          'actorUid': widget.currentUser.id,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
      widget.notifyUser(entry.memberId, dispute ? 'Diferență contestată' : 'Diferență acceptată',
        dispute ? 'Distribuitorul a contestat diferența de diurnă. Motiv: $reason' :
          'Distribuitorul a acceptat diferența de diurnă.');
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) showErrorMessage(context, 'Nu s-a putut înregistra decizia: $e');
    }
  }

  Future<void> _resolvePerDiemDispute(PerDiemEntry entry, String decision) async {
    if (!widget.isAdmin) return;
    final ref = FirebaseFirestore.instance.collection('perDiemDisputes').doc(entry.id);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists || snap.data()?['status'] != 'disputed') {
          throw StateError('Contestația nu mai este deschisă.');
        }
        tx.update(ref, {
          'status': decision,
          'resolvedBy': widget.currentUser.id,
          'resolvedAt': FieldValue.serverTimestamp(),
        });
      });
      widget.notifyUser(entry.memberId, 'Contestație diurnă soluționată',
        'Adminul a soluționat contestația: $decision. Suma confirmată rămâne nemodificată.');
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) showErrorMessage(context, 'Nu s-a putut soluționa contestația: $e');
    }
  }

  Widget _perDiemDisputeActions(PerDiemEntry entry) {
    if (entry.supplementaryFor != null || entry.status != PerDiemStatus.confirmed ||
        entry.actualReceivedAmount == null ||
        (entry.amount - entry.actualReceivedAmount!).abs() < 0.01) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('perDiemDisputes').doc(entry.id).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Text('Contestația nu poate fi încărcată.');
        if (!snapshot.hasData) return const SizedBox.shrink();
        final dispute = snapshot.data!.data();
        if (dispute == null && (entry.distributedBy == widget.currentUser.id || widget.isAdmin)) {
          return Wrap(spacing: 4, children: [
            TextButton(onPressed: () => _respondToPerDiemDifference(entry, dispute: false),
              child: const Text('Accept diferența')),
            TextButton(onPressed: () => _respondToPerDiemDifference(entry, dispute: true),
              child: const Text('Contest diferența')),
          ]);
        }
        if (dispute == null) return const SizedBox.shrink();
        final status = (dispute['status'] ?? '').toString();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Diferență: $status${(dispute['reason'] ?? '').toString().isEmpty ? '' : ' · ${dispute['reason']}'}'),
          if (widget.isAdmin && status == 'disputed')
            Wrap(spacing: 4, children: [
              TextButton(onPressed: () => _resolvePerDiemDispute(entry, 'resolved_accepted'),
                child: const Text('Validează diferența')),
              TextButton(onPressed: () => _resolvePerDiemDispute(entry, 'resolved_rejected'),
                child: const Text('Respinge contestația')),
            ]),
        ]);
      });
  }

  Future<void> _supplementaryPayment() async {
    if (!isManager || managerId == null || selectedClosed) return;
    final eligible = widget.perDiems.where((e) =>
      e.distributedBy == managerId && e.memberId != managerId &&
      e.supplementaryFor == null && e.status == PerDiemStatus.confirmed &&
      e.actualReceivedAmount != null && e.amount > e.actualReceivedAmount!).toList();
    if (eligible.isEmpty) {
      if (mounted) showErrorMessage(context, 'Nu există diferențe confirmate pentru acest distribuitor.');
      return;
    }
    PerDiemEntry original = eligible.first;
    final amount = TextEditingController();
    String method = 'Numerar';
    final payment = await showDialog<PerDiemEntry>(context: context, builder: (d) => StatefulBuilder(builder: (d, setD) =>
      AlertDialog(title: const Text('Plată suplimentară diurnă'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(initialValue: original.id,
            decoration: const InputDecoration(labelText: 'Diferența inițială'),
            items: eligible.map((e) => DropdownMenuItem(value: e.id,
              child: Text('${name(e.memberId)} · ${e.id.substring(0, e.id.length > 8 ? 8 : e.id.length)}'))).toList(),
            onChanged: (v) => setD(() => original = eligible.firstWhere((e) => e.id == v))),
          TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Sumă trimisă', suffixText: 'lei')),
          DropdownButtonFormField<String>(initialValue: method,
            items: const [DropdownMenuItem(value: 'Numerar', child: Text('Numerar')),
              DropdownMenuItem(value: 'Transfer bancar', child: Text('Transfer bancar'))],
            onChanged: (v) { if (v != null) setD(() => method = v); }),
        ]), actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Anulează')),
          FilledButton(onPressed: () {
            final bani = parsePerDiemBani(amount.text, allowZero: false);
            if (bani == null) { showErrorMessage(d, 'Introdu o sumă pozitivă validă.'); return; }
            Navigator.pop(d, PerDiemEntry(id: idNow(), teamId: team.id,
              settlementId: settlement?.id, memberId: original.memberId,
              date: DateTime.now(), amount: bani / 100,
              status: PerDiemStatus.awaitingConfirmation,
              distributedBy: managerId, distributedAt: DateTime.now(),
              method: method == 'Numerar' ? PerDiemPaymentMethod.cash : PerDiemPaymentMethod.bankTransfer,
              supplementaryFor: original.id));
          }, child: const Text('Trimite')), ])));
    amount.dispose();
    if (payment == null) return;
    try {
      await widget.savePerDiem(payment);
      widget.notifyUser(payment.memberId, 'Plată suplimentară de confirmat',
        'Ai o plată suplimentară de ${payment.amount.toStringAsFixed(2)} lei de confirmat.');
      widget.onChanged();
    } catch (e) {
      if (mounted) showErrorMessage(context, 'Plata suplimentară nu a putut fi salvată: $e');
    }
  }

  Future<void> _distribute() async {
    if (managerId == null) { if (mounted) showErrorMessage(context, 'Setează mai întâi gestionarul financiar.'); return; }
    String? beneficiary = visibleTeamMemberIds.where((x) => x != managerId).isEmpty ? null : visibleTeamMemberIds.where((x) => x != managerId).first;
    String method = 'Numerar';
    final amount = TextEditingController(text: perDiemRate.toStringAsFixed(2));
    final r = await showDialog<PerDiemEntry>(context: context, builder: (d) => StatefulBuilder(builder: (d, setD) => AlertDialog(title: const Text('Distribuire diurnă'), content: Column(mainAxisSize: MainAxisSize.min, children: [DropdownButtonFormField<String>(initialValue: beneficiary, decoration: const InputDecoration(labelText: 'Trimite către'), items: visibleTeamMemberIds.map((id) => DropdownMenuItem(value: id, child: Text(name(id)))).toList(), onChanged: (v) => setD(() => beneficiary = v)), const SizedBox(height: 8), TextField(controller: amount, decoration: const InputDecoration(labelText: 'Sumă'), keyboardType: const TextInputType.numberWithOptions(decimal: true)), const SizedBox(height: 8), DropdownButtonFormField<String>(initialValue: method, decoration: const InputDecoration(labelText: 'Metodă'), items: const [DropdownMenuItem(value: 'Numerar', child: Text('Numerar')), DropdownMenuItem(value: 'Transfer bancar', child: Text('Transfer bancar'))], onChanged: (v) { if (v != null) setD(() => method = v); })]), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Anulează')), FilledButton(onPressed: beneficiary == null ? null : () { final bani = parsePerDiemBani(amount.text, allowZero: false);
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


}
