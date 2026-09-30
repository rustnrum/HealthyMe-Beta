import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/models.dart';
import '../services/photo_service.dart';
import '../state/app_state.dart';
import '../widgets/command_card.dart';

class PhotosScreen extends ConsumerWidget {
  const PhotosScreen({super.key});

  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
  ) async {
    var view = 'Front';
    var source = ImageSource.gallery;

    final proceed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Add progress photo',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Front', label: Text('Front')),
                    ButtonSegment(value: 'Side', label: Text('Side')),
                    ButtonSegment(value: 'Back', label: Text('Back')),
                  ],
                  selected: {view},
                  onSelectionChanged: (values) =>
                      setModalState(() => view = values.first),
                ),
                const SizedBox(height: 14),
                SegmentedButton<ImageSource>(
                  segments: const [
                    ButtonSegment(
                      value: ImageSource.gallery,
                      label: Text('Gallery'),
                      icon: Icon(Icons.photo_library_outlined),
                    ),
                    ButtonSegment(
                      value: ImageSource.camera,
                      label: Text('Camera'),
                      icon: Icon(Icons.camera_alt_outlined),
                    ),
                  ],
                  selected: {source},
                  onSelectionChanged: (values) =>
                      setModalState(() => source = values.first),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Choose photo'),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (proceed != true) return;

    final photo = await PhotoService().pick(source: source, view: view);
    if (photo != null) {
      ref.read(appStateProvider.notifier).addPhoto(photo);
    }
  }

  Future<void> _remove(
    WidgetRef ref,
    ProgressPhoto photo,
  ) async {
    await PhotoService().delete(photo);
    ref.read(appStateProvider.notifier).removePhoto(photo.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = [...ref.watch(appStateProvider).photos]
      ..sort((a, b) => b.date.compareTo(a.date));

    final grouped = <String, List<ProgressPhoto>>{};
    for (final photo in photos) {
      final key =
          '${photo.date.month}/${photo.date.day}/${photo.date.year}';
      grouped.putIfAbsent(key, () => []).add(photo);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Progress Photos',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: () => _add(context, ref),
            icon: const Icon(Icons.add_a_photo_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          if (photos.isEmpty)
            CommandCard(
              child: Column(
                children: [
                  const Icon(Icons.photo_camera_back_outlined, size: 42),
                  const SizedBox(height: 9),
                  const Text(
                    'No progress photos yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Front, side and back photos can show changes that the scale misses.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () => _add(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Add photo'),
                  ),
                ],
              ),
            )
          else
            ...grouped.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 180,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: entry.value.map((photo) {
                          final file = File(photo.path);
                          return Container(
                            width: 126,
                            margin: const EdgeInsets.only(right: 9),
                            child: CommandCard(
                              padding: EdgeInsets.zero,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(20),
                                      ),
                                      child: file.existsSync()
                                          ? Image.file(
                                              file,
                                              fit: BoxFit.cover,
                                            )
                                          : const Center(
                                              child: Icon(
                                                Icons.image_not_supported_outlined,
                                              ),
                                            ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      10,
                                      7,
                                      4,
                                      7,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            photo.view,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () => _remove(ref, photo),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: photos.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _add(context, ref),
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Add'),
            ),
    );
  }
}
