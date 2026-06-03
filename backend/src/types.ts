import type { Role } from '@prisma/client';
declare module 'fastify' {
  interface FastifyRequest { userContext?: { id: string; workspaceId: string; role: Role; sessionId?: string } }
}
