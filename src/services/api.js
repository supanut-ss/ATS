/** API client for the production backend. */

const isLocalHost = typeof window !== 'undefined'
  && (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1');

export const BASE_URL = import.meta.env.VITE_API_URL
  || (isLocalHost ? 'http://localhost:5000' : '');

export function createApiClient(baseUrl) {
  const accessKeyStorageName = 'ats_dashboard_access_key';
  const readAccessKey = () => {
    if (typeof window === 'undefined') return '';
    try {
      return window.sessionStorage.getItem(accessKeyStorageName) || '';
    } catch {
      return '';
    }
  };

  const apiCall = async (path, options = {}) => {
    try {
      const accessKey = readAccessKey();
      const headers = {
        'Content-Type': 'application/json',
        ...(options.headers || {}),
      };
      if (accessKey) headers.Authorization = `Bearer ${accessKey}`;
      const res = await fetch(`${baseUrl}${path}`, {
        ...options,
        headers,
      });
      const data = await res.json();
      return { ok: res.ok, data };
    } catch (err) {
      return { ok: false, data: { error: err.message || 'Network error' } };
    }
  };

  return {
    baseUrl,
    hasAccessKey: () => Boolean(readAccessKey()),
    setAccessKey: (value) => {
      if (typeof window === 'undefined') return;
      const normalized = String(value || '').trim();
      if (normalized) window.sessionStorage.setItem(accessKeyStorageName, normalized);
      else window.sessionStorage.removeItem(accessKeyStorageName);
    },
    clearAccessKey: () => {
      if (typeof window !== 'undefined') window.sessionStorage.removeItem(accessKeyStorageName);
    },
    getStatus:     () => apiCall('/api/status'),
    getAccount:    () => apiCall('/api/account'),
    getPrice:      () => apiCall('/api/price'),
    getPositions:  () => apiCall('/api/positions'),
    getHistory:    (days = 7) => apiCall(`/api/history?days=${days}`),
    getRisk:       () => apiCall('/api/risk'),
    openTrade: (action, sl = 0, tp = 0) => apiCall('/api/trade', {
      method: 'POST',
      body: JSON.stringify({ action, sl, tp }),
    }),
    closePosition: (ticket) => apiCall(`/api/close/${ticket}`, { method: 'POST' }),
    closeAllPositions: () => apiCall('/api/close-all', { method: 'POST' }),
    modifyPosition: (ticket, sl, tp) => apiCall(`/api/modify/${ticket}`, {
      method: 'POST',
      body: JSON.stringify({ sl, tp }),
    }),
    getSignals:   () => apiCall('/api/signals'),
    clearSignals: () => apiCall('/api/signals/clear', { method: 'POST' }),
    getWebhookLog: () => apiCall('/api/webhook/log'),
    sendTestWebhook: (payload) => apiCall('/webhook', {
      method: 'POST',
      body: JSON.stringify(payload),
    }),
  };
}

export const productionApi = createApiClient(BASE_URL);

// Backward-compatible production exports for components not mounted by App yet.
export const getStatus = productionApi.getStatus;
export const getAccount = productionApi.getAccount;
export const getPrice = productionApi.getPrice;
export const getPositions = productionApi.getPositions;
export const getHistory = productionApi.getHistory;
export const getRisk = productionApi.getRisk;
export const openTrade = productionApi.openTrade;
export const closePosition = productionApi.closePosition;
export const closeAllPositions = productionApi.closeAllPositions;
export const modifyPosition = productionApi.modifyPosition;
export const getSignals = productionApi.getSignals;
export const clearSignals = productionApi.clearSignals;
export const getWebhookLog = productionApi.getWebhookLog;
