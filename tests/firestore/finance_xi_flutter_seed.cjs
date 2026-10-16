// Load an additive XI fixture into the SAME local demo used by the existing
// XVIII/IX controls. Production candidate file remains byte-for-byte unchanged.
const fs=require('node:fs');
const {initializeTestEnvironment}=require('@firebase/rules-unit-testing');
const {doc,setDoc,getDoc}=require('firebase/firestore');
let stage='guard';
(async()=>{
 if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8080'||process.env.FIREBASE_AUTH_EMULATOR_HOST!=='127.0.0.1:9099')throw Error('local_emulators_required');
 stage='compose';
 const fragment=fs.readFileSync('tests/firestore/finance_xi.rules','utf8').split('// XI_BEGIN')[1].split('// XI_END')[0];
 let rules=fs.readFileSync('firestore.rules','utf8');
 const excluded="['finance','settlements','expenses']";
 if(!rules.includes(excluded))throw Error('history_fixture_catchall_changed');
 rules=rules.replace(excluded,"['finance','settlements','expenses','financeHistoryXi']");
 rules=rules.replace('function signedIn() {',fragment+'\nfunction signedIn() {');
 stage='rules';
 const env=await initializeTestEnvironment({projectId:'demo-andi-carpet',firestore:{rules}});
 stage='fixtures';
 try{await env.withSecurityRulesDisabled(async c=>{
  const db=c.firestore(),team=(await getDoc(doc(db,'teams/flutter-team'))).data();
  for(const target of ['xi-sdk-main','xi-sdk-race','xi-sdk-revoke','xi-sdk-empty'])
   await setDoc(doc(db,`settlements/${target}`),{teamId:'flutter-team',managerId:team.financialManagerId,
    closed:false,receivedDeparture:0,receivedDuring:0,receivedEntries:[]});
 });}finally{await env.cleanup();}
 console.log('XI synthetic additive rules and empty-source fixtures ready.');
})().catch(error=>{
 if(stage==='rules' && typeof error.message==='string' && error.message.includes('Error compiling rules'))console.error(error.message);
 console.error('history_fixture_failed_'+stage);process.exitCode=1;});
