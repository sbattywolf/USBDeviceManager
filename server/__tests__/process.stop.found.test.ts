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

describe('Process stop (found) endpoint', () => {
  let app: express.Express;
  beforeAll(async () => { app = await makeApp(); });

  test('stop stops running processes and returns stopped count', async () => {
    (proc.listProcessesByName as jest.Mock).mockReturnValue([{ pid: 123, name: 'notepad.exe' }]);
    (proc.killProcesses as jest.Mock).mockReturnValue(true);

    const res = await request(app).post('/api/configs/stop/1');
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('success', true);
    expect(res.body).toHaveProperty('stopped', 1);
    expect(proc.killProcesses).toHaveBeenCalledWith([123]);
  });
});
