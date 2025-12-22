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

describe('Process control endpoints', () => {
  let app: express.Express;
  beforeAll(async () => { app = await makeApp(); });

  test('stop returns success when no processes', async () => {
    (proc.listProcessesByName as jest.Mock).mockReturnValue([]);
    const res = await request(app).post('/api/configs/stop/1');
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('success');
  });

});
