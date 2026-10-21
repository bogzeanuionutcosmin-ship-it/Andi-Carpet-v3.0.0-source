import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:andi_carpeta/operations/graph_closure_client.dart';

void main() {
  final operation = {'teamId':'team','graphId':'graph','requestId':'stable-request','days':[{'id':'day','writeToken':'v1'}]};
  final endpoint = Uri.parse('http://localhost:5001/demo/closeProgramGraph');
  test('lost acknowledgement retries identical request ID, body and auth', () async {
    final bodies=<String>[];
    final receipt=await requestGraphClosure(endpoint:endpoint,getIdToken:() async=>'token',operation:operation,
      post:(uri,{headers,body}) async {
        expect(uri,endpoint); expect(headers!['Authorization'],'Bearer token'); bodies.add(body as String);
        if(bodies.length==1) throw TimeoutException('ACK lost after commit');
        return http.Response(jsonEncode({'closed':true,'receiptId':'receipt','replay':true}),200);
      });
    expect(receipt,'receipt'); expect(bodies,hasLength(2)); expect(bodies[0],bodies[1]);
  });
  test('server conflict never falls back or retries', () async {
    var calls=0;
    await expectLater(requestGraphClosure(endpoint:endpoint,getIdToken:() async=>'token',operation:operation,
      post:(_,{headers,body}) async {calls++;return http.Response('{"message":"Grafic modificat"}',409);}),
      throwsA(isA<StateError>()));
    expect(calls,1);
  });
  test('missing auth prevents network writes', () async {
    await expectLater(requestGraphClosure(endpoint:endpoint,getIdToken:() async=>null,operation:operation,
      post:(_,{headers,body}) async {fail('unauthenticated network write');}),throwsA(isA<StateError>()));
  });
  test('malformed or unconfirmed success response cannot confirm STOP', () async {
    for(final responseBody in ['not json','{"closed":false}','{"closed":true}']) {
      await expectLater(requestGraphClosure(endpoint:endpoint,getIdToken:() async=>'token',operation:operation,
        post:(_,{headers,body}) async=>http.Response(responseBody,200)),throwsA(isA<StateError>()));
    }
  });
}
