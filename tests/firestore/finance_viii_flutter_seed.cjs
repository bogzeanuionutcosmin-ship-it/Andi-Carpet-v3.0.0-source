// Synthetic fixtures, local demo Auth + Firestore emulators only. Never print tokens.
const fs=require('node:fs');
const {initializeTestEnvironment}=require('@firebase/rules-unit-testing');
const {doc,setDoc,Timestamp}=require('firebase/firestore');
(async()=>{
 if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8080' || process.env.FIREBASE_AUTH_EMULATOR_HOST!=='127.0.0.1:9099')throw Error('local_emulators_required');
 const users=[];
 for(const suffix of ['a','b']){
  const response=await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=synthetic-emulator-key',{
   method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:`viii-${suffix}@example.test`,password:'SyntheticEmulatorOnly123!',returnSecureToken:true})});
  if(!response.ok)throw Error('synthetic_auth_fixture_failed');
  const data=await response.json();if(typeof data.localId!=='string')throw Error('synthetic_uid_missing');users.push(data.localId);
 }
 const env=await initializeTestEnvironment({projectId:'demo-andi-carpet',firestore:{rules:fs.readFileSync('firestore.rules','utf8')}});
 try{await env.withSecurityRulesDisabled(async context=>{
  const db=context.firestore();
  for(const uid of users)await setDoc(doc(db,'users',uid),{active:true,role:'member',function:'worker',effectivePermissions:['viewOwnDecont']});
  await setDoc(doc(db,'teams/flutter-team'),{members:users,financialManagerId:users[0]});
  for(const target of ['flutter-main','flutter-lost','flutter-race','flutter-owner'])await setDoc(doc(db,'settlements',target),{teamId:'flutter-team',managerId:users[0],name:'Synthetic SDK trip',closed:false,startDate:Timestamp.fromDate(new Date('2026-10-01T00:00:00Z')),endDate:null,createdAt:Timestamp.fromDate(new Date('2026-10-01T00:00:00Z')),perDiemRate:50,receivedDeparture:25,receivedDuring:10,receivedEntries:[]});
  await setDoc(doc(db,'settlements/flutter-nanos'),{teamId:'flutter-team',managerId:users[0],name:'Exact timestamp fixture',closed:false,startDate:new Timestamp(1790812800,123456789),endDate:null,createdAt:new Timestamp(1790812800,987654321),perDiemRate:50,receivedDeparture:25,receivedDuring:0,receivedEntries:[{id:'historical',kind:'departure',amount:25,method:'Cash',fromName:'Synthetic',date:new Timestamp(1790812800,123456789)}]});
 });}finally{await env.cleanup();}
 console.log('Synthetic local Auth and Firestore fixtures ready; no live resource used.');
})().catch(()=>{console.error('synthetic_emulator_seed_failed');process.exitCode=1;});
