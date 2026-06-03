import { z } from 'zod';
import type { Prisma } from '@prisma/client';
import type { FastifyInstance } from 'fastify';
import { prisma } from '../plugins/prisma.js';
import { audit } from '../services/audit.js';
import { hashPassword } from '../utils/crypto.js';

const createUser = z.object({ username: z.string().min(2), email: z.string().email(), displayName: z.string().min(1), password: z.string().min(12), role: z.enum(['ADMIN', 'STAFF', 'VIEWER']) });
const updateUser = z.object({ displayName: z.string().min(1).optional(), disabled: z.boolean().optional() });

export async function userRoutes(app: FastifyInstance) {
  app.get('/users', { preHandler: app.requireRole('OWNER') }, async (req) => ({
    users: (await prisma.user.findMany({ where: { workspaceId: req.userContext!.workspaceId }, orderBy: { createdAt: 'desc' } })).map(publicUser),
  }));

  app.post('/users', { preHandler: app.requireRole('OWNER') }, async (req) => {
    const body = createUser.parse(req.body);
    const user = await prisma.user.create({
      data: {
        workspaceId: req.userContext!.workspaceId,
        username: body.username,
        email: body.email,
        displayName: body.displayName,
        role: body.role,
        passwordHash: await hashPassword(body.password),
      },
    });
    await audit({ userId: req.userContext!.id, action: 'user.create', target: user.id, metadata: { role: user.role } as Prisma.InputJsonValue });
    return { user: publicUser(user) };
  });

  app.patch('/users/:id', { preHandler: app.requireRole('OWNER') }, async (req) => {
    const { id } = z.object({ id: z.string() }).parse(req.params);
    const body = updateUser.parse(req.body);
    await prisma.user.findFirstOrThrow({ where: { id, workspaceId: req.userContext!.workspaceId } });
    const user = await prisma.user.update({ where: { id }, data: { displayName: body.displayName, disabledAt: body.disabled === undefined ? undefined : body.disabled ? new Date() : null } });
    await audit({ userId: req.userContext!.id, action: 'user.update', target: id });
    return { user: publicUser(user) };
  });

  app.patch('/users/:id/role', { preHandler: app.requireRole('OWNER') }, async (req) => {
    const { id } = z.object({ id: z.string() }).parse(req.params);
    const { role } = z.object({ role: z.enum(['ADMIN', 'STAFF', 'VIEWER']) }).parse(req.body);
    await prisma.user.findFirstOrThrow({ where: { id, workspaceId: req.userContext!.workspaceId } });
    const user = await prisma.user.update({ where: { id }, data: { role } });
    await audit({ userId: req.userContext!.id, action: 'user.role', target: id, metadata: { role } as Prisma.InputJsonValue });
    return { user: publicUser(user) };
  });

  app.delete('/users/:id', { preHandler: app.requireRole('OWNER') }, async (req) => {
    const { id } = z.object({ id: z.string() }).parse(req.params);
    await prisma.user.findFirstOrThrow({ where: { id, workspaceId: req.userContext!.workspaceId } });
    await prisma.user.update({ where: { id }, data: { disabledAt: new Date() } });
    await audit({ userId: req.userContext!.id, action: 'user.disable', target: id });
    return { ok: true };
  });
}

const publicUser = (user: { id: string; username: string; email: string; displayName: string; role: string; disabledAt?: Date | null }) => ({
  id: user.id,
  username: user.username,
  email: user.email,
  displayName: user.displayName,
  role: user.role,
  disabledAt: user.disabledAt,
});
