import '../models/app_data_models.dart';

void validateReceivedMoneyState({required double departure,required double during,
    required double perDiemRate,required Iterable<ReceivedMoneyEntry> entries}) {
  for(final amount in [departure,during,perDiemRate,...entries.map((e)=>e.amount)]) {
    if(!amount.isFinite || amount<0 || amount>100000000 ||
        (amount*100-(amount*100).round()).abs()>0.000001) {
      throw ArgumentError('Sumele trebuie să fie finite și să aibă maximum 2 zecimale.');
    }
  }
}

/// Prepare a separate snapshot; a rejected save must not change the displayed
/// balance, received history or the retry baseline owned by the caller.
Future<void> saveReceivedMoneyDraft({required ReceivedMoneyEntry entry,
  TravelSettlement? settlement,TeamFinance? finance,
  required Future<void> Function(TravelSettlement) saveSettlement,
  required Future<void> Function(TeamFinance) saveFinance,
}) async {
  if((settlement==null)==(finance==null))throw ArgumentError('Choose one financial target');
  if(!entry.amount.isFinite || entry.amount<=0 || entry.amount>100000000 ||
      (entry.amount*100-(entry.amount*100).round()).abs()>0.000001 ||
      !['departure','during'].contains(entry.kind) || entry.fromName.trim().isEmpty || entry.id.trim().isEmpty) {
    throw ArgumentError('Invalid received amount');
  }
  final history=settlement?.receivedEntries??finance!.receivedEntries;
  final nextHistory=_mergeReceivedMoneyEntry(history,entry);
  final legacyDeparture=settlement?.receivedDeparture??finance!.receivedDeparture;
  final legacyDuring=settlement?.receivedDuring??finance!.receivedDuring;
  if(history.isEmpty && (legacyDeparture!=0 || legacyDuring!=0)) {
    throw StateError('Sumele vechi fără istoric necesită reconciliere înainte de adăugare.');
  }
  if(settlement!=null){
    final draft=TravelSettlement(id:settlement.id,teamId:settlement.teamId,name:settlement.name,
      startDate:settlement.startDate,endDate:settlement.endDate,managerId:settlement.managerId,
      receivedDeparture:settlement.receivedDeparture,receivedDuring:settlement.receivedDuring,
      receivedEntries:nextHistory,perDiemRate:settlement.perDiemRate,
      closed:settlement.closed,createdAt:settlement.createdAt);
    draft.receivedDeparture=draft.departureTotal;draft.receivedDuring=draft.duringTotal;
    await saveSettlement(draft);
    settlement.receivedEntries=List.of(draft.receivedEntries);
    settlement.receivedDeparture=draft.receivedDeparture;settlement.receivedDuring=draft.receivedDuring;
  }else{
    final target=finance!;
    final draft=TeamFinance(teamId:target.teamId,managerId:target.managerId,
      receivedDeparture:target.receivedDeparture,receivedDuring:target.receivedDuring,
      receivedEntries:nextHistory,perDiemRate:target.perDiemRate);
    draft.receivedDeparture=draft.departureTotal;draft.receivedDuring=draft.duringTotal;
    await saveFinance(draft);
    target.receivedEntries=List.of(draft.receivedEntries);
    target.receivedDeparture=draft.receivedDeparture;target.receivedDuring=draft.receivedDuring;
  }
}

List<ReceivedMoneyEntry> _mergeReceivedMoneyEntry(
    Iterable<ReceivedMoneyEntry> history, ReceivedMoneyEntry incoming) {
  final byId=<String,ReceivedMoneyEntry>{};
  final merged=<ReceivedMoneyEntry>[];
  for(final item in [...history,incoming]) {
    final previous=byId[item.id];
    if(previous!=null) {
      if(!_sameReceivedMoney(previous,item)) {
        throw StateError('ID-ul sumei primite există cu date diferite.');
      }
      continue;
    }
    byId[item.id]=item;
    merged.add(item);
  }
  return merged;
}

bool _sameReceivedMoney(ReceivedMoneyEntry a, ReceivedMoneyEntry b) =>
    a.kind==b.kind && a.amount==b.amount && a.method==b.method &&
    a.fromName==b.fromName && a.date.isAtSameMomentAs(b.date);
