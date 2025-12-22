import express from 'express';
import { createServer } from 'http';
import request from 'supertest';
import { registerRoutes } from '../routes';
import * as proc from '../process';

jest.mock('../process');

async function makeApp() {
  const app = express();
  app.use(express.json());
  const http = createServer(app);
  await registerRoutes(http, app);
  app.use((err: any, _req: any, res: any, _next: any) => res.status(500).json({ error: err?.message || 'err' }));
  return app;
}

describe('Config status endpoint', () => {
  let app: express.Express;
  beforeAll(async () => { app = await makeApp(); });

  test('returns isRunning true when process helper reports running', async () => {
    (proc.isProcessRunning as jest.Mock).mockReturnValue(true);
    const res = await request(app).get('/api/configs/status/1');
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('isRunning', true);
  });

  test('returns isRunning false when process helper reports not running', async () => {
    (proc.isProcessRunning as jest.Mock).mockReturnValue(false);
    const res = await request(app).get('/api/configs/status/1');
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('isRunning', false);
  });

});
