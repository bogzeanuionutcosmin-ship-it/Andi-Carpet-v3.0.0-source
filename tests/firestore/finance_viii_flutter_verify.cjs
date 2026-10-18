// Independent raw server verification after Flutter's potentially lossy view.
const fs=require('node:fs');
const assert=require('node:assert/strict');
const {initializeTestEnvironment}=require('@firebase/rules-unit-testing');
const {doc,getDoc}=require('firebase/firestore');
(async()=>{
 if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8080' || process.env.FIREBASE_AUTH_EMULATOR_HOST!=='127.0.0.1:9099')throw Error('local_emulators_required');
 const env=await initializeTestEnvironment({projectId:'demo-andi-carpet',firestore:{rules:fs.readFileSync('firestore.rules','utf8')}});
 try{await env.withSecurityRulesDisabled(async context=>{
  const value=(await getDoc(doc(context.firestore(),'settlements/flutter-nanos'))).data();
  assert.equal(value.revision,2);assert.equal(value.receivedDeparture,225);
  assert.equal(value.receivedEntries.length,2);
  const baseline=JSON.parse(fs.readFileSync('/tmp/andicarpet-viii-timestamp-baseline.json','utf8'));
  // Compare actual server BEFORE/AFTER; the server may canonicalize the seed's
  // nanoseconds before Flutter ever reads it. Never invent pre-existing data.
  for(const [timestamp,expected] of [[value.startDate,baseline.startDate],[value.createdAt,baseline.createdAt],[value.receivedEntries[0].date,baseline.historicalReceipt]]){
   assert.deepEqual([timestamp.seconds,timestamp.nanoseconds],expected);
  }
 });}finally{await env.cleanup();}
 console.log('PASS raw server history timestamps unchanged after Flutter receipt/edit.');
})().catch(()=>{console.error('raw_server_timestamp_verification_failed');process.exitCode=1;});
