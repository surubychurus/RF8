import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/admin_api.dart';
import '../../data/models.dart';
import '../../theme/brand.dart';
import '../../widgets/common.dart';
import '../../widgets/image_editor.dart';
import '../../widgets/media_picker.dart';

/// Biblioteca de imágenes (Supabase Storage, bucket `media`).
class MediaScreen extends StatefulWidget {
  const MediaScreen({super.key});

  @override
  State<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends State<MediaScreen> {
  String _folder = AdminApi.mediaFolders.keys.first;
  Future<List<MediaFile>>? _files;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() => _files = context.read<AdminApi>().listMedia(_folder));

  Future<void> _upload() async {
    final url = await uploadNewImage(context, folder: _folder, square: _folder == 'icons' || _folder == 'logos');
    if (url != null && mounted) {
      showMessage(context, 'Imagen subida');
      _load();
    }
  }

  Future<void> _open(MediaFile f) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Brand.surface,
      builder: (_) => _MediaDetail(file: f),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Imágenes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _upload,
        icon: const Icon(Icons.upload),
        label: const Text('Subir'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final e in AdminApi.mediaFolders.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(e.value),
                      selected: _folder == e.key,
                      onSelected: (_) {
                        _folder = e.key;
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _load(),
              child: AsyncView(
                future: _files,
                onRetry: _load,
                builder: (context, files) => files.isEmpty
                    ? ListView(children: const [EmptyState(icon: Icons.image_outlined, text: 'No hay imágenes en esta carpeta')])
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 160,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemCount: files.length,
                        itemBuilder: (_, i) => InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _open(files[i]),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(files[i].url, fit: BoxFit.cover),
                          ),
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

class _MediaDetail extends StatefulWidget {
  const _MediaDetail({required this.file});

  final MediaFile file;

  @override
  State<_MediaDetail> createState() => _MediaDetailState();
}

class _MediaDetailState extends State<_MediaDetail> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    final ok = await runGuarded(context, action, success: success);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context, true);
  }

  Future<void> _rename() async {
    final f = widget.file;
    final dot = f.name.lastIndexOf('.');
    final ext = dot > 0 ? f.name.substring(dot) : '';
    final ctrl = TextEditingController(text: dot > 0 ? f.name.substring(0, dot) : f.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renombrar'),
        content: TextField(controller: ctrl, autofocus: true, decoration: InputDecoration(suffixText: ext)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    final clean = name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '-');
    final api = context.read<AdminApi>();
    await _run(() => api.renameMedia(f.path, '${f.folder}/$clean$ext'), 'Imagen renombrada');
  }

  /// Reemplaza el archivo manteniendo el nombre (los lugares que lo usan se actualizan).
  Future<void> _replace({required bool editCurrent}) async {
    final f = widget.file;
    final api = context.read<AdminApi>();
    EditedImage? edited;
    final png = f.name.toLowerCase().endsWith('.png');
    if (editCurrent) {
      setState(() => _busy = true);
      try {
        final data = await NetworkAssetBundle(Uri.parse(f.url)).load(f.url);
        if (!mounted) return;
        setState(() => _busy = false);
        edited = await editImage(context, data.buffer.asUint8List(), png: png);
      } catch (_) {
        if (mounted) {
          setState(() => _busy = false);
          showMessage(context, 'No se pudo descargar la imagen', error: true);
        }
        return;
      }
    } else {
      edited = await pickAndEditImage(context, png: png);
    }
    if (edited == null || !mounted) return;
    final result = edited;
    await _run(
      () async => api.uploadMedia(f.path, result.bytes, contentType: result.contentType, upsert: true),
      'Imagen actualizada',
    );
  }

  Future<void> _delete() async {
    final api = context.read<AdminApi>();
    if (!await confirm(context,
        title: 'Borrar imagen',
        message: 'Si se usa en el banner, el logo o un ícono, va a dejar de verse.',
        action: 'Borrar',
        danger: true)) {
      return;
    }
    if (!mounted) return;
    await _run(() => api.deleteMedia(widget.file.path), 'Imagen borrada');
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.file;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: Image.network(f.url, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 12),
            Text(f.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(
              [
                if (f.size != null) '${(f.size! / 1024).toStringAsFixed(0)} KB',
                if (f.updatedAt != null) DateFormat('dd/MM/yyyy HH:mm').format(f.updatedAt!.toLocal()),
              ].join(' · '),
              style: const TextStyle(color: Brand.textSecondary),
            ),
            const SizedBox(height: 12),
            if (_busy) const LinearProgressIndicator(),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copiar enlace'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: f.url.split('?').first));
                showMessage(context, 'Enlace copiado');
              },
            ),
            ListTile(leading: const Icon(Icons.tune), title: const Text('Editar (rotar, recortar, tamaño)'), onTap: _busy ? null : () => _replace(editCurrent: true)),
            ListTile(leading: const Icon(Icons.swap_horiz), title: const Text('Reemplazar por otra'), onTap: _busy ? null : () => _replace(editCurrent: false)),
            ListTile(leading: const Icon(Icons.drive_file_rename_outline), title: const Text('Renombrar'), onTap: _busy ? null : _rename),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Brand.danger),
              title: const Text('Borrar', style: TextStyle(color: Brand.danger)),
              onTap: _busy ? null : _delete,
            ),
          ],
        ),
      ),
    );
  }
}
