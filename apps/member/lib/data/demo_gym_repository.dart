import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../config/gym_config.dart';
import '../models/models.dart';
import 'gym_repository.dart';

/// Backend en memoria para probar la app sin Supabase.
///
///  * Usuario: `demo` / Clave: `demo1234`
///  * Código de invitación: `DEMO`
///
/// Replica las reglas del servidor (cupo, 1 turno por día, N por semana).
class DemoGymRepository implements GymRepository {
  DemoGymRepository({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  static const demoInviteToken = 'DEMO';

  final _sessionCtrl = StreamController<void>.broadcast();
  final _bookings = <Booking>[];
  final _users = <String, ({String password, Profile profile})>{
    'demo': (
      password: 'demo1234',
      profile: const Profile(
        id: 'u-demo',
        username: 'demo',
        fullName: 'Socio Demo RF8',
        email: 'demo@rf8.com.ar',
      ),
    ),
  };
  bool _inviteUsed = false;
  String? _currentUsername;
  int _seq = 0;

  static final _plans = [
    for (final kind in PlanKind.values)
      for (var d = 1; d <= 4; d++)
        Plan(
          id: '${kind.name}-$d',
          kind: kind,
          daysPerWeek: d,
          name: '${kind.label} · $d ${d == 1 ? 'día' : 'días'}',
          description: kind == PlanKind.normal
              ? 'Rutina estándar, $d ${d == 1 ? 'día' : 'días'} por semana'
              : 'Rutina con seguimiento personalizado, $d ${d == 1 ? 'día' : 'días'} por semana',
        ),
  ];

  static const _slots = [
    TimeSlot(id: 1, start: TimeOfDay(hour: 8, minute: 0), end: TimeOfDay(hour: 9, minute: 30), capacity: GymConfig.slotCapacity),
    TimeSlot(id: 2, start: TimeOfDay(hour: 9, minute: 30), end: TimeOfDay(hour: 11, minute: 0), capacity: GymConfig.slotCapacity),
    TimeSlot(id: 3, start: TimeOfDay(hour: 11, minute: 0), end: TimeOfDay(hour: 12, minute: 30), capacity: GymConfig.slotCapacity),
    TimeSlot(id: 4, start: TimeOfDay(hour: 13, minute: 30), end: TimeOfDay(hour: 15, minute: 0), capacity: GymConfig.slotCapacity),
    TimeSlot(id: 5, start: TimeOfDay(hour: 15, minute: 0), end: TimeOfDay(hour: 16, minute: 30), capacity: GymConfig.slotCapacity),
    TimeSlot(id: 6, start: TimeOfDay(hour: 17, minute: 0), end: TimeOfDay(hour: 18, minute: 30), capacity: GymConfig.slotCapacity),
    TimeSlot(id: 7, start: TimeOfDay(hour: 18, minute: 30), end: TimeOfDay(hour: 20, minute: 0), capacity: GymConfig.slotCapacity),
  ];

  /// Lunes a viernes todo el día; sábados sólo a la mañana (08:00–12:30).
  static bool _isOpen(DateTime d) => d.weekday <= DateTime.saturday;

  static bool _slotOpen(TimeSlot s, DateTime d) =>
      d.weekday < DateTime.saturday || (d.weekday == DateTime.saturday && s.end.hour * 60 + s.end.minute <= 12 * 60 + 30);

  Profile get _me {
    final u = _users[_currentUsername];
    if (u == null) throw const AppException('Tu sesión expiró, volvé a ingresar');
    return u.profile;
  }

  Future<void> _latency() => Future.delayed(const Duration(milliseconds: 350));

  /// Ocupación simulada de otros socios (determinística por día/turno).
  int _othersBooked(int slotId, DateTime date) {
    final seed = date.year * 10000 + date.month * 100 + date.day + slotId * 7;
    if (seed % 9 == 0) return GymConfig.slotCapacity; // algún turno lleno
    return Random(seed).nextInt(GymConfig.slotCapacity - 2);
  }

  @override
  String? get currentUserId => _currentUsername == null ? null : _me.id;

  @override
  Stream<void> get sessionChanges => _sessionCtrl.stream;

  @override
  Future<void> signIn(String usernameOrEmail, String password) async {
    await _latency();
    final login = usernameOrEmail.trim().toLowerCase();
    final entry = _users.entries.where(
      (e) => e.key == login || e.value.profile.email == login,
    );
    if (entry.isEmpty || entry.first.value.password != password) {
      throw const AppException('Usuario o contraseña incorrectos');
    }
    _currentUsername = entry.first.key;
    _sessionCtrl.add(null);
  }

  @override
  Future<void> signOut() async {
    _currentUsername = null;
    _sessionCtrl.add(null);
  }

  @override
  Future<InviteInfo> getInvite(String token) async {
    await _latency();
    if (token.trim().toUpperCase() != demoInviteToken) {
      throw const AppException('Invitación inválida');
    }
    if (_inviteUsed) throw const AppException('Esta invitación ya fue usada');
    return InviteInfo(
      fullName: 'Nuevo Socio',
      expiresAt: _clock().add(const Duration(hours: 72)),
    );
  }

  @override
  Future<void> acceptInvite({
    required String token,
    required String username,
    required String password,
    String? email,
  }) async {
    final invite = await getInvite(token);
    final mail = invite.email ?? email?.trim().toLowerCase() ?? '';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(mail)) {
      throw const AppException('Ingresá un email válido');
    }
    final u = username.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9._]{3,20}$').hasMatch(u)) {
      throw const AppException(
        'El usuario debe tener 3 a 20 caracteres: letras, números, punto o guion bajo',
      );
    }
    if (_users.containsKey(u)) throw const AppException('Ese usuario ya existe, probá con otro');
    _users[u] = (
      password: password,
      profile: Profile(id: 'u-$u', username: u, fullName: invite.fullName, email: mail),
    );
    _inviteUsed = true;
    await signIn(u, password);
  }

  @override
  Future<Profile> fetchProfile() async {
    await _latency();
    return _me;
  }

  @override
  Future<Profile> updateProfile({required String fullName, String? phone}) async {
    await _latency();
    final updated = _me.copyWith(fullName: fullName, phone: phone);
    final u = _users[_currentUsername]!;
    _users[_currentUsername!] = (password: u.password, profile: updated);
    return updated;
  }

  @override
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    await _latency();
    final u = _users[_currentUsername]!;
    if (u.password != currentPassword) {
      throw const AppException('La contraseña actual no es correcta');
    }
    _users[_currentUsername!] = (password: newPassword, profile: u.profile);
  }

  @override
  Future<Membership?> fetchMembership() async {
    await _latency();
    final today = DateUtils.dateOnly(_clock());
    return Membership(
      plan: _plans.firstWhere((p) => p.id == 'seguimiento-3'),
      startsOn: DateTime(today.year, today.month, 1),
      endsOn: DateTime(today.year, today.month + 1, 0),
    );
  }

  @override
  Future<List<Plan>> fetchPlans() async {
    await _latency();
    return _plans;
  }

  List<Booking> get _myActive =>
      _bookings.where((b) => b.isActive && b.id.startsWith('${_me.id}:')).toList();

  @override
  Future<List<SlotAvailability>> fetchSlots(DateTime date) async {
    await _latency();
    final d = DateUtils.dateOnly(date);
    if (!_isOpen(d)) return [];
    return [
      for (final s in _slots.where((s) => _slotOpen(s, d)))
        SlotAvailability(
          slot: s,
          booked: min(
            s.capacity,
            _othersBooked(s.id, d) +
                _bookings.where((b) => b.isActive && b.slot.id == s.id && b.date == d).length,
          ),
        ),
    ];
  }

  @override
  Future<List<Booking>> fetchMyBookings(DateTime from, DateTime to) async {
    await _latency();
    final f = DateUtils.dateOnly(from), t = DateUtils.dateOnly(to);
    return _myActive.where((b) => !b.date.isBefore(f) && !b.date.isAfter(t)).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  @override
  Future<void> book(int slotId, DateTime date) async {
    await _latency();
    final d = DateUtils.dateOnly(date);
    final today = DateUtils.dateOnly(_clock());
    final slot = _slots.firstWhere((s) => s.id == slotId);
    final membership = await fetchMembership();

    if (d.isBefore(today) || d.isAfter(today.add(const Duration(days: GymConfig.bookingWindowDays)))) {
      throw const AppException('Sólo podés reservar desde hoy hasta 7 días adelante');
    }
    if (!_isOpen(d) || !_slotOpen(slot, d)) throw const AppException('Ese turno no está disponible ese día');
    if (!slot.startOn(d).isAfter(_clock())) throw const AppException('Ese turno ya empezó');
    if (membership == null || !membership.isActiveOn(d)) {
      throw const AppException('No tenés un plan activo para esa fecha');
    }
    if (_myActive.any((b) => b.date == d)) {
      throw const AppException('Ya tenés un turno reservado ese día');
    }
    final monday = d.subtract(Duration(days: d.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    final used = _myActive.where((b) => !b.date.isBefore(monday) && !b.date.isAfter(sunday)).length;
    final quota = membership.plan.daysPerWeek;
    if (used >= quota) throw AppException('Ya usaste tus $quota turnos de esta semana');
    final taken = _othersBooked(slotId, d) +
        _bookings.where((b) => b.isActive && b.slot.id == slotId && b.date == d).length;
    if (taken >= slot.capacity) throw const AppException('El turno está completo');

    final rnd = Random.secure();
    _bookings.add(Booking(
      id: '${_me.id}:${_seq++}',
      date: d,
      slot: slot,
      status: BookingStatus.booked,
      qrSecret: List.generate(32, (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join(),
    ));
  }

  final _readNotifications = <String>{};

  @override
  Future<RemoteBranding> fetchBranding() async => const RemoteBranding();

  @override
  Future<List<BannerItem>> fetchBanners() async => const [
        BannerItem(
          id: 'b1',
          title: '¡Bienvenido a la app de RF8!',
          body: 'Reservá tu turno y entrá con tu QR desde la sección GO.',
        ),
        BannerItem(
          id: 'b2',
          title: 'Seguinos en Instagram',
          body: '@rf8.gimnasio',
          linkUrl: 'https://www.instagram.com/rf8.gimnasio',
        ),
      ];

  @override
  Future<List<AppLink>> fetchLinks() async => const [
        AppLink(label: 'Instagram', url: 'https://www.instagram.com/rf8.gimnasio', icon: 'instagram'),
      ];

  @override
  Future<List<AppNotification>> fetchNotifications() async {
    await _latency();
    return [
      AppNotification(
        id: 'n1',
        title: 'Horario especial',
        body: 'El feriado abrimos de 9 a 13 h.',
        createdAt: _clock().subtract(const Duration(hours: 3)),
        isGlobal: true,
        read: _readNotifications.contains('n1'),
      ),
      AppNotification(
        id: 'n2',
        title: 'Tu plan vence pronto',
        body: 'Acercate a recepción para renovarlo.',
        createdAt: _clock().subtract(const Duration(days: 1)),
        isGlobal: false,
        read: _readNotifications.contains('n2'),
      ),
    ];
  }

  @override
  Future<void> markNotificationsRead(Iterable<String> ids) async => _readNotifications.addAll(ids);

  @override
  Stream<void> get notificationEvents => const Stream.empty();

  @override
  Future<void> cancelBooking(String bookingId) async {
    await _latency();
    final i = _bookings.indexWhere((b) => b.id == bookingId && b.status == BookingStatus.booked);
    if (i < 0) throw const AppException('Turno no encontrado');
    final b = _bookings[i];
    if (!b.startsAt.isAfter(_clock())) {
      throw const AppException('No se puede cancelar un turno que ya empezó');
    }
    _bookings[i] = Booking(
      id: b.id,
      date: b.date,
      slot: b.slot,
      status: BookingStatus.cancelled,
      qrSecret: b.qrSecret,
    );
  }
}
