import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/admin_api.dart';
import '../data/models.dart';
import '../theme/brand.dart';
import 'common.dart';
import 'image_editor.dart';

/// Elegir una imagen ya subida o subir una nueva. Devuelve la URL pública.
Future<String?> pickMediaUrl(
  BuildContext context, {
  required String folder,
  bool square = false,
  int maxSize = 1600,
  bool png = false,
}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Brand.surface,
      builder: (_) => _MediaPicker(folder: folder, square: square, maxSize: maxSize, png: png),
    );

/// Sube una imagen editada a [folder] con un nombre único y devuelve su URL.
Future<String?> uploadNewImage(BuildContext context, {required String folder, bool square = false, int maxSize = 1600, bool png = false}) async {
  final api = context.read<AdminApi>();
  final edited = await pickAndEditImage(context, square: square, maxSize: maxSize, png: png);
  if (edited == null || !context.mounted) return null;
  final path = '$folder/${DateTime.now().millisecondsSinceEpoch}.${edited.extension}';
  try {
    return await api.uploadMedia(path, edited.bytes, contentType: edited.contentType);
  } on AppException catch (e) {
    if (context.mounted) showMessage(context, e.message, error: true);
    return null;
  }
}

class _MediaPicker extends StatefulWidget {
  const _MediaPicker({required this.folder, required this.square, required this.maxSize, required this.png});

  final String folder;
  final bool square;
  final int maxSize;
  final bool png;

  @override
  State<_MediaPicker> createState() => _MediaPickerState();
}

class _MediaPickerState extends State<_MediaPicker> {
  late final Future<List<MediaFile>> _files = context.read<AdminApi>().listMedia(widget.folder);
  bool _uploading = false;

  Future<void> _upload() async {
    setState(() => _uploading = true);
    final url = await uploadNewImage(context,
        folder: widget.folder, square: widget.square, maxSize: widget.maxSize, png: widget.png);
    if (!mounted) return;
    setState(() => _uploading = false);
    if (url != null) Navigator.pop(context, url);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              onPressed: _uploading ? null : _upload,
              icon: const Icon(Icons.upload),
              label: Text(_uploading ? 'Subiendo…' : 'Subir nueva imagen'),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: AsyncView(
              future: _files,
              builder: (context, files) => files.isEmpty
                  ? const EmptyState(icon: Icons.image_outlined, text: 'Todavía no hay imágenes en esta carpeta')
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemCount: files.length,
                      itemBuilder: (_, i) => InkWell(
                        onTap: () => Navigator.pop(context, files[i].url),
                        borderRadius: BorderRadius.circular(12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(files[i].url, fit: BoxFit.cover),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
