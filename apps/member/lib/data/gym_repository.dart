import '../models/models.dart';

/// Acceso a datos del gimnasio. Implementaciones:
///  * [SupabaseGymRepository]: backend real.
///  * [DemoGymRepository]: datos en memoria para probar la app sin backend.
abstract class GymRepository {
  /// Id del usuario con sesión iniciada, o null.
  String? get currentUserId;

  /// Emite cada vez que cambia la sesión (login, logout, expiración).
  Stream<void> get sessionChanges;

  /// Inicia sesión con usuario (o email) y contraseña.
  Future<void> signIn(String usernameOrEmail, String password);
  Future<void> signOut();

  /// Datos de una invitación recibida por correo.
  Future<InviteInfo> getInvite(String token);

  /// Crea el usuario a partir de la invitación y deja la sesión iniciada.
  Future<void> acceptInvite({
    required String token,
    required String username,
    required String password,
  });

  Future<Profile> fetchProfile();
  Future<Profile> updateProfile({required String fullName, String? phone});
  Future<void> changePassword({required String currentPassword, required String newPassword});

  /// Plan vigente (o el próximo) del socio, null si no tiene.
  Future<Membership?> fetchMembership();
  Future<List<Plan>> fetchPlans();

  Future<List<SlotAvailability>> fetchSlots(DateTime date);
  Future<List<Booking>> fetchMyBookings(DateTime from, DateTime to);
  Future<void> book(int slotId, DateTime date);
  Future<void> cancelBooking(String bookingId);

  // --- Contenido gestionado por el dueño -----------------------------------------

  /// Logo e íconos. Se puede leer sin sesión (pantalla de login).
  Future<RemoteBranding> fetchBranding();
  Future<List<BannerItem>> fetchBanners();
  Future<List<AppLink>> fetchLinks();

  /// Notificaciones personales y globales, con su estado de lectura.
  Future<List<AppNotification>> fetchNotifications();
  Future<void> markNotificationsRead(Iterable<String> ids);

  /// Emite cuando llega una notificación nueva (tiempo real).
  Stream<void> get notificationEvents;
}
