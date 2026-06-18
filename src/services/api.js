/**
 * api.js — Backend REST API service layer
 * Communicates with the Python Flask server running on localhost:5000
 */

const BASE_URL = import.meta.env.VITE_API_URL || "http://localhost:5000";

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
