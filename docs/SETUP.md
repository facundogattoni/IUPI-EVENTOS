# Puesta en marcha — IUPI Event Manager

## 1. Requisitos

- [Flutter](https://docs.flutter.dev/get-started/install) 3.22 o superior (incluye Dart 3).
- Una cuenta en [Supabase](https://supabase.com) (plan **Free** alcanza).
- Opcional: [Supabase CLI](https://supabase.com/docs/guides/cli) para correr migraciones desde la terminal.

## 2. Crear el proyecto en Supabase

1. Entrá a https://supabase.com → **New project**. Elegí una región cercana (South America / São Paulo).
2. Guardá la contraseña de la base.
3. En **Project Settings → API** copiá:
   - **Project URL** (`https://xxxx.supabase.co`)
   - **anon public key** (`eyJ...`)

## 3. Cargar el esquema de la base

### Opción A — con la CLI (recomendada)

```bash
supabase link --project-ref <TU_PROJECT_REF>
supabase db push          # aplica todo lo de supabase/migrations/
psql "$DATABASE_URL" -f supabase/seed.sql   # datos iniciales
```

### Opción B — desde el panel web

1. Abrí **SQL Editor** en el panel de Supabase.
2. Pegá y ejecutá, **en orden**, cada archivo de `supabase/migrations/`
   (`0001_...` → `0005_...`).
3. Ejecutá `supabase/seed.sql`.

## 4. Crear los usuarios administradores

Facundo, Camila, Emilia y Horacio arrancan como **administradores**.

1. En **Authentication → Users → Add user**, creá cada uno con su email y una contraseña temporal.
2. El trigger `handle_new_user` crea automáticamente su fila en `profiles` con rol `worker`.
3. Promocionalos a admin corriendo en el **SQL Editor**:

   ```sql
   update public.profiles
   set role = 'admin', full_name = 'Facundo'
   where id = (select id from auth.users where email = 'facundo@iupi.com');
   -- repetí para camila@, emilia@, horacio@ ...
   ```

   > `supabase/seed.sql` incluye un bloque comentado que hace esto por email; descomentalo y ajustá
   > los correos reales.

## 5. Configurar y correr la app

El repo versiona el código (`lib/`) y la configuración (`pubspec.yaml`), pero **no** las
carpetas de plataforma (`android/`, `ios/`, `web/`, ...). Se generan una sola vez con
`flutter create .`, que respeta `lib/` y `pubspec.yaml` existentes:

```bash
cd app
flutter create .            # genera android/ ios/ web/ (solo la primera vez)
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ...
```

> Las credenciales del proyecto IUPI ya vienen como valores por defecto (ver `lib/core/config/env.dart`),
> así que en la práctica alcanza con `flutter run`. Los `--dart-define` sirven para apuntar a otro proyecto.

Para no escribir las claves cada vez, podés usar un archivo `env.json` (ignorado por git):

```json
{ "SUPABASE_URL": "https://xxxx.supabase.co", "SUPABASE_ANON_KEY": "eyJ..." }
```

```bash
flutter run --dart-define-from-file=env.json
```

## 6. Builds

- **Android (APK para instalar en los celulares del equipo):**
  `flutter build apk --release --dart-define-from-file=env.json`
- **Web (para usar desde la compu, hosteable gratis en Supabase Storage / Netlify / GitHub Pages):**
  `flutter build web --release --dart-define-from-file=env.json`

## 7. Google Calendar (etapa E6)

Queda documentado el diseño en `docs/ARCHITECTURE.md`. Cuando se implemente, se agregará acá el
alta de credenciales OAuth de Google y el deploy de la Edge Function de sincronización.
