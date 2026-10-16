part of '../main.dart';

// Document conversion only; settings supplies the existing financial fallback.
mixin _HomeDocumentCodecs {
  AppSettings get settings;

  Map<String, dynamic> _locationMap(Location l) => {
    'name': l.name,
    'address': l.address,
    'type': l.type.name,
    'categoryId': l.categoryId,
    'status': l.status.name,
    'latitude': l.latitude,
    'longitude': l.longitude,
    'phone': l.phone,
    'contacts': l.contacts.map((c) => {'name': c.name, 'phone': c.phone, 'role': c.role, 'smsEnabled': c.smsEnabled}).toList(),
    'surfaceM2': l.surfaceM2,
    'facadeM2': l.facadeM2,
    'notes': l.notes,
    'active': l.active,
  };

  Location _locationFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    LocationType type = LocationType.million;
    final typeText = (d['type'] ?? 'million').toString();
    for (final item in LocationType.values) {
      if (item.name == typeText) type = item;
    }
    final rawContacts = d['contacts'];
    final contacts = <LocationContact>[];
    if (rawContacts is List) {
      for (final item in rawContacts) {
        if (item is Map) {
          contacts.add(LocationContact(
            name: (item['name'] ?? '').toString(),
            phone: (item['phone'] ?? '').toString(),
            role: (item['role'] ?? 'Manager').toString(),
            smsEnabled: item['smsEnabled'] != false,
          ));
        }
      }
    }
    double? numberOrNull(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }
    var status = LocationStatus.open;
    final statusText = (d['status'] ?? (d['active'] == false ? 'permanentlyClosed' : 'open')).toString();
    for (final value in LocationStatus.values) {
      if (value.name == statusText) status = value;
    }
    final categoryId = (d['categoryId'] ?? defaultCategoryIdForType(type)).toString();
    return Location(
      id: doc.id,
      name: (d['name'] ?? doc.id).toString(),
      address: (d['address'] ?? '').toString(),
      type: type,
      categoryId: categoryId,
      status: status,
      latitude: numberOrNull(d['latitude']),
      longitude: numberOrNull(d['longitude']),
      phone: d['phone']?.toString(),
      contacts: contacts,
      surfaceM2: numberOrNull(d['surfaceM2']) ?? 0,
      facadeM2: numberOrNull(d['facadeM2']) ?? 0,
      notes: (d['notes'] ?? '').toString(),
      active: d['active'] != false,
    );
  }

  Map<String, dynamic> _categoryMap(LocationCategory c) => {
    'name': c.name,
    'colorValue': c.colorValue,
    'active': c.active,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  LocationCategory _categoryFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return LocationCategory(
      id: doc.id,
      name: (d['name'] ?? doc.id).toString(),
      colorValue: d['colorValue'] is num ? (d['colorValue'] as num).toInt() : int.tryParse('${d['colorValue']}') ?? Colors.blueGrey.value,
      active: d['active'] != false,
    );
  }

  Map<String, dynamic> _functionMap(FunctionDefinition f) => {
    'name': f.name,
    'iconKey': f.iconKey,
    'badgeKeys': f.badgeKeys,
    'colorValue': f.colorValue,
    'permissions': f.permissions.toList()..sort(),
    'active': f.active,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  FunctionDefinition _functionFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final raw = d['permissions'];
    final rawIconKey = (d['iconKey'] ?? 'badge_driver').toString();
    final iconKey = rawIconKey == 'badge_coordinator' || rawIconKey == 'badge_machine' ? 'badge_worker' : rawIconKey;
    final badgeKeys = (d['badgeKeys'] is List
        ? (d['badgeKeys'] as List).map((e) => e.toString())
        : <String>[iconKey])
      .where((e) => e.isNotEmpty && e != 'badge_coordinator')
      .map((e) => e == 'badge_machine' ? 'badge_worker' : e)
      .toSet()
      .take(3)
      .toList();
    if (badgeKeys.isEmpty) badgeKeys.add(iconKey);
    return FunctionDefinition(
      id: doc.id,
      name: (d['name'] ?? doc.id).toString(),
      iconKey: iconKey,
      badgeKeys: badgeKeys,
      colorValue: d['colorValue'] is num ? (d['colorValue'] as num).toInt() : int.tryParse('${d['colorValue']}') ?? Colors.blueGrey.value,
      permissions: raw is List ? raw.map((e) => e.toString()).toSet() : <String>{},
      active: d['active'] != false,
    );
  }

  Map<String, dynamic> _teamMap(Team t) => {
    'name': t.name,
    'members': t.members,
    'carId': t.carId,
    'financialManagerId': t.financialManagerId,
    'active': t.active,
  };

  Team _teamFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final raw = d['members'];
    return Team(
      id: doc.id,
      name: (d['name'] ?? doc.id).toString(),
      members: raw is List ? raw.map((e) => e.toString()).toList() : <String>[],
      carId: d['carId']?.toString(),
      financialManagerId: d['financialManagerId']?.toString(),
      active: d['active'] != false,
    );
  }

  String? _dateString(DateTime? d) => d?.toIso8601String();

  DateTime? _dateFrom(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    return DateTime.tryParse(value.toString());
  }

  Map<String, dynamic> _carMap(Car c) => {
    'plate': c.plate,
    'makeModel': c.makeModel,
    'active': c.active,
    'rcaUntil': _dateString(c.rcaUntil),
    'itpUntil': _dateString(c.itpUntil),
    'rovinietaUntil': _dateString(c.rovinietaUntil),
    'averageConsumption': c.averageConsumption,
    'fuelPricePerLiter': c.fuelPricePerLiter,
    'fuelType': c.fuelType,
  };

  Car _carFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return Car(
      id: doc.id,
      plate: (d['plate'] ?? '').toString(),
      makeModel: (d['makeModel'] ?? '').toString(),
      active: d['active'] != false,
      rcaUntil: _dateFrom(d['rcaUntil']),
      itpUntil: _dateFrom(d['itpUntil']),
      rovinietaUntil: _dateFrom(d['rovinietaUntil']),
      averageConsumption: (d['averageConsumption'] is num) ? (d['averageConsumption'] as num).toDouble() : 0,
      fuelPricePerLiter: (d['fuelPricePerLiter'] is num) ? (d['fuelPricePerLiter'] as num).toDouble() : 0,
      fuelType: (d['fuelType'] ?? 'Motorină').toString(),
    );
  }

  Map<String, dynamic> _scheduleMap(WorkSchedule s) => {
    'teamId': s.teamId,
    'graphId': s.graphId,
    'graphName': s.graphName,
    'date': Timestamp.fromDate(s.date),
    'active': s.active,
    'closed': s.closed,
    'started': s.started,
    'paused': s.paused,
    'postponed': s.postponed,
    'autoProposed': s.autoProposed,
    'planAlertAt': s.planAlertAt == null ? null : Timestamp.fromDate(s.planAlertAt!),
    'planAlertReason': s.planAlertReason,
    'lastRecalculatedAt': s.lastRecalculatedAt == null ? null : Timestamp.fromDate(s.lastRecalculatedAt!),
    'recalculationCount': s.recalculationCount,
    'learningExplanation': s.learningExplanation,
    'learningConfidence': s.learningConfidence,
    'learningSamples': s.learningSamples,
    'departureName': s.departureName,
    'departureLatitude': s.departureLatitude,
    'departureLongitude': s.departureLongitude,
    'returnName': s.returnName,
    'returnLatitude': s.returnLatitude,
    'returnLongitude': s.returnLongitude,
    'items': s.items.map((i) => {
      'locationId': i.locationId,
      'locationNameSnapshot': i.locationNameSnapshot,
      'addressSnapshot': i.addressSnapshot,
      'typeSnapshot': i.typeSnapshot.name,
      'categoryIdSnapshot': i.categoryIdSnapshot,
      'order': i.order,
      'transferred': i.transferred,
      'facadePlanned': i.facadePlanned,
    }).toList(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  WorkSchedule _scheduleFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final rawItems = d['items'];
    final items = <ScheduleItem>[];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is! Map) continue;
        var type = LocationType.million;
        final typeText = (raw['typeSnapshot'] ?? 'million').toString();
        for (final value in LocationType.values) {
          if (value.name == typeText) type = value;
        }
        items.add(ScheduleItem(
          locationId: (raw['locationId'] ?? '').toString(),
          locationNameSnapshot: (raw['locationNameSnapshot'] ?? '').toString(),
          addressSnapshot: (raw['addressSnapshot'] ?? '').toString(),
          typeSnapshot: type,
          categoryIdSnapshot: (raw['categoryIdSnapshot'] ?? defaultCategoryIdForType(type)).toString(),
          order: raw['order'] is num ? (raw['order'] as num).toInt() : int.tryParse('${raw['order']}') ?? 0,
          transferred: raw['transferred'] == true,
          facadePlanned: raw['facadePlanned'] == true,
        ));
      }
    }
    items.sort((a, b) => a.order.compareTo(b.order));
    return WorkSchedule(
      id: doc.id,
      teamId: (d['teamId'] ?? '').toString(),
      graphId: (d['graphId'] ?? '').toString().trim().isNotEmpty
          ? (d['graphId'] ?? '').toString()
          : 'legacy_${(d['teamId'] ?? '').toString()}_${(_dateFrom(d['date']) ?? DateTime.now()).year}_${(_dateFrom(d['date']) ?? DateTime.now()).month.toString().padLeft(2, '0')}',
      graphName: (d['graphName'] ?? '').toString().trim().isNotEmpty
          ? (d['graphName'] ?? '').toString()
          : graphDefaultName(_dateFrom(d['date']) ?? DateTime.now()),
      date: _dateFrom(d['date']) ?? DateTime.now(),
      items: items,
      active: d['active'] != false,
      closed: d['closed'] == true,
      started: d['started'] == true,
      paused: d['paused'] == true,
      postponed: d['postponed'] == true,
      autoProposed: d['autoProposed'] == true,
      planAlertAt: _dateFrom(d['planAlertAt']),
      planAlertReason: (d['planAlertReason'] ?? '').toString(),
      lastRecalculatedAt: _dateFrom(d['lastRecalculatedAt']),
      recalculationCount: d['recalculationCount'] is num ? (d['recalculationCount'] as num).toInt() : int.tryParse('${d['recalculationCount']}') ?? 0,
      learningExplanation: (d['learningExplanation'] ?? '').toString(),
      learningConfidence: d['learningConfidence'] is num ? (d['learningConfidence'] as num).toDouble() : 0,
      learningSamples: d['learningSamples'] is num ? (d['learningSamples'] as num).toInt() : 0,
      departureName: (d['departureName'] ?? '').toString(),
      departureLatitude: d['departureLatitude'] is num ? (d['departureLatitude'] as num).toDouble() : null,
      departureLongitude: d['departureLongitude'] is num ? (d['departureLongitude'] as num).toDouble() : null,
      returnName: (d['returnName'] ?? '').toString(),
      returnLatitude: d['returnLatitude'] is num ? (d['returnLatitude'] as num).toDouble() : null,
      returnLongitude: d['returnLongitude'] is num ? (d['returnLongitude'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> _recordMap(CentralizerRecord r) => {
    'teamId': r.teamId,
    'locationId': r.locationId,
    'type': r.type.name,
    'locationNameSnapshot': r.locationNameSnapshot,
    'addressSnapshot': r.addressSnapshot,
    'waitingStartedAt': r.waitingStartedAt == null ? null : Timestamp.fromDate(r.waitingStartedAt!),
    'waitingEndedAt': r.waitingEndedAt == null ? null : Timestamp.fromDate(r.waitingEndedAt!),
    'startedAt': r.startedAt == null ? null : Timestamp.fromDate(r.startedAt!),
    'finishedAt': r.finishedAt == null ? null : Timestamp.fromDate(r.finishedAt!),
    'status': r.status.name,
    'refusalReason': r.refusalReason,
    'keptForLearning': r.keptForLearning,
    'facadePlanned': r.facadePlanned,
    'facadeDone': r.facadeDone,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  CentralizerRecord _recordFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    var type = LocationType.million;
    for (final value in LocationType.values) {
      if (value.name == (d['type'] ?? 'million').toString()) type = value;
    }
    var status = WorkAttemptStatus.waitingAccess;
    for (final value in WorkAttemptStatus.values) {
      if (value.name == (d['status'] ?? 'waitingAccess').toString()) status = value;
    }
    return CentralizerRecord(
      id: doc.id,
      teamId: (d['teamId'] ?? '').toString(),
      locationId: (d['locationId'] ?? '').toString(),
      type: type,
      locationNameSnapshot: (d['locationNameSnapshot'] ?? '').toString(),
      addressSnapshot: (d['addressSnapshot'] ?? '').toString(),
      waitingStartedAt: _dateFrom(d['waitingStartedAt']),
      waitingEndedAt: _dateFrom(d['waitingEndedAt']),
      startedAt: _dateFrom(d['startedAt']),
      finishedAt: _dateFrom(d['finishedAt']),
      status: status,
      refusalReason: d['refusalReason']?.toString(),
      keptForLearning: d['keptForLearning'] != false,
      facadePlanned: d['facadePlanned'] == true,
      facadeDone: d['facadeDone'] == true,
    );
  }

  Map<String, dynamic> _notificationMap(AppNotification n) => {
    'userId': n.userId,
    'title': n.title,
    'message': n.message,
    'createdAt': Timestamp.fromDate(n.createdAt),
    'read': n.read,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  AppNotification _notificationFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return AppNotification(
      id: doc.id,
      userId: (d['userId'] ?? '').toString(),
      title: (d['title'] ?? '').toString(),
      message: (d['message'] ?? '').toString(),
      createdAt: _dateFrom(d['createdAt']) ?? DateTime.now(),
      read: d['read'] == true,
    );
  }

  double _doubleFrom(dynamic value, [double fallback = 0]) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Map<String, dynamic> _expenseMap(Expense e) => {
    'teamId': e.teamId,
    'settlementId': e.settlementId,
    'category': e.category,
    'description': e.description,
    'amount': e.amount,
    'date': Timestamp.fromDate(e.date),
    'documentType': e.documentType.name,
    'documentNumber': e.documentNumber,
    'supplier': e.supplier,
    'liters': e.liters,
    'pricePerLiter': e.pricePerLiter,
    'documentImageBase64': e.documentImageBase64,
    'imageFingerprint': e.imageFingerprint,
    'ocrRawText': e.ocrRawText,
    'ocrConfidence': e.ocrConfidence,
    'confirmed': e.confirmed,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  Expense _expenseFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    var docType = ExpenseDocumentType.fiscalReceipt;
    for (final value in ExpenseDocumentType.values) {
      if (value.name == (d['documentType'] ?? '').toString()) docType = value;
    }
    return Expense(
      id: doc.id,
      teamId: (d['teamId'] ?? '').toString(),
      settlementId: d['settlementId']?.toString(),
      category: (d['category'] ?? 'Alte cheltuieli').toString(),
      description: (d['description'] ?? '').toString(),
      amount: _doubleFrom(d['amount']),
      date: _dateFrom(d['date']) ?? DateTime.now(),
      documentType: docType,
      documentNumber: (d['documentNumber'] ?? '').toString(),
      supplier: (d['supplier'] ?? '').toString(),
      liters: d['liters'] == null ? null : _doubleFrom(d['liters']),
      pricePerLiter: d['pricePerLiter'] == null ? null : _doubleFrom(d['pricePerLiter']),
      documentImageBase64: (d['documentImageBase64'] ?? '').toString(),
      imageFingerprint: (d['imageFingerprint'] ?? '').toString(),
      ocrRawText: (d['ocrRawText'] ?? '').toString(),
      ocrConfidence: _doubleFrom(d['ocrConfidence']),
      confirmed: d['confirmed'] != false,
    );
  }

  Map<String, dynamic> _perDiemMap(PerDiemEntry d) => {
    'teamId': d.teamId,
    'settlementId': d.settlementId,
    'memberId': d.memberId,
    'date': Timestamp.fromDate(d.date),
    'amount': d.amount,
    'status': d.status.name,
    'method': d.method?.name,
    'distributedBy': d.distributedBy,
    'distributedAt': d.distributedAt == null ? null : Timestamp.fromDate(d.distributedAt!),
    'confirmedAt': d.confirmedAt == null ? null : Timestamp.fromDate(d.confirmedAt!),
    'received': d.received,
    'actualReceivedAmount': d.actualReceivedAmount,
    'supplementaryFor': d.supplementaryFor,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  PerDiemEntry _perDiemFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    var status = PerDiemStatus.notGranted;
    for (final value in PerDiemStatus.values) {
      if (value.name == (d['status'] ?? '').toString()) status = value;
    }
    PerDiemPaymentMethod? method;
    for (final value in PerDiemPaymentMethod.values) {
      if (value.name == (d['method'] ?? '').toString()) method = value;
    }
    return PerDiemEntry(
      id: doc.id,
      teamId: (d['teamId'] ?? '').toString(),
      settlementId: d['settlementId']?.toString(),
      memberId: (d['memberId'] ?? '').toString(),
      date: _dateFrom(d['date']) ?? DateTime.now(),
      amount: _doubleFrom(d['amount']),
      status: status,
      method: method,
      distributedBy: d['distributedBy']?.toString(),
      distributedAt: _dateFrom(d['distributedAt']),
      confirmedAt: _dateFrom(d['confirmedAt']),
      received: d['received'] is bool ? d['received'] as bool : null,
      actualReceivedAmount: d['actualReceivedAmount'] == null ? null : _doubleFrom(d['actualReceivedAmount']),
      supplementaryFor: d['supplementaryFor']?.toString(),
    );
  }

  Map<String, dynamic> _settlementMap(TravelSettlement s) => {
    'teamId': s.teamId,
    'name': s.name,
    'startDate': Timestamp.fromDate(s.startDate),
    'endDate': s.endDate == null ? null : Timestamp.fromDate(s.endDate!),
    'managerId': s.managerId,
    'receivedDeparture': s.departureTotal,
    'receivedDuring': s.duringTotal,
    if (s.revision != null) ...{
      'revision': s.revision, 'lastOperationId': s.lastOperationId,
      'receivedOpeningDeparture': s.receivedOpeningDeparture,
      'receivedOpeningDuring': s.receivedOpeningDuring,
    },
    'receivedEntries': s.receivedEntries.map((e)=>{
      'id': e.id, 'kind': e.kind, 'amount': e.amount, 'method': e.method, 'fromName': e.fromName, 'date': Timestamp.fromDate(e.date),
    }).toList(),
    'perDiemRate': s.perDiemRate,
    'closed': s.closed,
    'createdAt': Timestamp.fromDate(s.createdAt),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  TravelSettlement _settlementFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final receivedEntries=<ReceivedMoneyEntry>[];
    final rawReceived=d['receivedEntries'];
    if(rawReceived is List){
      for(final raw in rawReceived){
        if(raw is! Map)continue;
        receivedEntries.add(ReceivedMoneyEntry(
          id:(raw['id']??idNow()).toString(),
          kind:(raw['kind']??'during').toString(),
          amount:_doubleFrom(raw['amount']),
          method:(raw['method']??'Cash').toString(),
          fromName:(raw['fromName']??'').toString(),
          date:_dateFrom(raw['date'])??DateTime.now(),
        ));
      }
    }
    return TravelSettlement(
      id: doc.id,
      teamId: (d['teamId'] ?? '').toString(),
      name: (d['name'] ?? 'Deplasare').toString(),
      startDate: _dateFrom(d['startDate']) ?? DateTime.now(),
      endDate: _dateFrom(d['endDate']),
      managerId: d['managerId']?.toString(),
      receivedDeparture: _doubleFrom(d['receivedDeparture']),
      receivedDuring: _doubleFrom(d['receivedDuring']),
      receivedOpeningDeparture: _doubleFrom(d['receivedOpeningDeparture']),
      receivedOpeningDuring: _doubleFrom(d['receivedOpeningDuring']),
      revision: d['revision'] is int ? d['revision'] as int : null,
      lastOperationId: d['lastOperationId'] as String?,
      receivedEntries: receivedEntries,
      perDiemRate: _doubleFrom(d['perDiemRate'], settings.defaultPerDiem),
      closed: d['closed'] == true,
      createdAt: _dateFrom(d['createdAt']),
    );
  }

  Map<String, dynamic> _financeMap(TeamFinance f) => {
    'teamId': f.teamId,
    'managerId': f.managerId,
    'receivedDeparture': f.departureTotal,
    'receivedDuring': f.duringTotal,
    if (f.revision != null) ...{
      'revision': f.revision, 'lastOperationId': f.lastOperationId,
      'receivedOpeningDeparture': f.receivedOpeningDeparture,
      'receivedOpeningDuring': f.receivedOpeningDuring,
    },
    'receivedEntries': f.receivedEntries.map((e)=>{
      'id': e.id, 'kind': e.kind, 'amount': e.amount, 'method': e.method, 'fromName': e.fromName, 'date': Timestamp.fromDate(e.date),
    }).toList(),
    'perDiemRate': f.perDiemRate,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  TeamFinance _financeFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final receivedEntries=<ReceivedMoneyEntry>[];
    final rawReceived=d['receivedEntries'];
    if(rawReceived is List){
      for(final raw in rawReceived){
        if(raw is! Map)continue;
        receivedEntries.add(ReceivedMoneyEntry(
          id:(raw['id']??idNow()).toString(),
          kind:(raw['kind']??'during').toString(),
          amount:_doubleFrom(raw['amount']),
          method:(raw['method']??'Cash').toString(),
          fromName:(raw['fromName']??'').toString(),
          date:_dateFrom(raw['date'])??DateTime.now(),
        ));
      }
    }
    return TeamFinance(
      teamId: doc.id,
      managerId: d['managerId']?.toString(),
      receivedDeparture: _doubleFrom(d['receivedDeparture']),
      receivedDuring: _doubleFrom(d['receivedDuring']),
      receivedOpeningDeparture: _doubleFrom(d['receivedOpeningDeparture']),
      receivedOpeningDuring: _doubleFrom(d['receivedOpeningDuring']),
      revision: d['revision'] is int ? d['revision'] as int : null,
      lastOperationId: d['lastOperationId'] as String?,
      receivedEntries: receivedEntries,
      perDiemRate: _doubleFrom(d['perDiemRate'], settings.defaultPerDiem),
    );
  }

  String _encoded(Map<String, dynamic> value) => jsonEncode(value.map((key, value) {
    if (value is FieldValue) return MapEntry(key, '<serverTimestamp>');
    if (value is Timestamp) return MapEntry(key, value.toDate().toIso8601String());
    if (value is List) {
      return MapEntry(key, value.map((e) {
        if (e is Map) return e.map((k, v) => MapEntry(k.toString(), v is Timestamp ? v.toDate().toIso8601String() : v));
        return e;
      }).toList());
    }
    return MapEntry(key, value);
  }));

}
