const {test,before,after}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,setDoc,updateDoc,getDoc}=require('firebase/firestore');
let env;
const db=uid=>env.authenticatedContext(uid).firestore();
before(async()=>{
 env=await initializeTestEnvironment({projectId:'demo-andi-carpet',firestore:{rules:fs.readFileSync('firestore.rules','utf8')}});
 await env.withSecurityRulesDisabled(async c=>{
  const d=c.firestore();
  for(const uid of ['manager','worker','outsider','admin'])await setDoc(doc(d,'users',uid),{active:true,role:uid==='admin'?'admin':'worker',effectivePermissions:['viewOwnDecont']});
  await setDoc(doc(d,'teams/team'),{members:['manager','worker']});
  for(const id of ['replace','worker-replace','ordinary','admin','team-change','outside']){
   await setDoc(doc(d,'teams',id),{members:['manager','worker']});
   await setDoc(doc(d,'finance',id),{teamId:id,managerId:'manager',receivedDuring:0});
  }
  await setDoc(doc(d,'teams/legacy'),{members:['manager']});
  await setDoc(doc(d,'finance/legacy'),{receivedDuring:0});
 });
});
after(async()=>{if(env)await env.cleanup();});
test('manager cannot reassign financial identity; rejected payload changes nothing',async()=>{
 const ref=doc(db('manager'),'finance/replace');
 await assertFails(updateDoc(ref,{managerId:'outsider',receivedDuring:900}));
 const current=(await getDoc(ref)).data();assert.equal(current.managerId,'manager');assert.equal(current.receivedDuring,0);
});
test('another permitted team member cannot replace the manager',async()=>{
 await assertFails(updateDoc(doc(db('worker'),'finance/worker-replace'),{managerId:'worker'}));
});
test('ordinary existing financial update preserves identity and remains compatible',async()=>{
 await assertSucceeds(updateDoc(doc(db('manager'),'finance/ordinary'),{receivedDuring:10}));
});
test('admin may explicitly assign a different manager',async()=>{
 await assertSucceeds(updateDoc(doc(db('admin'),'finance/admin'),{managerId:'worker'}));
});
test('non-admin cannot create a manager assignment',async()=>{
 await assertFails(setDoc(doc(db('worker'),'finance/team'),{teamId:'team',managerId:'worker',receivedDuring:0}));
});
test('legacy missing identity fields remain editable without adding authority',async()=>{
 await assertSucceeds(updateDoc(doc(db('manager'),'finance/legacy'),{receivedDuring:5}));
 await assertFails(updateDoc(doc(db('manager'),'finance/legacy'),{managerId:'manager'}));
});
test('member cannot move the finance identity to another team',async()=>{
 await assertFails(updateDoc(doc(db('manager'),'finance/team-change'),{teamId:'elsewhere'}));
});
test('outsider cannot update team finance',async()=>{
 await assertFails(updateDoc(doc(db('outsider'),'finance/outside'),{receivedDuring:100}));
});
