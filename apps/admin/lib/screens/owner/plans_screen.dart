import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/admin_api.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';

/// Precios y datos de los planes mensuales.
class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  Future<List<Plan>>? _plans;
  static final _money = NumberFormat.currency(locale: 'es', symbol: r'$', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() => _plans = context.read<AdminApi>().plans());

  Future<void> _edit(Plan p) async {
    final api = context.read<AdminApi>();
    final name = TextEditingController(text: p.name);
    final desc = TextEditingController(text: p.description);
    final price = TextEditingController(text: p.monthlyPrice?.toStringAsFixed(0));
    var active = p.active;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('${p.kindLabel} · ${p.daysPerWeek} ${p.daysPerWeek == 1 ? 'día' : 'días'}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: price,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Precio mensual',
                    prefixText: r'$ ',
                    helperText: 'Vacío = "Precio a definir"',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Nombre')),
                const SizedBox(height: 12),
                TextField(controller: desc, maxLines: 2, decoration: const InputDecoration(labelText: 'Descripción')),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Disponible'),
                  value: active,
                  onChanged: (v) => setLocal(() => active = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final saved = await runGuarded(
      context,
      () => api.updatePlan(
        p.id,
        name: name.text.trim().isEmpty ? p.name : name.text.trim(),
        description: desc.text.trim().isEmpty ? null : desc.text.trim(),
        price: price.text.isEmpty ? null : double.parse(price.text),
        active: active,
      ),
      success: 'Plan actualizado',
    );
    if (saved) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Planes y precios')),
      body: AsyncView(
        future: _plans,
        onRetry: _load,
        builder: (context, plans) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            for (final kind in const ['normal', 'seguimiento']) ...[
              SectionTitle(kind == 'normal' ? 'Rutina normal' : 'Seguimiento'),
              Card(
                child: Column(
                  children: [
                    for (final (i, p) in plans.where((p) => p.kind == kind).indexed) ...[
                      if (i > 0) const Divider(),
                      ListTile(
                        leading: CircleAvatar(child: Text('${p.daysPerWeek}x')),
                        title: Text(p.name),
                        subtitle: Text(p.active ? 'Disponible' : 'No disponible'),
                        trailing: Text(
                          p.monthlyPrice == null ? 'A definir' : _money.format(p.monthlyPrice),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        onTap: () => _edit(p),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
