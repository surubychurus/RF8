import 'package:flutter/material.dart';

enum Role {
  member('Socio'),
  gym('Gym'),
  owner('Dueño');

  const Role(this.label);
  final String label;

  static Role parse(String? v) => Role.values.firstWhere((r) => r.name == v, orElse: () => Role.member);
}

class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => message;
}

DateTime _date(String s) => DateTime.parse(s);
TimeOfDay _time(String s) {
  final p = s.split(':');
  return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
}

String fmtTime(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

class Plan {
  const Plan({
    required this.id,
    required this.kind,
    required this.daysPerWeek,
    required this.name,
    this.description,
    this.monthlyPrice,
    required this.active,
  });

  final String id;
  final String kind; // normal | seguimiento
  final int daysPerWeek;
  final String name;
  final String? description;
  final double? monthlyPrice;
  final bool active;

  String get kindLabel => kind == 'seguimiento' ? 'Seguimiento' : 'Rutina normal';

  factory Plan.fromJson(Map<String, dynamic> j) => Plan(
        id: j['id'] as String,
        kind: j['kind'] as String,
        daysPerWeek: (j['days_per_week'] as num).toInt(),
        name: j['name'] as String,
        description: j['description'] as String?,
        monthlyPrice: (j['monthly_price'] as num?)?.toDouble(),
        active: j['active'] as bool? ?? true,
      );
}

class Membership {
  const Membership({required this.id, required this.plan, required this.startsOn, required this.endsOn});

  final String id;
  final Plan plan;
  final DateTime startsOn;
  final DateTime endsOn;

  bool get isCurrent {
    final today = DateUtils.dateOnly(DateTime.now());
    return !today.isBefore(startsOn) && !today.isAfter(endsOn);
  }

  factory Membership.fromJson(Map<String, dynamic> j) => Membership(
        id: j['id'] as String,
        plan: Plan.fromJson(j['plans'] as Map<String, dynamic>),
        startsOn: _date(j['starts_on'] as String),
        endsOn: _date(j['ends_on'] as String),
      );
}

class Member {
  const Member({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    this.phone,
    this.notes,
    required this.role,
    required this.active,
    required this.createdAt,
    this.memberships = const [],
  });

  final String id;
  final String username;
  final String fullName;
  final String email;
  final String? phone;
  final String? notes;
  final Role role;
  final bool active;
  final DateTime createdAt;
  final List<Membership> memberships;

  /// Plan vigente hoy, o el próximo a empezar.
  Membership? get currentMembership {
    final today = DateUtils.dateOnly(DateTime.now());
    final valid = memberships.where((m) => !m.endsOn.isBefore(today)).toList()
      ..sort((a, b) => a.startsOn.compareTo(b.startsOn));
    return valid.isEmpty ? null : valid.first;
  }

  factory Member.fromJson(Map<String, dynamic> j) => Member(
        id: j['id'] as String,
        username: j['username'] as String,
        fullName: j['full_name'] as String,
        email: j['email'] as String,
        phone: j['phone'] as String?,
        notes: j['notes'] as String?,
        role: Role.parse(j['role'] as String?),
        active: j['active'] as bool? ?? true,
        createdAt: DateTime.parse(j['created_at'] as String),
        memberships: ((j['memberships'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(Membership.fromJson)
            .toList(),
      );
}

class Invitation {
  const Invitation({
    required this.id,
    this.email,
    required this.fullName,
    this.phone,
    required this.expiresAt,
    this.acceptedAt,
  });

  final String id;

  /// Opcional: si no se carga, el socio lo completa al crear su usuario.
  final String? email;
  final String fullName;
  final String? phone;
  final DateTime expiresAt;
  final DateTime? acceptedAt;

  bool get expired => expiresAt.isBefore(DateTime.now());

  factory Invitation.fromJson(Map<String, dynamic> j) => Invitation(
        id: j['id'] as String,
        email: j['email'] as String?,
        fullName: j['full_name'] as String,
        phone: j['phone'] as String?,
        expiresAt: DateTime.parse(j['expires_at'] as String),
        acceptedAt: j['accepted_at'] == null ? null : DateTime.parse(j['accepted_at'] as String),
      );
}

/// Código de invitación recién generado (sólo se puede ver en ese momento).
class InviteCode {
  const InviteCode({required this.code, required this.invitationId, required this.expiresAt});

  final String code;
  final String invitationId;
  final DateTime expiresAt;

  factory InviteCode.fromJson(Map<String, dynamic> j) => InviteCode(
        code: j['code'] as String,
        invitationId: j['invitation_id'] as String,
        expiresAt: DateTime.parse(j['expires_at'] as String).toLocal(),
      );
}

class TimeSlot {
  const TimeSlot({required this.id, required this.start, required this.end, required this.capacity});

  final int id;
  final TimeOfDay start;
  final TimeOfDay end;
  final int capacity;

  String get label => '${fmtTime(start)} – ${fmtTime(end)}';

  factory TimeSlot.fromJson(Map<String, dynamic> j) => TimeSlot(
        id: (j['id'] as num).toInt(),
        start: _time(j['starts_at'] as String),
        end: _time(j['ends_at'] as String),
        capacity: (j['capacity'] as num).toInt(),
      );
}

class DayBooking {
  const DayBooking({
    required this.id,
    required this.date,
    required this.status,
    required this.slot,
    required this.userId,
    required this.fullName,
    this.phone,
    this.checkedInAt,
  });

  final String id;
  final DateTime date;
  final String status; // booked | attended | cancelled
  final TimeSlot slot;
  final String userId;
  final String fullName;
  final String? phone;
  final DateTime? checkedInAt;

  bool get attended => status == 'attended';

  factory DayBooking.fromJson(Map<String, dynamic> j) {
    final p = j['profiles'] as Map<String, dynamic>;
    return DayBooking(
      id: j['id'] as String,
      date: _date(j['date'] as String),
      status: j['status'] as String,
      slot: TimeSlot.fromJson(j['time_slots'] as Map<String, dynamic>),
      userId: j['user_id'] as String,
      fullName: p['full_name'] as String,
      phone: p['phone'] as String?,
      checkedInAt: j['checked_in_at'] == null ? null : DateTime.parse(j['checked_in_at'] as String),
    );
  }
}

class CheckInResult {
  const CheckInResult({required this.fullName, required this.slotLabel});

  final String fullName;
  final String slotLabel;
}

class Announcement {
  Announcement({
    this.id,
    required this.title,
    this.body,
    this.imageUrl,
    this.linkUrl,
    this.active = true,
    this.startsAt,
    this.endsAt,
    this.sortOrder = 0,
  });

  final String? id;
  String title;
  String? body;
  String? imageUrl;
  String? linkUrl;
  bool active;
  DateTime? startsAt;
  DateTime? endsAt;
  int sortOrder;

  bool get isLive {
    final now = DateTime.now();
    return active && (startsAt == null || !startsAt!.isAfter(now)) && (endsAt == null || endsAt!.isAfter(now));
  }

  factory Announcement.fromJson(Map<String, dynamic> j) => Announcement(
        id: j['id'] as String,
        title: j['title'] as String,
        body: j['body'] as String?,
        imageUrl: j['image_url'] as String?,
        linkUrl: j['link_url'] as String?,
        active: j['active'] as bool,
        startsAt: j['starts_at'] == null ? null : DateTime.parse(j['starts_at'] as String).toLocal(),
        endsAt: j['ends_at'] == null ? null : DateTime.parse(j['ends_at'] as String).toLocal(),
        sortOrder: (j['sort_order'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'body': body,
        'image_url': imageUrl,
        'link_url': linkUrl,
        'active': active,
        'starts_at': startsAt?.toUtc().toIso8601String(),
        'ends_at': endsAt?.toUtc().toIso8601String(),
        'sort_order': sortOrder,
      };
}

class AppLink {
  AppLink({this.id, required this.label, required this.url, this.icon = 'link', this.active = true, this.sortOrder = 0});

  final String? id;
  String label;
  String url;
  String icon;
  bool active;
  int sortOrder;

  static const icons = {
    'instagram': Icons.camera_alt_outlined,
    'whatsapp': Icons.chat_outlined,
    'web': Icons.language,
    'mail': Icons.mail_outline,
    'map': Icons.place_outlined,
    'link': Icons.link,
  };

  IconData get iconData => icons[icon] ?? Icons.link;

  factory AppLink.fromJson(Map<String, dynamic> j) => AppLink(
        id: j['id'] as String,
        label: j['label'] as String,
        url: j['url'] as String,
        icon: j['icon'] as String,
        active: j['active'] as bool,
        sortOrder: (j['sort_order'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {
        'label': label,
        'url': url,
        'icon': icon,
        'active': active,
        'sort_order': sortOrder,
      };
}

class AppNotification {
  const AppNotification({
    required this.id,
    this.userId,
    required this.title,
    required this.body,
    this.linkUrl,
    required this.createdAt,
  });

  final String id;
  final String? userId;
  final String title;
  final String body;
  final String? linkUrl;
  final DateTime createdAt;

  bool get isGlobal => userId == null;

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        userId: j['user_id'] as String?,
        title: j['title'] as String,
        body: j['body'] as String,
        linkUrl: j['link_url'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
      );
}

class MediaFile {
  const MediaFile({required this.path, required this.url, this.size, this.updatedAt, this.mimeType});

  final String path;
  final String url;
  final int? size;
  final DateTime? updatedAt;
  final String? mimeType;

  String get name => path.split('/').last;
  String get folder => path.contains('/') ? path.substring(0, path.lastIndexOf('/')) : '';
}
