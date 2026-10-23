# RF8 — app de socios

Ver el [README principal](../../README.md).

```
lib/
  config/     AppConfig (entorno, modo demo) y GymConfig (reglas visibles)
  theme/      Brand (colores, tipografías y logo placeholder) y tema
  models/     Plan, Membership, Profile, TimeSlot, Booking…
  data/       GymRepository + implementaciones Supabase y Demo
  services/   Sesión/bloqueo, PIN + biometría, QR dinámico, ícono de la app, deep links
  screens/    auth · lock · turnos · go · cuenta · home
  widgets/    PinPad, BrandLogo, comunes
```

```bash
flutter test      # reglas de reserva, QR, deep links y flujo completo de UI
flutter analyze
```
