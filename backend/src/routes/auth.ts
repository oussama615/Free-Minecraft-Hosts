import { z } from 'zod';
import type { FastifyInstance } from 'fastify';
import { prisma } from '../plugins/prisma.js';
import { audit } from '../services/audit.js';
import { hashPassword, randomToken, verifyPassword } from '../utils/crypto.js';

const loginSchema = z.object({ usernameOrEmail: z.string().min(1), password: z.string().min(8) });
const refreshSchema = z.object({ refreshToken: z.string().min(20) });

export async function authRoutes(app: FastifyInstance) {
  app.post('/auth/login', async (req) => {
    const body = loginSchema.parse(req.body);
    const user = await prisma.user.findFirst({
      where: { OR: [{ username: body.usernameOrEmail }, { email: body.usernameOrEmail }], disabledAt: null },
    });
    if (!user || !(await verifyPassword(user.passwordHash, body.password))) throw app.httpErrors.unauthorized('Invalid credentials');

    const refreshToken = randomToken(48);
    const userAgent = Array.isArray(req.headers['user-agent']) ? req.headers['user-agent'][0] : req.headers['user-agent'];
    const session = await prisma.userSession.create({
      data: {
        userId: user.id,
        refreshHash: await hashPassword(refreshToken),
        expiresAt: new Date(Date.now() + 1000 * 60 * 60 * 24 * 30),
        userAgent,
        ipAddress: req.ip,
      },
    });
    const accessToken = app.jwt.sign({ workspaceId: user.workspaceId, role: user.role, sessionId: session.id }, { sub: user.id, expiresIn: '15m' });
    await audit({ userId: user.id, action: 'auth.login' });
    return { accessToken, refreshToken, user: publicUser(user) };
  });

  app.post('/auth/refresh', async (req) => {
    const { refreshToken } = refreshSchema.parse(req.body);
    const sessions = await prisma.userSession.findMany({
      where: { revokedAt: null, expiresAt: { gt: new Date() } },
      include: { user: true },
    });
    let session: (typeof sessions)[number] | undefined;
    for (const candidate of sessions) {
      if (await verifyPassword(candidate.refreshHash, refreshToken)) { session = candidate; break; }
    }
    if (!session || session.user.disabledAt) throw app.httpErrors.unauthorized('Invalid refresh token');
    return { accessToken: app.jwt.sign({ workspaceId: session.user.workspaceId, role: session.user.role, sessionId: session.id }, { sub: session.user.id, expiresIn: '15m' }) };
  });

  app.post('/auth/logout', { preHandler: app.authenticate }, async (req) => {
    if (req.userContext?.sessionId) await prisma.userSession.updateMany({ where: { id: req.userContext.sessionId }, data: { revokedAt: new Date() } });
    return { ok: true };
  });

  app.get('/auth/me', { preHandler: app.authenticate }, async (req) => ({
    user: publicUser(await prisma.user.findUniqueOrThrow({ where: { id: req.userContext!.id } })),
  }));
}

const publicUser = (user: { id: string; username: string; email: string; displayName: string; role: string; workspaceId: string }) => ({
  id: user.id,
  username: user.username,
  email: user.email,
  displayName: user.displayName,
  role: user.role,
  workspaceId: user.workspaceId,
});
