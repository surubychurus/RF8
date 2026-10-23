import 'package:flutter/foundation.dart';

import '../data/gym_repository.dart';
import '../models/models.dart';

/// Logo e íconos configurados por el dueño desde la app de administración.
class BrandingController extends ChangeNotifier {
  BrandingController(this.repo);

  final GymRepository repo;
  RemoteBranding value = const RemoteBranding();

  Future<void> load() async {
    try {
      value = await repo.fetchBranding();
      notifyListeners();
    } on AppException {
      // Sin conexión: se usan los recursos que vienen en la app.
    }
  }
}
