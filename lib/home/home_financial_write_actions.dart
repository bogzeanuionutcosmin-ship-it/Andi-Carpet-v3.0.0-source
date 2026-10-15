part of '../main.dart';

// Mutare exclusiv structurală a operațiunilor de scriere financiară.
// Condițiile de drept, tranzacția și auditul rămân nemodificate.
extension _HomeFinancialWriteActions on _HomePageState {
  Future<void> _saveExpenseDirect(Expense expense) async {
    if (!canEditTeam(expense.teamId) || !hasPermission(FunctionPermission.viewOwnDecont)) {
      throw StateError('Nu ai dreptul să modifici Decontul acestei echipe.');
    }
    final data = _expenseMap(expense);
    await FirebaseFirestore.instance.collection('expenses').doc(expense.id).set(data, SetOptions(merge: true));
    unawaited(_writeLearningEvent(category: expense.ocrRawText.trim().isNotEmpty ? 'ocr' : 'finance', event: 'expense_saved', teamId: expense.teamId, data: {
      'category': expense.category, 'amount': expense.amount, 'documentType': expense.documentType.name,
      'ocrConfidence': expense.ocrConfidence, 'confirmed': expense.confirmed, 'hasImage': expense.hasImage,
    }));
    _expenseCache[expense.id] = _encoded(data);
  }

  Future<void> _savePerDiemDirect(PerDiemEntry entry) async {
    final canWrite = isAdmin || entry.memberId == currentUserId ||
        (canEditTeam(entry.teamId) && hasPermission(FunctionPermission.viewOwnDecont));
    if (!canWrite) throw StateError('Nu ai dreptul să modifici această diurnă.');
    final data = _perDiemMap(entry);
    // Confirmarea sau refuzul se salvează atomic. Verificarea exclusiv în UI
    // nu poate preveni două confirmări simultane de pe dispozitive diferite.
    final isReceiptResponse = entry.distributedBy != null &&
        (entry.status == PerDiemStatus.confirmed ||
         (entry.status == PerDiemStatus.awaitingConfirmation && entry.received == false));
    final db = FirebaseFirestore.instance;
    final ref = db.collection('perDiems').doc(entry.id);
    if (isReceiptResponse) {
      if (entry.memberId != currentUserId) {
        throw StateError('Doar beneficiarul poate confirma primirea diurnei.');
      }
      // 79–86: validarea se face înainte de tranzacție, iar în tranzacție
      // verificăm documentul curent, nu datele posibil învechite din UI.
      final received = entry.actualReceivedAmount;
      final receivedBani = received == null ? null :
          (received.isFinite ? parsePerDiemBani(received.toString()) : null);
      final isRefusal = entry.received == false &&
          entry.status == PerDiemStatus.awaitingConfirmation && received == null;
      if (!isRefusal && (entry.status != PerDiemStatus.confirmed ||
          entry.received != true || receivedBani == null || receivedBani <= 0)) {
        throw StateError('Confirmare invalidă: suma primită trebuie să fie pozitivă.');
      }
      if (FirebaseAuth.instance.currentUser?.uid != currentUserId) {
        throw StateError('Sesiunea de autentificare nu corespunde beneficiarului.');
      }
      final auditRef = ref.collection('receiptAudit').doc();
      await db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) throw StateError('Distribuirea nu mai există.');
        final previous = snap.data()!;
        if (previous['memberId'] != currentUserId ||
            previous['distributedBy'] == null ||
            previous['status'] != PerDiemStatus.awaitingConfirmation.name ||
            previous['actualReceivedAmount'] != null) {
          throw StateError('Diurna a fost deja confirmată sau modificată. Reîncarcă datele.');
        }
        if (previous['distributedBy'] is! String ||
            (previous['distributedBy'] as String).isEmpty) {
          throw StateError('Distribuitorul acestei diurne este invalid.');
        }
        final declared = previous['amount'];
        if (declared is! num || !declared.toDouble().isFinite ||
            declared <= 0 || parsePerDiemBani(declared.toString()) == null) {
          throw StateError('Suma declarată nu este validă.');
        }
        if (isRefusal && previous['received'] == false) {
          throw StateError('Refuzul a fost deja înregistrat.');
        }
        // Valoarea declarată, identitatea și echipa NU sunt modificate.
        final declaredBani = parsePerDiemBani(declared.toString())!;
        final changes = <String, dynamic>{
          'received': !isRefusal,
          'actualReceivedAmount': isRefusal ? null : receivedBani! / 100,
          'status': isRefusal ? PerDiemStatus.awaitingConfirmation.name
              : PerDiemStatus.confirmed.name,
          'confirmedAt': isRefusal ? null : FieldValue.serverTimestamp(),
          'receiptUpdatedAt': FieldValue.serverTimestamp(),
        };
        tx.update(ref, changes);
        tx.set(auditRef, {
          'actorUid': currentUserId,
          'action': isRefusal ? 'reported_missing' : 'confirmed_received',
          'distributorId': previous['distributedBy'],
          'beneficiaryId': previous['memberId'],
          'declaredAmountBani': declaredBani,
          'actualReceivedBani': isRefusal ? 0 : receivedBani,
          'differenceBani': declaredBani - (isRefusal ? 0 : receivedBani!),
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } else {
      // Distribuirea este imuabilă: nu suprascriem confirmări existente.
      await db.runTransaction((tx) async {
        if ((await tx.get(ref)).exists) {
          throw StateError('Această distribuire există deja.');
        }
        tx.set(ref, data);
      });
    }
    unawaited(_writeLearningEvent(category: 'finance', event: 'per_diem_saved', teamId: entry.teamId, data: {
      'memberId': entry.memberId, 'amount': entry.amount, 'status': entry.status.name, 'method': entry.method?.name ?? '',
    }));
    _perDiemCache[entry.id] = _encoded(data);
  }

  Future<void> _saveSettlementDirect(TravelSettlement settlement) async {
    if (!canEditTeam(settlement.teamId) || !hasPermission(FunctionPermission.viewOwnDecont)) {
      throw FinanceSaveRejected('Nu ai dreptul să modifici această deplasare.');
    }
    await FirebaseFirestore.instance.collection('settlements').doc(settlement.id).set(_settlementMap(settlement), SetOptions(merge: true));
    unawaited(_writeLearningEvent(category: 'finance', event: 'settlement_saved', teamId: settlement.teamId, data: {
      'name': settlement.name, 'closed': settlement.closed, 'received': settlement.totalReceived,
    }));
  }

  Future<void> _saveFinanceDirect(TeamFinance finance) async {
    if (!canEditTeam(finance.teamId) || !hasPermission(FunctionPermission.viewOwnDecont)) {
      throw FinanceSaveRejected('Nu ai dreptul să modifici datele financiare ale acestei echipe.');
    }
    final data = _financeMap(finance);
    await FirebaseFirestore.instance.collection('finance').doc(finance.teamId).set(data, SetOptions(merge: true));
    unawaited(_writeLearningEvent(category: 'finance', event: 'team_finance_saved', teamId: finance.teamId, data: {
      'receivedDeparture': finance.receivedDeparture, 'receivedDuring': finance.receivedDuring, 'perDiemRate': finance.perDiemRate,
    }));
    _financeCache[finance.teamId] = _encoded(data);
  }

}
