import express from 'express';
import { createServer } from 'http';
import request from 'supertest';
import { registerRoutes } from '../routes';
import * as proc from '../process';

jest.mock('../process');
jest.mock('child_process', () => ({
  spawn: jest.fn(() => { throw new Error('spawn failed'); })
}));

async function makeApp() {
  const app = express();
  app.use(express.json());
  const http = createServer(app);
  await registerRoutes(http, app);
  app.use((err: any, _req: any, res: any, _next: any) => res.status(500).json({ error: err?.message || 'err' }));
  return app;
}

describe('Process restart error path', () => {
  let app: express.Express;
  beforeAll(async () => { app = await makeApp(); });

  test('restart returns 500 when spawn throws', async () => {
    (proc.listProcessesByName as jest.Mock).mockReturnValue([]);

    const res = await request(app).post('/api/configs/restart/1');
    expect(res.status).toBe(500);
    expect(res.body).toHaveProperty('success', false);
    expect(res.body.message).toMatch(/Error restarting/);
  });
});
