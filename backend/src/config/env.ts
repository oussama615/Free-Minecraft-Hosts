import 'dotenv/config';
import { z } from 'zod';

const schema = z.object({
  DATABASE_URL: z.string().url(),
  JWT_SECRET: z.string().min(32),
  JWT_REFRESH_SECRET: z.string().min(32),
  CORS_ORIGIN: z.string().default('http://localhost:3000'),
  PORT: z.coerce.number().default(3000),
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  AGENT_PAIRING_TOKEN_TTL_MINUTES: z.coerce.number().default(15),
  AGENT_MESSAGE_SKEW_SECONDS: z.coerce.number().default(60),
  FCM_MODE: z.enum(['mock', 'firebase']).default('mock'),
});

export const env = schema.parse(process.env);
export const corsOrigins = env.CORS_ORIGIN.split(',').map((value) => value.trim()).filter(Boolean);
