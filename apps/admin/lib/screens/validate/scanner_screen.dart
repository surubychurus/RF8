import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../data/admin_api.dart';
import '../../data/models.dart';
import '../../theme/brand.dart';

/// Escanea el QR de la sección GO del socio y registra la asistencia.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _busy = false;
  _Result? _result;
  Timer? _reset;
  int _validated = 0;

  @override
  void dispose() {
    _reset?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy || _result != null) return;
    final raw = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    if (raw == null) return;
    _busy = true;
    final api = context.read<AdminApi>();
    _Result result;
    try {
      if (!raw.startsWith('RF8|')) throw const AppException('Este QR no es de RF8');
      final r = await api.checkIn(raw);
      result = _Result(ok: true, title: r.fullName, subtitle: 'Turno ${r.slotLabel}');
      _validated++;
      HapticFeedback.mediumImpact();
    } on AppException catch (e) {
      result = _Result(ok: false, title: 'No válido', subtitle: e.message);
      HapticFeedback.heavyImpact();
    }
    if (!mounted) return;
    setState(() => _result = result);
    _busy = false;
    _reset = Timer(const Duration(seconds: 3), _next);
  }

  void _next() {
    _reset?.cancel();
    if (mounted) setState(() => _result = null);
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(_validated == 0 ? 'Escanear QR' : 'Escanear QR · $_validated validados'),
        actions: [
          IconButton(icon: const Icon(Icons.flash_on), onPressed: _controller.toggleTorch),
          IconButton(icon: const Icon(Icons.cameraswitch_outlined), onPressed: _controller.switchCamera),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  error.errorCode == MobileScannerErrorCode.permissionDenied
                      ? 'Dale permiso a la cámara para escanear'
                      : 'No se pudo abrir la cámara',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white70, width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 48,
            child: Text(
              'Apuntá al QR de la sección GO del socio',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ),
          if (r != null)
            GestureDetector(
              onTap: _next,
              child: Container(
                color: (r.ok ? Brand.success : Brand.danger).withValues(alpha: 0.94),
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(r.ok ? Icons.check_circle : Icons.cancel, size: 120, color: Colors.white),
                    const SizedBox(height: 24),
                    Text(r.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(height: 8),
                    Text(r.subtitle,
                        textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, color: Colors.white)),
                    const SizedBox(height: 32),
                    const Text('Tocá para escanear otro', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Result {
  const _Result({required this.ok, required this.title, required this.subtitle});

  final bool ok;
  final String title;
  final String subtitle;
}
