import { z } from 'zod';
import type { FastifyInstance } from 'fastify';
import { prisma } from '../plugins/prisma.js';
import { audit } from '../services/audit.js';
export async function alertRoutes(app: FastifyInstance) {
  app.get('/alerts', { preHandler: app.requireRole('STAFF') }, async (req) => ({ alerts: await prisma.alert.findMany({ where: { OR: [{ server: { workspaceId: req.userContext!.workspaceId } }, { serverId: null }] }, orderBy: { createdAt: 'desc' }, take: 100 }) }));
  app.get('/servers/:id/alerts', { preHandler: app.requireRole('STAFF') }, async (req) => { const id = await serverId(req); return { alerts: await prisma.alert.findMany({ where: { serverId: id }, orderBy: { createdAt: 'desc' }, take: 100 }) }; });
  app.post('/alerts/:id/acknowledge', { preHandler: app.requireRole('ADMIN') }, async (req) => { const { id } = z.object({ id: z.string() }).parse(req.params); const alert = await prisma.alert.update({ where: { id }, data: { acknowledgedAt: new Date(), acknowledgedBy: req.userContext!.id } }); await audit({ userId: req.userContext!.id, serverId: alert.serverId ?? undefined, action: 'alert.ack', target: id }); return { alert }; });
}
async function serverId(req: any) { const { id } = z.object({ id: z.string() }).parse(req.params); return (await prisma.server.findFirstOrThrow({ where: { id, workspaceId: req.userContext.workspaceId } })).id; }
