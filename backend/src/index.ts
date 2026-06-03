import Fastify from 'fastify';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import rateLimit from '@fastify/rate-limit';
import websocket from '@fastify/websocket';
import sensible from '@fastify/sensible';
import { env, corsOrigins } from './config/env.js';
import authPlugin from './plugins/auth.js';
import { prisma } from './plugins/prisma.js';
import { authRoutes } from './routes/auth.js';
import { userRoutes } from './routes/users.js';
import { serverRoutes } from './routes/servers.js';
import { alertRoutes } from './routes/alerts.js';
import { logRoutes } from './routes/logs.js';
import { policyRoutes } from './routes/policies.js';
import { commandRoutes } from './routes/commands.js';
import { agentRoutes } from './routes/agent.js';
import { deviceRoutes } from './routes/devices.js';
import './types.js';

const app = Fastify({ logger: true });
let databaseConnected = false;

await app.register(sensible);
await app.register(helmet);
await app.register(cors, { origin: corsOrigins, credentials: true });
await app.register(rateLimit, { max: 200, timeWindow: '1 minute' });
await app.register(websocket, { options: { maxPayload: 1024 * 256 } });
await app.register(authPlugin);
await app.register(authRoutes);
await app.register(userRoutes);
await app.register(serverRoutes);
await app.register(alertRoutes);
await app.register(logRoutes);
await app.register(policyRoutes);
await app.register(commandRoutes);
await app.register(agentRoutes);
await app.register(deviceRoutes);

app.get('/health', async () => ({
  ok: databaseConnected,
  name: 'EMP Control API',
  environment: env.NODE_ENV,
  websocket: 'enabled',
  database: databaseConnected ? 'connected' : 'disconnected',
}));

app.setErrorHandler((error, _request, reply) => {
  if ('issues' in error) return reply.status(400).send({ error: 'ValidationError', details: (error as { issues: unknown }).issues });
  const statusCode = error.statusCode ?? 500;
  app.log.error({ error }, 'request failed');
  reply.status(statusCode).send({ error: error.name, message: statusCode >= 500 ? 'Internal server error' : error.message });
});

try {
  await prisma.$connect();
  await prisma.$queryRaw`SELECT 1`;
  databaseConnected = true;
} catch (error) {
  app.log.error({ error }, 'Database connection failed. Start Docker Compose PostgreSQL and verify DATABASE_URL.');
  throw error;
}

const address = await app.listen({ host: '0.0.0.0', port: env.PORT });
app.log.info({
  apiPort: env.PORT,
  apiUrl: `http://localhost:${env.PORT}`,
  listenAddress: address,
  database: databaseConnected ? 'connected' : 'disconnected',
  websocket: 'enabled at /agent/ws',
  environment: env.NODE_ENV,
}, 'EMP Control API started');

const shutdown = async (signal: string) => {
  app.log.info({ signal }, 'Shutting down EMP Control API');
  await app.close();
  await prisma.$disconnect();
  process.exit(0);
};
process.on('SIGINT', () => void shutdown('SIGINT'));
process.on('SIGTERM', () => void shutdown('SIGTERM'));
