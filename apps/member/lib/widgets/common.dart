import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/brand.dart';

void showMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? Theme.of(context).colorScheme.error : Brand.surfaceHigh,
    ));
}

/// Ejecuta [action] mostrando el error como snackbar si falla.
Future<bool> runGuarded(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
    return true;
  } on AppException catch (e) {
    if (context.mounted) showMessage(context, e.message, error: true);
    return false;
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: Brand.textSecondary,
          ),
        ),
      );
}

class LoadingButton extends StatelessWidget {
  const LoadingButton({super.key, required this.label, required this.loading, this.onPressed});

  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : Text(label),
      );
}

class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Brand.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Brand.warning.withValues(alpha: 0.4)),
        ),
        child: const Text(
          'Modo demo · usuario: demo · clave: demo1234 · invitación: DEMO',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Brand.warning),
        ),
      );
}
