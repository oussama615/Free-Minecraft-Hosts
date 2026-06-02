import { z } from 'zod';
import type { Prisma } from '@prisma/client';
import type { FastifyInstance } from 'fastify';
import { prisma } from '../plugins/prisma.js';
import { audit } from '../services/audit.js';
import { randomToken } from '../utils/crypto.js';
import { sendCommandToAgent } from '../services/agentHub.js';
const commandSchema = z.object({ command: z.string().min(1).max(240), confirmed: z.boolean().default(false) });
export async function commandRoutes(app: FastifyInstance) {
  app.post('/servers/:id/commands', { preHandler: app.requireRole('OWNER') }, async (req) => { const server = await getServer(req); const body = commandSchema.parse(req.body); const root = body.command.trim().toLowerCase().split(/\s+/).slice(0, 2).join(' '); const policy = await prisma.commandPolicy.findFirst({ where: { serverId: server.id, OR: [{ command: root }, { command: root.split(' ')[0] }] } }); if (policy?.action === 'BLOCK' || (policy?.action === 'REQUIRE_CONFIRMATION' && !body.confirmed)) { await prisma.securityEvent.create({ data: { serverId: server.id, type: 'REMOTE_COMMAND_POLICY', action: 'blocked_or_requires_confirmation', metadata: { command: body.command, policy } as Prisma.InputJsonValue } }); return { status: policy.action === 'BLOCK' ? 'BLOCKED' : 'REQUIRES_CONFIRMATION' }; } const cmd = await prisma.remoteCommand.create({ data: { serverId: server.id, userId: req.userContext!.id, command: body.command, nonce: randomToken(16) } }); const sent = sendCommandToAgent(server.id, cmd); await prisma.remoteCommand.update({ where: { id: cmd.id }, data: { status: sent ? 'SENT' : 'PENDING', sentAt: sent ? new Date() : undefined } }); await audit({ userId: req.userContext!.id, serverId: server.id, action: 'remote_command.request', target: cmd.id, metadata: { command: body.command } as Prisma.InputJsonValue }); return { commandId: cmd.id, status: sent ? 'SENT' : 'PENDING' }; });
  app.get('/servers/:id/commands', { preHandler: app.requireRole('ADMIN') }, async (req) => ({ commands: await prisma.remoteCommand.findMany({ where: { serverId: (await getServer(req)).id }, orderBy: { requestedAt: 'desc' }, take: 100 }) }));
  app.get('/servers/:id/commands/:commandId', { preHandler: app.requireRole('ADMIN') }, async (req) => { const server = await getServer(req); const { commandId } = z.object({ commandId: z.string() }).parse(req.params); return { command: await prisma.remoteCommand.findFirstOrThrow({ where: { id: commandId, serverId: server.id } }) }; });
}
async function getServer(req: any) { const { id } = z.object({ id: z.string() }).parse(req.params); return prisma.server.findFirstOrThrow({ where: { id, workspaceId: req.userContext.workspaceId } }); }
