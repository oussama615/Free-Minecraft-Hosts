import { z } from 'zod';
import type { FastifyInstance } from 'fastify';
import { prisma } from '../plugins/prisma.js';
import { sha256 } from '../utils/crypto.js';
export async function deviceRoutes(app: FastifyInstance) {
  app.post('/devices', { preHandler: app.authenticate }, async (req) => { const body = z.object({ token: z.string().min(10), platform: z.enum(['android','ios','web']).default('android') }).parse(req.body); const device = await prisma.deviceToken.create({ data: { userId: req.userContext!.id, tokenHash: sha256(body.token), platform: body.platform } }); return { id: device.id, enabled: device.enabled }; });
}
