import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../theme/brand.dart';

/// Imagen lista para subir.
class EditedImage {
  const EditedImage(this.bytes, this.contentType, this.extension);

  final Uint8List bytes;
  final String contentType;
  final String extension;
}

class EditOptions {
  const EditOptions({
    this.quarterTurns = 0,
    this.flip = false,
    this.square = false,
    this.maxSize = 1600,
    this.png = false,
    this.quality = 85,
  });

  final int quarterTurns;
  final bool flip;
  final bool square;
  final int maxSize;
  final bool png;
  final int quality;

  EditOptions copyWith({int? quarterTurns, bool? flip, bool? square, int? maxSize, bool? png, int? quality}) =>
      EditOptions(
        quarterTurns: quarterTurns ?? this.quarterTurns,
        flip: flip ?? this.flip,
        square: square ?? this.square,
        maxSize: maxSize ?? this.maxSize,
        png: png ?? this.png,
        quality: quality ?? this.quality,
      );
}

/// Procesa la imagen (en un isolate para no trabar la UI).
Future<EditedImage> processImage(Uint8List source, EditOptions o) =>
    compute(_process, (source, o.quarterTurns, o.flip, o.square, o.maxSize, o.png, o.quality));

EditedImage _process((Uint8List, int, bool, bool, int, bool, int) args) {
  final (bytes, turns, flip, square, maxSize, png, quality) = args;
  var im = img.decodeImage(bytes);
  if (im == null) throw const FormatException('Formato de imagen no soportado');
  im = img.bakeOrientation(im);
  if (turns % 4 != 0) im = img.copyRotate(im, angle: 90 * (turns % 4));
  if (flip) im = img.flipHorizontal(im);
  if (square) {
    final side = im.width < im.height ? im.width : im.height;
    im = img.copyCrop(im, x: (im.width - side) ~/ 2, y: (im.height - side) ~/ 2, width: side, height: side);
  }
  final longest = im.width > im.height ? im.width : im.height;
  if (longest > maxSize) {
    im = im.width >= im.height ? img.copyResize(im, width: maxSize) : img.copyResize(im, height: maxSize);
  }
  return png
      ? EditedImage(img.encodePng(im), 'image/png', 'png')
      : EditedImage(img.encodeJpg(im, quality: quality), 'image/jpeg', 'jpg');
}

/// Elige una imagen de la galería y la abre en el editor.
Future<EditedImage?> pickAndEditImage(BuildContext context, {bool square = false, int maxSize = 1600, bool png = false}) async {
  final file = await ImagePicker().pickImage(source: ImageSource.gallery);
  if (file == null || !context.mounted) return null;
  final bytes = await file.readAsBytes();
  if (!context.mounted) return null;
  return editImage(context, bytes, square: square, maxSize: maxSize, png: png);
}

Future<EditedImage?> editImage(BuildContext context, Uint8List bytes, {bool square = false, int maxSize = 1600, bool png = false}) =>
    Navigator.of(context).push<EditedImage>(MaterialPageRoute(
      builder: (_) => ImageEditorScreen(source: bytes, initial: EditOptions(square: square, maxSize: maxSize, png: png)),
    ));

class ImageEditorScreen extends StatefulWidget {
  const ImageEditorScreen({super.key, required this.source, this.initial = const EditOptions()});

  final Uint8List source;
  final EditOptions initial;

  @override
  State<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends State<ImageEditorScreen> {
  late EditOptions _o = widget.initial;
  EditedImage? _preview;
  String? _error;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _render();
  }

  Future<void> _render() async {
    final gen = ++_gen;
    setState(() => _error = null);
    try {
      final r = await processImage(widget.source, _o);
      if (mounted && gen == _gen) setState(() => _preview = r);
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo procesar la imagen');
    }
  }

  void _update(EditOptions o) {
    _o = o;
    _render();
  }

  @override
  Widget build(BuildContext context) {
    final p = _preview;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar imagen'),
        actions: [
          TextButton(
            onPressed: p == null ? null : () => Navigator.pop(context, p),
            child: const Text('Usar'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Brand.surface, borderRadius: BorderRadius.circular(16)),
              alignment: Alignment.center,
              child: _error != null
                  ? Text(_error!)
                  : p == null
                      ? const CircularProgressIndicator()
                      : Image.memory(p.bytes, fit: BoxFit.contain, gaplessPlayback: true),
            ),
          ),
          if (p != null)
            Text('${(p.bytes.lengthInBytes / 1024).toStringAsFixed(0)} KB · ${p.extension.toUpperCase()}',
                style: const TextStyle(color: Brand.textSecondary)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                IconButton.filledTonal(
                  tooltip: 'Rotar a la izquierda',
                  icon: const Icon(Icons.rotate_left),
                  onPressed: () => _update(_o.copyWith(quarterTurns: _o.quarterTurns + 3)),
                ),
                IconButton.filledTonal(
                  tooltip: 'Rotar a la derecha',
                  icon: const Icon(Icons.rotate_right),
                  onPressed: () => _update(_o.copyWith(quarterTurns: _o.quarterTurns + 1)),
                ),
                IconButton.filledTonal(
                  tooltip: 'Espejar',
                  icon: const Icon(Icons.flip),
                  onPressed: () => _update(_o.copyWith(flip: !_o.flip)),
                ),
                FilterChip(
                  label: const Text('Cuadrada'),
                  selected: _o.square,
                  onSelected: (v) => _update(_o.copyWith(square: v)),
                ),
                FilterChip(
                  label: const Text('PNG'),
                  selected: _o.png,
                  onSelected: (v) => _update(_o.copyWith(png: v)),
                ),
                DropdownButton<int>(
                  value: _o.maxSize,
                  items: const [
                    DropdownMenuItem(value: 512, child: Text('512 px')),
                    DropdownMenuItem(value: 1024, child: Text('1024 px')),
                    DropdownMenuItem(value: 1600, child: Text('1600 px')),
                    DropdownMenuItem(value: 2400, child: Text('2400 px')),
                  ],
                  onChanged: (v) => _update(_o.copyWith(maxSize: v)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
