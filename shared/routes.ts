
import { z } from 'zod';
import { insertUsbConfigSchema, insertUsbLogSchema, usbConfigs, usbLogs } from './schema';

export const errorSchemas = {
  validation: z.object({
    message: z.string(),
    field: z.string().optional(),
  }),
  notFound: z.object({
    message: z.string(),
  }),
  internal: z.object({
    message: z.string(),
  }),
};

export const api = {
  configs: {
    list: {
      method: 'GET' as const,
      path: '/api/configs',
      responses: {
        200: z.array(z.custom<typeof usbConfigs.$inferSelect>()),
      },
    },
    create: {
      method: 'POST' as const,
      path: '/api/configs',
      input: insertUsbConfigSchema,
      responses: {
        201: z.custom<typeof usbConfigs.$inferSelect>(),
        400: errorSchemas.validation,
      },
    },
    update: {
      method: 'PUT' as const,
      path: '/api/configs/:id',
      input: insertUsbConfigSchema.partial(),
      responses: {
        200: z.custom<typeof usbConfigs.$inferSelect>(),
        404: errorSchemas.notFound,
      },
    },
    delete: {
      method: 'DELETE' as const,
      path: '/api/configs/:id',
      responses: {
        204: z.void(),
        404: errorSchemas.notFound,
      },
    },
  },
  logs: {
    list: {
      method: 'GET' as const,
      path: '/api/logs',
      responses: {
        200: z.array(z.custom<typeof usbLogs.$inferSelect>()),
      },
    },
    create: {
      method: 'POST' as const,
      path: '/api/logs',
      input: insertUsbLogSchema,
      responses: {
        201: z.custom<typeof usbLogs.$inferSelect>(),
      },
    },
    clear: {
      method: 'DELETE' as const,
      path: '/api/logs',
      responses: {
        204: z.void(),
      },
    }
  },
  agent: {
    download: {
      method: 'GET' as const,
      path: '/api/agent/download',
      responses: {
        200: z.any(), // File download
      },
    }
  },
  health: {
    check: {
      method: 'GET' as const,
      path: '/api/health',
      responses: {
        200: z.object({
          status: z.enum(['healthy', 'degraded', 'failed']),
          timestamp: z.string(),
          checks: z.array(z.object({
            id: z.string(),
            name: z.string(),
            description: z.string(),
            status: z.enum(['pass', 'fail', 'warning']),
            details: z.string().optional(),
            remediation: z.string().optional(),
          })),
        }),
      },
    }
  }
};

export function buildUrl(path: string, params?: Record<string, string | number>): string {
  let url = path;
  if (params) {
    Object.entries(params).forEach(([key, value]) => {
      if (url.includes(`:${key}`)) {
        url = url.replace(`:${key}`, String(value));
      }
    });
  }
  return url;
}
