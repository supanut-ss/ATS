/**
 * api.js — Backend REST API service layer
 * Communicates with the Python Flask server running on localhost:5000
 */

export const BASE_URL = import.meta.env.VITE_API_URL ||
  (typeof window !== "undefined" && (window.location.hostname === "localhost" || window.location.hostname === "127.0.0.1")
    ? "http://localhost:5000"
    : "");

async function apiCall(path, options = {}) {
  try {
    const res = await fetch(`${BASE_URL}${path}`, {
      headers: { "Content-Type": "application/json" },
      ...options,
    });
    const data = await res.json();
    return { ok: res.ok, data };
  } catch (err) {
    return { ok: false, data: { error: err.message || "Network error" } };
  }
}

// ──────────────────────────────────────────────
// Status & Connection
// ──────────────────────────────────────────────
export const getStatus     = () => apiCall("/api/status");
export const connectMT5    = () => apiCall("/api/connect",    { method: "POST" });
export const disconnectMT5 = () => apiCall("/api/disconnect", { method: "POST" });

// ──────────────────────────────────────────────
// Market Data
// ──────────────────────────────────────────────
export const getAccount    = () => apiCall("/api/account");
export const getPrice      = () => apiCall("/api/price");
export const getPositions  = () => apiCall("/api/positions");
export const getHistory    = (days = 7) => apiCall(`/api/history?days=${days}`);
export const getRisk       = () => apiCall("/api/risk");

// ──────────────────────────────────────────────
// Trade Operations
// ──────────────────────────────────────────────
export const openTrade = (action, sl = 0, tp = 0) =>
  apiCall("/api/trade", {
    method: "POST",
    body: JSON.stringify({ action, sl, tp }),
  });

export const closePosition = (ticket) =>
  apiCall(`/api/close/${ticket}`, { method: "POST" });

export const closeAllPositions = () =>
  apiCall("/api/close-all", { method: "POST" });

export const modifyPosition = (ticket, sl, tp) =>
  apiCall(`/api/modify/${ticket}`, {
    method: "POST",
    body: JSON.stringify({ sl, tp }),
  });

// ──────────────────────────────────────────────
// Signal performance tracking (for .NET Backend)
// ──────────────────────────────────────────────
export const getSignals    = () => apiCall("/api/signals");
export const clearSignals  = () => apiCall("/api/signals/clear", { method: "POST" });
export const getWebhookLog = () => apiCall("/api/webhook/log");

export const sendTestWebhook = (action = "BUY") => {
  const id = `dashboard_test_${Date.now()}`;
  const price = 2650.0;
  const payload = action === "BUY" || action === "SELL"
    ? {
        token: "ats_sec_9f5c4b8e2a1d7f0e3c6b8a9f",
        action,
        symbol: "XAUUSD",
        signal_id: id,
        entry_price: price,
        sl: action === "BUY" ? price - 10 : price + 10,
        tp: action === "BUY" ? price + 20 : price - 20,
        rr: 2,
        timeframe: "5",
        bar_time: Date.now(),
        comment: `Dashboard Test ${action}`,
      }
    : {
        token: "ats_sec_9f5c4b8e2a1d7f0e3c6b8a9f",
        action: "CLOSE_SIGNAL",
        symbol: "XAUUSD",
        signal_id: id,
        entry_price: price - 10,
        exit_price: price,
        profit: action === "WIN" ? 200 : -100,
        result: action,
        timeframe: "5",
        bar_time: Date.now(),
      };
  return apiCall("/webhook", { method: "POST", body: JSON.stringify(payload) });
};

