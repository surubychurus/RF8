import 'package:flutter/material.dart';

import '../config/gym_config.dart';
import '../data/gym_repository.dart';
import '../models/models.dart';

/// Datos del socio compartidos por las 3 secciones (Turnos, GO, Mi cuenta).
class MemberController extends ChangeNotifier {
  MemberController(this.repo);

  final GymRepository repo;

  Profile? profile;
  Membership? membership;
  List<Plan> plans = const [];
  List<Booking> bookings = const [];
  bool loading = false;
  String? error;

  static DateTime get today => DateUtils.dateOnly(DateTime.now());
  static DateTime mondayOf(DateTime d) =>
      DateUtils.dateOnly(d).subtract(Duration(days: d.weekday - 1));

  /// Rango cubierto por [bookings]: desde el lunes de esta semana hasta el
  /// domingo de la semana del último día reservable.
  DateTime get _from => mondayOf(today);
  DateTime get _to =>
      mondayOf(today.add(const Duration(days: GymConfig.bookingWindowDays))).add(const Duration(days: 6));

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        repo.fetchProfile(),
        repo.fetchMembership(),
        repo.fetchPlans(),
        repo.fetchMyBookings(_from, _to),
      ]);
      profile = results[0] as Profile;
      membership = results[1] as Membership?;
      plans = results[2] as List<Plan>;
      bookings = results[3] as List<Booking>;
    } on AppException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshBookings() async {
    bookings = await repo.fetchMyBookings(_from, _to);
    notifyListeners();
  }

  Booking? bookingOn(DateTime day) {
    final d = DateUtils.dateOnly(day);
    for (final b in bookings) {
      if (b.isActive && b.date == d) return b;
    }
    return null;
  }

  int usedInWeekOf(DateTime day) {
    final monday = mondayOf(day);
    final sunday = monday.add(const Duration(days: 6));
    return bookings
        .where((b) => b.isActive && !b.date.isBefore(monday) && !b.date.isAfter(sunday))
        .length;
  }

  int? get weeklyQuota => membership?.plan.daysPerWeek;

  /// Turno de hoy (para el QR) o el próximo reservado.
  Booking? get todayBooking => bookingOn(today);

  Booking? get nextBooking {
    final now = DateTime.now();
    for (final b in bookings) {
      if (b.status == BookingStatus.booked && b.endsAt.isAfter(now)) return b;
    }
    return null;
  }

  Future<void> book(int slotId, DateTime date) async {
    await repo.book(slotId, date);
    await refreshBookings();
  }

  Future<void> cancel(Booking b) async {
    await repo.cancelBooking(b.id);
    await refreshBookings();
  }

  Future<void> updateProfile({required String fullName, String? phone}) async {
    profile = await repo.updateProfile(fullName: fullName, phone: phone);
    notifyListeners();
  }
}
