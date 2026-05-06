// ==================== KT BANQUE - UTILS ====================

export const RESOURCE_NAME =
  typeof (window as any).GetParentResourceName === 'function'
    ? (window as any).GetParentResourceName()
    : 'kt_banque';

export function formatCurrency(amount: number): string {
  return (
    '$' +
    Math.floor(amount).toLocaleString('fr-FR', {
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    })
  );
}

export function formatDate(dateString: string): string {
  if (!dateString) return 'Date inconnue';
  const date = new Date(dateString);
  if (isNaN(date.getTime())) return 'Date invalide';
  const diff = (Date.now() - date.getTime()) / 1000;

  if (diff < 60) return "À l'instant";
  if (diff < 3600) return `Il y a ${Math.floor(diff / 60)} min`;
  if (diff < 86400) return `Il y a ${Math.floor(diff / 3600)}h`;

  return date.toLocaleDateString('fr-FR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

export async function sendToServer(event: string, data: object = {}): Promise<any> {
  try {
    const resp = await fetch(`https://${RESOURCE_NAME}/${event}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });
    if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
    return await resp.json().catch(() => ({}));
  } catch (err) {
    console.error(`[KT Banque] NUI error (${event}):`, err);
    throw err;
  }
}

export function maskCardNumber(raw: string): string {
  if (!raw) return '**** **** **** ****';
  const parts = raw.split(' ');
  return parts
    .map((p, i) => (i < parts.length - 1 ? '****' : p))
    .join(' ');
}

export function cardTypeLabel(type: string): string {
  const map: Record<string, string> = {
    carte_basique: 'Basique',
    carte_or: 'Or',
    carte_dimas: 'Diamant',
  };
  return map[type] ?? type;
}
