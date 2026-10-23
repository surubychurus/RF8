import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/gym_config.dart';
import '../../models/models.dart';
import '../../services/member_controller.dart';
import '../../theme/brand.dart';
import '../../widgets/common.dart';
import '../../widgets/content_widgets.dart';
import '../cuenta/plans_screen.dart';

/// Sección 1: reservar 1 turno por día, hasta N por semana según el plan.
class TurnosScreen extends StatefulWidget {
  const TurnosScreen({super.key});

  @override
  State<TurnosScreen> createState() => _TurnosScreenState();
}

class _TurnosScreenState extends State<TurnosScreen> {
  late DateTime _day = MemberController.today;
  List<SlotAvailability>? _slots;
  String? _error;
  int? _busySlot;

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  List<DateTime> get _days => List.generate(
        GymConfig.bookingWindowDays + 1,
        (i) => MemberController.today.add(Duration(days: i)),
      );

  Future<void> _loadSlots() async {
    setState(() {
      _slots = null;
      _error = null;
    });
    final day = _day;
    try {
      final slots = await context.read<MemberController>().repo.fetchSlots(day);
      if (mounted && day == _day) setState(() => _slots = slots);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _refresh() async {
    final member = context.read<MemberController>();
    await Future.wait([member.refreshBookings(), member.refreshContent(), _loadSlots()]);
  }

  Future<void> _book(SlotAvailability s) async {
    final member = context.read<MemberController>();
    final dateLabel = DateFormat("EEEE d 'de' MMMM", 'es').format(_day);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: Brand.surface,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Confirmar turno', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              Text('${_capitalize(dateLabel)} · ${s.slot.label}', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 4),
              Text('Quedan ${s.remaining} lugares', style: const TextStyle(color: Brand.textSecondary)),
              const SizedBox(height: 24),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reservar')),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busySlot = s.slot.id);
    final done = await runGuarded(context, () => member.book(s.slot.id, _day));
    if (!mounted) return;
    setState(() => _busySlot = null);
    if (done) showMessage(context, '¡Listo! Tu turno quedó reservado 💪');
    _loadSlots();
  }

  Future<void> _cancel(Booking b) async {
    final member = context.read<MemberController>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar turno?'),
        content: Text('Vas a liberar tu lugar de ${b.slot.label}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Volver')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancelar turno')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busySlot = b.slot.id);
    final done = await runGuarded(context, () => member.cancel(b));
    if (!mounted) return;
    setState(() => _busySlot = null);
    if (done) showMessage(context, 'Turno cancelado');
    _loadSlots();
  }

  @override
  Widget build(BuildContext context) {
    final member = context.watch<MemberController>();
    final membership = member.membership;
    final quota = member.weeklyQuota;
    final used = member.usedInWeekOf(_day);
    final mine = member.bookingOn(_day);
    final planActive = membership?.isActiveOn(_day) ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Turnos'), actions: const [NotificationsButton()]),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            const BannerCarousel(),
            const SizedBox(height: 12),
            _PlanSummary(membership: membership, used: used, quota: quota),
            const SizedBox(height: 16),
            SizedBox(
              height: 76,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _days.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final d = _days[i];
                  return _DayChip(
                    day: d,
                    selected: d == _day,
                    hasBooking: member.bookingOn(d) != null,
                    onTap: () {
                      setState(() => _day = d);
                      _loadSlots();
                    },
                  );
                },
              ),
            ),
            SectionTitle(_capitalize(DateFormat("EEEE d 'de' MMMM", 'es').format(_day))),
            if (_error != null)
              _Empty(icon: Icons.wifi_off, text: _error!)
            else if (_slots == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_slots!.isEmpty)
              const _Empty(icon: Icons.event_busy, text: 'El gimnasio no abre este día')
            else
              for (final s in _slots!)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SlotTile(
                    availability: s,
                    day: _day,
                    mine: mine?.slot.id == s.slot.id ? mine : null,
                    busy: _busySlot == s.slot.id,
                    blockReason: _blockReason(
                      planActive: planActive,
                      hasMembership: membership != null,
                      hasBookingToday: mine != null,
                      used: used,
                      quota: quota,
                    ),
                    onBook: () => _book(s),
                    onCancel: _cancel,
                  ),
                ),
            const SizedBox(height: 8),
            Text(
              'Turnos de 1h 30m · ${GymConfig.slotCapacity} personas por turno\n'
              'Horarios: ${GymConfig.openingBlocks.join(' · ')}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Brand.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  String? _blockReason({
    required bool planActive,
    required bool hasMembership,
    required bool hasBookingToday,
    required int used,
    required int? quota,
  }) {
    if (!hasMembership) return 'Sin plan activo';
    if (!planActive) return 'Plan no vigente';
    if (hasBookingToday) return 'Ya tenés turno este día';
    if (quota != null && used >= quota) return 'Cupo semanal completo';
    return null;
  }
}

String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

class _PlanSummary extends StatelessWidget {
  const _PlanSummary({required this.membership, required this.used, required this.quota});

  final Membership? membership;
  final int used;
  final int? quota;

  @override
  Widget build(BuildContext context) {
    final m = membership;
    if (m == null) {
      return Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: const Icon(Icons.info_outline, color: Brand.warning),
          title: const Text('No tenés un plan activo'),
          subtitle: const Text('Acercate a recepción para activarlo. Mirá los planes disponibles.'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlansScreen())),
        ),
      );
    }
    final q = quota ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(m.plan.kind.label,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                Text(
                  'Vence ${DateFormat('dd/MM').format(m.endsOn)}',
                  style: const TextStyle(color: Brand.textSecondary, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 0; i < q; i++)
                  Expanded(
                    child: Container(
                      height: 8,
                      margin: EdgeInsets.only(right: i == q - 1 ? 0 : 6),
                      decoration: BoxDecoration(
                        color: i < used ? Brand.primary : Brand.surfaceHigh,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$used de $q turnos usados esta semana',
              style: const TextStyle(color: Brand.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.day, required this.selected, required this.hasBooking, required this.onTap});

  final DateTime day;
  final bool selected;
  final bool hasBooking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isToday = day == MemberController.today;
    return Material(
      color: selected ? Brand.primary : Brand.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? Brand.primary : Brand.outline),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isToday ? 'HOY' : DateFormat('EEE', 'es').format(day).toUpperCase().replaceAll('.', ''),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white70 : Brand.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text('${day.day}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasBooking ? (selected ? Colors.white : Brand.primary) : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.availability,
    required this.day,
    required this.mine,
    required this.busy,
    required this.blockReason,
    required this.onBook,
    required this.onCancel,
  });

  final SlotAvailability availability;
  final DateTime day;
  final Booking? mine;
  final bool busy;
  final String? blockReason;
  final VoidCallback onBook;
  final void Function(Booking) onCancel;

  @override
  Widget build(BuildContext context) {
    final s = availability;
    final started = !s.slot.startOn(day).isAfter(DateTime.now());
    final fill = s.booked / s.slot.capacity;
    final mine = this.mine;

    Widget action;
    if (busy) {
      action = const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2.5));
    } else if (mine != null) {
      action = mine.status == BookingStatus.attended
          ? const _Tag(text: 'Asististe', color: Brand.success)
          : started
              ? const _Tag(text: 'Tu turno', color: Brand.primary)
              : OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: () => onCancel(mine),
                  child: const Text('Cancelar'),
                );
    } else if (started) {
      action = const _Tag(text: 'Finalizado', color: Brand.textSecondary);
    } else if (s.isFull) {
      action = const _Tag(text: 'Completo', color: Brand.textSecondary);
    } else if (blockReason != null) {
      action = const Icon(Icons.lock_outline, color: Brand.textSecondary);
    } else {
      action = FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
        onPressed: onBook,
        child: const Text('Reservar'),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Brand.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: mine != null ? Brand.primary : Brand.outline, width: mine != null ? 2 : 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.slot.label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fill,
                    minHeight: 6,
                    backgroundColor: Brand.surfaceHigh,
                    color: s.isFull ? Brand.textSecondary : (fill > 0.75 ? Brand.warning : Brand.success),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  s.isFull
                      ? 'Sin lugares'
                      : '${s.remaining} ${s.remaining == 1 ? 'lugar libre' : 'lugares libres'} de ${s.slot.capacity}'
                          '${mine == null && !started && !s.isFull && blockReason != null ? ' · $blockReason' : ''}',
                  style: const TextStyle(color: Brand.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          action,
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
      );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(icon, size: 48, color: Brand.textSecondary),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Brand.textSecondary)),
          ],
        ),
      );
}
