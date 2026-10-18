// Cross-version schedule: a new client commits, then an old APK sends its
// previously captured merge payload. Main is a risk witness, not repaired ACL.
const {test,before,after}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const crypto=require('node:crypto');
const {initializeTestEnvironment,assertFails,assertSucceeds}=require('@firebase/rules-unit-testing');
const {doc,setDoc,getDoc,writeBatch,Timestamp,serverTimestamp}=require('firebase/firestore');
const environments=[];
const main=fs.readFileSync('tests/firestore/fixtures/finance_ix_main.rules','utf8');
const candidate=fs.readFileSync('firestore.rules','utf8');
const stamp=Timestamp.fromDate(new Date('2026-10-16T00:00:00Z'));
before(()=>{
 if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8080')throw Error('local_emulator_required');
 // Snapshot provenance is pinned separately from the candidate rules.
 assert.equal(crypto.createHash('sha256').update(main).digest('hex'),'589fe5eadc06cae665eaa27e9c9df0aea54eea6dffc10994438b4d97c58367da');
});
after(async()=>{for(const env of environments)await env.cleanup();});
for(const strict of [false,true])for(const collection of ['finance','settlements']){
 test(`${strict?'candidate blocks':'main exposes KNOWN UNSAFE'} old merge after new atomic ${collection}`,async()=>{
  const env=await initializeTestEnvironment({projectId:`demo-ix-${strict?'strict':'legacy'}-${collection}`,firestore:{rules:strict?candidate:main}});environments.push(env);
  const target=`${collection}/${collection==='finance'?'team':'trip'}`;
  const legacy={teamId:'team',managerId:'admin',name:'Synthetic compatibility',closed:false,
    startDate:stamp,endDate:null,createdAt:stamp,perDiemRate:50,receivedDeparture:25,
    receivedDuring:10,receivedEntries:[]};
  await env.withSecurityRulesDisabled(async c=>{
   await setDoc(doc(c.firestore(),'users/admin'),{active:true,role:'admin',function:'worker',effectivePermissions:[]});
   await setDoc(doc(c.firestore(),'teams/team'),{members:['admin'],financialManagerId:'admin'});
   await setDoc(doc(c.firestore(),target),legacy);
  });
  const db=env.authenticatedContext('admin').firestore();
  const id='a'.repeat(32),marker=`${target}/financialIntents/${id}`;
  const batch=writeBatch(db);
  batch.set(doc(db,target),{...legacy,receivedDeparture:225,receivedOpeningDeparture:25,
    receivedOpeningDuring:10,receivedEntries:[{id,kind:'departure',amount:200,method:'Cash',
      fromName:'Synthetic',date:stamp}],revision:1,lastOperationId:id,updatedAt:serverTimestamp()});
  batch.set(doc(db,marker),{operationId:id,actorUid:'admin',teamId:'team',targetPath:target,
    baseRevision:0,revision:1,kind:'receipt',digest:'b'.repeat(64),createdAt:serverTimestamp()});
  await assertSucceeds(batch.commit());
  const oldApk=setDoc(doc(db,target),legacy,{merge:true});
  if(strict)await assertFails(oldApk);else await assertSucceeds(oldApk);
  const data=(await getDoc(doc(db,target))).data();
  assert.equal(data.receivedDeparture,strict?225:25);
  assert.equal(data.receivedEntries.length,strict?1:0);
  assert.equal(data.revision,1);assert.equal(data.lastOperationId,id);
  assert.equal((await getDoc(doc(db,marker))).data().revision,1);
 });
}
