import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/admin_api.dart';
import '../../data/models.dart';
import '../../theme/brand.dart';
import '../../widgets/common.dart';

/// Enlaces que ven los socios en Mi cuenta (Instagram, WhatsApp, web…).
class LinksScreen extends StatefulWidget {
  const LinksScreen({super.key});

  @override
  State<LinksScreen> createState() => _LinksScreenState();
}

class _LinksScreenState extends State<LinksScreen> {
  List<AppLink>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await context.read<AdminApi>().links();
      if (mounted) setState(() => _items = items);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _edit([AppLink? link]) async {
    final api = context.read<AdminApi>();
    final l = link ?? AppLink(label: '', url: 'https://', sortOrder: _items?.length ?? 0);
    final label = TextEditingController(text: l.label);
    final url = TextEditingController(text: l.url);
    var icon = l.icon;
    var active = l.active;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(link == null ? 'Nuevo enlace' : 'Editar enlace'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: label, decoration: const InputDecoration(labelText: 'Nombre')),
                const SizedBox(height: 12),
                TextField(
                  controller: url,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(labelText: 'URL'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final e in AppLink.icons.entries)
                      ChoiceChip(
                        avatar: Icon(e.value, size: 18),
                        label: Text(e.key),
                        selected: icon == e.key,
                        onSelected: (_) => setLocal(() => icon = e.key),
                      ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Visible'),
                  value: active,
                  onChanged: (v) => setLocal(() => active = v),
                ),
              ],
            ),
          ),
          actions: [
            if (link != null)
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'delete'),
                child: const Text('Borrar', style: TextStyle(color: Brand.danger)),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (!mounted || result == null) return;
    if (result == 'delete') {
      if (await runGuarded(context, () => api.deleteLink(link!.id!), success: 'Enlace borrado')) _load();
      return;
    }
    final u = Uri.tryParse(url.text.trim());
    if (label.text.trim().isEmpty || u == null || !u.hasScheme) {
      showMessage(context, 'Completá nombre y una URL válida', error: true);
      return;
    }
    l
      ..label = label.text.trim()
      ..url = url.text.trim()
      ..icon = icon
      ..active = active;
    if (await runGuarded(context, () => api.saveLink(l), success: 'Enlace guardado')) _load();
  }

  Future<void> _reorder(int from, int to) async {
    final items = [..._items!];
    items.insert(to, items.removeAt(from));
    setState(() => _items = items);
    await runGuarded(context, () => context.read<AdminApi>().reorder('app_links', [for (final l in items) l.id!]));
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('Enlaces')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add_link),
        label: const Text('Nuevo enlace'),
      ),
      body: _error != null
          ? Center(child: Text(_error!))
          : items == null
              ? const Center(child: CircularProgressIndicator())
              : items.isEmpty
                  ? const EmptyState(icon: Icons.link_off, text: 'Sin enlaces')
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                      itemCount: items.length,
                      onReorderItem: _reorder,
                      itemBuilder: (_, i) {
                        final l = items[i];
                        return Padding(
                          key: ValueKey(l.id),
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Card(
                            child: ListTile(
                              leading: Icon(l.iconData),
                              title: Text(l.label),
                              subtitle: Text(l.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                              trailing: l.active ? null : const Tag('Oculto'),
                              onTap: () => _edit(l),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
