// Real Chromium tabs, worker, IndexedDB and Web Locks; no RAM storage substitute.
const {test, before, after} = require('node:test');
const assert = require('node:assert/strict');
const {createServer} = require('node:http');
const {readFile} = require('node:fs/promises');
const {resolve, extname} = require('node:path');
const {chromium} = require('playwright');
let server, browser, context, origin;
const root = resolve(__dirname, '../..');
const key = JSON.stringify(['history-xi',2,'synthetic','team']);
const lockName = `andi-finance-history-v2/journals/${key}`;
function raw(n, target=`trip-${n}`, amount=200) {
  return JSON.stringify({protocol:2,receipt:{version:1,operationId:n.toString(16).padStart(32,'0'),
    actorUid:'synthetic',teamId:'team',collection:'settlements',documentId:target,baseRevision:0,
    kind:'receipt',changes:{kind:'departure',amount,method:'Cash',fromName:'Synthetic',date:{'@timestamp':[1790812800,123456789]}}}});
}
async function page() {
  const p = await context.newPage(); await p.goto(origin+'/tests/journal_v2/host.html');
  await p.waitForFunction(()=>globalThis.ready);
  await p.evaluate(()=>{globalThis.current=true; globalThis.j=andiCreateFinanceJournalV2({ownerUid:'synthetic',teamId:'team',sessionIsCurrent:()=>globalThis.current});});
  return p;
}
async function invoke(p, action, value) {
  return p.evaluate(async ({action,value})=>{
    try {return {ok:true,value:await j[action](value)};} catch(e){return {ok:false,code:e.message};}
  },{action,value});
}
async function reset() {
  for (const p of context.pages()) await p.close();
  await context.close(); context=await browser.newContext();
}
async function stored(p) {
  return p.evaluate(async key=>{
    const db=await new Promise((yes,no)=>{const q=indexedDB.open('andi-finance-history-v2',1);q.onsuccess=()=>yes(q.result);q.onerror=no;});
    return new Promise((yes,no)=>{const tx=db.transaction('journals');const q=tx.objectStore('journals').get(key);tx.oncomplete=()=>{db.close();yes(q.result);};tx.onabort=no;});
  },key);
}
before(async()=>{
  server=createServer(async(req,res)=>{
    const path=resolve(root,'.'+new URL(req.url,'http://localhost').pathname);
    if(!path.startsWith(root+'/')){res.writeHead(403).end();return;}
    try {res.setHeader('Content-Type',extname(path)==='.mjs'?'text/javascript':'text/html');res.end(await readFile(path));}
    catch(_){res.writeHead(404).end();}
  });
  await new Promise(r=>server.listen(0,'127.0.0.1',r));origin=`http://127.0.0.1:${server.address().port}`;
  browser=await chromium.launch({headless:true,args:['--site-per-process']});context=await browser.newContext();
  console.log('Chromium',browser.version(),'real tabs + dedicated worker; renderer PID allocation is browser-controlled');
});
after(async()=>{await browser?.close();await new Promise(r=>server?.close(r));});

test('exclusive lock covers read/validate/write: another tab fails closed',async()=>{
  await reset();const a=await page(),b=await page();
  await a.evaluate(name=>{globalThis.holding=false;globalThis.hold=navigator.locks.request(name,async()=>{holding=true;await new Promise(r=>globalThis.release=r);});},lockName);
  await a.waitForFunction(()=>holding);
  assert.deepEqual(await invoke(b,'prepare',raw(1)),{ok:false,code:'journal_v2_busy'});
  await a.evaluate(()=>release());await a.evaluate(()=>hold);
  assert.equal((await invoke(b,'prepare',raw(1))).value,true);
});

test('24 independent tab and worker RMW calls retain every distinct intent',async()=>{
  await reset();const a=await page(),b=await page();
  await a.evaluate(()=>{globalThis.worker=new Worker('/tests/journal_v2/worker.mjs',{type:'module'});});
  for(let n=1;n<=24;n+=3){
    const r=await Promise.all([invoke(a,'prepare',raw(n)),invoke(b,'prepare',raw(n+1)),a.evaluate(raw=>new Promise(resolve=>{worker.onmessage=e=>resolve(e.data);worker.postMessage({action:'prepare',raw});}),raw(n+2))]);
    for(let k=0;k<3;k++){
      if(!r[k].ok){assert.equal(r[k].code,'journal_v2_busy');assert.equal((await invoke(b,'prepare',raw(n+k))).value,true);}
    }
  }
  const actual=(await invoke(b,'pending')).value;
  assert.equal(actual.length,24);assert.deepEqual(new Set(actual),new Set(Array.from({length:24},(_,k)=>raw(k+1))));
  assert.equal(JSON.parse(await stored(b)).revision,24);
});

test('same operation across tabs grants one send authorization; target and identity reuse refused',async()=>{
  await reset();const a=await page(),b=await page();
  const values=await Promise.all([invoke(a,'prepare',raw(1)),invoke(b,'prepare',raw(1))]);
  assert.equal(values.filter(v=>v.ok&&v.value===true).length,1);
  assert.deepEqual(await invoke(b,'prepare',raw(1)),{ok:true,value:false});
  assert.equal((await invoke(b,'prepare',raw(1,'trip-1',201))).code,'journal_v2_identity_reuse');
  assert.equal((await invoke(b,'prepare',raw(2,'trip-1'))).code,'journal_v2_unresolved_target');
  assert.equal((await invoke(b,'pending')).value.length,1);
});

test('renderer crash after strict commit before lock release preserves intent and frees lock',async()=>{
  await reset();const a=await page(),b=await page();
  await a.evaluate(()=>{
    const request=navigator.locks.request.bind(navigator.locks);
    navigator.locks.request=(...args)=>{const callback=args.pop();return request(...args,async lock=>{
      const result=await callback(lock);globalThis.committed=true;await new Promise(()=>{});return result;
    });};
  });
  // Wait for the production critical section to finish its strict commit.
  await a.evaluate(raw=>{void j.prepare(raw);},raw(1));
  await a.waitForFunction(()=>globalThis.committed===true);
  const crashed=a.waitForEvent('crash');const cdp=await context.newCDPSession(a);
  void cdp.send('Page.crash').catch(()=>{});await crashed;await a.close();
  assert.deepEqual((await invoke(b,'pending')).value,[raw(1)]);
  assert.deepEqual(await invoke(b,'prepare',raw(1)),{ok:true,value:false});
  assert.equal((await invoke(b,'prepare',raw(2))).value,true);
});

test('worker termination during checksum leaves prior envelope intact and releases lock',async()=>{
  await reset();const a=await page();await invoke(a,'prepare',raw(1));const before=await stored(a);
  await a.evaluate(({raw})=>new Promise(resolve=>{
    const source=`import {createJournalV2} from '${location.origin}/lib/finance/journal_v2/browser_journal_v2.mjs';
      crypto.subtle.digest=async()=>{postMessage('held');await new Promise(()=>{});};
      const j=createJournalV2({ownerUid:'synthetic',teamId:'team',sessionIsCurrent:()=>true});
      void j.prepare(${JSON.stringify(raw)});`;
    globalThis.dying=new Worker(URL.createObjectURL(new Blob([source],{type:'text/javascript'})),{type:'module'});
    dying.onmessage=()=>resolve();
  }),{raw:raw(2)});
  assert.equal((await invoke(a,'prepare',raw(3))).code,'journal_v2_busy');
  await a.evaluate(()=>dying.terminate());
  // Wait for browser-observed release, without stealing or retrying a write.
  await a.waitForFunction(async name=>!(await navigator.locks.query()).held.some(l=>l.name===name),lockName);
  assert.equal(await stored(a),before);assert.equal((await invoke(a,'prepare',raw(3))).value,true);
});

test('aborted IndexedDB transaction cannot authorize send or lose previous intents',async()=>{
  await reset();const a=await page();await invoke(a,'prepare',raw(1));const before=await stored(a);
  await a.evaluate(()=>{
    const put=IDBObjectStore.prototype.put;
    IDBObjectStore.prototype.put=function(...args){const q=put.apply(this,args);this.transaction.abort();return q;};
  });
  assert.equal((await invoke(a,'prepare',raw(2))).ok,false);assert.equal(await stored(a),before);
});

test('missing Web Locks, unsupported strict durability and revoked session fail closed',async()=>{
  await reset();const a=await page();
  await a.evaluate(()=>Object.defineProperty(navigator,'locks',{value:undefined,configurable:true}));
  assert.equal((await invoke(a,'prepare',raw(1))).code,'journal_v2_platform_unavailable');
  const b=await page();
  await b.evaluate(()=>Object.defineProperty(IDBTransaction.prototype,'durability',{get:()=> 'default',configurable:true}));
  assert.equal((await invoke(b,'prepare',raw(1))).code,'journal_v2_durability_unavailable');
  const c=await page();await invoke(c,'prepare',raw(1));
  await c.evaluate(()=>{current=false;});assert.equal((await invoke(c,'pending')).code,'journal_v2_session_expired');
  await c.evaluate(()=>{current=true;});assert.equal((await invoke(c,'prepare',raw(2))).code,'journal_v2_session_expired');
  const d=await page();assert.deepEqual((await invoke(d,'pending')).value,[raw(1)]);
});

test('corrupt envelope and V1 input are retained/refused without reset or import',async()=>{
  await reset();const a=await page();await invoke(a,'prepare',raw(1));
  assert.equal((await invoke(a,'prepare',JSON.stringify({version:1}))).code,'journal_v2_invalid_intent');
  await a.evaluate(async key=>{
    const db=await new Promise(resolve=>{const q=indexedDB.open('andi-finance-history-v2',1);q.onsuccess=()=>resolve(q.result);});
    await new Promise(resolve=>{const tx=db.transaction('journals','readwrite');tx.objectStore('journals').put('corrupt evidence',key);tx.oncomplete=resolve;});db.close();
  },key);
  assert.equal((await invoke(a,'pending')).code,'journal_v2_corrupt');
  assert.equal((await invoke(a,'prepare',raw(2))).code,'journal_v2_corrupt');
  assert.equal(await stored(a),'corrupt evidence');
});

test('confirm and prepare from independent tabs preserve unrelated pending; read has no network',async()=>{
  await reset();const a=await page(),b=await page();await invoke(a,'prepare',raw(1));await invoke(b,'prepare',raw(2));
  let network=0;await context.route('**/*',route=>{network++;return route.abort();});
  const results=await Promise.all([invoke(a,'confirm',raw(1)),invoke(b,'prepare',raw(3))]);
  for(let k=0;k<2;k++)if(!results[k].ok){assert.equal(results[k].code,'journal_v2_busy');await invoke(b,k===0?'confirm':'prepare',raw(k===0?1:3));}
  assert.deepEqual(new Set((await invoke(b,'pending')).value),new Set([raw(2),raw(3)]));assert.equal(network,0);
});
