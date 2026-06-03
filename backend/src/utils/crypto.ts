import { createHmac, randomBytes, timingSafeEqual, createHash } from 'node:crypto';
import argon2 from 'argon2';

export const randomToken = (bytes = 32) => randomBytes(bytes).toString('base64url');
export const sha256 = (value: string) => createHash('sha256').update(value).digest('hex');
export const hashPassword = (password: string) => argon2.hash(password, { type: argon2.argon2id });
export const verifyPassword = (hash: string, password: string) => argon2.verify(hash, password);
export const signPayload = (secret: string, canonical: string) => createHmac('sha256', secret).update(canonical).digest('base64url');
export function safeEqual(a: string, b: string) {
  const aa = Buffer.from(a); const bb = Buffer.from(b);
  return aa.length === bb.length && timingSafeEqual(aa, bb);
}
