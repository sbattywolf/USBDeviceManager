import express from 'express';
import { createServer } from 'http';
import request from 'supertest';
import { registerRoutes } from '../routes';
import fs from 'fs';

jest.spyOn(fs, 'existsSync').mockReturnValue(false);

async function makeApp() {
  const app = express();
  app.use(express.json());
  const http = createServer(app);
  await registerRoutes(http, app);
  app.use((err: any, _req: any, res: any, _next: any) => res.status(500).json({ error: err?.message || 'err' }));
  return app;
}

describe('Process start with missing triggerPath', () => {
  let app: express.Express;
  beforeAll(async () => { app = await makeApp(); });

  test('start returns 400 when triggerPath does not exist', async () => {
    const res = await request(app).post('/api/configs/start/1');
    expect(res.status).toBe(400);
    expect(res.body).toHaveProperty('success', false);
    expect(res.body).toHaveProperty('message');
  });
});
