// ==================== KT BANQUE v7.4.1 - UTILS ====================

export const RESOURCE_NAME: string =
  typeof (window as any).GetParentResourceName === 'function'
    ? (window as any).GetParentResourceName()
    : 'kt_banque';

// ==================== FORMATAGE ====================

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
  if (diff < 60)    return "À l'instant";
  if (diff < 3600)  return `Il y a ${Math.floor(diff / 60)} min`;
  if (diff < 86400) return `Il y a ${Math.floor(diff / 3600)}h`;
  return date.toLocaleDateString('fr-FR', {
    day: '2-digit', month: '2-digit', year: 'numeric',
    hour: '2-digit', minute: '2-digit',
  });
}

export function maskCardNumber(raw: string): string {
  if (!raw) return '**** **** **** ****';
  const parts = raw.split(' ');
  return parts.map((p, i) => (i < parts.length - 1 ? '****' : p)).join(' ');
}

// FIX: clés alignées avec config.lua (card_basic / card_gold / card_diamond)
export function cardTypeLabel(type: string): string {
  const map: Record<string, string> = {
    card_basic   : 'Basique',
    card_gold    : 'Or',
    card_diamond : 'Diamant',
  };
  return map[type] ?? type;
}

// ==================== SÉCURITÉ ====================

/**
 * Hash le PIN côté client avant envoi au serveur.
 * DOIT être identique à Utils.HashPin dans server/main.lua
 * et HashPin dans client/main.lua.
 */
export function hashPin(pin: string): string {
  const salt    = 'kt_banque_v7';
  const combined = salt + pin;
  let hash = 0;
  for (let i = 0; i < combined.length; i++) {
    hash = (Math.imul(hash, 31) + combined.charCodeAt(i)) >>> 0;
  }
  return hash.toString(16).padStart(8, '0');
}

// ==================== COMMUNICATION NUI ====================

/**
 * Envoie une requête NUI au serveur FiveM.
 * Timeout 8 secondes pour éviter de bloquer l'UI.
 */
export async function sendToServer(event: string, data: object = {}): Promise<unknown> {
  const controller = new AbortController();
  const timeoutId  = setTimeout(() => controller.abort(), 8000);
  try {
    const resp = await fetch(`https://${RESOURCE_NAME}/${event}`, {
      method : 'POST',
      headers: { 'Content-Type': 'application/json' },
      body   : JSON.stringify(data),
      signal : controller.signal,
    });
    clearTimeout(timeoutId);
    if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
    return await resp.json().catch(() => ({}));
  } catch (err: unknown) {
    clearTimeout(timeoutId);
    if (err instanceof Error && err.name === 'AbortError') {
      console.warn(`[KT Banque] NUI timeout (${event})`);
    } else {
      console.error(`[KT Banque] NUI error (${event}):`, err);
    }
    throw err;
  }
}
