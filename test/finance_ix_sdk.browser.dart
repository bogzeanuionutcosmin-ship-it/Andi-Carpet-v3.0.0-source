// Genuine secure-storage web plugin + Auth/Firestore demo SDK. Isolated CI only.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_web/flutter_secure_storage_web.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:andi_carpeta/finance/intents/finance_checked_journal.dart';
import 'package:andi_carpeta/finance/intents/finance_secure_journal.dart';
import 'package:andi_carpeta/finance/intents/finance_journal.dart';
import 'package:andi_carpeta/finance/intents/finance_repository.dart';
import 'package:andi_carpeta/finance/intents/firestore_finance_port.dart';
import 'finance_flutter_sdk_emulator.browser.dart' as viii;

void main(){
  // Retain all VIII SDK/raw timestamp controls without duplicating their code.
  viii.main();
  FlutterSecureStorageWeb.registerWith(webPluginRegistrar);
  late FirebaseApp app;late FirebaseAuth auth;late FirebaseFirestore db;late String uid;
  const secure=FlutterSecureStorage(
    aOptions:AndroidOptions(resetOnError:false,migrateOnAlgorithmChange:false),
    webOptions:WebOptions(useSessionStorage:false));
  FinanceCheckedJournalStorage storage(bool Function() owner)=>
    FinanceCheckedJournalStorage.singleWriterCandidate(
      storage:const FinanceSecureJournalStorage(secure),ownerUid:uid,sessionIsCurrent:owner);
  setUpAll(()async{
    app=await Firebase.initializeApp(name:'ix-secure-storage',options:const FirebaseOptions(
      apiKey:'synthetic-emulator-key',appId:'1:123:web:ix',messagingSenderId:'123',projectId:'demo-andi-carpet'));
    auth=FirebaseAuth.instanceFor(app:app);
    await auth.useAuthEmulator('127.0.0.1',9099,automaticHostMapping:false);
    await auth.setPersistence(Persistence.NONE);
    db=FirebaseFirestore.instanceFor(app:app);db.settings=const Settings(persistenceEnabled:false);
    FirestoreFinanceAtomicPort.emulator(firestore:db);
    await auth.signInWithEmailAndPassword(email:'viii-a@example.test',password:'SyntheticEmulatorOnly123!');
    uid=auth.currentUser!.uid;
  });
  tearDownAll(()async{await auth.signOut();await app.delete();});
  testWidgets('IX genuine secure plugin survives adapter recreation after committed receipt lost ack',(t)async{
    var oldCurrent=true,firstClosed=false;
    final observed=viii.ObservedPort(FirestoreFinanceAtomicPort.emulator(firestore:db));
    final firstStorage=storage(()=>oldCurrent&&auth.currentUser?.uid==uid);
    final first=viii.SdkExpenseUi(uid,observed,()=>oldCurrent&&auth.currentUser?.uid==uid,storage:firstStorage);
    await first.fixture.mount(t);
    try{
      await first.create(t);observed.loseAcknowledgement=true;
      await first.receipt(t);
      await first.wait(t,()=>first.adapter.pendingCodes.values.contains('finance_result_uncertain'));
      final original=(await t.runAsync(()=>first.scope.coordinator.journal.pending()))!.single;
      expect(observed.atomicCalls,2);final reads=observed.serverReads;
      final durable=await t.runAsync(()=>secure.read(key:'finance_intents_v1_$uid'));
      expect(durable,isNotNull);
      await first.close(t);firstClosed=true;oldCurrent=false;firstStorage.dispose();
      observed.loseAcknowledgement=false;
      final secondStorage=storage(()=>auth.currentUser?.uid==uid);
      final second=viii.SdkExpenseUi(uid,observed,()=>auth.currentUser?.uid==uid,storage:secondStorage);
      try{
        await second.fixture.mount(t);
        expect(observed.atomicCalls,2);expect(observed.serverReads,reads);
        await t.tap(find.text('Verifică operațiile în așteptare'));await t.pump();
        await second.wait(t,()=>second.adapter.pendingCodes.isNotEmpty);
        final recovered=(await t.runAsync(()=>second.scope.coordinator.journal.pending()))!.single;
        expect(recovered.encode(),original.encode());
        await t.tap(find.text('Verifică salvarea'));await t.pump();
        await second.wait(t,()=>second.adapter.pendingCodes.isEmpty);
        expect(observed.atomicCalls,2);expect(observed.serverReads,reads+2);
        expect(second.fixture.settlementOverride!.receivedEntries,hasLength(1));
        expect(second.fixture.settlementOverride!.receivedDeparture,200);
        expect(second.fixture.settlementOverride!.revision,2);
        expect(second.fixture.logs,isEmpty); // No success audit for disposed dialog.
        expect(await t.runAsync(()=>second.scope.coordinator.journal.pending()),isEmpty);
      }finally{await second.close(t);secondStorage.dispose();}
    }finally{if(!firstClosed)await first.close(t);firstStorage.dispose();}
  });
  test('IX genuine plugin corruption is retained and blocks journal recovery',()async{
    final key='finance_intents_v1_$uid',before=await secure.read(key:'finance_intents_v1_$uid');
    expect(before,isNotNull);
    await secure.write(key:key,value:'synthetic-torn-envelope');
    try{
      final checked=storage(()=>auth.currentUser?.uid==uid);
      final journal=FinanceIntentJournal(storage:checked,ownerUid:uid,sessionIsCurrent:()=>true);
      await expectLater(journal.pending(),throwsA(isA<FinanceRefusal>()));
      expect(await secure.read(key:key),'synthetic-torn-envelope');checked.dispose();
    }finally{await secure.write(key:key,value:before!);}
  });
}
