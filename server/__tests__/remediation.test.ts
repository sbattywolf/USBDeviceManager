import express from 'express';
import { createServer } from 'http';
import request from 'supertest';
import { registerRoutes } from '../routes';

async function makeApp() {
  const app = express();
  app.use(express.json());
  const http = createServer(app);
  await registerRoutes(http, app);
  app.use((err: any, _req: any, res: any, _next: any) => res.status(500).json({ error: err?.message || 'err' }));
  return app;
}

describe('Remediation endpoint', () => {
  let app: express.Express;
  beforeAll(async () => { app = await makeApp(); });

  test('returns 400 for unknown id', async () => {
    await request(app).post('/api/remediation').send({ id: 'unknown' }).expect(400);
  });

  test('returns command for install_python', async () => {
    const res = await request(app).post('/api/remediation').send({ id: 'install_python' }).expect(200);
    expect(res.body).toHaveProperty('command');
    expect(res.body).toHaveProperty('commands');
  });
});
