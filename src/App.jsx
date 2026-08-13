import { useState, useEffect, useCallback } from 'react';
import {
  ThemeProvider, createTheme, CssBaseline, Box,
  AppBar, Toolbar, Typography, IconButton, Button, Tooltip, CircularProgress,
  Chip, Dialog, DialogTitle, DialogContent, DialogActions,
  Alert, TextField,
} from '@mui/material';
import {
  Refresh as RefreshIcon,
  MonetizationOn,
  Webhook,
  Close as CloseIcon,
  Key as KeyIcon,
} from '@mui/icons-material';

import PositionsTable    from './components/PositionsTable';
import TradeHistoryTable from './components/TradeHistoryTable';
import WebhookGuide      from './components/WebhookGuide';
import SignalsTracker    from './components/SignalsTracker';
import QuickOverview     from './components/QuickOverview';
import WorldCupPredictions from './components/WorldCupPredictions';

import { productionApi } from './services/api';

const theme = createTheme({
  palette: {
    mode: 'dark',
    primary:    { main: '#6366f1', light: '#818cf8', dark: '#4f46e5' },
    secondary:  { main: '#10b981' },
    error:      { main: '#f43f5e' },
    warning:    { main: '#f59e0b' },
    background: { default: '#05070f', paper: 'rgba(17, 24, 39, 0.75)' },
    text:       { primary: '#f3f4f6', secondary: '#9ca3af' },
    divider:    'rgba(255,255,255,0.06)',
  },
  typography: {
    fontFamily: '"Plus Jakarta Sans","Outfit","Inter",sans-serif',
    button: { textTransform: 'none', fontWeight: 700 },
  },
  components: {
    MuiPaper: {
      styleOverrides: {
        root: {
          backgroundImage: 'none',
          borderRadius: 16,
          border: '1px solid rgba(255,255,255,0.05)',
          boxShadow: '0 8px 32px 0 rgba(0, 0, 0, 0.3)',
          background: 'linear-gradient(180deg, rgba(20, 25, 40, 0.5) 0%, rgba(10, 15, 30, 0.8) 100%)',
          backdropFilter: 'blur(16px)',
        },
      },
    },
    MuiTableCell: {
      styleOverrides: {
        root: { borderBottom: '1px solid rgba(255,255,255,0.04)', py: 1.2 },
      },
    },
    MuiButton: {
      styleOverrides: { root: { borderRadius: 10, textTransform: 'none', fontWeight: 700 } },
    },
  },
});

export default function App() {
  const requestedPath = window.location.pathname.replace(/\/$/, '') || '/';
  const currentPath = requestedPath === '/trade' ? '/' : requestedPath;
  const isTradeRoute = currentPath !== '/wc2026';
  const apiClient = productionApi;

  const [guideOpen, setGuideOpen]     = useState(false);
  const [historyOpen, setHistoryOpen] = useState(false);
  const [accessKeyOpen, setAccessKeyOpen] = useState(false);
  const [accessKeyInput, setAccessKeyInput] = useState('');
  const [accessKeyConfigured, setAccessKeyConfigured] = useState(() => apiClient.hasAccessKey());

  const [status,    setStatus]    = useState(null);
  const [account,   setAccount]   = useState(null);
  const [price,     setPrice]     = useState(null);
  const [positions, setPositions] = useState([]);
  const [history,   setHistory]   = useState([]);
  const [risk,      setRisk]      = useState(null);
  const [signals,   setSignals]   = useState([]);

  const [loading,   setLoading]   = useState(false);
  const [lastRefresh, setLastRefresh] = useState(null);

  const connected = status?.mt5_connected || false;

  const fetchAll = useCallback(async (isBackground = false) => {
    if (!isTradeRoute) return;
    if (!isBackground) setLoading(true);
    try {
      const [s, a, p, pos, h, r, sigs] = await Promise.all([
        apiClient.getStatus(), apiClient.getAccount(), apiClient.getPrice(),
        apiClient.getPositions(), apiClient.getHistory(), apiClient.getRisk(),
        apiClient.getSignals(),
      ]);
      if (s.ok)   setStatus(s.data);
      if (a.ok)   setAccount(a.data);
      if (p.ok)   setPrice(p.data);
      if (pos.ok) setPositions(Array.isArray(pos.data) ? pos.data : []);
      if (h.ok)   setHistory(Array.isArray(h.data) ? h.data : []);
      if (r.ok)   setRisk(r.data);
      if (sigs.ok) setSignals(Array.isArray(sigs.data) ? sigs.data : []);
      setLastRefresh(new Date());
    } finally {
      if (!isBackground) setLoading(false);
    }
  }, [isTradeRoute, apiClient]);

  useEffect(() => {
    if (requestedPath !== '/' && requestedPath !== '/wc2026') {
      window.location.replace('/');
      return;
    }
    if (!isTradeRoute) return;
    fetchAll(false);
    const id = setInterval(() => fetchAll(true), 5000);
    return () => clearInterval(id);
  }, [fetchAll, isTradeRoute, requestedPath]);

  const saveAccessKey = () => {
    apiClient.setAccessKey(accessKeyInput);
    setAccessKeyConfigured(apiClient.hasAccessKey());
    setAccessKeyInput('');
    setAccessKeyOpen(false);
    fetchAll(false);
  };

  const clearAccessKey = () => {
    apiClient.clearAccessKey();
    setAccessKeyConfigured(false);
    setAccessKeyInput('');
    setAccessKeyOpen(false);
  };

  if (!isTradeRoute) {
    return (
      <ThemeProvider theme={theme}>
        <CssBaseline />
        <Box sx={{ p: { xs: 2, sm: 4 }, minHeight: '100vh', bgcolor: 'background.default' }}>
          <WorldCupPredictions />
        </Box>
      </ThemeProvider>
    );
  }

  return (
    <ThemeProvider theme={theme}>
      <CssBaseline />

      <style>{`
        @keyframes pulse {
          0%, 100% { opacity: 1; transform: scale(1); }
          50% { opacity: 0.5; transform: scale(0.85); }
        }
      `}</style>

      {/* --- Top Navbar --- */}
      <AppBar
        position="fixed"
        sx={{
          bgcolor: 'rgba(5, 7, 15, 0.75)',
          backdropFilter: 'blur(16px)',
          borderBottom: '1px solid rgba(255,255,255,0.05)',
          boxShadow: 'none',
        }}
      >
        <Toolbar sx={{ display: 'flex', justifyContent: 'space-between', px: { xs: 2, sm: 4 }, gap: 2 }}>
          {/* Logo / Title */}
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5 }}>
            <Box sx={{
              p: 0.7, borderRadius: 2,
              background: 'linear-gradient(135deg,#6366f1,#fbbf24)',
              display: 'flex',
              alignItems: 'center',
            }}>
              <MonetizationOn sx={{ fontSize: 22, color: '#fff' }} />
            </Box>
            <Box>
              <Typography variant="h6" sx={{ fontWeight: 800, lineHeight: 1.1, fontSize: { xs: '1rem', sm: '1.15rem' }, background: 'linear-gradient(90deg,#FFE082,#FFB300)', WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent' }}>
                XAUUSD Bot Dashboard
              </Typography>
              <Typography variant="caption" sx={{ color: 'text.secondary', display: { xs: 'none', sm: 'block' }, fontSize: '0.68rem', fontWeight: 500 }}>
                LIVE · Automated Pure Structure EA
              </Typography>
            </Box>
          </Box>

          {/* Center/Right Status and Actions */}
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
            {lastRefresh && (
              <Typography variant="caption" sx={{ color: 'text.secondary', display: { xs: 'none', lg: 'block' }, fontWeight: 500 }}>
                Updated {lastRefresh.toLocaleTimeString('en-US')}
              </Typography>
            )}

            {/* Refresh Button */}
            <Tooltip title="Refresh data">
              <IconButton onClick={() => fetchAll(false)} disabled={loading} size="small" sx={{ border: '1px solid rgba(255,255,255,0.08)', borderRadius: 1.5 }}>
                {loading
                  ? <CircularProgress size={18} sx={{ color: 'text.secondary' }} />
                  : <RefreshIcon sx={{ fontSize: 18, color: 'text.secondary' }} />
                }
              </IconButton>
            </Tooltip>

            <Tooltip title={accessKeyConfigured ? 'Dashboard access key is set for this session' : 'Set dashboard access key'}>
              <IconButton
                onClick={() => setAccessKeyOpen(true)}
                size="small"
                color={accessKeyConfigured ? 'success' : 'default'}
                sx={{ border: '1px solid rgba(255,255,255,0.08)', borderRadius: 1.5 }}
              >
                <KeyIcon sx={{ fontSize: 18 }} />
              </IconButton>
            </Tooltip>

            {/* Float Profit/Loss Chip */}
            {account && (
              <Chip
                label={`${account.profit >= 0 ? '+' : ''}$${Number(account.profit).toFixed(2)}`}
                size="small"
                sx={{
                  bgcolor: account.profit >= 0 ? 'rgba(16,185,129,0.12)' : 'rgba(244,63,94,0.12)',
                  color:   account.profit >= 0 ? '#10b981' : '#f43f5e',
                  fontWeight: 800,
                  fontSize: '0.75rem',
                  px: 0.5,
                  borderRadius: 1.5
                }}
              />
            )}

            {/* Quick Actions */}
            <Box sx={{ display: 'flex', gap: 1 }}>
              <Button
                variant="outlined"
                onClick={() => setGuideOpen(true)}
                sx={{
                  minWidth: { xs: 40, md: 'auto' },
                  px: { xs: 1, md: 2 },
                  borderRadius: 2,
                  fontSize: '0.8rem',
                  borderColor: 'rgba(99,102,241,0.25)',
                  color: '#818cf8',
                  '&:hover': { borderColor: '#818cf8', bgcolor: 'rgba(99,102,241,0.04)' }
                }}
              >
                <Webhook sx={{ mr: { xs: 0, md: 1 }, fontSize: 20 }} />
                <Box component="span" sx={{ display: { xs: 'none', md: 'inline' } }}>Setup Guide</Box>
              </Button>
              <Chip
                label={connected ? 'MT5 LIVE' : 'MT5 OFFLINE'}
                color={connected ? 'success' : 'default'}
                size="small"
                sx={{ fontWeight: 800 }}
              />
            </Box>
          </Box>
        </Toolbar>
      </AppBar>

      {/* --- Main Dashboard Container --- */}
      <Box
        component="main"
        sx={{
          flexGrow: 1,
          px: { xs: 2, sm: 3, md: 4 },
          pb: { xs: 4, sm: 6 },
          pt: { xs: 11, sm: 12 },
          minHeight: '100vh',
          bgcolor: 'background.default',
          backgroundImage: 'none',
        }}
      >
        <Box sx={{ display: 'flex', flexDirection: 'column', gap: 3.5, width: '100%', maxWidth: '1680px', mx: 'auto' }}>
          <QuickOverview
            connected={connected}
            account={account}
            price={price}
            positions={positions}
            risk={risk}
          />

          <PositionsTable positions={positions} onRefresh={fetchAll} apiClient={apiClient} actionsDisabled={false} />

          <SignalsTracker signals={signals} loading={loading} onRefresh={fetchAll} apiClient={apiClient} actionsDisabled={false} />
        </Box>
      </Box>

      <Dialog open={accessKeyOpen} onClose={() => setAccessKeyOpen(false)} maxWidth="xs" fullWidth>
        <DialogTitle>Dashboard access key</DialogTitle>
        <DialogContent>
          <Alert severity="info" sx={{ mb: 2 }}>
            The key stays only in this browser-tab session and is never included in the website bundle.
          </Alert>
          <TextField
            autoFocus
            fullWidth
            type="password"
            label="X-Dashboard-Access-Key"
            placeholder="Paste your access key"
            value={accessKeyInput}
            onChange={(event) => setAccessKeyInput(event.target.value)}
            onKeyDown={(event) => {
              if (event.key === 'Enter' && accessKeyInput.trim()) saveAccessKey();
            }}
          />
        </DialogContent>
        <DialogActions>
          {accessKeyConfigured && <Button color="error" onClick={clearAccessKey}>Clear</Button>}
          <Button onClick={() => setAccessKeyOpen(false)}>Cancel</Button>
          <Button variant="contained" disabled={!accessKeyInput.trim()} onClick={saveAccessKey}>Save for session</Button>
        </DialogActions>
      </Dialog>

      {/* --- Guide Dialog Popup --- */}
      <Dialog
        open={guideOpen}
        onClose={() => setGuideOpen(false)}
        maxWidth="md"
        fullWidth
        scroll="paper"
        PaperProps={{
          sx: {
            bgcolor: 'background.paper',
            backgroundImage: 'none',
            borderRadius: 3,
            border: '1px solid rgba(255,255,255,0.08)',
          }
        }}
      >
        <DialogTitle sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', pb: 1 }}>
          <Typography variant="h6" sx={{ fontWeight: 800 }}>System & Setup Guide</Typography>
          <IconButton onClick={() => setGuideOpen(false)} size="small" sx={{ color: 'text.secondary' }}>
            <CloseIcon />
          </IconButton>
        </DialogTitle>
        <DialogContent dividers sx={{ borderColor: 'rgba(255,255,255,0.05)', px: { xs: 2, sm: 3 } }}>
          <WebhookGuide serverStatus={connected} backendUrl={apiClient.baseUrl} />
        </DialogContent>
        <DialogActions sx={{ p: 2 }}>
          <Button variant="contained" onClick={() => setGuideOpen(false)} sx={{ px: 3, borderRadius: 1.5 }}>
            Close
          </Button>
        </DialogActions>
      </Dialog>

      {/* --- History Dialog Popup --- */}
      <Dialog
        open={historyOpen}
        onClose={() => setHistoryOpen(false)}
        maxWidth="md"
        fullWidth
        scroll="paper"
        PaperProps={{
          sx: {
            bgcolor: 'background.paper',
            backgroundImage: 'none',
            borderRadius: 3,
            border: '1px solid rgba(255,255,255,0.08)',
          }
        }}
      >
        <DialogTitle sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', pb: 1 }}>
          <Typography variant="h6" sx={{ fontWeight: 800 }}>Trade History Log</Typography>
          <IconButton onClick={() => setHistoryOpen(false)} size="small" sx={{ color: 'text.secondary' }}>
            <CloseIcon />
          </IconButton>
        </DialogTitle>
        <DialogContent dividers sx={{ borderColor: 'rgba(255,255,255,0.05)', p: 0 }}>
          <TradeHistoryTable history={history} loading={false} />
        </DialogContent>
        <DialogActions sx={{ p: 2 }}>
          <Button variant="contained" onClick={() => setHistoryOpen(false)} sx={{ px: 3, borderRadius: 1.5 }}>
            Close
          </Button>
        </DialogActions>
      </Dialog>
    </ThemeProvider>
  );
}
