import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

Future<void> saveTextFile(String filename, String content) async {
  final bytes = Uint8List.fromList(utf8.encode(content));
  try {
    final uri = await FilePicker.saveFile(
      dialogTitle: 'Export Chaturaji Graph',
      fileName: filename,
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: ['txt'],
      mimeType: 'text/plain',
    );
    if (uri != null) return;
  } catch (_) {}

  saveFileDirect('data/$filename', content);
}

void saveFileDirect(String path, String content) {
  try {
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  } catch (_) {}
}

String? readFileDirect(String path) {
  try {
    final file = File(path);
    if (file.existsSync()) {
      return file.readAsStringSync();
    }
  } catch (_) {}
  return null;
}
