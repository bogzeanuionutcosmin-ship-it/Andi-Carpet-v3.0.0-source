// Test-only loopback transport gate. No live endpoint, traffic logging or data
// persistence. Cutting all proxy sockets makes offline independent of SDK flags.
const http=require('node:http');
const {spawn}=require('node:child_process');
if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8080' || process.env.FIREBASE_AUTH_EMULATOR_HOST!=='127.0.0.1:9099')throw Error('local_emulators_required');
const entry=process.argv[2]??'test/finance_flutter_sdk_emulator.browser.dart';
if(!['test/finance_flutter_sdk_emulator.browser.dart','test/finance_ix_sdk.browser.dart','test/finance_xi_sdk.browser.dart'].includes(entry))throw Error('unsupported_browser_entry');
let online=true;
const sockets=new Set();
function track(socket){if(sockets.has(socket))return;sockets.add(socket);socket.once('close',()=>sockets.delete(socket));}
function unavailable(res){if(!res.headersSent)res.writeHead(503,{'Access-Control-Allow-Origin':'*'});res.end();}
const proxy=http.createServer((req,res)=>{
 if(!online){unavailable(res);return;}
 const upstream=http.request({host:'127.0.0.1',port:8080,path:req.url,method:req.method,
  agent:false,headers:{...req.headers,host:'127.0.0.1:8080',connection:'close'}},response=>{
   res.writeHead(response.statusCode,response.headers);response.pipe(res);
  });
 upstream.on('socket',track);upstream.on('error',error=>{
  if(online)console.log(['ECONNRESET','ECONNREFUSED','EPIPE'].includes(error.code)?
   `VIII_PROXY_UPSTREAM_${error.code}`:'VIII_PROXY_UPSTREAM_OTHER');
  unavailable(res);
 });
 req.on('aborted',()=>upstream.destroy());req.pipe(upstream);
});
proxy.on('connection',track);
const control=http.createServer((req,res)=>{
 const headers={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Methods':'POST, OPTIONS',
  'Access-Control-Allow-Headers':'Content-Type'};
 if(req.method==='OPTIONS'){res.writeHead(204,headers);res.end();return;}
 if(req.method!=='POST' || req.url!=='/network'){res.writeHead(404,headers);res.end();return;}
 let body='';req.on('data',chunk=>{body+=chunk;if(body.length>16)req.destroy();});
 req.on('end',()=>{
  if(!['offline','online'].includes(body)){res.writeHead(400,headers);res.end();return;}
  online=body==='online';
  if(!online)for(const socket of sockets)socket.destroy();
  res.writeHead(200,headers);res.end(online?'online':'offline');
 });
});
function listen(server,port){return new Promise((resolve,reject)=>{
 server.once('error',reject);server.listen(port,'127.0.0.1',resolve);
});}
(async()=>{
 try {
  await listen(proxy,8081);await listen(control,8082);
  console.log('VIII local browser transport gate ready.');
  const code=await new Promise((resolve,reject)=>{
   const child=spawn('flutter',['test','--platform','chrome',entry,'--reporter','expanded'],{stdio:'inherit'});
   child.on('error',reject);child.on('exit',code=>resolve(code??1));
  });
  process.exitCode=code;
 } finally {
  for(const socket of sockets)socket.destroy();
  await Promise.all([proxy,control].map(server=>new Promise(resolve=>server.close(resolve))));
 }
})().catch(()=>{console.error('local_browser_transport_gate_failed');process.exitCode=1;});
