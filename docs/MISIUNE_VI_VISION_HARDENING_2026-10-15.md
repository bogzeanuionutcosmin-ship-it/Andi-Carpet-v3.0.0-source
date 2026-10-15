# MISIUNEA VI — Vision/AuthGate hardening

Issue #39. Noua ramură `hardening/vision-authgate-v1-20261015`, din #38 `7a87d1d1d8bd7e1315cefa2d716832baca9c6679`, tree `3304deb0334f8a79205e983a25aeba97ecd2c97c`. Draft TEST/HARDENING DO NOT MERGE; base main numai pentru CI.

## Proveniență / preflight

#28 fd602ed, #29 545e020, #34 d84641b8a0ed719e61d9d48e150889febe673e9a, #35/#36 b2b1314 și main 377f1fd au fost verificate live. Nu exista altă ramură hardening. Checkout #38 curat. Sursele rămân nemodificate. Misiunile III–V nu sunt repetate.

## Lot 1 — coalescing local

Sursa read-only #34 folosește `_draining` și `_requestedRevision`, dar scrie din nou după fiecare flush succesiv fără schimbare și nu drenează un eveniment nou fără alt flush. Implementarea selectivă păstrează un singur Future activ, așteaptă restore, înregistrează snapshotul reușit și include revizia nouă apărută în timpul write. Un snapshot identic salvat nu este rescris; TTL poate produce un snapshot diferit chiar fără nou changed(). Failure same-revision oprește drain-ul; retry numai la flush explicit, fără timer/polling/rețea nouă. Formatul/cheia/statusul sunt păstrate.

Șase probe noi: 1200 flush-uri în spatele read → un snapshot; write blocat +1200 cereri → două snapshoturi; eveniment în timpul write fără alt flush → inclus; failure/retry aceeași revizie; TTL fără changed; late failure + revizie nouă → recovery final. Testele existente păstrează encode throw, read failure, pending/saved, restore merge și serializarea.

Înainte: fiecare apel flush al sursei #38 adaugă `.then` și o scriere (1200 apeluri → 1200 operații, concluzie statică, nu benchmark pe hardware). După: numerele 1/2 sunt asserted în teste deterministe și se raportează executate numai după CI.

Workflow-ul Android existent, neprotejat, acceptă în plus noua ramură izolată. Același entrypoint real, fără upload/install/deploy/config/secrets.

Local 167 Python PASS; Flutter/Dart nu sunt instalate local. CI pe commitul lotului este obligatoriu înainte de următorul lot publicat.

## Reluare

Lot 1 implementat, CI în așteptare. Urmează verificarea CI, apoi lot 2 (presiune jurnal). Loturile 2–10 NEEXECUTATE în acest checkpoint. Hardware/login Firebase/GPS/FCM/cameră/Keystore reale NEEXECUTATE. Fără merge/deploy/APK/web/producție/finanțe/roluri/paid AI.
