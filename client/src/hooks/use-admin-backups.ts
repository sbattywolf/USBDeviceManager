import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { apiRequest } from '@/lib/queryClient';

export function useAdminBackups() {
  const qc = useQueryClient();

  const list = useQuery(['/api/admin/backups'], async () => {
    const res = await apiRequest('GET', '/api/admin/backups');
    return res.json();
  });

  const restore = useMutation(async (filename: string) => {
    const res = await apiRequest('POST', '/api/admin/restore', { filename });
    return res.json();
  }, {
    onSuccess: () => qc.invalidateQueries(['/api/admin/backups'])
  });

  const migrate = useMutation(async () => {
    const res = await apiRequest('POST', '/api/admin/migrate-json-to-sqlite');
    return res.json();
  }, {
    onSuccess: () => qc.invalidateQueries(['/api/admin/backups'])
  });

  return { list, restore, migrate };
}
