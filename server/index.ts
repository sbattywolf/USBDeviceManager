import express, { type Request, Response, NextFunction } from "express";
import { registerRoutes } from "./routes";
import cors from "cors";
import { serveStatic } from "./static";
import { createServer } from "http";

import fs from "fs";
import path from "path";

const app = express();
const httpServer = createServer(app);

declare module "http" {
  interface IncomingMessage {
    rawBody: unknown;
  }
}

app.use(
  express.json({
    verify: (req, _res, buf) => {
      req.rawBody = buf;
    },
  }),
);

// Allow cross-origin requests during development and for agents
app.use(cors());

app.use(express.urlencoded({ extended: false }));

export function log(message: string, source = "express") {
  const formattedTime = new Date().toLocaleTimeString("en-US", {
    hour: "numeric",
    minute: "2-digit",
    second: "2-digit",
    hour12: true,
  });

  console.log(`${formattedTime} [${source}] ${message}`);
}

app.use((req, res, next) => {
  const start = Date.now();
  const path = req.path;
  let capturedJsonResponse: Record<string, any> | undefined = undefined;

  const originalResJson = res.json;
  res.json = function (bodyJson, ...args) {
    capturedJsonResponse = bodyJson;
    return originalResJson.apply(res, [bodyJson, ...args]);
  };

  res.on("finish", () => {
    const duration = Date.now() - start;
    if (path.startsWith("/api")) {
      let logLine = `${req.method} ${path} ${res.statusCode} in ${duration}ms`;
      if (capturedJsonResponse) {
        logLine += ` :: ${JSON.stringify(capturedJsonResponse)}`;
      }

      log(logLine);
    }
  });

  next();
});

// Simple log-to-file utility for errors
function logErrorToFile(message: string) {
  const logPath = path.resolve(process.cwd(), "data", "error.log");
  const line = `[${new Date().toISOString()}] ${message}\n`;
  try {
    fs.appendFileSync(logPath, line, { encoding: "utf8" });
  } catch (e) {
    // Fallback: log to console if file write fails
    console.error("Failed to write to error.log:", e);
  }
}

(async () => {
  await registerRoutes(httpServer, app);

  app.use((err: any, _req: Request, res: Response, _next: NextFunction) => {
    const status = err.status || err.statusCode || 500;
    const message = err.message || "Internal Server Error";
    const details = err.stack || String(err);
    // Log to console and to file
    console.error('Unhandled error in request handler:', details);
    logErrorToFile(`${message} :: ${details}`);
    res.status(status).json({ message });
  });

  // importantly only setup vite in development and after
  // setting up all the other routes so the catch-all route
  // doesn't interfere with the other routes
  if (process.env.NODE_ENV === "production") {
    serveStatic(app);
  } else {
    const { setupVite } = await import("./vite");
    await setupVite(httpServer, app);
  }

  // ALWAYS serve the app on the port specified in the environment variable PORT
  // Other ports are firewalled. Default to 5000 if not specified.
  // this serves both the API and the client.
  // It is the only port that is not firewalled.
  const port = parseInt(process.env.PORT || "5000", 10);
  const host = process.env.HOST || "0.0.0.0";
  const listenOptions: any = { port, host };
  // `reusePort` is not supported on some Windows environments — enable only when supported
  if (process.platform !== 'win32') listenOptions.reusePort = true;

  httpServer.listen(listenOptions, () => {
    log(`serving on ${host}:${port}`);
  });
})();

// Global process handlers to capture unexpected errors during development
process.on('unhandledRejection', (reason) => {
  console.error('Unhandled Rejection at:', reason);
});

process.on('uncaughtException', (err) => {
  console.error('Uncaught Exception:', err && err.stack ? err.stack : err);
});
