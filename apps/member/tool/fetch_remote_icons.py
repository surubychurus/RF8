"""Descarga las imágenes de íconos que el dueño subió desde la app de administración.

Lee `app_settings.app_icons` de Supabase (lectura pública) y guarda cada imagen
como <dir>/<VariantId>.png. Después `generate_icons.py` las usa para los
íconos nativos de Android/iOS. Lo corre GitHub Actions antes de compilar.

Uso:  SUPABASE_URL=... SUPABASE_KEY=... python3 tool/fetch_remote_icons.py <dir>
"""
import json
import os
import sys
import urllib.request

url = os.environ.get("SUPABASE_URL", "").rstrip("/")
key = os.environ.get("SUPABASE_KEY", "")
out = sys.argv[1] if len(sys.argv) > 1 else "build/remote_icons"

if not url or not key:
    print("Sin SUPABASE_URL/SUPABASE_KEY: se usan los íconos del repositorio.")
    sys.exit(0)

req = urllib.request.Request(
    f"{url}/rest/v1/app_settings?key=eq.app_icons&select=value",
    headers={"apikey": key, "Authorization": f"Bearer {key}"},
)
try:
    with urllib.request.urlopen(req, timeout=30) as r:
        rows = json.load(r)
except Exception as e:  # noqa: BLE001 — el build no debe fallar por esto
    print(f"No se pudo leer app_icons ({e}): se usan los íconos del repositorio.")
    sys.exit(0)

icons = (rows[0]["value"] if rows else None) or {}
os.makedirs(out, exist_ok=True)
count = 0
for variant, image_url in icons.items():
    if not image_url:
        continue
    try:
        with urllib.request.urlopen(image_url, timeout=60) as r, open(os.path.join(out, f"{variant}.png"), "wb") as f:
            f.write(r.read())
        count += 1
        print(f"✓ {variant}")
    except Exception as e:  # noqa: BLE001
        print(f"✗ {variant}: {e}")
print(f"{count} íconos personalizados descargados en {out}")
