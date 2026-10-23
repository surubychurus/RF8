import 'package:flutter/material.dart';

enum PlanKind {
  normal('Rutina normal'),
  seguimiento('Seguimiento');

  const PlanKind(this.label);
  final String label;

  static PlanKind parse(String value) =>
      PlanKind.values.firstWhere((k) => k.name == value, orElse: () => PlanKind.normal);
}

class Plan {
  const Plan({
    required this.id,
    required this.kind,
    required this.daysPerWeek,
    required this.name,
    this.description,
    this.monthlyPrice,
  });

  final String id;
  final PlanKind kind;
  final int daysPerWeek;
  final String name;
  final String? description;

  /// null = precio a definir (placeholder).
  final double? monthlyPrice;

  factory Plan.fromJson(Map<String, dynamic> j) => Plan(
        id: j['id'] as String,
        kind: PlanKind.parse(j['kind'] as String),
        daysPerWeek: (j['days_per_week'] as num).toInt(),
        name: j['name'] as String,
        description: j['description'] as String?,
        monthlyPrice: (j['monthly_price'] as num?)?.toDouble(),
      );
}

class Membership {
  const Membership({required this.plan, required this.startsOn, required this.endsOn});

  final Plan plan;
  final DateTime startsOn;
  final DateTime endsOn;

  bool isActiveOn(DateTime day) {
    final d = DateUtils.dateOnly(day);
    return !d.isBefore(startsOn) && !d.isAfter(endsOn);
  }
}

class Profile {
  const Profile({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    this.phone,
  });

  final String id;
  final String username;
  final String fullName;
  final String email;
  final String? phone;

  Profile copyWith({String? fullName, String? phone}) => Profile(
        id: id,
        username: username,
        fullName: fullName ?? this.fullName,
        email: email,
        phone: phone ?? this.phone,
      );

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id'] as String,
        username: j['username'] as String,
        fullName: j['full_name'] as String,
        email: j['email'] as String,
        phone: j['phone'] as String?,
      );
}

class TimeSlot {
  const TimeSlot({required this.id, required this.start, required this.end, required this.capacity});

  final int id;
  final TimeOfDay start;
  final TimeOfDay end;
  final int capacity;

  String get label => '${_fmt(start)} – ${_fmt(end)}';

  DateTime startOn(DateTime day) => DateTime(day.year, day.month, day.day, start.hour, start.minute);
  DateTime endOn(DateTime day) => DateTime(day.year, day.month, day.day, end.hour, end.minute);

  static TimeOfDay parseTime(String s) {
    final p = s.split(':');
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  static String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class SlotAvailability {
  const SlotAvailability({required this.slot, required this.booked});

  final TimeSlot slot;
  final int booked;

  int get remaining => (slot.capacity - booked).clamp(0, slot.capacity);
  bool get isFull => remaining == 0;
}

enum BookingStatus {
  booked,
  cancelled,
  attended;

  static BookingStatus parse(String v) =>
      BookingStatus.values.firstWhere((s) => s.name == v, orElse: () => BookingStatus.booked);
}

class Booking {
  const Booking({
    required this.id,
    required this.date,
    required this.slot,
    required this.status,
    required this.qrSecret,
  });

  final String id;
  final DateTime date;
  final TimeSlot slot;
  final BookingStatus status;
  final String qrSecret;

  bool get isActive => status != BookingStatus.cancelled;
  DateTime get startsAt => slot.startOn(date);
  DateTime get endsAt => slot.endOn(date);
}

class InviteInfo {
  const InviteInfo({required this.email, required this.fullName, required this.expiresAt});

  final String email;
  final String fullName;
  final DateTime expiresAt;
}

/// Error de negocio con un mensaje listo para mostrar al usuario.
class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Anuncio del banner superior (lo gestiona el dueño).
class BannerItem {
  const BannerItem({required this.id, required this.title, this.body, this.imageUrl, this.linkUrl});

  final String id;
  final String title;
  final String? body;
  final String? imageUrl;
  final String? linkUrl;

  factory BannerItem.fromJson(Map<String, dynamic> j) => BannerItem(
        id: j['id'] as String,
        title: j['title'] as String,
        body: j['body'] as String?,
        imageUrl: j['image_url'] as String?,
        linkUrl: j['link_url'] as String?,
      );
}

/// Enlace (Instagram, WhatsApp, web…).
class AppLink {
  const AppLink({required this.label, required this.url, required this.icon});

  final String label;
  final String url;
  final String icon;

  IconData get iconData => switch (icon) {
        'instagram' => Icons.camera_alt_outlined,
        'whatsapp' => Icons.chat_outlined,
        'web' => Icons.language,
        'mail' => Icons.mail_outline,
        'map' => Icons.place_outlined,
        _ => Icons.link,
      };

  factory AppLink.fromJson(Map<String, dynamic> j) =>
      AppLink(label: j['label'] as String, url: j['url'] as String, icon: j['icon'] as String);
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.linkUrl,
    required this.createdAt,
    required this.isGlobal,
    this.read = false,
  });

  final String id;
  final String title;
  final String body;
  final String? linkUrl;
  final DateTime createdAt;
  final bool isGlobal;
  final bool read;

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        title: title,
        body: body,
        linkUrl: linkUrl,
        createdAt: createdAt,
        isGlobal: isGlobal,
        read: read ?? this.read,
      );

  factory AppNotification.fromJson(Map<String, dynamic> j, {bool read = false}) => AppNotification(
        id: j['id'] as String,
        title: j['title'] as String,
        body: j['body'] as String,
        linkUrl: j['link_url'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
        isGlobal: j['user_id'] == null,
        read: read,
      );
}

/// Marca configurable desde la app de administración.
class RemoteBranding {
  const RemoteBranding({this.logoUrl, this.iconUrls = const {}, this.enabledIcons});

  final String? logoUrl;

  /// Imagen personalizada de cada variante de ícono (id → URL).
  final Map<String, String> iconUrls;

  /// Variantes habilitadas; null = todas.
  final List<String>? enabledIcons;

  factory RemoteBranding.fromSettings(Map<String, dynamic> s) => RemoteBranding(
        logoUrl: s['logo_url'] as String?,
        iconUrls: {
          for (final e in ((s['app_icons'] as Map?) ?? const {}).entries)
            if (e.value is String) e.key as String: e.value as String,
        },
        enabledIcons: (s['enabled_icons'] as List?)?.cast<String>(),
      );
}
