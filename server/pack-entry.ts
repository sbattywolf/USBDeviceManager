import express from 'express';
import { createServer } from 'http';
import { registerRoutes } from './routes';
import { serveStatic } from './static';

async function main() {
  process.env.NODE_ENV = process.env.NODE_ENV || 'production';

  const app = express();
  const http = createServer(app);

  app.use(express.json());
  app.use(express.urlencoded({ extended: false }));

  await registerRoutes(http, app);

  if (process.env.NODE_ENV === 'production') {
    serveStatic(app);
  }

  const port = parseInt(process.env.PORT || '5000', 10);
  http.listen(port, '0.0.0.0', () => console.log(`server listening on ${port}`));
}

main().catch((err) => {
  console.error('Failed to start server:', err);
  process.exit(1);
});
