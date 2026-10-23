import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'gym_repository.dart';

class SupabaseGymRepository implements GymRepository {
  SupabaseGymRepository(this._client);

  final SupabaseClient _client;
  static final _date = DateFormat('yyyy-MM-dd');

  GoTrueClient get _auth => _client.auth;
  String get _uid {
    final id = _auth.currentUser?.id;
    if (id == null) throw const AppException('Tu sesión expiró, volvé a ingresar');
    return id;
  }

  @override
  String? get currentUserId => _auth.currentUser?.id;

  @override
  Stream<void> get sessionChanges => _auth.onAuthStateChange
      .where((s) => s.event != AuthChangeEvent.tokenRefreshed)
      .map((_) {});

  @override
  Future<void> signIn(String usernameOrEmail, String password) => _guard(() async {
        final login = usernameOrEmail.trim();
        if (login.contains('@')) {
          await _auth.signInWithPassword(email: login.toLowerCase(), password: password);
          return;
        }
        final res = await _client.functions
            .invoke('sign-in', body: {'username': login, 'password': password});
        final data = res.data as Map<String, dynamic>;
        await _auth.setSession(data['refresh_token'] as String);
      });

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<InviteInfo> getInvite(String token) => _guard(() async {
        final res = await _client.functions.invoke('invite-info', body: {'token': token});
        final j = res.data as Map<String, dynamic>;
        return InviteInfo(
          email: j['email'] as String,
          fullName: j['full_name'] as String,
          expiresAt: DateTime.parse(j['expires_at'] as String),
        );
      });

  @override
  Future<void> acceptInvite({
    required String token,
    required String username,
    required String password,
  }) =>
      _guard(() async {
        await _client.functions.invoke('accept-invite', body: {
          'token': token,
          'username': username,
          'password': password,
        });
        await signIn(username, password);
      });

  @override
  Future<Profile> fetchProfile() => _guard(() async {
        final row = await _client.from('profiles').select().eq('id', _uid).single();
        return Profile.fromJson(row);
      });

  @override
  Future<Profile> updateProfile({required String fullName, String? phone}) => _guard(() async {
        final row = await _client
            .from('profiles')
            .update({'full_name': fullName, 'phone': phone})
            .eq('id', _uid)
            .select()
            .single();
        return Profile.fromJson(row);
      });

  @override
  Future<void> changePassword({required String currentPassword, required String newPassword}) =>
      _guard(() async {
        final email = _auth.currentUser?.email;
        if (email == null) throw const AppException('Tu sesión expiró, volvé a ingresar');
        try {
          await _auth.signInWithPassword(email: email, password: currentPassword);
        } on AuthException {
          throw const AppException('La contraseña actual no es correcta');
        }
        await _auth.updateUser(UserAttributes(password: newPassword));
      });

  @override
  Future<Membership?> fetchMembership() => _guard(() async {
        final row = await _client
            .from('memberships')
            .select('starts_on, ends_on, plans(*)')
            .eq('user_id', _uid)
            .gte('ends_on', _date.format(DateTime.now()))
            .order('starts_on')
            .limit(1)
            .maybeSingle();
        if (row == null) return null;
        return Membership(
          plan: Plan.fromJson(row['plans'] as Map<String, dynamic>),
          startsOn: DateTime.parse(row['starts_on'] as String),
          endsOn: DateTime.parse(row['ends_on'] as String),
        );
      });

  @override
  Future<List<Plan>> fetchPlans() => _guard(() async {
        final rows = await _client
            .from('plans')
            .select()
            .eq('active', true)
            .order('kind')
            .order('days_per_week');
        return rows.map(Plan.fromJson).toList();
      });

  @override
  Future<List<SlotAvailability>> fetchSlots(DateTime date) => _guard(() async {
        final rows = await _client
            .rpc('get_slot_availability', params: {'p_date': _date.format(date)}) as List;
        return rows.cast<Map<String, dynamic>>().map((r) {
          return SlotAvailability(
            slot: TimeSlot(
              id: (r['slot_id'] as num).toInt(),
              start: TimeSlot.parseTime(r['starts_at'] as String),
              end: TimeSlot.parseTime(r['ends_at'] as String),
              capacity: (r['capacity'] as num).toInt(),
            ),
            booked: (r['booked'] as num).toInt(),
          );
        }).toList();
      });

  @override
  Future<List<Booking>> fetchMyBookings(DateTime from, DateTime to) => _guard(() async {
        final rows = await _client
            .from('bookings')
            .select('id, date, status, qr_secret, time_slots(id, starts_at, ends_at, capacity)')
            .eq('user_id', _uid)
            .neq('status', 'cancelled')
            .gte('date', _date.format(from))
            .lte('date', _date.format(to))
            .order('date');
        return rows.map((r) {
          final s = r['time_slots'] as Map<String, dynamic>;
          return Booking(
            id: r['id'] as String,
            date: DateTime.parse(r['date'] as String),
            status: BookingStatus.parse(r['status'] as String),
            qrSecret: r['qr_secret'] as String,
            slot: TimeSlot(
              id: (s['id'] as num).toInt(),
              start: TimeSlot.parseTime(s['starts_at'] as String),
              end: TimeSlot.parseTime(s['ends_at'] as String),
              capacity: (s['capacity'] as num).toInt(),
            ),
          );
        }).toList();
      });

  @override
  Future<void> book(int slotId, DateTime date) => _guard(() async {
        await _client.rpc('book_slot', params: {'p_slot_id': slotId, 'p_date': _date.format(date)});
      });

  @override
  Future<void> cancelBooking(String bookingId) => _guard(() async {
        await _client.rpc('cancel_booking', params: {'p_booking_id': bookingId});
      });

  /// Traduce errores de Supabase a [AppException] con mensajes legibles.
  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on AppException {
      rethrow;
    } on FunctionException catch (e) {
      final details = e.details;
      final msg = details is Map && details['error'] is String ? details['error'] as String : null;
      throw AppException(msg ?? 'No pudimos completar la operación (${e.status})');
    } on PostgrestException catch (e) {
      // Los errores de negocio (P0001) ya vienen redactados para el usuario.
      throw AppException(e.code == 'P0001' ? e.message : 'Error del servidor, probá de nuevo');
    } on AuthException catch (e) {
      throw AppException(
        e.code == 'invalid_credentials' ? 'Usuario o contraseña incorrectos' : e.message,
      );
    } catch (_) {
      throw const AppException('Sin conexión. Revisá tu internet y probá de nuevo');
    }
  }
}
