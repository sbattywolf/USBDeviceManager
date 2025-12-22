import express from 'express';
import { createServer } from 'http';
import request from 'supertest';
import { registerRoutes } from '../routes';
import * as proc from '../process';

jest.mock('../process');
jest.mock('child_process', () => ({
  spawn: jest.fn(() => ({ unref: jest.fn() }))
}));

async function makeApp() {
  const app = express();
  app.use(express.json());
  const http = createServer(app);
  await registerRoutes(http, app);
  app.use((err: any, _req: any, res: any, _next: any) => res.status(500).json({ error: err?.message || 'err' }));
  return app;
}

describe('Process restart endpoint', () => {
  let app: express.Express;
  beforeAll(async () => { app = await makeApp(); });

  test('restart kills running processes then spawns new process', async () => {
    (proc.listProcessesByName as jest.Mock).mockReturnValue([{ pid: 333, name: 'notepad.exe' }]);
    (proc.killProcesses as jest.Mock).mockReturnValue(true);

    const res = await request(app).post('/api/configs/restart/1');
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('success', true);
    expect(res.body.message).toContain('Restarted');
    expect(proc.killProcesses).toHaveBeenCalledWith([333]);
  });
});
