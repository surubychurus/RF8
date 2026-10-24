import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:local_auth/local_auth.dart';
import 'package:rf8_app/app.dart';
import 'package:rf8_app/data/demo_gym_repository.dart';
import 'package:rf8_app/screens/cuenta/cuenta_screen.dart';
import 'package:rf8_app/services/app_icon_service.dart';
import 'package:rf8_app/services/local_security.dart';
import 'package:rf8_app/services/session_controller.dart';

/// Dispositivo sin biometría.
class _NoBiometrics extends LocalAuthentication {
  @override
  Future<bool> isDeviceSupported() async => false;

  @override
  Future<bool> get canCheckBiometrics async => false;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => const [];
}

Future<void> enterPin(WidgetTester tester, String pin) async {
  for (final d in pin.split('')) {
    await tester.tap(find.text(d).last);
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('login → crear PIN → secciones Turnos / GO / Mi cuenta → bloquear', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final repo = DemoGymRepository();
    final session = SessionController(repo: repo, security: LocalSecurity(auth: _NoBiometrics()));
    await session.init();

    await tester.pumpWidget(Rf8App(repo: repo, session: session, appIcons: AppIconService()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Bienvenido a RF8'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Usuario'), 'demo');
    await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'demo1234');
    await tester.tap(find.text('Ingresar'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));

    // Sin biometría en el entorno de test: va directo a crear el PIN.
    expect(find.text('Creá tu PIN de 6 dígitos'), findsOneWidget);
    await enterPin(tester, '123456');
    expect(find.text('Repetí tu PIN'), findsOneWidget);
    await enterPin(tester, '123456');
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));

    // GO: nombre completo arriba
    expect(find.text('Socio Demo RF8'), findsWidgets);
    expect(find.text('No tenés turno para hoy'), findsOneWidget);

    await tester.tap(find.text('Mi cuenta'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Ícono de la app'), findsOneWidget);
    expect(find.text('Seguridad'.toUpperCase()), findsOneWidget);

    // Pantallas que se abren con push desde Mi cuenta (necesitan los datos del socio).
    for (final (entry, title) in [
      ('Planes y precios', 'Rutina normal'),
      ('Datos personales', 'Nombre completo'),
    ]) {
      await tester.scrollUntilVisible(
        find.text(entry),
        200,
        scrollable: find.descendant(of: find.byType(CuentaScreen), matching: find.byType(Scrollable)).first,
      );
      tester.widget<ListTile>(find.ancestor(of: find.text(entry), matching: find.byType(ListTile))).onTap!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull, reason: entry);
      expect(find.textContaining(title), findsWidgets, reason: entry);
      Navigator.of(tester.element(find.textContaining(title).first)).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }

    await tester.tap(find.text('Turnos').last);
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('turnos usados esta semana'), findsOneWidget);

    session.lock();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Ingresá tu PIN'), findsOneWidget);
    await enterPin(tester, '000000');
    expect(find.textContaining('PIN incorrecto'), findsOneWidget);
    await enterPin(tester, '123456');
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Ingresá tu PIN'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
}
