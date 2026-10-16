import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Photographs are user-selected; no unrelated or invented food illustrations.
/// ImagePicker paths are temporary, so copy into permanent app documents.
class SalusRecipePhotoService {
  const SalusRecipePhotoService();

  Future<String?> chooseAndKeep() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery, maxWidth: 1600, imageQuality: 82,
    );
    if (picked == null) return null;
    final file = File(picked.path);
    if (!await file.exists()) throw StateError('Selected photo could not be opened.');
    final length = await file.length();
    if (length == 0 || length > 12 * 1024 * 1024) {
      throw StateError('Choose a photo smaller than 12 MB.');
    }
    final documents = await getApplicationDocumentsDirectory();
    final folder = Directory('${documents.path}/salus_recipe_photos');
    await folder.create(recursive: true);
    final name = 'meal_${DateTime.now().microsecondsSinceEpoch}.jpg';
    return (await file.copy('${folder.path}/$name')).path;
  }
}

/// Show the actual saved meal photograph or a plainly empty placeholder.
class SalusRecipePhoto extends StatelessWidget {
  final String imagePath;
  final double width;
  final double height;
  const SalusRecipePhoto({super.key, required this.imagePath,
    this.width = 100, this.height = 100});

  @override
  Widget build(BuildContext context) {
    Widget fallback() => const ColoredBox(
      color: Color(0xFF1E2D3A),
      child: Center(child: Icon(Icons.add_a_photo_outlined,
        color: Color(0xFF99AEBB), size: 32)),
    );
    return ClipRRect(borderRadius: BorderRadius.circular(13),
      child: SizedBox(width: width, height: height,
        child: imagePath.trim().isNotEmpty
          ? Image.file(File(imagePath), fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback())
          : fallback()),
    );
  }
}
