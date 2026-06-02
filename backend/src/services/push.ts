export interface PushProvider { sendCriticalAlert(input: { title: string; message: string; serverId?: string }): Promise<void>; }
export class MockPushProvider implements PushProvider {
  async sendCriticalAlert(input: { title: string; message: string; serverId?: string }) { console.info('[mock-fcm]', input); }
}
export const pushProvider: PushProvider = new MockPushProvider();
