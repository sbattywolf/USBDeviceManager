import express from 'express';
import { createServer } from 'http';
import request from 'supertest';

import { registerRoutes } from '../routes';

async function makeApp() {
  const app = express();
  app.use(express.json());
  const http = createServer(app);
  await registerRoutes(http, app);
  // basic error handler
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  app.use((err: any, _req: any, res: any, _next: any) => res.status(500).json({ error: err?.message || 'err' }));
  return app;
}

describe('API routes (fallback storage)', () => {
  let app: express.Express;

  beforeAll(async () => {
    app = await makeApp();
  });

  test('GET /api/configs returns array', async () => {
    const res = await request(app).get('/api/configs').expect(200);
    expect(Array.isArray(res.body)).toBe(true);
  });

  test('POST /api/configs create and then GET list', async () => {
    const payload = {
      deviceId: 'test:1',
      friendlyName: 'Test Device',
      port: undefined,
      isEnabled: true,
      triggerPath: 'C:\\Windows\\notepad.exe',
      triggerParams: '',
      runSilently: false,
      forceMinimize: false
    };

    const create = await request(app).post('/api/configs').send(payload).expect(201);
    expect(create.body).toHaveProperty('id');

    const list = await request(app).get('/api/configs').expect(200);
    expect(list.body.find((c: any) => c.id === create.body.id)).toBeTruthy();
  });

  test('POST /api/logs accepts a log', async () => {
    const payload = { deviceId: 'test:1', friendlyName: 'Test Device', eventType: 'CONNECTED', actionTaken: 'TRIGGER_STARTED', details: 'ok' };
    const res = await request(app).post('/api/logs').send(payload).expect(201);
    expect(res.body).toHaveProperty('id');
  });
});
