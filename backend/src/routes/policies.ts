import { z } from 'zod';
import type { FastifyInstance } from 'fastify';
import { prisma } from '../plugins/prisma.js';
import { audit } from '../services/audit.js';
const patch = z.object({ policies: z.array(z.object({ command: z.string().min(1), action: z.enum(['BLOCK','ALERT_ONLY','REQUIRE_CONFIRMATION','ALLOW']) })).optional(), allowedOps: z.array(z.object({ uuid: z.string(), name: z.string().optional() })).optional(), panicMode: z.boolean().optional() });
export async function policyRoutes(app: FastifyInstance) {
  app.get('/servers/:id/security-policy', { preHandler: app.requireRole('ADMIN') }, async (req) => { const server = await getServer(req); return { panicMode: server.panicMode, policies: await prisma.commandPolicy.findMany({ where: { serverId: server.id } }), allowedOps: await prisma.allowedOp.findMany({ where: { serverId: server.id } }) }; });
  app.patch('/servers/:id/security-policy', { preHandler: app.requireRole('OWNER') }, async (req) => { const server = await getServer(req); const body = patch.parse(req.body); if (body.policies) for (const p of body.policies) await prisma.commandPolicy.upsert({ where: { serverId_command: { serverId: server.id, command: p.command.toLowerCase() } }, update: { action: p.action }, create: { serverId: server.id, command: p.command.toLowerCase(), action: p.action } }); if (body.allowedOps) { await prisma.allowedOp.deleteMany({ where: { serverId: server.id } }); for (const op of body.allowedOps) await prisma.allowedOp.create({ data: { serverId: server.id, ...op } }); } if (body.panicMode !== undefined) await prisma.server.update({ where: { id: server.id }, data: { panicMode: body.panicMode } }); await audit({ userId: req.userContext!.id, serverId: server.id, action: 'security_policy.update' }); return { ok: true }; });
}
async function getServer(req: any) { const { id } = z.object({ id: z.string() }).parse(req.params); return prisma.server.findFirstOrThrow({ where: { id, workspaceId: req.userContext.workspaceId } }); }
