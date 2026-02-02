import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class AudioImportService {
  Future<String?> pickAndCopyAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav'],
    );

    if (result == null || result.files.single.path == null) return null;

    final sourcePath = result.files.single.path!;
    final appDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory(p.join(appDir.path, 'audio'));
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }

    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${p.basename(sourcePath)}';
    final destPath = p.join(audioDir.path, fileName);
    await File(sourcePath).copy(destPath);

    return destPath;
  }

  String getFileName(String path) {
    return p.basenameWithoutExtension(path);
  }
}
