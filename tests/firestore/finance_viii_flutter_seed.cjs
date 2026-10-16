// Synthetic fixtures, local demo Auth + Firestore emulators only. Never print tokens.
const fs=require('node:fs');
const {initializeTestEnvironment}=require('@firebase/rules-unit-testing');
const {doc,setDoc,getDoc,Timestamp}=require('firebase/firestore');
(async()=>{
 if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8080' || process.env.FIREBASE_AUTH_EMULATOR_HOST!=='127.0.0.1:9099')throw Error('local_emulators_required');
 const users=[];
 for(const suffix of ['a','b','admin']){
  const response=await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=synthetic-emulator-key',{
   method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:`viii-${suffix}@example.test`,password:'SyntheticEmulatorOnly123!',returnSecureToken:true})});
  if(!response.ok)throw Error('synthetic_auth_fixture_failed');
  const data=await response.json();if(typeof data.localId!=='string')throw Error('synthetic_uid_missing');users.push(data.localId);
 }
 const env=await initializeTestEnvironment({projectId:'demo-andi-carpet',firestore:{rules:fs.readFileSync('firestore.rules','utf8')}});
 try{await env.withSecurityRulesDisabled(async context=>{
  const db=context.firestore();
  for(const uid of users)await setDoc(doc(db,'users',uid),{active:true,role:'member',function:'worker',effectivePermissions:['viewOwnDecont']});
  await setDoc(doc(db,'users',users[2]),{active:true,role:'admin',function:'worker',effectivePermissions:[]});
  await setDoc(doc(db,'teams/flutter-team'),{members:users.slice(0,2),financialManagerId:users[0]});
  for(const target of ['flutter-main','flutter-lost','flutter-race','flutter-owner','flutter-offline'])await setDoc(doc(db,'settlements',target),{teamId:'flutter-team',managerId:users[0],name:'Synthetic SDK trip',closed:false,startDate:Timestamp.fromDate(new Date('2026-10-01T00:00:00Z')),endDate:null,createdAt:Timestamp.fromDate(new Date('2026-10-01T00:00:00Z')),perDiemRate:50,receivedDeparture:25,receivedDuring:10,receivedEntries:[]});
  await setDoc(doc(db,'settlements/flutter-nanos'),{teamId:'flutter-team',managerId:users[0],name:'Exact timestamp fixture',closed:false,startDate:new Timestamp(1790812800,123456789),endDate:null,createdAt:new Timestamp(1790812800,987654321),perDiemRate:50,receivedDeparture:25,receivedDuring:0,receivedEntries:[{id:'historical',kind:'departure',amount:25,method:'Cash',fromName:'Synthetic',date:new Timestamp(1790812800,123456789)}]});
  await setDoc(doc(db,'settlements/flutter-restore'),{teamId:'flutter-team',managerId:users[0],name:'Restore fixture',closed:false,startDate:new Timestamp(1790812800,123456789),endDate:null,createdAt:new Timestamp(1790812800,987654321),perDiemRate:50,receivedDeparture:0,receivedDuring:0,receivedEntries:[]});
  await setDoc(doc(db,'locations/flutter-restore-room'),{name:'Original demo room'});
  const baseline=(await getDoc(doc(db,'settlements/flutter-nanos'))).data();
  const pair=t=>[t.seconds,t.nanoseconds];
  fs.writeFileSync('/tmp/andicarpet-viii-timestamp-baseline.json',JSON.stringify({
   startDate:pair(baseline.startDate),createdAt:pair(baseline.createdAt),
   historicalReceipt:pair(baseline.receivedEntries[0].date)}));
  console.log(baseline.startDate.nanoseconds===123456789?
   'VIII_SERVER_BASELINE_NANOSECOND_PRECISION':'VIII_SERVER_BASELINE_CANONICALIZED_PRECISION');
 });}finally{await env.cleanup();}
 console.log('Synthetic local Auth and Firestore fixtures ready; no live resource used.');
})().catch(()=>{console.error('synthetic_emulator_seed_failed');process.exitCode=1;});
