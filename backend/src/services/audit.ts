import type { Prisma } from '@prisma/client';
import { prisma } from '../plugins/prisma.js';

export async function audit(input: { userId?: string; serverId?: string; action: string; target?: string; metadata?: unknown }) {
  await prisma.auditLog.create({ data: { ...input, metadata: input.metadata as Prisma.InputJsonValue | undefined } });
}
