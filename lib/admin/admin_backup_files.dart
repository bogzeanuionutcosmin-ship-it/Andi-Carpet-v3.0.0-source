import 'dart:typed_data';

/// File operations used by the existing Admin backup actions. Selection and
/// byte reading remain separate awaits; cancellation is represented by null.
abstract interface class AdminBackupFiles {
  Future<AdminBackupFile?> pickJson();
  Future<Object?> saveJson({required String fileName, required Uint8List bytes});
}

class AdminBackupFile {
  final String name;
  final Future<Uint8List> Function() _read;
  const AdminBackupFile({required this.name, required Future<Uint8List> Function() readAsBytes}) : _read = readAsBytes;
  Future<Uint8List> readAsBytes() => _read();
}
