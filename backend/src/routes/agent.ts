import { z } from 'zod';
import type { Prisma } from '@prisma/client';
import type { FastifyInstance } from 'fastify';
import { prisma } from '../plugins/prisma.js';
import { pushProvider } from '../services/push.js';
import { randomToken, safeEqual, sha256, signPayload } from '../utils/crypto.js';
import { env } from '../config/env.js';
import { registerAgent } from '../services/agentHub.js';

const pairSchema = z.object({ pairingToken: z.string().min(20), publicIdentity: z.string().min(8), serverInfo: z.object({ version: z.string().optional(), address: z.string().optional() }).optional() });
const envelope = z.object({ type: z.string(), serverId: z.string(), timestamp: z.number(), nonce: z.string(), payload: z.any(), signature: z.string() });
const seenNonces = new Map<string, number>();

export async function agentRoutes(app: FastifyInstance) {
  app.post('/agent/pair', async (req) => {
    const body = pairSchema.parse(req.body);
    const credential = await prisma.agentCredential.findFirst({ where: { pairingTokenHash: sha256(body.pairingToken), pairingExpiresAt: { gt: new Date() }, revokedAt: null }, include: { server: true } });
    if (!credential) throw app.httpErrors.unauthorized('Invalid pairing token');
    const agentSecret = randomToken(48);
    await prisma.agentCredential.update({ where: { id: credential.id }, data: { publicIdentity: body.publicIdentity, secretHash: sha256(agentSecret), pairingTokenHash: null, pairingExpiresAt: null, lastRotatedAt: new Date() } });
    await prisma.server.update({ where: { id: credential.serverId }, data: { agentPublicIdentity: body.publicIdentity, version: body.serverInfo?.version, address: body.serverInfo?.address } });
    app.log.info({ serverId: credential.serverId, publicIdentity: body.publicIdentity }, 'Agent paired');
    return { serverId: credential.serverId, agentSecret, websocketUrl: '/agent/ws' };
  });

  app.get('/agent/ws', { websocket: true }, async (connection, req) => {
    const serverId = String((req.query as { serverId?: string; identity?: string }).serverId ?? '');
    const publicIdentity = String((req.query as { serverId?: string; identity?: string }).identity ?? '');
    const credential = await prisma.agentCredential.findFirst({ where: { serverId, publicIdentity, revokedAt: null, pairingTokenHash: null }, orderBy: { createdAt: 'desc' } });
    if (!credential) {
      app.log.warn({ serverId, publicIdentity }, 'Rejected agent websocket connection');
      return connection.socket.close(1008, 'not paired');
    }

    const secret = credential.secretHash;
    registerAgent(serverId, connection.socket, secret);
    await prisma.server.update({ where: { id: serverId }, data: { status: 'ONLINE', lastSeenAt: new Date() } });
    app.log.info({ serverId, publicIdentity }, 'Agent websocket connected');

    connection.socket.on('message', async (raw) => {
      try {
        const msg = envelope.parse(JSON.parse(raw.toString()));
        if (msg.serverId !== serverId || !verifyEnvelope(msg, secret)) throw new Error('bad signature');
        await handleAgentMessage(msg);
      } catch (error) {
        app.log.warn({ serverId, error }, 'Rejected agent message');
      }
    });
    connection.socket.on('close', () => app.log.info({ serverId }, 'Agent websocket disconnected'));
  });
}

function verifyEnvelope(msg: z.infer<typeof envelope>, secret: string) {
  const now = Date.now();
  if (Math.abs(now - msg.timestamp) > env.AGENT_MESSAGE_SKEW_SECONDS * 1000) return false;
  const key = `${msg.serverId}:${msg.nonce}`;
  if (seenNonces.has(key)) return false;
  seenNonces.set(key, now);
  for (const [nonce, timestamp] of seenNonces) if (now - timestamp > env.AGENT_MESSAGE_SKEW_SECONDS * 2000) seenNonces.delete(nonce);
  const canonical = `${msg.serverId}.${msg.timestamp}.${msg.nonce}.${JSON.stringify(msg.payload)}`;
  return safeEqual(signPayload(secret, canonical), msg.signature);
}

async function handleAgentMessage(msg: z.infer<typeof envelope>) {
  await prisma.server.update({ where: { id: msg.serverId }, data: { status: 'ONLINE', lastSeenAt: new Date(), version: msg.payload?.health?.serverVersion } });
  if (msg.type === 'heartbeat' || msg.type === 'metrics') {
    await prisma.serverMetric.create({ data: { serverId: msg.serverId, snapshot: msg.payload } });
    await prisma.serverLatestSnapshot.upsert({ where: { serverId: msg.serverId }, update: { snapshot: msg.payload }, create: { serverId: msg.serverId, snapshot: msg.payload } });
    const ramPct = msg.payload?.performance?.ramPercentage ?? 0;
    const tps = msg.payload?.health?.tps1m ?? 20;
    if (ramPct > 90 || tps < 16) await createAlert(msg.serverId, ramPct > 90 ? 'RAM above threshold' : 'TPS below threshold', msg.payload);
  }
  if (msg.type === 'consoleLog') await prisma.consoleLog.create({ data: { serverId: msg.serverId, level: msg.payload.level ?? 'INFO', source: msg.payload.source ?? 'agent', message: msg.payload.message ?? '', category: msg.payload.category ?? 'PLUGIN' } });
  if (msg.type === 'securityEvent') {
    await prisma.securityEvent.create({ data: { serverId: msg.serverId, type: msg.payload.type ?? 'SECURITY', actor: msg.payload.actor, subject: msg.payload.subject, action: msg.payload.action ?? 'detected', metadata: msg.payload as Prisma.InputJsonValue } });
    await createAlert(msg.serverId, msg.payload.title ?? 'Security event detected', msg.payload, 'CRITICAL', 'SECURITY');
  }
  if (msg.type === 'remoteCommandResult') await prisma.remoteCommand.update({ where: { id: msg.payload.commandId }, data: { status: msg.payload.success ? 'EXECUTED' : 'FAILED', executedAt: new Date(), result: msg.payload.result, error: msg.payload.error } });
}

async function createAlert(serverId: string, title: string, metadata: unknown, severity: 'CRITICAL'|'WARNING'|'INFO'='WARNING', category: 'SECURITY'|'PERFORMANCE'|'SERVER'|'PLAYER'|'NETWORK'='PERFORMANCE') {
  const alert = await prisma.alert.create({ data: { serverId, severity, category, title, message: title, metadata: metadata as Prisma.InputJsonValue } });
  if (severity === 'CRITICAL') await pushProvider.sendCriticalAlert({ title, message: title, serverId });
  return alert;
}
