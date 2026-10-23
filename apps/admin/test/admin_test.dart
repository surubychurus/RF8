import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:rf8_admin/data/admin_api.dart';
import 'package:rf8_admin/data/models.dart';
import 'package:rf8_admin/data/session.dart';
import 'package:rf8_admin/screens/home_shell.dart';
import 'package:rf8_admin/theme/app_theme.dart';
import 'package:rf8_admin/widgets/common.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Member _member(Role role) => Member.fromJson({
      'id': 'u1',
      'username': 'staff',
      'full_name': 'Staff RF8',
      'email': 'staff@rf8.com.ar',
      'role': role.name,
      'active': true,
      'created_at': '2026-10-01T10:00:00Z',
      'memberships': [],
    });

/// API sin red: devuelve listas vacías.
class _FakeApi extends AdminApi {
  _FakeApi()
      : super(SupabaseClient('http://localhost', 'key',
            authOptions: const AuthClientOptions(autoRefreshToken: false)));

  @override
  Future<List<TimeSlot>> slots() async => const [];
  @override
  Future<List<DayBooking>> bookingsOn(DateTime day) async => const [];
  @override
  Future<List<Member>> members({String search = ''}) async => const [];
  @override
  Future<List<Invitation>> pendingInvitations() async => const [];
}

/// Sesión fija para probar la navegación por rol sin backend.
class _FakeSession extends AdminSession {
  _FakeSession(Role role) : super(_FakeApi()) {
    me = _member(role);
    state = SessionState.ready;
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  group('WhatsApp', () {
    test('agrega código de país y 9 para celulares de Argentina', () {
      expect(whatsappNumber('11 2345 6789'), '5491123456789');
      expect(whatsappNumber('011 2345-6789'), '5491123456789');
    });
    test('respeta números internacionales', () {
      expect(whatsappNumber('+54 9 11 2345 6789'), '5491123456789');
      expect(whatsappNumber('+598 99 123 456'), '59899123456');
    });
    test('sin número', () {
      expect(whatsappNumber(null), isNull);
      expect(whatsappNumber('  '), isNull);
    });
  });

  test('plan vigente: el que cubre hoy o el próximo', () {
    final today = DateUtils.dateOnly(DateTime.now());
    String d(DateTime x) => x.toIso8601String().substring(0, 10);
    final plan = {'id': 'p', 'kind': 'normal', 'days_per_week': 3, 'name': 'Normal 3', 'active': true};
    final m = Member.fromJson({
      ..._member(Role.member).toJsonForTest(),
      'memberships': [
        {'id': 'old', 'starts_on': d(today.subtract(const Duration(days: 60))), 'ends_on': d(today.subtract(const Duration(days: 31))), 'plans': plan},
        {'id': 'cur', 'starts_on': d(today.subtract(const Duration(days: 3))), 'ends_on': d(today.add(const Duration(days: 27))), 'plans': plan},
      ],
    });
    expect(m.currentMembership?.id, 'cur');
    expect(m.currentMembership?.isCurrent, isTrue);
  });

  Future<void> pumpShell(WidgetTester tester, Role role) async {
    final session = _FakeSession(role);
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider.value(value: session.api),
        ChangeNotifierProvider<AdminSession>.value(value: session),
      ],
      child: MaterialApp(theme: buildAppTheme(), home: const HomeShell()),
    ));
    await tester.pump();
  }

  testWidgets('rol gym: sin sección Gestión', (tester) async {
    await pumpShell(tester, Role.gym);
    expect(find.text('Validar'), findsWidgets);
    expect(find.text('Socios'), findsWidgets);
    expect(find.text('Gestión'), findsNothing);
    await _settle(tester);
  });

  testWidgets('rol dueño: con sección Gestión', (tester) async {
    await pumpShell(tester, Role.owner);
    expect(find.text('Gestión'), findsWidgets);
    await tester.tap(find.text('Gestión').last);
    await tester.pump();
    for (final item in ['Banner superior', 'Notificaciones globales', 'Enlaces', 'Imágenes', 'Logo e íconos', 'Planes y precios']) {
      expect(find.text(item), findsOneWidget, reason: item);
    }
    await _settle(tester);
  });
}

/// Desmonta la app al terminar.
Future<void> _settle(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
}

extension on Member {
  Map<String, dynamic> toJsonForTest() => {
        'id': id,
        'username': username,
        'full_name': fullName,
        'email': email,
        'role': role.name,
        'active': active,
        'created_at': createdAt.toIso8601String(),
      };
}
