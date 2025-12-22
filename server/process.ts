import { execSync } from 'child_process';

function shellEscapeArg(s: string) {
  if (!s) return '';
  // Simple escape for double quotes and shell-sensitive chars
  return s.replace(/"/g, '');
}

export function listProcessesByName(processName: string): Array<{ pid: number; name: string }> {
  if (!processName || typeof processName !== 'string') return [];
  try {
    if (process.platform === 'win32') {
      // Use tasklist CSV and filter in JS to avoid shell injection
      const out = execSync(`tasklist /FO CSV /NH`, { encoding: 'utf-8' });
      const lines = out.trim().split(/\r?\n/).filter(Boolean);
      const results: Array<{ pid: number; name: string }> = [];
      for (const line of lines) {
        const cols = line.split(',').map(s => s.replace(/^"|"$/g, '').trim());
        if (cols.length >= 2) {
          const name = cols[0];
          const pid = Number(cols[1]) || 0;
          if (pid && name.toLowerCase() === processName.toLowerCase()) {
            results.push({ pid, name });
          }
        }
      }
      return results;
    } else {
      // Unix-like: use pgrep with -f and safely quoted pattern
      const safe = shellEscapeArg(processName);
      const out = execSync(`pgrep -f "${safe}" || true`, { encoding: 'utf-8', stdio: ['pipe', 'pipe', 'ignore'] });
      if (!out) return [];
      const pids = out.trim().split(/\r?\n/).filter(Boolean).map(p => Number(p)).filter(Boolean);
      return pids.map(pid => ({ pid, name: processName }));
    }
  } catch (e) {
    return [];
  }
}

export function isProcessRunning(processName: string): boolean {
  return listProcessesByName(processName).length > 0;
}

export function killProcesses(pids: number[]): boolean {
  if (!Array.isArray(pids) || pids.length === 0) return true;
  try {
    if (process.platform === 'win32') {
      for (const pid of pids) {
        // Ensure pid is a number
        const n = Number(pid);
        if (!n) continue;
        execSync(`taskkill /PID ${n} /F`, { stdio: ['pipe', 'ignore', 'ignore'] });
      }
    } else {
      const safePids = pids.map(p => Number(p)).filter(Boolean);
      if (safePids.length === 0) return true;
      execSync(`kill -9 ${safePids.join(' ')}`, { stdio: ['pipe', 'ignore', 'ignore'] });
    }
    return true;
  } catch (e) {
    return false;
  }
}

export default { listProcessesByName, isProcessRunning, killProcesses };
