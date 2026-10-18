import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import '../history/history_xi.dart';
import '../intents/finance_repository.dart';
import 'history_v2_journal.dart';

// Explicit host composition only:
// import {createJournalV2} from <served browser_journal_v2.mjs>;
// globalThis.andiCreateFinanceJournalV2 = createJournalV2;
// Main/Home/AuthGate never load it. Missing module => fail-closed.
@JS('andiCreateFinanceJournalV2')
external _BrowserJournal _create(JSObject options);
extension type _BrowserJournal._(JSObject _) implements JSObject {
  external JSPromise<JSArray<JSString>> pending();
  external JSPromise<JSBoolean> prepare(JSString raw);
  external JSPromise<JSBoolean> confirm(JSString raw);
  external void dispose();
}
HistoryV2Journal createBrowserHistoryV2Journal({required String ownerUid,
  required String teamId, required bool Function() sessionIsCurrent}) {
  final options = JSObject();
  options.setProperty('ownerUid'.toJS, ownerUid.toJS);
  options.setProperty('teamId'.toJS, teamId.toJS);
  options.setProperty('sessionIsCurrent'.toJS, (() => sessionIsCurrent().toJS).toJS);
  return _WebJournal(ownerUid, teamId, _create(options));
}
class _WebJournal implements HistoryV2Journal {
  @override final String ownerUid;
  @override final String teamId;
  final _BrowserJournal _port;
  _WebJournal(this.ownerUid, this.teamId, this._port);
  void _binding(HistoryXiIntent i) {
    if (i.receipt.actorUid != ownerUid || i.receipt.teamId != teamId) {
      throw const FinanceRefusal('journal_v2_scope_mismatch');
    }
  }
  @override Future<List<HistoryXiIntent>> pending() async {
    final raws = (await _port.pending().toDart).toDart;
    return List.unmodifiable(raws.map((raw) {
      final i = HistoryXiIntent.decode(raw.toDart); _binding(i);
      if (i.encode() != raw.toDart) throw const FinanceRefusal('journal_v2_noncanonical');
      return i;
    }));
  }
  @override Future<bool> prepare(HistoryXiIntent i) async {
    _binding(i); return (await _port.prepare(i.encode().toJS).toDart).toDart;
  }
  @override Future<bool> confirm(HistoryXiIntent i) async {
    _binding(i); return (await _port.confirm(i.encode().toJS).toDart).toDart;
  }
  @override void dispose() => _port.dispose();
}
