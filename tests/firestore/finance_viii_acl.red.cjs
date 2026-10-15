// New strict acceptances. Baseline MUST fail; no assertSucceeds for an abuse.
const {test,before,after}=require('node:test');
const fs=require('node:fs');
const {initializeTestEnvironment,assertFails,assertSucceeds}=require('@firebase/rules-unit-testing');
const {doc,setDoc,updateDoc,getDoc}=require('firebase/firestore');
let env;
const db=uid=>env.authenticatedContext(uid).firestore();
before(async()=>{
 env=await initializeTestEnvironment({projectId:'demo-andi-carpet',firestore:{rules:fs.readFileSync('firestore.rules','utf8')}});
 await env.withSecurityRulesDisabled(async c=>{
  const d=c.firestore();
  for(const [uid,data] of Object.entries({admin:{role:'admin'},manager:{},worker:{},outsider:{},director:{function:'director'},inactive:{active:false}}))
   await setDoc(doc(d,'users',uid),{active:true,role:'member',function:'worker',effectivePermissions:['viewOwnDecont','viewOtherDecont'],...data});
  await setDoc(doc(d,'teams','team'),{members:['manager','worker','director','inactive'],financialManagerId:'manager'});
  await setDoc(doc(d,'finance','team'),{teamId:'team',managerId:'manager',receivedDeparture:10,receivedDuring:0,receivedEntries:[],perDiemRate:50});
  await setDoc(doc(d,'settlements','trip'),{teamId:'team',managerId:'manager',closed:true,name:'Trip',receivedDeparture:10,receivedDuring:0,receivedEntries:[]});
  await setDoc(doc(d,'expenses','bill'),{teamId:'team',settlementId:null,createdBy:'manager',amount:50,confirmed:true});
 });
});
after(async()=>{if(env)await env.cleanup();});
test('VIII_RED worker cannot rewrite amount or confirmation',()=>assertFails(updateDoc(doc(db('worker'),'expenses','bill'),{amount:1,confirmed:false})));
test('VIII_RED worker cannot replace finance manager',()=>assertFails(updateDoc(doc(db('worker'),'finance','team'),{managerId:'worker'})));
test('VIII_RED worker cannot reopen settlement',()=>assertFails(updateDoc(doc(db('worker'),'settlements','trip'),{closed:false})));
test('VIII_RED director cannot write own team finance',()=>assertFails(updateDoc(doc(db('director'),'finance','team'),{receivedDeparture:500})));
test('VIII_RED even admin cannot bypass operation evidence on financial update',()=>assertFails(updateDoc(doc(db('admin'),'finance','team'),{receivedDuring:5})));
test('VIII_RED legitimate unconfirmed expense needs no distributedBy',()=>assertSucceeds(setDoc(doc(db('worker'),'expenses','legitimate'),{teamId:'team',settlementId:null,createdBy:'worker',amount:20,confirmed:false})));
test('positive admin may read existing legacy history',()=>assertSucceeds(getDoc(doc(db('admin'),'finance','team'))));
test('positive outsider cannot write another team finance',()=>assertFails(updateDoc(doc(db('outsider'),'finance','team'),{receivedDeparture:5})));
