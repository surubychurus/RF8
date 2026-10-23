# RF8 Gimnasio

App de socios de [RF8 Gimnasio](https://www.instagram.com/rf8.gimnasio) en Flutter + backend en Supabase.

```
apps/member/   App de socios (Flutter, Android + iOS)
apps/admin/    App de administración (Flutter, Android + iOS) — roles Gym y Dueño
supabase/      Base de datos, reglas de negocio y Edge Functions (invitaciones por Resend, login)
hosting/       Página /invite de respaldo y archivos .well-known para App Links / Universal Links
.github/       GitHub Actions: compila los APK de las dos apps
```

Backend: proyecto de Supabase **archivo-natacion** (`pnamtuhhettqgkfugzik`). Ese proyecto
también tiene tablas de otra app (`photos`, `albums`, `user_profiles`, `announcements`); RF8 no
las toca (por eso el banner de RF8 usa la tabla `banners`).

## App de administración

| | Gym | Dueño |
|---|:-:|:-:|
| Validar turnos (escáner QR + validación manual) | ✅ | ✅ |
| Ver turnos del día por horario | ✅ | ✅ |
| Socios: alta por invitación (mail Resend), editar, activar/desactivar, notas | ✅ | ✅ |
| Gestionar el plan del socio (asignar, renovar, editar, quitar) | ✅ | ✅ |
| Ver y abrir el WhatsApp del socio | ✅ | ✅ |
| Notificaciones a un socio | ✅ | ✅ |
| Notificaciones globales (crear, editar, borrar) | | ✅ |
| Banner superior (anuncios con imagen, enlace, fechas y orden) | | ✅ |
| Enlaces (Instagram, WhatsApp, web…) | | ✅ |
| Imágenes: subir, editar (rotar, espejar, recortar, tamaño, formato), renombrar, reemplazar, borrar | | ✅ |
| Logo de la app de socios e íconos (imagen por variante, habilitar/deshabilitar) | | ✅ |
| Precios y planes | | ✅ |
| Equipo: cambiar roles · eliminar usuarios | | ✅ |

Los permisos se aplican en la base (RLS + funciones), no sólo en la app.

**Primer dueño:** crear su cuenta como cualquier socio (invitación) y después, en el SQL Editor:
`update public.profiles set role = 'owner' where username = '<usuario>';`. Desde ahí, los
demás roles se asignan desde la app (ficha del socio → Cambiar rol).

**Íconos de la app:** la imagen que sube el dueño se ve enseguida en el selector de la app de
socios. El ícono del teléfono es parte del instalable, así que se actualiza en la próxima
compilación: GitHub Actions descarga esas imágenes y regenera los íconos nativos.

## APK con GitHub Actions

`.github/workflows/build-apk.yml` compila **los dos APK** en cada push a `main`/`claude/**`
(y en PRs): analiza, corre los tests, toma los íconos personalizados y compila.

- Descarga: pestaña **Actions** → la ejecución → **Artifacts** (`rf8-member-apk`, `rf8-admin-apk`).
- Release: `git tag v1.0.0 && git push origin v1.0.0` crea un Release con los dos APK.
- Están firmados con la clave debug (sirven para instalar). Para Play Store hay que configurar
  una clave de firma propia.

## Flujo del socio

1. **Invitación**: el staff da de alta al socio → `send-invite` envía un mail con **Resend**
   desde el dominio de RF8 con un link `https://app.rf8.com.ar/invite?token=…` (y el código
   por si el link no abre la app).
2. **Crear usuario**: el link abre la app → el socio elige **usuario** y **contraseña**.
3. **Ingreso rápido**: la app pide permiso para usar **biometría** (huella / Face ID) y el socio
   define un **PIN de 6 dígitos** (respaldo si la biometría falla o no está disponible).
4. Desde ahí, al abrir la app (o volver tras 1 minuto en segundo plano) se desbloquea con
   biometría o PIN. 5 PIN incorrectos cierran la sesión.

## Secciones

| Sección | Qué hace |
|---|---|
| **Turnos** | Reservar 1 turno por día, hasta 1/2/3/4 por semana según el plan. Cupo de 15 por turno de 1h 30m. Cancelar hasta que empiece. |
| **GO** | Nombre completo arriba, **QR dinámico** en el medio (cambia cada 30 s) y el turno reservado debajo. Lo escanea el staff con la app de administración. |
| **Mi cuenta** | Elegir el **ícono de la app** (6 variantes estilo Discord Nitro), datos personales, contraseña, PIN, biometría, plan y precios, enlaces, cerrar sesión. |

Además: **banner superior** (en Turnos y GO) y **notificaciones** (campana con contador, en tiempo
real), todo gestionado desde la app de administración.

### Planes
Mensuales, de 2 tipos — **Rutina normal** y **Seguimiento** — de 1 a 4 días por semana.
**Precios: placeholder** (`plans.monthly_price = null` → "Precio a definir"). Se cargan en la tabla `plans`.

### Horarios (Montevideo, Uruguay — zona `America/Montevideo`)

| Día | Bloques | Turnos de 1h 30m (tabla `time_slots`) |
|---|---|---|
| Lunes a viernes | 08:00–12:30 · 13:30–16:30 · 17:00–21:00 | 08:00, 09:30, 11:00, 13:30, 15:00, 17:00, 18:30 |
| Sábados | 08:00–12:30 | 08:00, 09:30, 11:00 |
| Domingos | cerrado | — |

⚠️ El bloque 17:00–21:00 dura 4 h, que no es múltiplo de 1h 30m: quedaron 2 turnos
(17:00–18:30 y 18:30–20:00) y sobra 20:00–21:00. Se ajusta en `time_slots` (p. ej. un último
turno 19:30–21:00 superpuesto, o uno de 1 h).

## Marca (placeholders)

| Qué | Dónde |
|---|---|
| Logo | `apps/member/assets/branding/logo.png` (si no existe se muestra "RF8") |
| Tipografías | `apps/member/assets/fonts/` + bloque `fonts:` en `pubspec.yaml` + `Brand.displayFont/bodyFont` |
| Colores | `apps/member/lib/theme/brand.dart` y `apps/admin/lib/theme/brand.dart` (todos PLACEHOLDER) |
| Íconos de la app | `apps/member/tool/generate_icons.py` (genera Android, iOS y vistas previas) |
| Mail de invitación | `supabase/functions/send-invite/index.ts` (`inviteHtml`) |
| Dominio | `app.rf8.com.ar` / `no-reply@rf8.com.ar` (ver abajo) |

## Puesta en marcha

### 1. Correr las apps

Las dos apps ya apuntan al proyecto de Supabase **archivo-natacion**:

```bash
cd apps/member && flutter pub get && flutter run   # app de socios
cd apps/admin  && flutter pub get && flutter run   # administración
```

Modo demo de la app de socios (datos en memoria, sin backend):

```bash
cd apps/member && flutter run --dart-define=DEMO=true
```

En demo: usuario `demo` / clave `demo1234`, o "Tengo una invitación" con el código `DEMO`.

### 2. Backend (Supabase)

Ya está aplicado y desplegado en **archivo-natacion** (migraciones + 5 Edge Functions).
Falta sólo configurar Resend:

```bash
supabase secrets set --project-ref pnamtuhhettqgkfugzik \
  RESEND_API_KEY=re_xxx RESEND_FROM="RF8 Gimnasio <no-reply@tu-dominio>" \
  INVITE_URL_BASE=https://app.rf8.com.ar/invite
```

Para recrearlo en otro proyecto:

```bash
supabase link --project-ref <ref>
supabase db push                                   # tablas, RLS y reglas
cp supabase/.env.example supabase/.env             # completar
supabase secrets set --env-file supabase/.env
supabase functions deploy send-invite
supabase functions deploy invite-info --no-verify-jwt
supabase functions deploy accept-invite --no-verify-jwt
supabase functions deploy sign-in --no-verify-jwt
supabase functions deploy delete-user
```

- En **Auth → Providers → Email**: desactivar "Allow new users to sign up" (sólo por invitación).
- En **Resend**: verificar el dominio de RF8 y usar un remitente de ese dominio en `RESEND_FROM`.
Para apuntar las apps a otro proyecto: `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_KEY=...`.

### 3. Links de invitación

- Publicar `hosting/` en `https://app.rf8.com.ar` (cualquier hosting estático).
- Completar `hosting/.well-known/assetlinks.json` (SHA-256 del certificado de firma) y
  `apple-app-site-association` (Team ID).
- iOS: agregar la capability **Associated Domains** con `applinks:app.rf8.com.ar` en Xcode.
- Si cambia el dominio: `AppConfig.appLinkHost`, `AndroidManifest.xml`, `INVITE_URL_BASE`.

Mientras tanto, el esquema propio `rf8gym://invite?token=…` y el código manual funcionan siempre.

## Seguridad

- Todas las reglas de turnos se validan en el servidor (`book_slot`, `cancel_booking`), con lock
  por turno para que nunca entren más de 15.
- RLS: cada socio sólo ve sus datos; sólo puede editar nombre y teléfono.
- El token de invitación se guarda hasheado (SHA-256), vence a las 72 h y es de un solo uso.
- El login por usuario resuelve el email en el servidor (no se expone).
- QR: `RF8|1|<booking_id>|<step>|<hmac>` con HMAC-SHA256 del secreto del turno y ventana de 30 s;
  una captura de pantalla deja de servir enseguida. `check_in` valida firma, fecha y horario.
- PIN: hash con sal en Keychain/Keystore (`flutter_secure_storage`), nunca sale del teléfono.
