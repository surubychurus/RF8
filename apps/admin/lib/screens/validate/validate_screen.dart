import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/admin_api.dart';
import '../../data/models.dart';
import '../../theme/brand.dart';
import '../../widgets/common.dart';
import '../members/member_detail_screen.dart';
import 'scanner_screen.dart';

/// Validación de asistencia: escáner + turnos del día.
class ValidateScreen extends StatefulWidget {
  const ValidateScreen({super.key});

  @override
  State<ValidateScreen> createState() => _ValidateScreenState();
}

class _ValidateScreenState extends State<ValidateScreen> {
  DateTime _day = DateUtils.dateOnly(DateTime.now());
  Future<(List<TimeSlot>, List<DayBooking>)>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final api = context.read<AdminApi>();
    setState(() {
      _data = Future.wait([api.slots(), api.bookingsOn(_day)])
          .then((r) => (r[0] as List<TimeSlot>, r[1] as List<DayBooking>));
    });
  }

  bool get _isToday => _day == DateUtils.dateOnly(DateTime.now());

  Future<void> _scan() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScannerScreen()));
    _load();
  }

  Future<void> _manual(DayBooking b) async {
    final api = context.read<AdminApi>();
    if (!await confirm(context,
        title: 'Validar sin QR', message: '¿Registrar la asistencia de ${b.fullName} (${b.slot.label})?', action: 'Validar')) {
      return;
    }
    if (!mounted) return;
    if (await runGuarded(context, () => api.checkInManual(b.id), success: 'Asistencia registrada')) _load();
  }

  Future<void> _pickDay() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now().add(const Duration(days: 14)),
    );
    if (d != null) {
      _day = d;
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Validar turnos'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      floatingActionButton: _isToday
          ? FloatingActionButton.extended(
              onPressed: _scan,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Escanear QR'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => _load(),
        child: AsyncView(
          future: _data,
          onRetry: _load,
          builder: (context, data) {
            final (slots, bookings) = data;
            final present = bookings.where((b) => b.attended).length;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.event),
                    title: Text(_capitalize(DateFormat("EEEE d 'de' MMMM", 'es').format(_day))),
                    subtitle: Text('${bookings.length} reservas · $present presentes'),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: _pickDay,
                  ),
                ),
                if (slots.isEmpty) const EmptyState(icon: Icons.event_busy, text: 'No hay turnos configurados'),
                for (final s in slots) ..._slotSection(s, bookings.where((b) => b.slot.id == s.id).toList()),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _slotSection(TimeSlot s, List<DayBooking> list) {
    final present = list.where((b) => b.attended).length;
    return [
      SectionTitle(
        s.label,
        trailing: Text('${list.length}/${s.capacity} · $present ✓',
            style: const TextStyle(color: Brand.textSecondary, fontSize: 12)),
      ),
      if (list.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('Sin reservas', style: TextStyle(color: Brand.textSecondary)),
        )
      else
        Card(
          child: Column(
            children: [
              for (var i = 0; i < list.length; i++) ...[
                if (i > 0) const Divider(),
                ListTile(
                  leading: Avatar(list[i].fullName, radius: 18),
                  title: Text(list[i].fullName),
                  subtitle: list[i].attended && list[i].checkedInAt != null
                      ? Text('Ingresó ${DateFormat.Hm().format(list[i].checkedInAt!.toLocal())}')
                      : null,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => MemberDetailScreen(memberId: list[i].userId)),
                  ),
                  trailing: list[i].attended
                      ? const Tag('Presente', color: Brand.success)
                      : _isToday
                          ? TextButton(onPressed: () => _manual(list[i]), child: const Text('Validar'))
                          : const Tag('Reservado'),
                ),
              ],
            ],
          ),
        ),
    ];
  }
}

String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
