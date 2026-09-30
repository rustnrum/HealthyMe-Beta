import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';

class PhotoService {
  final ImagePicker _picker = ImagePicker();

  Future<ProgressPhoto?> pick({
    required ImageSource source,
    required String view,
  }) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 88,
      maxWidth: 1800,
    );
    if (picked == null) return null;

    final directory = await getApplicationDocumentsDirectory();
    final photoDir = Directory('${directory.path}/progress_photos');
    if (!await photoDir.exists()) {
      await photoDir.create(recursive: true);
    }

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final extension = picked.path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    final target = File('${photoDir.path}/$id.$extension');
    await File(picked.path).copy(target.path);

    return ProgressPhoto(
      id: id,
      path: target.path,
      date: DateTime.now(),
      view: view,
    );
  }

  Future<void> delete(ProgressPhoto photo) async {
    final file = File(photo.path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
