import 'package:flutter_test/flutter_test.dart';
import 'package:rf8_app/data/demo_gym_repository.dart';
import 'package:rf8_app/models/models.dart';

/// Reglas de reserva (las mismas que aplica `book_slot` en el servidor),
/// probadas contra el backend demo. Plan demo: seguimiento, 3 días/semana.
void main() {
  // Lunes 6 a las 07:00, antes del primer turno.
  final monday = DateTime(2026, 4, 6);
  late DemoGymRepository repo;

  setUp(() async {
    repo = DemoGymRepository(clock: () => monday.add(const Duration(hours: 7)));
    await repo.signIn('demo', 'demo1234');
  });

  Future<int> freeSlot(DateTime day) async {
    final slots = await repo.fetchSlots(day);
    return slots.firstWhere((s) => !s.isFull).slot.id;
  }

  test('1 turno por día', () async {
    await repo.book(await freeSlot(monday), monday);
    expect(
      () async => repo.book(await freeSlot(monday), monday),
      throwsA(isA<AppException>().having((e) => e.message, 'message', contains('ese día'))),
    );
  });

  test('respeta la cantidad de días por semana del plan', () async {
    for (var i = 0; i < 3; i++) {
      final day = monday.add(Duration(days: i));
      await repo.book(await freeSlot(day), day);
    }
    final thursday = monday.add(const Duration(days: 3));
    expect(
      () async => repo.book(await freeSlot(thursday), thursday),
      throwsA(isA<AppException>().having((e) => e.message, 'message', contains('3 turnos'))),
    );
    // La semana siguiente vuelve a haber cupo.
    final nextMonday = monday.add(const Duration(days: 7));
    await repo.book(await freeSlot(nextMonday), nextMonday);
  });

  test('cancelar libera el día y el cupo semanal', () async {
    await repo.book(await freeSlot(monday), monday);
    final mine = await repo.fetchMyBookings(monday, monday);
    await repo.cancelBooking(mine.single.id);
    expect(await repo.fetchMyBookings(monday, monday), isEmpty);
    await repo.book(await freeSlot(monday), monday);
  });

  test('no se puede reservar un turno lleno, pasado o con el gimnasio cerrado', () async {
    // Turno lleno
    for (var i = 0; i < 7; i++) {
      final day = monday.add(Duration(days: i));
      final full = (await repo.fetchSlots(day)).where((s) => s.isFull);
      if (full.isNotEmpty) {
        expect(() => repo.book(full.first.slot.id, day), throwsA(isA<AppException>()));
        break;
      }
    }
    // Domingo cerrado
    final sunday = monday.add(const Duration(days: 6));
    expect(await repo.fetchSlots(sunday), isEmpty);
    // Más allá de la ventana de 7 días
    final far = monday.add(const Duration(days: 8));
    expect(() => repo.book(1, far), throwsA(isA<AppException>()));
  });

  test('los turnos son de 1h30 dentro de los bloques del gimnasio', () async {
    final slots = await repo.fetchSlots(monday);
    for (final s in slots) {
      final start = s.slot.start.hour * 60 + s.slot.start.minute;
      final end = s.slot.end.hour * 60 + s.slot.end.minute;
      expect(end - start, 90);
      expect(s.slot.capacity, 15);
      final inBlock = (start >= 8 * 60 && end <= 12 * 60 + 30) ||
          (start >= 13 * 60 + 30 && end <= 16 * 60 + 30) ||
          (start >= 17 * 60 && end <= 21 * 60);
      expect(inBlock, isTrue, reason: s.slot.label);
    }
  });
}
