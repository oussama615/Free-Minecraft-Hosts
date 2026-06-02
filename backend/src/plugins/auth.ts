import fp from 'fastify-plugin';
import jwt from '@fastify/jwt';
import type { FastifyRequest } from 'fastify';
import { env } from '../config/env.js';
import { prisma } from './prisma.js';
import { canAtLeast } from '../utils/rbac.js';
import type { Role } from '@prisma/client';

export default fp(async (app) => {
  await app.register(jwt, { secret: env.JWT_SECRET });
  app.decorate('authenticate', async (request: FastifyRequest) => {
    const decoded = await request.jwtVerify<{ sub: string; workspaceId: string; role: Role; sessionId?: string }>();
    const user = await prisma.user.findUnique({ where: { id: decoded.sub } });
    if (!user || user.disabledAt) throw app.httpErrors.unauthorized('User disabled or missing');
    request.userContext = { id: user.id, workspaceId: user.workspaceId, role: user.role, sessionId: decoded.sessionId };
  });
  app.decorate('requireRole', (min: Role) => async (request: FastifyRequest) => {
    await app.authenticate(request);
    if (!request.userContext || !canAtLeast(request.userContext.role, min)) throw app.httpErrors.forbidden('Insufficient role');
  });
});

declare module 'fastify' {
  interface FastifyInstance {
    authenticate(request: FastifyRequest): Promise<void>;
    requireRole(min: Role): (request: FastifyRequest) => Promise<void>;
  }
}
