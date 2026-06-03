import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { hashPassword } from '../src/utils/crypto.js';
const prisma = new PrismaClient();
async function main() {
  const count = await prisma.user.count();
  if (count > 0) { console.log('Users already exist; default owner seed skipped.'); return; }
  const username = process.env.DEFAULT_OWNER_USERNAME;
  const email = process.env.DEFAULT_OWNER_EMAIL;
  const password = process.env.DEFAULT_OWNER_PASSWORD;
  const displayName = process.env.DEFAULT_OWNER_DISPLAY_NAME ?? username;
  if (!username || !email || !password || password.length < 12) throw new Error('Set DEFAULT_OWNER_USERNAME, DEFAULT_OWNER_EMAIL, and a 12+ character DEFAULT_OWNER_PASSWORD before seeding.');
  const workspace = await prisma.workspace.create({ data: { name: 'EMP Control Network' } });
  await prisma.user.create({ data: { workspaceId: workspace.id, username, email, displayName: displayName ?? username, role: 'OWNER', passwordHash: await hashPassword(password) } });
  console.log(`Created default OWNER ${username} in workspace ${workspace.id}`);
}
main().finally(() => prisma.$disconnect());
