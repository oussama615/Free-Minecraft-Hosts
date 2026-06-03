import { z } from 'zod';
import type { FastifyInstance } from 'fastify';
import { prisma } from '../plugins/prisma.js';
export async function logRoutes(app: FastifyInstance) {
  app.get('/servers/:id/logs', { preHandler: app.requireRole('ADMIN') }, async (req) => ({ logs: await prisma.consoleLog.findMany({ where: { serverId: await serverId(req) }, orderBy: { createdAt: 'desc' }, take: 200 }) }));
  app.get('/servers/:id/security-events', { preHandler: app.requireRole('STAFF') }, async (req) => ({ events: await prisma.securityEvent.findMany({ where: { serverId: await serverId(req) }, orderBy: { createdAt: 'desc' }, take: 200 }) }));
  app.get('/audit-logs', { preHandler: app.requireRole('ADMIN') }, async (req) => ({ logs: await prisma.auditLog.findMany({ where: { OR: [{ user: { workspaceId: req.userContext!.workspaceId } }, { userId: null }] }, orderBy: { createdAt: 'desc' }, take: 200 }) }));
}
async function serverId(req: any) { const { id } = z.object({ id: z.string() }).parse(req.params); return (await prisma.server.findFirstOrThrow({ where: { id, workspaceId: req.userContext.workspaceId } })).id; }
