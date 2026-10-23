import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../data/models.dart';
import '../theme/brand.dart';

void showMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? Brand.danger : Brand.surfaceHigh,
    ));
}

/// Ejecuta [action] y muestra el error si falla. Devuelve true si salió bien.
Future<bool> runGuarded(BuildContext context, Future<void> Function() action, {String? success}) async {
  try {
    await action();
    if (success != null && context.mounted) showMessage(context, success);
    return true;
  } on AppException catch (e) {
    if (context.mounted) showMessage(context, e.message, error: true);
    return false;
  }
}

Future<bool> confirm(BuildContext context, {required String title, required String message, String action = 'Confirmar', bool danger = false}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: Brand.danger) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Número de WhatsApp en formato internacional (sólo dígitos).
String? whatsappNumber(String? phone) {
  if (phone == null) return null;
  var digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;
  if (phone.trim().startsWith('+')) return digits;
  digits = digits.replaceFirst(RegExp(r'^0+'), '');
  if (!digits.startsWith(AppConfig.defaultCountryCode)) {
    // Argentina: celulares llevan 9 después del 54.
    digits = '${AppConfig.defaultCountryCode}9$digits';
  }
  return digits;
}

Future<void> openWhatsApp(BuildContext context, String? phone, {String? text}) async {
  final n = whatsappNumber(phone);
  if (n == null) {
    showMessage(context, 'El socio no tiene WhatsApp cargado', error: true);
    return;
  }
  final uri = Uri.https('wa.me', '/$n', {'text': ?text});
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
    showMessage(context, 'No se pudo abrir WhatsApp', error: true);
  }
}

Future<void> openUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) showMessage(context, 'No se pudo abrir el enlace', error: true);
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text.toUpperCase(),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: Brand.textSecondary),
              ),
            ),
            ?trailing,
          ],
        ),
      );
}

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color = Brand.textSecondary});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          children: [
            Icon(icon, size: 48, color: Brand.textSecondary),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Brand.textSecondary)),
          ],
        ),
      );
}

/// Carga asíncrona con estados de carga / error / reintento.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.future, required this.builder, this.onRetry});

  final Future<T>? future;
  final Widget Function(BuildContext, T) builder;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
        future: future,
        builder: (context, snap) {
          if (snap.hasError) {
            final msg = snap.error is AppException ? (snap.error as AppException).message : '${snap.error}';
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(msg, textAlign: TextAlign.center),
                    if (onRetry != null) ...[
                      const SizedBox(height: 12),
                      OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
                    ],
                  ],
                ),
              ),
            );
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return builder(context, snap.data as T);
        },
      );
}

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

class Avatar extends StatelessWidget {
  const Avatar(this.name, {super.key, this.radius = 22});

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: radius,
        backgroundColor: Brand.surfaceHigh,
        child: Text(initials(name), style: TextStyle(fontWeight: FontWeight.w800, fontSize: radius * 0.7)),
      );
}
