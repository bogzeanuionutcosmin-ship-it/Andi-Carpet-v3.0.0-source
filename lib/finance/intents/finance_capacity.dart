import 'dart:convert';
import 'finance_intent.dart';

// Firestore documented storage-size formula for this protocol's supported
// values only. It is NOT an index/billing/wire-size or retention certificate.
// https://firebase.google.com/docs/firestore/storage-size
const financeDocumentLimitBytes=1024*1024;
int _string(String value)=>utf8.encode(value).length+1;
int _value(Object? value,int depth) {
  if(depth>20)throw const FormatException('finance_document_depth');
  if(value==null || value is bool)return 1;
  if(value is num || value is DateTime || value is FinanceTimestamp)return 8;
  if(value is String)return _string(value);
  if(value is List)return value.fold<int>(0,(sum,item)=>sum+_value(item,depth+1));
  if(value is Map<String,Object?>)return 32+value.entries.fold<int>(0,
    (sum,entry)=>sum+_string(entry.key)+_value(entry.value,depth+1));
  throw const FormatException('finance_document_unsupported_value');
}
int estimateFinanceDocumentBytes(String path,Map<String,Object?> data,
    {bool includesServerUpdate=false}) {
  final parts=path.split('/');
  if(parts.length.isOdd || parts.any((part)=>part.isEmpty))throw const FormatException('finance_document_path');
  final fields=includesServerUpdate ? <String,Object?>{...data,'updatedAt':DateTime.utc(1970)} : data;
  return 16+parts.fold<int>(0,(sum,part)=>sum+_string(part))+_value(fields,0);
}
