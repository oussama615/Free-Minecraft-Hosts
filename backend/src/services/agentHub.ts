import type { WebSocket } from 'ws';
import { prisma } from '../plugins/prisma.js';
import { signPayload } from '../utils/crypto.js';

const clients = new Map<string, { ws: WebSocket; secret: string }>();
export function registerAgent(serverId: string, ws: WebSocket, secret: string) { clients.set(serverId, { ws, secret }); ws.on('close', async () => { clients.delete(serverId); await prisma.server.update({ where: { id: serverId }, data: { status: 'OFFLINE' } }).catch(() => undefined); }); }
export function sendCommandToAgent(serverId: string, command: { id: string; command: string; nonce: string }) {
  const client = clients.get(serverId); if (!client) return false;
  const timestamp = Date.now(); const payload = { commandId: command.id, command: command.command };
  const canonical = `${serverId}.${timestamp}.${command.nonce}.${JSON.stringify(payload)}`;
  client.ws.send(JSON.stringify({ type: 'remoteCommand', serverId, timestamp, nonce: command.nonce, payload, signature: signPayload(client.secret, canonical) }));
  return true;
}
