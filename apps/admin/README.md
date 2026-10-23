# RF8 — app de administración

Ver el [README principal](../../README.md) (tabla de permisos por rol).

```
lib/
  config/     AppConfig (Supabase, bucket de imágenes, código de país)
  theme/      Brand (colores PLACEHOLDER) y tema
  data/       AdminApi (todas las operaciones), modelos y sesión con roles
  screens/
    validate/ Escáner de QR y turnos del día
    members/  Socios: lista, alta, ficha, plan, notificaciones
    owner/    Sólo dueños: banner, enlaces, notificaciones globales, imágenes,
              logo e íconos, precios, equipo
  widgets/    Comunes, editor de imágenes y selector de imágenes
```

```bash
flutter run      # apunta a Supabase archivo-natacion por defecto
flutter test
```
