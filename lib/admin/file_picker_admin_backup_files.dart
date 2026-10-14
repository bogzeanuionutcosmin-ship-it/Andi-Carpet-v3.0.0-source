import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'admin_backup_files.dart';

/// Stateless default adapter: the same SDK calls and arguments as before.
class FilePickerAdminBackupFiles implements AdminBackupFiles {
  const FilePickerAdminBackupFiles();
  @override
  Future<AdminBackupFile?> pickJson() async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['json']);
    if (file == null) return null;
    return AdminBackupFile(name: file.name, readAsBytes: file.readAsBytes);
  }
  @override
  Future<Object?> saveJson({required String fileName, required Uint8List bytes}) =>
      FilePicker.saveFile(fileName: fileName, bytes: bytes);
}
