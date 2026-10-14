part of '../main.dart';

// Abonările financiare existente, mutate fără schimbări de logică.
extension _HomeFinancialSync on _HomePageState {
  void _startFinancialSync() {
    if (!_sessionActive) return;
    final canViewAll = isAdmin || hasPermission(FunctionPermission.viewOtherDecont);
    final scope = canViewAll ? '*' : me.teamId;
    if (_financialTeamScope == scope) return;
    _financialTeamScope = scope;
    for (final sub in _financialSubscriptions) { sub.cancel(); }
    _financialSubscriptions.clear();
    expenses.clear(); perDiems.clear(); finances.clear(); settlements.clear();
    if (scope == null || scope.isEmpty) {
      if (_sessionActive) setState(() {});
      return;
    }
    final db=_syncDb;
    final Query<Map<String,dynamic>> expensesQuery = canViewAll ? db.collection('expenses') : db.collection('expenses').where('teamId',isEqualTo:scope);
    final Query<Map<String,dynamic>> perDiemQuery = canViewAll ? db.collection('perDiems') : db.collection('perDiems').where('teamId',isEqualTo:scope);
    final Query<Map<String,dynamic>> financeQuery = canViewAll ? db.collection('finance') : db.collection('finance').where('teamId',isEqualTo:scope);
    final Query<Map<String,dynamic>> settlementQuery = canViewAll ? db.collection('settlements') : db.collection('settlements').where('teamId',isEqualTo:scope);
    _financialSubscriptions.add(expensesQuery.snapshots().listen((snap){
        if (!_sessionActive) return;
      final list=snap.docs.map(_expenseFromDoc).toList()..sort((a,b)=>a.date.compareTo(b.date));
      if(!_sessionActive)return;setState((){expenses..clear()..addAll(list);});
    },onError:(Object e){if(_sessionActive)setState(()=>coreSyncError='Cheltuieli: $e');}));
    _financialSubscriptions.add(perDiemQuery.snapshots().listen((snap){
        if (!_sessionActive) return;
      final list=snap.docs.map(_perDiemFromDoc).toList()..sort((a,b)=>a.date.compareTo(b.date));
      if(!_sessionActive)return;setState((){perDiems..clear()..addAll(list);});
    },onError:(Object e){if(_sessionActive)setState(()=>coreSyncError='Diurne: $e');}));
    _financialSubscriptions.add(financeQuery.snapshots().listen((snap){
        if (!_sessionActive) return;
      final list=snap.docs.map(_financeFromDoc).toList();
      if(!_sessionActive)return;setState((){finances..clear()..addAll(list);});
    },onError:(Object e){if(_sessionActive)setState(()=>coreSyncError='Financiar: $e');}));
    _financialSubscriptions.add(settlementQuery.snapshots().listen((snap){
        if (!_sessionActive) return;
      final list=snap.docs.map(_settlementFromDoc).toList()..sort((a,b)=>b.startDate.compareTo(a.startDate));
      if(!_sessionActive)return;setState((){settlements..clear()..addAll(list);});
    },onError:(Object e){if(_sessionActive)setState(()=>coreSyncError='Deplasări: $e');}));
  }

}
