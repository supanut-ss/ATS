/**
 * API clients for the isolated production and script-test environments.
 * /demo uses the same backend process through the /demo namespace.
 */

const isLocalHost = typeof window !== 'undefined'
  && (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1');

export const BASE_URL = import.meta.env.VITE_API_URL
  || (isLocalHost ? 'http://localhost:5000' : '');

export const DEMO_BASE_URL = import.meta.env.VITE_DEMO_API_URL
  || (isLocalHost ? 'http://localhost:5000/demo' : '/demo');

export function createApiClient(baseUrl) {
  const apiCall = async (path, options = {}) => {
    try {
      const res = await fetch(`${baseUrl}${path}`, {
        headers: { 'Content-Type': 'application/json' },
        ...options,
      });
      const data = await res.json();
      return { ok: res.ok, data };
    } catch (err) {
      return { ok: false, data: { error: err.message || 'Network error' } };
    }
  };

  return {
    baseUrl,
    getStatus:     () => apiCall('/api/status'),
    connectMT5:    () => apiCall('/api/connect', { method: 'POST' }),
    disconnectMT5: () => apiCall('/api/disconnect', { method: 'POST' }),
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
export const demoApi = createApiClient(DEMO_BASE_URL);
export const getApiClient = (isDemo = false) => isDemo ? demoApi : productionApi;

// Backward-compatible production exports for components not mounted by App yet.
export const getStatus = productionApi.getStatus;
export const connectMT5 = productionApi.connectMT5;
export const disconnectMT5 = productionApi.disconnectMT5;
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
