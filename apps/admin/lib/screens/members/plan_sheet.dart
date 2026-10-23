import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/admin_api.dart';
import '../../data/models.dart';
import '../../theme/brand.dart';
import '../../widgets/common.dart';

/// Asignar, renovar, editar o quitar el plan mensual de un socio.
class PlanSheet extends StatefulWidget {
  const PlanSheet({super.key, required this.member, this.membership});

  final Member member;

  /// null = asignar uno nuevo.
  final Membership? membership;

  @override
  State<PlanSheet> createState() => _PlanSheetState();
}

class _PlanSheetState extends State<PlanSheet> {
  late final Future<List<Plan>> _plans = context.read<AdminApi>().plans(onlyActive: true);
  String? _planId;
  late DateTime _start;
  late DateTime _end;
  bool _saving = false;

  static DateTime _monthAfter(DateTime start) => DateTime(start.year, start.month + 1, start.day - 1);

  @override
  void initState() {
    super.initState();
    final edit = widget.membership;
    if (edit != null) {
      _planId = edit.plan.id;
      _start = edit.startsOn;
      _end = edit.endsOn;
    } else {
      // Renovación: arranca al día siguiente del plan vigente.
      final current = widget.member.currentMembership;
      final today = DateUtils.dateOnly(DateTime.now());
      _planId = current?.plan.id;
      _start = current != null && !current.endsOn.isBefore(today) ? current.endsOn.add(const Duration(days: 1)) : today;
      _end = _monthAfter(_start);
    }
  }

  Future<void> _pick(bool start) async {
    final d = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (d == null) return;
    setState(() {
      if (start) {
        _start = d;
        _end = _monthAfter(d);
      } else {
        _end = d;
      }
    });
  }

  Future<void> _save() async {
    if (_planId == null) return;
    if (_end.isBefore(_start)) {
      showMessage(context, 'La fecha de fin es anterior al inicio', error: true);
      return;
    }
    setState(() => _saving = true);
    final api = context.read<AdminApi>();
    final edit = widget.membership;
    final ok = await runGuarded(
      context,
      () => edit == null
          ? api.assignPlan(widget.member.id, planId: _planId!, startsOn: _start, endsOn: _end)
          : api.updateMembership(edit.id, planId: _planId!, startsOn: _start, endsOn: _end),
      success: 'Plan guardado',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final api = context.read<AdminApi>();
    if (!await confirm(context, title: 'Quitar plan', message: '¿Eliminar este período del plan?', action: 'Quitar', danger: true)) {
      return;
    }
    if (!mounted) return;
    if (await runGuarded(context, () => api.deleteMembership(widget.membership!.id), success: 'Plan quitado') && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = DateFormat('dd/MM/yyyy');
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: FutureBuilder<List<Plan>>(
        future: _plans,
        builder: (context, snap) {
          final plans = snap.data ?? const <Plan>[];
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.membership == null ? 'Asignar plan' : 'Editar plan',
                  style: Theme.of(context).textTheme.titleLarge),
              Text(widget.member.fullName, style: const TextStyle(color: Brand.textSecondary)),
              const SizedBox(height: 16),
              if (!snap.hasData)
                const Center(child: CircularProgressIndicator())
              else
                for (final kind in const ['normal', 'seguimiento']) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 6),
                    child: Text(kind == 'normal' ? 'Rutina normal' : 'Seguimiento',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final p in plans.where((p) => p.kind == kind))
                        ChoiceChip(
                          label: Text('${p.daysPerWeek} ${p.daysPerWeek == 1 ? 'día' : 'días'}'),
                          selected: _planId == p.id,
                          onSelected: (_) => setState(() => _planId = p.id),
                        ),
                    ],
                  ),
                ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(onPressed: () => _pick(true), child: Text('Desde ${f.format(_start)}')),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(onPressed: () => _pick(false), child: Text('Hasta ${f.format(_end)}')),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _saving || _planId == null ? null : _save, child: const Text('Guardar')),
              if (widget.membership != null)
                TextButton(
                  onPressed: _delete,
                  child: const Text('Quitar este plan', style: TextStyle(color: Brand.danger)),
                ),
            ],
          );
        },
      ),
    );
  }
}
