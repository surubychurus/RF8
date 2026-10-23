import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/local_security.dart';
import '../theme/brand.dart';

/// Teclado numérico para un PIN de 6 dígitos.
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.onCompleted,
    this.error,
    this.onBiometric,
    this.biometricIcon = Icons.fingerprint,
    this.enabled = true,
  });

  /// Se llama al completar los 6 dígitos. El teclado se limpia al terminar.
  final Future<void> Function(String pin) onCompleted;
  final String? error;
  final VoidCallback? onBiometric;
  final IconData biometricIcon;
  final bool enabled;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _pin = '';
  bool _busy = false;

  Future<void> _tap(String d) async {
    if (_busy || !widget.enabled || _pin.length >= LocalSecurity.pinLength) return;
    HapticFeedback.selectionClick();
    setState(() => _pin += d);
    if (_pin.length == LocalSecurity.pinLength) {
      _busy = true;
      try {
        await widget.onCompleted(_pin);
      } finally {
        if (mounted) {
          setState(() {
            _pin = '';
            _busy = false;
          });
        }
      }
    }
  }

  void _delete() {
    if (_busy || _pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.error;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < LocalSecurity.pinLength; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _pin.length
                      ? (error != null ? Theme.of(context).colorScheme.error : Brand.primary)
                      : Colors.transparent,
                  border: Border.all(
                    color: i < _pin.length ? Colors.transparent : Brand.textSecondary,
                    width: 2,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(
          height: 40,
          child: Center(
            child: error == null
                ? null
                : Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [for (final d in row) _Key(label: d, onTap: () => _tap(d))],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            widget.onBiometric == null
                ? const SizedBox(width: _Key.size + 24)
                : _Key(icon: widget.biometricIcon, onTap: widget.onBiometric!, subtle: true),
            _Key(label: '0', onTap: () => _tap('0')),
            _Key(icon: Icons.backspace_outlined, onTap: _delete, subtle: true),
          ],
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({this.label, this.icon, required this.onTap, this.subtle = false});

  static const size = 72.0;

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Material(
        color: subtle ? Colors.transparent : Brand.surface,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: size,
            child: Center(
              child: label != null
                  ? Text(label!, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600))
                  : Icon(icon, size: 28, color: Brand.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
