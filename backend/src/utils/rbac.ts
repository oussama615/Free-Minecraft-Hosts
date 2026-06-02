import type { Role } from '@prisma/client';
const rank: Record<Role, number> = { VIEWER: 1, STAFF: 2, ADMIN: 3, OWNER: 4 };
export const canAtLeast = (role: Role, min: Role) => rank[role] >= rank[min];
export const isOwner = (role: Role) => role === 'OWNER';
