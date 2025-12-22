import React, { useState } from 'react';
import { Card } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { useAdminBackups } from '@/hooks/use-admin-backups';
import { useToast } from '@/hooks/use-toast';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
  DialogTrigger,
} from '@/components/ui/dialog';

export default function BackupsPanel() {
  const { list, restore, migrate } = useAdminBackups();
  const { toast } = useToast();

  const backups = list.data || [];
  const [restoreTarget, setRestoreTarget] = useState<string | null>(null);
  const [migrateOpen, setMigrateOpen] = useState(false);

  return (
    <Card className="p-6">
      <div className="flex items-center justify-between mb-4">
        <h3 className="text-lg font-bold">Backups & Migration</h3>
        <div className="flex gap-2">
          <Dialog open={migrateOpen} onOpenChange={setMigrateOpen}>
            <DialogTrigger asChild>
              <Button size="sm" onClick={() => setMigrateOpen(true)} disabled={migrate.isLoading}>Migrate JSON → SQLite</Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>Confirm Migration</DialogTitle>
                <DialogDescription>Move data from JSON fallback to embedded SQLite. This is irreversible — a backup will be created automatically.</DialogDescription>
              </DialogHeader>
              <DialogFooter>
                <Button variant="ghost" onClick={() => setMigrateOpen(false)}>Cancel</Button>
                <Button variant="default" onClick={() => {
                  migrate.mutate(undefined, {
                    onSuccess: (data: any) => toast({ title: 'Migration complete', description: `${data.migrated?.configs || 0} configs migrated` }),
                    onError: (err: any) => toast({ title: 'Migration failed', description: String(err) })
                  });
                  setMigrateOpen(false);
                }} data-testid="confirm-migrate">
                  Migrate
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        </div>
      </div>

      <div>
        {list.isLoading && <div>Loading backups…</div>}
        {!list.isLoading && backups.length === 0 && <div className="text-sm text-muted-foreground">No backups found.</div>}

        <ul className="space-y-2 mt-3">
          {backups.map((b: any) => (
            <li key={b.name} className="flex items-center justify-between p-2 border rounded">
              <div>
                <div className="font-medium">{b.name}</div>
                <div className="text-xs text-muted-foreground">{new Date(b.mtime).toLocaleString()}</div>
              </div>
              <div className="flex gap-2">
                <Dialog open={restoreTarget === b.name} onOpenChange={(open) => { if (!open) setRestoreTarget(null); }}>
                  <DialogTrigger asChild>
                    <Button size="sm" variant="outline" onClick={() => setRestoreTarget(b.name)}>Restore</Button>
                  </DialogTrigger>
                  <DialogContent>
                    <DialogHeader>
                      <DialogTitle>Confirm Restore</DialogTitle>
                      <DialogDescription>Are you sure you want to restore <strong>{b.name}</strong>? Current JSON will be backed up before restore.</DialogDescription>
                    </DialogHeader>
                    <DialogFooter>
                      <Button variant="ghost" onClick={() => setRestoreTarget(null)}>Cancel</Button>
                      <Button variant="destructive" onClick={() => {
                        restore.mutate(b.name, {
                          onSuccess: () => toast({ title: 'Restored', description: `Restored ${b.name}` }),
                          onError: (err: any) => toast({ title: 'Restore failed', description: String(err) })
                        });
                        setRestoreTarget(null);
                      }} data-testid={`confirm-restore-${b.name}`}>
                        Restore
                      </Button>
                    </DialogFooter>
                  </DialogContent>
                </Dialog>
              </div>
            </li>
          ))}
        </ul>
      </div>
    </Card>
  );
}
