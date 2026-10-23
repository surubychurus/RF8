import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/admin_api.dart';
import '../../data/models.dart';
import '../../theme/brand.dart';
import '../../widgets/common.dart';
import '../../widgets/media_picker.dart';

/// Anuncios del banner superior de la app de socios.
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  List<Announcement>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await context.read<AdminApi>().announcements();
      if (mounted) setState(() => _items = items);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _edit([Announcement? a]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AnnouncementEditor(announcement: a, nextOrder: _items?.length ?? 0)),
    );
    if (saved == true) _load();
  }

  Future<void> _reorder(int from, int to) async {
    final items = [..._items!];
    items.insert(to, items.removeAt(from));
    setState(() => _items = items);
    await runGuarded(context, () => context.read<AdminApi>().reorder('banners', [for (final a in items) a.id!]));
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('Banner superior')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo anuncio'),
      ),
      body: _error != null
          ? Center(child: Text(_error!))
          : items == null
              ? const Center(child: CircularProgressIndicator())
              : items.isEmpty
                  ? const EmptyState(icon: Icons.view_carousel_outlined, text: 'Sin anuncios. Creá el primero.')
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                      itemCount: items.length,
                      onReorderItem: _reorder,
                      header: const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text('Mantené presionado para cambiar el orden.',
                            style: TextStyle(color: Brand.textSecondary)),
                      ),
                      itemBuilder: (_, i) {
                        final a = items[i];
                        return Padding(
                          key: ValueKey(a.id),
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => _edit(a),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (a.imageUrl != null)
                                    AspectRatio(aspectRatio: 16 / 7, child: Image.network(a.imageUrl!, fit: BoxFit.cover)),
                                  ListTile(
                                    title: Text(a.title),
                                    subtitle: a.body == null ? null : Text(a.body!, maxLines: 2, overflow: TextOverflow.ellipsis),
                                    trailing: a.isLive
                                        ? const Tag('Visible', color: Brand.success)
                                        : Tag(a.active ? 'Programado' : 'Oculto'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

class AnnouncementEditor extends StatefulWidget {
  const AnnouncementEditor({super.key, this.announcement, required this.nextOrder});

  final Announcement? announcement;
  final int nextOrder;

  @override
  State<AnnouncementEditor> createState() => _AnnouncementEditorState();
}

class _AnnouncementEditorState extends State<AnnouncementEditor> {
  late final Announcement _a = widget.announcement ??
      Announcement(title: '', sortOrder: widget.nextOrder);
  late final _title = TextEditingController(text: _a.title);
  late final _body = TextEditingController(text: _a.body);
  late final _link = TextEditingController(text: _a.linkUrl);
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final d = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (d == null || !mounted) return null;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial ?? DateTime.now()));
    return DateTime(d.year, d.month, d.day, t?.hour ?? 0, t?.minute ?? 0);
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      showMessage(context, 'Poné un título', error: true);
      return;
    }
    String? opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    _a
      ..title = _title.text.trim()
      ..body = opt(_body)
      ..linkUrl = opt(_link);
    setState(() => _saving = true);
    final ok = await runGuarded(context, () => context.read<AdminApi>().saveAnnouncement(_a), success: 'Anuncio guardado');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final api = context.read<AdminApi>();
    if (!await confirm(context, title: 'Borrar anuncio', message: '¿Borrar "${_a.title}"?', action: 'Borrar', danger: true)) {
      return;
    }
    if (!mounted) return;
    if (await runGuarded(context, () => api.deleteAnnouncement(_a.id!), success: 'Anuncio borrado') && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = DateFormat('dd/MM/yyyy HH:mm');
    return Scaffold(
      appBar: AppBar(
        title: Text(_a.id == null ? 'Nuevo anuncio' : 'Editar anuncio'),
        actions: [
          if (_a.id != null) IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Imagen
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 16 / 7,
              child: Material(
                color: Brand.surface,
                child: InkWell(
                  onTap: () async {
                    final url = await pickMediaUrl(context, folder: 'banner', maxSize: 1600);
                    if (url != null) setState(() => _a.imageUrl = url);
                  },
                  child: _a.imageUrl == null
                      ? const Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.add_photo_alternate_outlined, size: 40),
                            SizedBox(height: 8),
                            Text('Agregar imagen (opcional)'),
                          ]),
                        )
                      : Image.network(_a.imageUrl!, fit: BoxFit.cover),
                ),
              ),
            ),
          ),
          if (_a.imageUrl != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () => setState(() => _a.imageUrl = null), child: const Text('Quitar imagen')),
            ),
          const SizedBox(height: 16),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Título')),
          const SizedBox(height: 12),
          TextField(controller: _body, maxLines: 3, decoration: const InputDecoration(labelText: 'Texto (opcional)')),
          const SizedBox(height: 12),
          TextField(
            controller: _link,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'Enlace al tocar (opcional)', prefixIcon: Icon(Icons.link)),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Visible'),
            value: _a.active,
            onChanged: (v) => setState(() => _a.active = v),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: Text(_a.startsAt == null ? 'Desde: ya' : 'Desde: ${f.format(_a.startsAt!)}'),
            trailing: _a.startsAt == null
                ? null
                : IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _a.startsAt = null)),
            onTap: () async {
              final d = await _pickDateTime(_a.startsAt);
              if (d != null) setState(() => _a.startsAt = d);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_busy),
            title: Text(_a.endsAt == null ? 'Hasta: sin fin' : 'Hasta: ${f.format(_a.endsAt!)}'),
            trailing: _a.endsAt == null
                ? null
                : IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _a.endsAt = null)),
            onTap: () async {
              final d = await _pickDateTime(_a.endsAt);
              if (d != null) setState(() => _a.endsAt = d);
            },
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Guardar')),
        ],
      ),
    );
  }
}
