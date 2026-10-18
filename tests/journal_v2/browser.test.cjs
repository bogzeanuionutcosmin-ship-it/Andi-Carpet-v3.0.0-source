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

test('tab termination after strict commit before lock release preserves intent and frees lock',async()=>{
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
  await a.close(); // Actual context termination, not claimed as OS/renderer crash.
  // Target close completion need not synchronously release browser lock state.
  await b.waitForFunction(async name=>!(await navigator.locks.query()).held.some(l=>l.name===name),lockName);
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

test('actual browser process SIGKILL and same-profile restart recover committed exact intent',async()=>{
  const {spawn}=require('node:child_process');
  const {mkdtemp,rm}=require('node:fs/promises');const {tmpdir}=require('node:os');
  const profile=await mkdtemp(resolve(tmpdir(),'andi-v2-profile-'));
  let child,remote,diagnostic='';
  async function launch(){
    // Separate actual Chromium browser process, persistent profile, no fake disk.
    child=spawn(process.env.XII_CHROMIUM_EXECUTABLE || chromium.executablePath(),['--headless','--no-sandbox','--disable-dev-shm-usage',
      '--remote-debugging-port=0',`--user-data-dir=${profile}`,'--no-first-run','--no-default-browser-check','--disable-background-networking','--disable-component-update','--disable-sync'],
      {stdio:['ignore','ignore','pipe'],detached:true});
    diagnostic='';child.stderr.on('data',chunk=>{diagnostic=(diagnostic+chunk.toString()).slice(-2000);});
    let port;
    for(let n=0;n<150;n++){
      try {port=Number((await readFile(resolve(profile,'DevToolsActivePort'),'utf8')).split('\n')[0]);
        remote=await chromium.connectOverCDP(`http://127.0.0.1:${port}`,{timeout:1000});break;
      }catch(_){await new Promise(r=>setTimeout(r,100));}
    }
    assert.ok(remote,`browser CDP must start: ${diagnostic}`);
    const p=await remote.contexts()[0].newPage();await p.goto(origin+'/tests/journal_v2/host.html');
    await p.waitForFunction(()=>globalThis.ready);
    await p.evaluate(()=>{globalThis.j=andiCreateFinanceJournalV2({ownerUid:'synthetic',teamId:'team',sessionIsCurrent:()=>true});});
    return p;
  }
  async function kill(){
    const exited=new Promise(resolve=>child.once('exit',resolve));process.kill(-child.pid,'SIGKILL');await exited;
    remote=undefined;
  }
  try{
    const first=await launch();assert.equal((await invoke(first,'prepare',raw(31))).value,true);
    const before=await stored(first);await kill();
    const second=await launch();
    assert.equal(await stored(second),before);assert.deepEqual((await invoke(second,'pending')).value,[raw(31)]);
    assert.deepEqual(await invoke(second,'prepare',raw(31)),{ok:true,value:false});
    await kill();
  }finally{
    if(child && child.exitCode===null && child.signalCode===null){try{process.kill(-child.pid,'SIGKILL');}catch(_){}}
    await rm(profile,{recursive:true,force:true});
  }
});

test('32-intent and UTF8 envelope bounds refuse growth without altering accepted evidence',async()=>{
  await reset();const a=await page();
  for(let n=1;n<=32;n++)assert.equal((await invoke(a,'prepare',raw(n))).value,true);
  const before=await stored(a);assert.equal((await invoke(a,'prepare',raw(33))).code,'journal_v2_full');
  assert.equal(await stored(a),before);
  await reset();const b=await page();let accepted=0,prior;
  for(let n=1;n<=32;n++){
    const data=JSON.parse(raw(n));data.receipt.changes.fromName='漢'.repeat(4000);
    const r=await invoke(b,'prepare',JSON.stringify(data));
    if(!r.ok){assert.equal(r.code,'journal_v2_full');assert.equal(await stored(b),prior);break;}
    accepted++;prior=await stored(b);
  }
  assert.ok(accepted>0 && accepted<32);console.log('Measured UTF8 bound accepted',accepted,'large synthetic receipts before refusal');
});

test('two actual renderer PIDs share the journal lock and cannot overwrite pending',async()=>{
  await reset();const a=await page(),b=await page();
  async function rendererPid(page){
    // Tracing is target-scoped: browser-target metadata has no frame binding.
    // Capture each live page's frame->PID from its own CDP tracing session.
    const trace=await context.newCDPSession(page),events=[];
    const frame=(await trace.send('Page.getFrameTree')).frameTree.frame.id;
    trace.on('Tracing.dataCollected',data=>events.push(...data.value));
    const complete=new Promise(resolve=>trace.once('Tracing.tracingComplete',resolve));
    await trace.send('Tracing.start',{categories:'devtools.timeline,disabled-by-default-devtools.timeline',transferMode:'ReportEvents'});
    await page.evaluate(()=>performance.mark('journal-process-probe'));
    await new Promise(resolve=>setTimeout(resolve,200));
    await trace.send('Tracing.end');await complete;
    const frames=events.flatMap(e=>e.name==='TracingStartedInBrowser'?(e.args?.data?.frames||[]):[]);
    const pid=frames.find(f=>f.frame===frame)?.processId;await trace.detach();
    assert.ok(Number.isInteger(pid),'actual target trace must identify renderer PID');return pid;
  }
  const pa=await rendererPid(a),pb=await rendererPid(b);
  assert.notEqual(pa,pb,'same renderer cannot certify cross-process exclusion');
  console.log('Verified independent renderer PIDs:',pa,pb);
  await a.evaluate(raw=>{
    const digest=crypto.subtle.digest.bind(crypto.subtle);let first=true;
    crypto.subtle.digest=async(...args)=>{
      if(first){first=false;globalThis.readBeforeWrite=true;await new Promise(r=>globalThis.continueWrite=r);}
      return digest(...args);
    };
    globalThis.firstWrite=j.prepare(raw);
  },raw(1));
  await a.waitForFunction(()=>globalThis.readBeforeWrite===true);
  // A has read the old envelope and is validating under its REAL lock.
  // B runs in another measured renderer PID and must not read/overwrite it.
  assert.deepEqual(await invoke(b,'prepare',raw(2)),{ok:false,code:'journal_v2_busy'});
  await a.evaluate(()=>continueWrite());assert.equal(await a.evaluate(()=>firstWrite),true);
  assert.equal((await invoke(b,'prepare',raw(2))).value,true);
  assert.deepEqual(new Set((await invoke(a,'pending')).value),new Set([raw(1),raw(2)]));
});

test('logout during awaited validation retains prior bytes and cannot authorize a write',async()=>{
  await reset();const a=await page();await invoke(a,'prepare',raw(1));const before=await stored(a);
  await a.evaluate(()=>{
    const digest=crypto.subtle.digest.bind(crypto.subtle);globalThis.inDigest=false;
    crypto.subtle.digest=async(...args)=>{globalThis.inDigest=true;await new Promise(r=>globalThis.resume=r);return digest(...args);};
  });
  await a.evaluate(raw=>{globalThis.attempt=j.prepare(raw).catch(e=>e.message);},raw(2));
  await a.waitForFunction(()=>inDigest);await a.evaluate(()=>{current=false;resume();});
  assert.equal(await a.evaluate(()=>attempt),'journal_v2_session_expired');assert.equal(await stored(a),before);
});

test('UID/team namespaces and V1 storage survive V2 operations independently',async()=>{
  await reset();const a=await page();
  await a.evaluate(()=>localStorage.setItem('finance_intents_v1_synthetic','historical V1 evidence'));
  await invoke(a,'prepare',raw(1));
  const other=JSON.parse(raw(2));other.receipt.teamId='other-team';
  await a.evaluate(async raw=>{
    const foreign=andiCreateFinanceJournalV2({ownerUid:'synthetic',teamId:'other-team',sessionIsCurrent:()=>true});
    await foreign.prepare(raw);if((await foreign.pending()).length!==1)throw Error('namespace');foreign.dispose();
  },JSON.stringify(other));
  assert.deepEqual((await invoke(a,'pending')).value,[raw(1)]);
  assert.equal(await a.evaluate(()=>localStorage.getItem('finance_intents_v1_synthetic')),'historical V1 evidence');
});
