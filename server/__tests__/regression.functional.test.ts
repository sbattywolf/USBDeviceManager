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

describe('Regression functional API tests', () => {
  let app: express.Express;

  beforeAll(async () => {
    app = await makeApp();
  });

  test('Agent download and health check', async () => {
    const agent = await request(app).get('/api/agent/download').expect(200);
    expect(agent.text).toContain('API_URL');

    const health = await request(app).get('/api/health').expect(200);
    expect(health.body).toHaveProperty('status');
  });

  test('Create config, start it, check status, and clear logs', async () => {
    const payload = {
      deviceId: 'reg:1',
      friendlyName: 'Reg Device',
      port: undefined,
      isEnabled: true,
      triggerPath: process.execPath, // node executable
      triggerParams: '-e console.log(123)',
      runSilently: false,
      forceMinimize: false
    };

    const create = await request(app).post('/api/configs').send(payload).expect(201);
    const id = create.body.id;
    expect(id).toBeTruthy();

    const start = await request(app).post(`/api/configs/start/${id}`).expect(200);
    expect(start.body).toHaveProperty('success');

    const status = await request(app).get(`/api/configs/status/${id}`).expect(200);
    expect(status.body).toHaveProperty('isRunning');

    // Logs exist
    const logs = await request(app).get('/api/logs').expect(200);
    expect(Array.isArray(logs.body)).toBe(true);

    // Clear logs
    await request(app).delete('/api/logs').expect(204);
    const after = await request(app).get('/api/logs').expect(200);
    expect(after.body.length).toBe(0);
  }, 20000);
});
