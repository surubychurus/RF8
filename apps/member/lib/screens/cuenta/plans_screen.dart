import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/gym_config.dart';
import '../../models/models.dart';
import '../../services/member_controller.dart';
import '../../theme/brand.dart';

/// Planes mensuales: rutina normal y seguimiento, de 1 a 4 días por semana.
class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final member = context.watch<MemberController>();
    final currentId = member.membership?.plan.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Planes y precios')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Todos los planes son mensuales. Para contratar o cambiar tu plan, acercate a recepción.',
            style: TextStyle(color: Brand.textSecondary),
          ),
          for (final kind in PlanKind.values) ...[
            const SizedBox(height: 24),
            Text(kind.label, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              kind == PlanKind.normal
                  ? 'Rutina estándar armada por el equipo de RF8.'
                  : 'Rutina con seguimiento y ajustes personalizados.',
              style: const TextStyle(color: Brand.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            for (final plan in member.plans.where((p) => p.kind == kind))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PlanTile(plan: plan, current: plan.id == currentId),
              ),
          ],
        ],
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({required this.plan, required this.current});

  final Plan plan;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final price = plan.monthlyPrice;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Brand.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: current ? Brand.primary : Brand.outline, width: current ? 2 : 1),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Brand.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${plan.daysPerWeek}x',
              style: const TextStyle(color: Brand.primary, fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${plan.daysPerWeek} ${plan.daysPerWeek == 1 ? 'día' : 'días'} por semana',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (current)
                  const Text('Tu plan actual', style: TextStyle(color: Brand.primary, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                // PLACEHOLDER: los precios se cargan en la tabla `plans`.
                price == null
                    ? '${GymConfig.currencySymbol} —'
                    : NumberFormat.currency(locale: 'es', symbol: GymConfig.currencySymbol, decimalDigits: 0)
                        .format(price),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              Text(
                price == null ? 'Precio a definir' : 'por mes',
                style: const TextStyle(color: Brand.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
