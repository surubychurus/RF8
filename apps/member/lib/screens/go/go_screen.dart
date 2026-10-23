import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/models.dart';
import '../../services/member_controller.dart';
import '../../services/qr_token.dart';
import '../../theme/brand.dart';
import '../../widgets/content_widgets.dart';

/// Sección GO: nombre completo, QR de entrada y el turno reservado.
/// El QR lo escanea el staff con la app de administración.
class GoScreen extends StatelessWidget {
  const GoScreen({super.key, required this.onGoToTurnos});

  final VoidCallback onGoToTurnos;

  @override
  Widget build(BuildContext context) {
    final member = context.watch<MemberController>();
    final name = member.profile?.fullName ?? '';
    final today = member.todayBooking;
    final next = member.nextBooking;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => Future.wait([member.refreshBookings(), member.refreshContent()]),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: [
              const Align(alignment: Alignment.centerRight, child: NotificationsButton()),
              const BannerCarousel(),
              const SizedBox(height: 16),
              const Text(
                'GO',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Brand.primary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 32),
              if (today != null && today.status == BookingStatus.attended)
                const _QrPlaceholder(
                  icon: Icons.check_circle,
                  color: Brand.success,
                  text: 'Asistencia registrada.\n¡Buen entrenamiento!',
                )
              else if (today != null && today.endsAt.isAfter(DateTime.now()))
                _LiveQr(booking: today)
              else
                _QrPlaceholder(
                  icon: Icons.qr_code_2,
                  color: Brand.textSecondary,
                  text: today != null ? 'Tu turno de hoy ya terminó' : 'No tenés turno para hoy',
                ),
              const SizedBox(height: 32),
              _BookingInfo(today: today, next: next, onGoToTurnos: onGoToTurnos),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveQr extends StatefulWidget {
  const _LiveQr({required this.booking});

  final Booking booking;

  @override
  State<_LiveQr> createState() => _LiveQrState();
}

class _LiveQrState extends State<_LiveQr> {
  late Timer _timer;
  late String _payload;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _update();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) => _tick());
  }

  @override
  void didUpdateWidget(covariant _LiveQr old) {
    super.didUpdateWidget(old);
    if (old.booking.id != widget.booking.id) {
      _step = 0;
      _update();
    }
  }

  /// Regenera el código cuando cambia la ventana de 30 s.
  void _update() {
    final now = DateTime.now();
    final step = QrToken.stepAt(now);
    if (step == _step) return;
    _step = step;
    _payload = QrToken.payload(bookingId: widget.booking.id, qrSecret: widget.booking.qrSecret, at: now);
  }

  // También redibuja la barra de cuenta regresiva.
  void _tick() => setState(_update);

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = QrToken.remaining();
    final progress = remaining.inMilliseconds / QrToken.period.inMilliseconds;
    return Column(
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Brand.primary.withValues(alpha: 0.35), blurRadius: 40)],
            ),
            child: QrImageView(
              data: _payload,
              size: 240,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 240,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: Brand.surfaceHigh,
              color: Brand.primary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Mostralo en la entrada · se renueva en ${remaining.inSeconds + 1}s',
          style: const TextStyle(color: Brand.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

class _QrPlaceholder extends StatelessWidget {
  const _QrPlaceholder({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 272,
          height: 272,
          decoration: BoxDecoration(
            color: Brand.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Brand.outline),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 72, color: color),
              const SizedBox(height: 16),
              Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Brand.textSecondary)),
            ],
          ),
        ),
      );
}

class _BookingInfo extends StatelessWidget {
  const _BookingInfo({required this.today, required this.next, required this.onGoToTurnos});

  final Booking? today;
  final Booking? next;
  final VoidCallback onGoToTurnos;

  @override
  Widget build(BuildContext context) {
    final b = today ?? next;
    if (b == null) {
      return Column(
        children: [
          const Text('Todavía no reservaste ningún turno', style: TextStyle(color: Brand.textSecondary)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onGoToTurnos,
            icon: const Icon(Icons.calendar_month),
            label: const Text('Reservar turno'),
          ),
        ],
      );
    }
    final isToday = b == today;
    final day = isToday ? 'Hoy' : _capitalize(DateFormat("EEEE d 'de' MMMM", 'es').format(b.date));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Brand.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.schedule, color: Brand.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isToday ? 'TU TURNO DE HOY' : 'PRÓXIMO TURNO',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: Brand.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(b.slot.label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  Text(day, style: const TextStyle(color: Brand.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
