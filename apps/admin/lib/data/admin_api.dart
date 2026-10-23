import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import 'models.dart';

/// Todas las operaciones de la app de administración contra Supabase.
/// Los permisos reales los aplica la base (RLS y funciones por rol).
class AdminApi {
  AdminApi(this._client);

  final SupabaseClient _client;
  static final _day = DateFormat('yyyy-MM-dd');

  static const _memberSelect =
      'id, username, full_name, email, phone, notes, role, active, created_at, '
      'memberships(id, starts_on, ends_on, plans(*))';

  GoTrueClient get auth => _client.auth;
  String? get userId => auth.currentUser?.id;
  StorageFileApi get _media => _client.storage.from(AppConfig.mediaBucket);

  // --- Sesión -------------------------------------------------------------------

  Future<void> signIn(String login, String password) => _guard(() async {
        final l = login.trim();
        if (l.contains('@')) {
          await auth.signInWithPassword(email: l.toLowerCase(), password: password);
          return;
        }
        final res = await _client.functions.invoke('sign-in', body: {'username': l, 'password': password});
        await auth.setSession((res.data as Map<String, dynamic>)['refresh_token'] as String);
      });

  Future<void> signOut() => auth.signOut();

  Future<Member> me() => _guard(() async {
        final row = await _client.from('profiles').select(_memberSelect).eq('id', userId!).single();
        return Member.fromJson(row);
      });

  // --- Validación de turnos -------------------------------------------------------

  Future<CheckInResult> checkIn(String payload) => _guard(() async {
        final rows = await _client.rpc('check_in', params: {'p_payload': payload}) as List;
        final r = rows.first as Map<String, dynamic>;
        final start = (r['slot_start'] as String).substring(0, 5);
        final end = (r['slot_end'] as String).substring(0, 5);
        return CheckInResult(fullName: r['full_name'] as String, slotLabel: '$start – $end');
      });

  Future<void> checkInManual(String bookingId) =>
      _guard(() => _client.rpc('check_in_booking', params: {'p_booking_id': bookingId}));

  Future<List<DayBooking>> bookingsOn(DateTime day) => _guard(() async {
        final rows = await _client
            .from('bookings')
            .select('id, date, status, user_id, checked_in_at, '
                'profiles!bookings_user_id_fkey(full_name, phone), time_slots(id, starts_at, ends_at, capacity)')
            .eq('date', _day.format(day))
            .neq('status', 'cancelled');
        final list = rows.map(DayBooking.fromJson).toList()
          ..sort((a, b) {
            final s = (a.slot.start.hour * 60 + a.slot.start.minute)
                .compareTo(b.slot.start.hour * 60 + b.slot.start.minute);
            return s != 0 ? s : a.fullName.compareTo(b.fullName);
          });
        return list;
      });

  Future<List<DayBooking>> memberBookings(String userId, {required DateTime from}) => _guard(() async {
        final rows = await _client
            .from('bookings')
            .select('id, date, status, user_id, checked_in_at, '
                'profiles!bookings_user_id_fkey(full_name, phone), time_slots(id, starts_at, ends_at, capacity)')
            .eq('user_id', userId)
            .gte('date', _day.format(from))
            .neq('status', 'cancelled')
            .order('date', ascending: false)
            .limit(30);
        return rows.map(DayBooking.fromJson).toList();
      });

  Future<List<TimeSlot>> slots() => _guard(() async {
        final rows = await _client.from('time_slots').select().eq('active', true).order('starts_at');
        return rows.map(TimeSlot.fromJson).toList();
      });

  // --- Socios ---------------------------------------------------------------------

  Future<List<Member>> members({String search = ''}) => _guard(() async {
        var q = _client.from('profiles').select(_memberSelect);
        final s = search.trim().replaceAll(RegExp(r'[,()]'), ' ');
        if (s.isNotEmpty) {
          q = q.or('full_name.ilike.%$s%,username.ilike.%$s%,email.ilike.%$s%,phone.ilike.%$s%');
        }
        final rows = await q.order('full_name').limit(200);
        return rows.map(Member.fromJson).toList();
      });

  Future<Member> member(String id) => _guard(() async {
        final row = await _client.from('profiles').select(_memberSelect).eq('id', id).single();
        return Member.fromJson(row);
      });

  Future<void> updateMember(String id, {required String fullName, String? phone, String? notes, bool? active}) =>
      _guard(() => _client.from('profiles').update({
            'full_name': fullName,
            'phone': phone,
            'notes': notes,
            'active': ?active,
          }).eq('id', id));

  Future<void> inviteMember({required String fullName, required String email, String? phone, String? planId}) =>
      _guard(() => _client.functions.invoke('send-invite', body: {
            'full_name': fullName,
            'email': email,
            'phone': phone,
            'plan_id': planId,
          }));

  Future<List<Invitation>> pendingInvitations() => _guard(() async {
        final rows = await _client
            .from('invitations')
            .select('id, email, full_name, phone, expires_at, accepted_at')
            .isFilter('accepted_at', null)
            .order('created_at', ascending: false);
        return rows.map(Invitation.fromJson).toList();
      });

  Future<void> deleteInvitation(String id) => _guard(() => _client.from('invitations').delete().eq('id', id));

  /// Elimina la cuenta del socio (sólo dueños).
  Future<void> deleteUser(String id) =>
      _guard(() => _client.functions.invoke('delete-user', body: {'user_id': id}));

  Future<void> setRole(String userId, Role role) =>
      _guard(() => _client.rpc('set_user_role', params: {'p_user': userId, 'p_role': role.name}));

  // --- Planes -----------------------------------------------------------------------

  Future<List<Plan>> plans({bool onlyActive = false}) => _guard(() async {
        var q = _client.from('plans').select();
        if (onlyActive) q = q.eq('active', true);
        final rows = await q.order('kind').order('days_per_week');
        return rows.map(Plan.fromJson).toList();
      });

  Future<void> updatePlan(String id, {required String name, String? description, double? price, required bool active}) =>
      _guard(() => _client.from('plans').update({
            'name': name,
            'description': description,
            'monthly_price': price,
            'active': active,
          }).eq('id', id));

  Future<void> assignPlan(String userId, {required String planId, required DateTime startsOn, required DateTime endsOn}) =>
      _guard(() => _client.from('memberships').insert({
            'user_id': userId,
            'plan_id': planId,
            'starts_on': _day.format(startsOn),
            'ends_on': _day.format(endsOn),
          }));

  Future<void> updateMembership(String id, {required String planId, required DateTime startsOn, required DateTime endsOn}) =>
      _guard(() => _client.from('memberships').update({
            'plan_id': planId,
            'starts_on': _day.format(startsOn),
            'ends_on': _day.format(endsOn),
          }).eq('id', id));

  Future<void> deleteMembership(String id) => _guard(() => _client.from('memberships').delete().eq('id', id));

  // --- Notificaciones ---------------------------------------------------------------

  Future<void> sendNotification({String? userId, required String title, required String body, String? linkUrl}) =>
      _guard(() => _client.from('notifications').insert({
            'user_id': userId,
            'title': title,
            'body': body,
            'link_url': (linkUrl ?? '').trim().isEmpty ? null : linkUrl!.trim(),
            'created_by': this.userId,
          }));

  Future<List<AppNotification>> notifications({String? userId, bool global = false}) => _guard(() async {
        var q = _client.from('notifications').select();
        if (global) {
          q = q.isFilter('user_id', null);
        } else if (userId != null) {
          q = q.eq('user_id', userId);
        }
        final rows = await q.order('created_at', ascending: false).limit(100);
        return rows.map(AppNotification.fromJson).toList();
      });

  Future<void> updateNotification(String id, {required String title, required String body, String? linkUrl}) =>
      _guard(() => _client.from('notifications').update({
            'title': title,
            'body': body,
            'link_url': (linkUrl ?? '').trim().isEmpty ? null : linkUrl!.trim(),
          }).eq('id', id));

  Future<void> deleteNotification(String id) => _guard(() => _client.from('notifications').delete().eq('id', id));

  // --- Banner y enlaces -------------------------------------------------------------

  Future<List<Announcement>> announcements() => _guard(() async {
        final rows = await _client.from('banners').select().order('sort_order').order('created_at');
        return rows.map(Announcement.fromJson).toList();
      });

  Future<void> saveAnnouncement(Announcement a) => _guard(() async {
        if (a.id == null) {
          await _client.from('banners').insert(a.toJson());
        } else {
          await _client.from('banners').update(a.toJson()).eq('id', a.id!);
        }
      });

  Future<void> deleteAnnouncement(String id) => _guard(() => _client.from('banners').delete().eq('id', id));

  Future<List<AppLink>> links() => _guard(() async {
        final rows = await _client.from('app_links').select().order('sort_order').order('created_at');
        return rows.map(AppLink.fromJson).toList();
      });

  Future<void> saveLink(AppLink l) => _guard(() async {
        if (l.id == null) {
          await _client.from('app_links').insert(l.toJson());
        } else {
          await _client.from('app_links').update(l.toJson()).eq('id', l.id!);
        }
      });

  Future<void> deleteLink(String id) => _guard(() => _client.from('app_links').delete().eq('id', id));

  /// Guarda el orden (sort_order = posición en la lista).
  Future<void> reorder(String table, List<String> ids) => _guard(() async {
        for (var i = 0; i < ids.length; i++) {
          await _client.from(table).update({'sort_order': i}).eq('id', ids[i]);
        }
      });

  // --- Configuración (logo / íconos) ----------------------------------------------

  Future<Map<String, dynamic>> settings() => _guard(() async {
        final rows = await _client.from('app_settings').select('key, value');
        return {for (final r in rows) r['key'] as String: r['value']};
      });

  Future<void> setSetting(String key, Object? value) => _guard(() => _client
      .from('app_settings')
      .upsert({'key': key, 'value': value, 'updated_at': DateTime.now().toUtc().toIso8601String(), 'updated_by': userId}));

  // --- Imágenes (Storage) ------------------------------------------------------------

  static const mediaFolders = {
    'general': 'General',
    'banner': 'Banner',
    'logos': 'Logos',
    'icons': 'Íconos',
  };

  Future<List<MediaFile>> listMedia(String folder) => _guard(() async {
        final files = await _media.list(
          path: folder,
          searchOptions: const SearchOptions(limit: 500, sortBy: SortBy(column: 'updated_at', order: 'desc')),
        );
        return files
            .where((f) => f.id != null && f.name != '.emptyFolderPlaceholder')
            .map((f) {
              final path = '$folder/${f.name}';
              final updated = f.updatedAt == null ? null : DateTime.tryParse(f.updatedAt!);
              return MediaFile(
                path: path,
                url: publicUrl(path, version: updated?.millisecondsSinceEpoch),
                size: (f.metadata?['size'] as num?)?.toInt(),
                mimeType: f.metadata?['mimetype'] as String?,
                updatedAt: updated,
              );
            })
            .toList();
      });

  /// Sube (o reemplaza si [upsert]) una imagen y devuelve su URL pública.
  Future<String> uploadMedia(String path, Uint8List bytes, {required String contentType, bool upsert = false}) =>
      _guard(() async {
        await _media.uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: upsert, cacheControl: '60'),
        );
        return publicUrl(path, version: DateTime.now().millisecondsSinceEpoch);
      });

  Future<void> renameMedia(String from, String to) => _guard(() => _media.move(from, to));

  Future<void> deleteMedia(String path) => _guard(() => _media.remove([path]));

  /// URL pública; [version] evita que se muestre una versión vieja cacheada.
  String publicUrl(String path, {int? version}) {
    final url = _media.getPublicUrl(path);
    return version == null ? url : '$url?v=$version';
  }

  // --- Errores --------------------------------------------------------------------

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on AppException {
      rethrow;
    } on FunctionException catch (e) {
      final d = e.details;
      throw AppException(d is Map && d['error'] is String ? d['error'] as String : 'Error (${e.status})');
    } on PostgrestException catch (e) {
      if (e.code == 'P0001') throw AppException(e.message);
      if (e.code == '42501') throw const AppException('No tenés permisos para esto');
      throw AppException('Error del servidor: ${e.message}');
    } on StorageException catch (e) {
      if (e.statusCode == '409') throw const AppException('Ya existe un archivo con ese nombre');
      if (e.statusCode == '403') throw const AppException('No tenés permisos para esto');
      throw AppException('Error con la imagen: ${e.message}');
    } on AuthException catch (e) {
      throw AppException(e.code == 'invalid_credentials' ? 'Usuario o contraseña incorrectos' : e.message);
    } catch (_) {
      throw const AppException('Sin conexión. Revisá tu internet y probá de nuevo');
    }
  }
}
