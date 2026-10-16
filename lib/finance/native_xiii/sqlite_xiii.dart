// Minimal reviewed C-ABI boundary. No new pubspec dependency or shell/SQL process.
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import '../intents/finance_repository.dart';

typedef _OpenC = Int32 Function(Pointer<Uint8>, Pointer<Pointer<Void>>, Int32, Pointer<Uint8>);
typedef _OpenD = int Function(Pointer<Uint8>, Pointer<Pointer<Void>>, int, Pointer<Uint8>);
typedef _OneC = Int32 Function(Pointer<Void>);
typedef _OneD = int Function(Pointer<Void>);
typedef _PrepareC = Int32 Function(Pointer<Void>, Pointer<Uint8>, Int32, Pointer<Pointer<Void>>, Pointer<Pointer<Uint8>>);
typedef _PrepareD = int Function(Pointer<Void>, Pointer<Uint8>, int, Pointer<Pointer<Void>>, Pointer<Pointer<Uint8>>);
typedef _BindC = Int32 Function(Pointer<Void>, Int32, Pointer<Uint8>, Int32, Pointer<Void>);
typedef _BindD = int Function(Pointer<Void>, int, Pointer<Uint8>, int, Pointer<Void>);
typedef _ColumnC = Int32 Function(Pointer<Void>, Int32);
typedef _ColumnD = int Function(Pointer<Void>, int);
typedef _IntC = Int64 Function(Pointer<Void>, Int32);
typedef _IntD = int Function(Pointer<Void>, int);
typedef _TextC = Pointer<Uint8> Function(Pointer<Void>, Int32);
typedef _TextD = Pointer<Uint8> Function(Pointer<Void>, int);

class SqliteXiii {
  late final DynamicLibrary _lib;
  late final Pointer<Void> _db;
  late final _OpenD _open;
  late final _OneD _close, _step, _finalize, _count;
  late final _PrepareD _prepare;
  late final _BindD _bind;
  late final _ColumnD _type, _bytes;
  late final _IntD _int;
  late final _TextD _text;
  late final Pointer<Void> Function(int) _malloc;
  late final void Function(Pointer<Void>) _free;
  late final int version;
  bool _closed = false;
  SqliteXiii(String path) {
    if (!File(path).isAbsolute || path.contains('\u0000')) throw const FinanceRefusal('native_v2_invalid_path');
    try {
      // No arbitrary library path injection. Android private system sqlite is
      // deliberately NOT assumed to be a supported public NDK API.
      if (Platform.isLinux) { _lib=DynamicLibrary.open('libsqlite3.so.0'); }
      else if (Platform.isWindows) { _lib=DynamicLibrary.open('winsqlite3.dll'); }
      else if (Platform.isMacOS || Platform.isIOS) { _lib=DynamicLibrary.open('/usr/lib/libsqlite3.dylib'); }
      else { throw const FinanceRefusal('native_v2_sqlite_platform_blocked'); }
      _open=_lib.lookupFunction<_OpenC,_OpenD>('sqlite3_open_v2');
      _close=_lib.lookupFunction<_OneC,_OneD>('sqlite3_close_v2');
      _step=_lib.lookupFunction<_OneC,_OneD>('sqlite3_step');
      _finalize=_lib.lookupFunction<_OneC,_OneD>('sqlite3_finalize');
      _count=_lib.lookupFunction<_OneC,_OneD>('sqlite3_column_count');
      _prepare=_lib.lookupFunction<_PrepareC,_PrepareD>('sqlite3_prepare_v2');
      _bind=_lib.lookupFunction<_BindC,_BindD>('sqlite3_bind_text');
      _type=_lib.lookupFunction<_ColumnC,_ColumnD>('sqlite3_column_type');
      _bytes=_lib.lookupFunction<_ColumnC,_ColumnD>('sqlite3_column_bytes');
      _int=_lib.lookupFunction<_IntC,_IntD>('sqlite3_column_int64');
      _text=_lib.lookupFunction<_TextC,_TextD>('sqlite3_column_text');
      _malloc=_lib.lookupFunction<Pointer<Void> Function(Uint64),Pointer<Void> Function(int)>('sqlite3_malloc64');
      _free=_lib.lookupFunction<Void Function(Pointer<Void>),void Function(Pointer<Void>)>('sqlite3_free');
      version=_lib.lookupFunction<Int32 Function(),int Function()>('sqlite3_libversion_number')();
      final threadsafe=_lib.lookupFunction<Int32 Function(),int Function()>('sqlite3_threadsafe')();
      // trusted_schema=OFF is required, with readback; old engines fail closed.
      if (version<3031000 || threadsafe==0) throw const FinanceRefusal('native_v2_sqlite_capability_blocked');
      final name=_string(path);
      Pointer<Pointer<Void>> out=nullptr;
      try {
        out=_allocate(sizeOf<Pointer<Void>>()).cast<Pointer<Void>>();
        out.value=nullptr;
        final result=_open(name,out,0x00010006,nullptr); // RW|CREATE|FULLMUTEX, no URI/custom VFS.
        _db=out.value;
        if(result!=0){if(_db!=nullptr)_close(_db);_error(result);}
        final limit=_lib.lookupFunction<Int32 Function(Pointer<Void>,Int32,Int32),int Function(Pointer<Void>,int,int)>('sqlite3_limit');
        limit(_db,0,512*1024);
        if(limit(_db,0,-1)!=512*1024){_close(_db);throw const FinanceRefusal('native_v2_length_limit_blocked');}
      } finally {_free(name.cast());_free(out.cast());}
    } on FinanceRefusal {rethrow;} catch (_) {throw const FinanceRefusal('native_v2_sqlite_unavailable');}
  }
  Pointer<Void> _allocate(int size){
    final p=_malloc(size);if(p==nullptr)throw const FinanceRefusal('native_v2_out_of_memory');return p;
  }
  Pointer<Uint8> _string(String s){
    final data=utf8.encode(s);final p=_allocate(data.length+1).cast<Uint8>();
    p.asTypedList(data.length+1).setAll(0,[...data,0]);return p;
  }
  Never _error(int code)=>throw FinanceRefusal('native_v2_sqlite_${code & 255}');
  List<List<Object?>> query(String sql,[List<String> values=const []]){
    if(_closed)throw const FinanceRefusal('native_v2_closed');
    if(utf8.encode(sql).length>4096)throw const FinanceRefusal('native_v2_oversized_sql');
    final text=_string(sql);Pointer<Pointer<Void>> out=nullptr;
    Pointer<Void> stmt=nullptr;
    try {
      out=_allocate(sizeOf<Pointer<Void>>()).cast<Pointer<Void>>();
      out.value=nullptr;final rc=_prepare(_db,text,-1,out,nullptr);stmt=out.value;
      if(rc!=0)_error(rc);
      if(stmt==nullptr)throw const FinanceRefusal('native_v2_empty_sql');
      for(var n=0;n<values.length;n++){
        final p=_string(values[n]);
        try {final rc=_bind(stmt,n+1,p,utf8.encode(values[n]).length,Pointer<Void>.fromAddress(-1));if(rc!=0)_error(rc);}
        finally{_free(p.cast());}
      }
      final rows=<List<Object?>>[];
      while(true){
        final rc=_step(stmt);if(rc==101)break;if(rc!=100)_error(rc);
        final row=<Object?>[];
        for(var n=0;n<_count(stmt);n++){
          final t=_type(stmt,n);
          if(t==1){row.add(_int(stmt,n));}
          else if(t==5){row.add(null);}
          else if(t==3){
            final p=_text(stmt,n);if(p==nullptr)throw const FinanceRefusal('native_v2_storage_corrupt');
            final length=_bytes(stmt,n);if(length<0 || length>512*1024)throw const FinanceRefusal('native_v2_oversized_storage');
            row.add(length==0?'':utf8.decode(p.asTypedList(length)));
          }else{throw const FinanceRefusal('native_v2_unexpected_sql_type');}
        }
        rows.add(row);if(rows.length>40)throw const FinanceRefusal('native_v2_oversized_query');
      }
      return rows;
    }finally{
      if(stmt!=nullptr)_finalize(stmt);_free(text.cast());_free(out.cast());
    }
  }
  Object? scalar(String sql)=>query(sql).single.single;
  void close(){if(!_closed){_closed=true;final rc=_close(_db);if(rc!=0)_error(rc);}}
}
