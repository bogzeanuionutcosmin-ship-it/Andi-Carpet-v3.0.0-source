import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_data_models.dart';
import '../models/app_enums_permissions.dart';
import '../models/category_identity.dart' show defaultCategoryIdForType;
import '../utils/date_formatters.dart' show graphDefaultName;

Map<String, dynamic> scheduleDocumentData(
  WorkSchedule schedule, {
  Timestamp? updatedAt,
  String? writeToken,
}) => {
  'teamId': schedule.teamId,
  'graphId': schedule.graphId,
  'graphName': schedule.graphName,
  'date': Timestamp.fromDate(schedule.date),
  'active': schedule.active,
  'closed': schedule.closed,
  'started': schedule.started,
  'paused': schedule.paused,
  'postponed': schedule.postponed,
  'autoProposed': schedule.autoProposed,
  'planAlertAt': schedule.planAlertAt == null ? null : Timestamp.fromDate(schedule.planAlertAt!),
  'planAlertReason': schedule.planAlertReason,
  'lastRecalculatedAt': schedule.lastRecalculatedAt == null ? null : Timestamp.fromDate(schedule.lastRecalculatedAt!),
  'recalculationCount': schedule.recalculationCount,
  'learningExplanation': schedule.learningExplanation,
  'learningConfidence': schedule.learningConfidence,
  'learningSamples': schedule.learningSamples,
  'departureName': schedule.departureName,
  'departureLatitude': schedule.departureLatitude,
  'departureLongitude': schedule.departureLongitude,
  'returnName': schedule.returnName,
  'returnLatitude': schedule.returnLatitude,
  'returnLongitude': schedule.returnLongitude,
  'interventionLocations': {
    for (final item in schedule.items)
      if (item.interventionId.isNotEmpty) item.interventionId: item.locationId,
  },
  'items': schedule.items.map((item) => {
    'interventionId': item.interventionId,
    'locationId': item.locationId,
    'locationNameSnapshot': item.locationNameSnapshot,
    'addressSnapshot': item.addressSnapshot,
    'typeSnapshot': item.typeSnapshot.name,
    'categoryIdSnapshot': item.categoryIdSnapshot,
    'order': item.order,
    'transferred': item.transferred,
    'facadePlanned': item.facadePlanned,
  }).toList(),
  'updatedAt': updatedAt ?? (schedule.updatedAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(schedule.updatedAt!)),
  'writeToken': writeToken ?? schedule.writeToken,
};

WorkSchedule scheduleFromDocumentData(String id, Map<String, dynamic> data) {
  DateTime? dateFrom(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '');
  }

  final date = dateFrom(data['date']) ?? DateTime.now();
  final rawItems = data['items'];
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
        interventionId: (raw['interventionId'] ?? '').toString(),
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
    id: id,
    teamId: (data['teamId'] ?? '').toString(),
    graphId: (data['graphId'] ?? '').toString().trim().isNotEmpty
        ? data['graphId'].toString()
        : 'legacy_${(data['teamId'] ?? '').toString()}_${date.year}_${date.month.toString().padLeft(2, '0')}',
    graphName: (data['graphName'] ?? '').toString().trim().isNotEmpty
        ? data['graphName'].toString()
        : graphDefaultName(date),
    date: date,
    items: items,
    active: data['active'] != false,
    closed: data['closed'] == true,
    started: data['started'] == true,
    paused: data['paused'] == true,
    postponed: data['postponed'] == true,
    autoProposed: data['autoProposed'] == true,
    planAlertAt: dateFrom(data['planAlertAt']),
    planAlertReason: (data['planAlertReason'] ?? '').toString(),
    lastRecalculatedAt: dateFrom(data['lastRecalculatedAt']),
    recalculationCount: data['recalculationCount'] is num ? (data['recalculationCount'] as num).toInt() : int.tryParse('${data['recalculationCount']}') ?? 0,
    learningExplanation: (data['learningExplanation'] ?? '').toString(),
    learningConfidence: data['learningConfidence'] is num ? (data['learningConfidence'] as num).toDouble() : 0,
    learningSamples: data['learningSamples'] is num ? (data['learningSamples'] as num).toInt() : 0,
    departureName: (data['departureName'] ?? '').toString(),
    departureLatitude: data['departureLatitude'] is num ? (data['departureLatitude'] as num).toDouble() : null,
    departureLongitude: data['departureLongitude'] is num ? (data['departureLongitude'] as num).toDouble() : null,
    returnName: (data['returnName'] ?? '').toString(),
    returnLatitude: data['returnLatitude'] is num ? (data['returnLatitude'] as num).toDouble() : null,
    returnLongitude: data['returnLongitude'] is num ? (data['returnLongitude'] as num).toDouble() : null,
    updatedAt: dateFrom(data['updatedAt']),
    writeToken: data['writeToken']?.toString(),
    persisted: true,
  );
}
