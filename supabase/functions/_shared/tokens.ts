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
