
import { 
  usbConfigs, usbLogs, 
  type UsbConfig, type InsertUsbConfig, 
  type UsbLog, type InsertUsbLog 
} from "@shared/schema";
import { db } from "./db";
import { eq, desc } from "drizzle-orm";

export interface IStorage {
  // Configs
  getConfigs(): Promise<UsbConfig[]>;
  getConfig(id: number): Promise<UsbConfig | undefined>;
  getConfigByDeviceId(deviceId: string): Promise<UsbConfig | undefined>;
  createConfig(config: InsertUsbConfig): Promise<UsbConfig>;
  updateConfig(id: number, config: Partial<InsertUsbConfig>): Promise<UsbConfig>;
  deleteConfig(id: number): Promise<void>;

  // Logs
  getLogs(): Promise<UsbLog[]>;
  createLog(log: InsertUsbLog): Promise<UsbLog>;
  clearLogs(): Promise<void>;
}

export class DatabaseStorage implements IStorage {
  // Configs
  async getConfigs(): Promise<UsbConfig[]> {
    return await db.select().from(usbConfigs).orderBy(desc(usbConfigs.createdAt));
  }

  async getConfig(id: number): Promise<UsbConfig | undefined> {
    const [config] = await db.select().from(usbConfigs).where(eq(usbConfigs.id, id));
    return config;
  }

  async getConfigByDeviceId(deviceId: string): Promise<UsbConfig | undefined> {
    const [config] = await db.select().from(usbConfigs).where(eq(usbConfigs.deviceId, deviceId));
    return config;
  }

  async createConfig(insertConfig: InsertUsbConfig): Promise<UsbConfig> {
    const [config] = await db.insert(usbConfigs).values(insertConfig).returning();
    return config;
  }

  async updateConfig(id: number, updates: Partial<InsertUsbConfig>): Promise<UsbConfig> {
    const [config] = await db
      .update(usbConfigs)
      .set({ ...updates, updatedAt: new Date() })
      .where(eq(usbConfigs.id, id))
      .returning();
    return config;
  }

  async deleteConfig(id: number): Promise<void> {
    await db.delete(usbConfigs).where(eq(usbConfigs.id, id));
  }

  // Logs
  async getLogs(): Promise<UsbLog[]> {
    return await db.select().from(usbLogs).orderBy(desc(usbLogs.timestamp));
  }

  async createLog(insertLog: InsertUsbLog): Promise<UsbLog> {
    const [log] = await db.insert(usbLogs).values(insertLog).returning();
    return log;
  }

  async clearLogs(): Promise<void> {
    await db.delete(usbLogs);
  }
}

export const storage = new DatabaseStorage();
