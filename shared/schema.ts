
import { pgTable, text, serial, boolean, timestamp } from "drizzle-orm/pg-core";
import { createInsertSchema } from "drizzle-zod";
import { z } from "zod";

// === TABLE DEFINITIONS ===

// Configuration for USB devices and their triggers
export const usbConfigs = pgTable("usb_configs", {
  id: serial("id").primaryKey(),
  deviceId: text("device_id").notNull(), // e.g., VID:PID or Serial Number
  friendlyName: text("friendly_name").notNull(),
  port: text("port"), // Optional specific port binding
  isEnabled: boolean("is_enabled").default(true).notNull(),
  
  // Software Trigger Config
  triggerPath: text("trigger_path").notNull(), // Path to .exe or script
  triggerParams: text("trigger_params"), // Command line arguments
  runSilently: boolean("run_silently").default(false).notNull(),
  forceMinimize: boolean("force_minimize").default(false).notNull(),
  
  createdAt: timestamp("created_at").defaultNow(),
  updatedAt: timestamp("updated_at").defaultNow(),
});

// Historical logs of USB events
export const usbLogs = pgTable("usb_logs", {
  id: serial("id").primaryKey(),
  deviceId: text("device_id").notNull(),
  friendlyName: text("friendly_name"),
  eventType: text("event_type").notNull(), // 'CONNECTED', 'DISCONNECTED'
  actionTaken: text("action_taken"), // 'TRIGGER_STARTED', 'SKIPPED_RUNNING', 'NO_CONFIG'
  details: text("details"), // Error messages or success info
  timestamp: timestamp("timestamp").defaultNow(),
});

// === SCHEMAS ===

export const insertUsbConfigSchema = createInsertSchema(usbConfigs).omit({ 
  id: true, 
  createdAt: true, 
  updatedAt: true 
});

export const insertUsbLogSchema = createInsertSchema(usbLogs).omit({ 
  id: true, 
  timestamp: true 
});

// === EXPLICIT TYPES ===

export type UsbConfig = typeof usbConfigs.$inferSelect;
export type InsertUsbConfig = z.infer<typeof insertUsbConfigSchema>;

export type UsbLog = typeof usbLogs.$inferSelect;
export type InsertUsbLog = z.infer<typeof insertUsbLogSchema>;

// API Request/Response Types
export type CreateConfigParams = InsertUsbConfig;
export type UpdateConfigParams = Partial<InsertUsbConfig>;

export type SimulationRequest = {
  deviceId: string;
  eventType: 'CONNECTED' | 'DISCONNECTED';
};

// Health Check Types
export type HealthCheckStatus = 'pass' | 'fail' | 'warning';

export interface HealthCheckItem {
  id: string;
  name: string;
  description: string;
  status: HealthCheckStatus;
  details?: string;
  remediation?: string;
}

export interface HealthCheckResponse {
  status: 'healthy' | 'degraded' | 'failed';
  timestamp: string;
  checks: HealthCheckItem[];
}
