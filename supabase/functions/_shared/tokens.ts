import { encodeBase64Url } from "jsr:@std/encoding@1/base64url";
import { encodeHex } from "jsr:@std/encoding@1/hex";

export function randomToken(bytes = 32): string {
  return encodeBase64Url(crypto.getRandomValues(new Uint8Array(bytes)));
}

export async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return encodeHex(new Uint8Array(digest));
}

export const USERNAME_RE = /^[a-z0-9._]{3,20}$/;
export const MIN_PASSWORD = 8;

// Códigos legibles para compartir a mano: RF8-XXXX-XXXX (sin 0/O/1/I).
const CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

export function inviteCode(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(8));
  const chars = [...bytes].map((b) => CODE_ALPHABET[b % CODE_ALPHABET.length]);
  return `RF8-${chars.slice(0, 4).join("")}-${chars.slice(4).join("")}`;
}

/** Normaliza lo que escribe el socio (espacios, minúsculas) para los códigos RF8-. */
export function normalizeToken(token: unknown): string {
  const t = String(token ?? "").trim();
  return /^rf8-[a-z0-9-]+$/i.test(t) ? t.toUpperCase() : t;
}

export const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
