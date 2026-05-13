// ==================== KT BANQUE v7.5.0 - UTILS ====================
// CORRECTIONS v7.5.0 :
//   FIX-1 : sendToServer — les events NUI correspondent aux RegisterNUICallback Lua.
//   FIX-2 : hashPin — commentaire d'alignement avec Utils.HashPin Lua.
//   FIX-3 : sendNUI ajouté pour les callbacks sans réponse attendue.

export const RESOURCE_NAME: string =
  typeof (window as unknown as Record<string, unknown>)['GetParentResourceName'] === 'function'
    ? (window as unknown as Record<string, () => string>)['GetParentResourceName']()
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

// FIX-1 : clés alignées avec Config.BankCardItem côté Lua
export function cardTypeLabel(type: string): string {
  const map: Record<string, string> = {
    card_basic   : '⬡ Basique',
    card_gold    : '◆ Or',
    card_diamond : '◈ Diamant',
  };
  return map[type] ?? type;
}

// ==================== SÉCURITÉ ====================

/**
 * FIX-2 : Hash PIN côté client — IDENTIQUE à Utils.HashPin dans server/modules/utils.lua
 *
 * Lua :   hash = (hash * 31 + combined:byte(i)) % 4294967296
 * JS  :   hash = (Math.imul(hash, 31) + combined.charCodeAt(i)) >>> 0
 *
 * Les deux sont équivalents sur les entiers non-signés 32 bits.
 */
export function hashPin(pin: string): string {
  const salt     = 'kt_banque_v7';
  const combined = salt + pin;
  let hash       = 0;
  for (let i = 0; i < combined.length; i++) {
    hash = (Math.imul(hash, 31) + combined.charCodeAt(i)) >>> 0;
  }
  return hash.toString(16).padStart(8, '0');
}

// ==================== COMMUNICATION NUI ====================

/**
 * FIX-1 : envoie une requête NUI vers un RegisterNUICallback Lua.
 * Les noms d'événements doivent correspondre exactement aux callbacks enregistrés.
 *
 * Callbacks disponibles (client/modules/ui.lua + card_recovery.lua) :
 *   'close', 'deposit', 'withdraw', 'transfer', 'createAccount', 'recoverCard', 'selfBlockCard'
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

/**
 * FIX-3 : variante sans attente de réponse (fire-and-forget)
 * Utile pour 'close', 'recoverCard', 'selfBlockCard'
 */
export function sendNUI(event: string, data: object = {}): void {
  sendToServer(event, data).catch(() => {
    // silencieux — le Lua a déjà fermé ou le joueur est déconnecté
  });
}
