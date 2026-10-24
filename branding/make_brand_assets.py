"""Genera las máscaras del logo de RF8 a partir de logo_original.png.

  emblem_mask.png  emblema (ícono) en alta resolución, cuadrado, blanco sobre transparente
  logo_mask.png    logo completo (emblema + RF8 + "Centro Integral de Entrenamiento")

Las apps y los íconos se generan desde estas máscaras (ver apps/*/tool/generate_icons.py).
Uso: python3 branding/make_brand_assets.py
"""
import os

import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ORANGE = np.array([0xEE, 0x6E, 0x31], float)
NAVY = np.array([0x10, 0x1A, 0x33], float)
SCALE = 6  # el original es chico: se agranda y se re-nitidiza el borde


def shape_alpha(img):
    rgb = np.asarray(img.convert("RGB")).astype(float)
    d = NAVY - ORANGE
    t = ((rgb - ORANGE) @ d) / (d @ d)
    return Image.fromarray((np.clip(t, 0, 1) * 255).astype("uint8"), "L")


def crisp(mask, scale=SCALE):
    big = mask.resize((mask.width * scale, mask.height * scale), Image.BICUBIC)
    big = big.filter(ImageFilter.GaussianBlur(scale * 0.35))
    a = np.asarray(big).astype(float) / 255
    a = 1 / (1 + np.exp(-(a - 0.5) * 14))  # borde nítido pero suave
    return Image.fromarray((a * 255).astype("uint8"), "L")


def bbox(mask, threshold=128):
    a = np.asarray(mask) > threshold
    ys, xs = np.where(a)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def main():
    mask = shape_alpha(Image.open(os.path.join(HERE, "logo_original.png")))

    # Logo completo
    x0, y0, x1, y1 = bbox(mask)
    full = crisp(mask.crop((x0, y0, x1, y1)))
    full.save(os.path.join(HERE, "logo_mask.png"))

    # Emblema: la parte izquierda, antes de la "R", sin el texto de abajo
    a = np.asarray(mask) > 128
    rows_used = np.where(a.any(axis=1))[0]
    top_end = rows_used[0]
    while top_end < a.shape[0] and a[top_end].any():
        top_end += 1  # primera fila vacía: separa el logo del texto
    a = a.copy()
    a[top_end:] = False
    left = a[:, : x0 + (x1 - x0) // 3]
    cols = np.where(left.any(axis=0))[0]
    # termina en la primera columna vacía después del emblema
    end = cols[0]
    while end < left.shape[1] and left[:, end].any():
        end += 1
    rows = np.where(a[:, cols[0]:end].any(axis=1))[0]
    em = mask.crop((cols[0], rows[0], end, rows[-1] + 1))
    em = crisp(em)
    side = max(em.size)
    square = Image.new("L", (side, side), 0)
    square.paste(em, ((side - em.width) // 2, (side - em.height) // 2))
    square.save(os.path.join(HERE, "emblem_mask.png"))
    print("logo", full.size, "emblema", square.size)


if __name__ == "__main__":
    main()
