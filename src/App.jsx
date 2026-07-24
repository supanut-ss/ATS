import React, { useState, useEffect, useCallback } from 'react';
import {
  ThemeProvider, createTheme, CssBaseline, Box,
  AppBar, Toolbar, Typography, IconButton, Grid, Button, Tooltip, CircularProgress,
  Chip, Dialog, DialogTitle, DialogContent, DialogActions,
} from '@mui/material';
import {
  Refresh as RefreshIcon,
  MonetizationOn,
  Webhook,
  History as HistoryIcon,
  Link as LinkIcon,
  LinkOff,
  Close as CloseIcon,
} from '@mui/icons-material';

import PositionsTable    from './components/PositionsTable';
import TradeHistoryTable from './components/TradeHistoryTable';
import WebhookGuide      from './components/WebhookGuide';
import SignalsTracker    from './components/SignalsTracker';
import QuickOverview     from './components/QuickOverview';
import WorldCupPredictions from './components/WorldCupPredictions';

import {
  getStatus, getAccount, getPrice,
  getPositions, getHistory, getRisk,
  connectMT5, disconnectMT5, getSignals,
} from './services/api';

const theme = createTheme({
  palette: {
    mode: 'dark',
    primary:    { main: '#6366f1', light: '#818cf8', dark: '#4f46e5' },
    secondary:  { main: '#10b981' },
    error:      { main: '#f43f5e' },
    warning:    { main: '#f59e0b' },
    background: { default: '#0b0f19', paper: '#111827' },
    text:       { primary: '#f3f4f6', secondary: '#9ca3af' },
    divider:    'rgba(255,255,255,0.07)',
  },
  typography: {
    fontFamily: '"Plus Jakarta Sans","Outfit","Inter",sans-serif',
    button: { textTransform: 'none', fontWeight: 600 },
  },
  components: {
    MuiPaper: {
      styleOverrides: {
        root: {
          backgroundImage: 'none',
          borderRadius: 12,
          border: '1px solid rgba(255,255,255,0.05)',
          boxShadow: '0 4px 24px rgba(0,0,0,0.3)',
        },
      },
    },
    MuiTableCell: {
      styleOverrides: {
        root: { borderBottom: '1px solid rgba(255,255,255,0.04)' },
      },
    },
    MuiButton: {
      styleOverrides: { root: { borderRadius: 8, textTransform: 'none' } },
    },
  },
});

export default function App() {
  if (window.location.pathname === '/trade') {
    window.location.replace('/');
    return null;
  }

  const isTradeRoute = window.location.pathname !== '/wc2026';

  const [guideOpen, setGuideOpen]     = useState(false);
  const [historyOpen, setHistoryOpen] = useState(false);

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
        getStatus(), getAccount(), getPrice(),
        getPositions(), getHistory(), getRisk(),
        getSignals(),
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
  }, [isTradeRoute]);

  useEffect(() => {
    if (!isTradeRoute) return;
    fetchAll(false);
    const id = setInterval(() => fetchAll(true), 5000);
    return () => clearInterval(id);
  }, [fetchAll, isTradeRoute]);

  const handleConnect = async () => {
    const res = await connectMT5();
    if (res.ok) fetchAll();
  };

  const handleDisconnect = async () => {
    await disconnectMT5();
    setStatus(s => ({ ...s, mt5_connected: false }));
    setAccount(null);
    setPositions([]);
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
          bgcolor: 'rgba(11,15,25,0.75)',
          backdropFilter: 'blur(12px)',
          borderBottom: '1px solid rgba(255,255,255,0.05)',
          boxShadow: 'none',
        }}
      >
        <Toolbar sx={{ display: 'flex', justifyContent: 'space-between', px: { xs: 2, sm: 4 }, gap: 2 }}>
          {/* Logo / Title */}
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5 }}>
            <Box sx={{
              p: 0.7, borderRadius: 1.5,
              background: 'linear-gradient(135deg,#6366f1,#d97706)',
              display: 'flex',
              alignItems: 'center',
            }}>
              <MonetizationOn sx={{ fontSize: 22, color: '#fff' }} />
            </Box>
            <Box>
              <Typography variant="h6" sx={{ fontWeight: 800, lineHeight: 1.1, background: 'linear-gradient(90deg,#fbbf24,#f59e0b)', WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent' }}>
                XAUUSD Bot Dashboard
              </Typography>
              <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block', fontSize: '0.7rem' }}>
                Exness Demo · Automated Pure Structure EA
              </Typography>
            </Box>
          </Box>

          {/* Center/Right Status and Actions */}
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
            {lastRefresh && (
              <Typography variant="caption" sx={{ color: 'text.secondary', display: { xs: 'none', lg: 'block' } }}>
                อัปเดต {lastRefresh.toLocaleTimeString('th-TH')}
              </Typography>
            )}

            {/* Refresh Button */}
            <Tooltip title="รีเฟรชข้อมูล">
              <IconButton onClick={() => fetchAll(false)} disabled={loading} size="small" sx={{ border: '1px solid rgba(255,255,255,0.08)' }}>
                {loading
                  ? <CircularProgress size={18} sx={{ color: 'text.secondary' }} />
                  : <RefreshIcon sx={{ fontSize: 18, color: 'text.secondary' }} />
                }
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
                  fontWeight: 700,
                  fontSize: '0.75rem',
                  px: 0.5,
                }}
              />
            )}

            {/* Quick Actions */}
            <Box sx={{ display: 'flex', gap: 1 }}>
              <Button
                variant="outlined"
                startIcon={<Webhook />}
                onClick={() => setGuideOpen(true)}
                sx={{
                  borderRadius: 2,
                  fontSize: '0.8rem',
                  borderColor: 'rgba(99,102,241,0.25)',
                  color: '#818cf8',
                  '&:hover': { borderColor: '#818cf8', bgcolor: 'rgba(99,102,241,0.04)' }
                }}
              >
                คู่มือการตั้งค่า
              </Button>
              <Button
                variant="outlined"
                startIcon={<HistoryIcon />}
                onClick={() => setHistoryOpen(true)}
                sx={{
                  borderRadius: 2,
                  fontSize: '0.8rem',
                  borderColor: 'rgba(255,255,255,0.08)',
                  color: 'text.primary',
                  '&:hover': { borderColor: 'rgba(255,255,255,0.2)', bgcolor: 'rgba(255,255,255,0.02)' }
                }}
              >
                ประวัติการเทรด
              </Button>
              <Button
                variant="contained"
                onClick={connected ? handleDisconnect : handleConnect}
                color={connected ? 'error' : 'primary'}
                size="medium"
                startIcon={connected ? <LinkOff /> : <LinkIcon />}
                sx={{
                  borderRadius: 2,
                  fontSize: '0.8rem',
                  fontWeight: 700,
                  background: connected ? undefined : 'linear-gradient(135deg,#6366f1,#4f46e5)',
                  boxShadow: connected ? undefined : '0 4px 12px rgba(99,102,241,0.2)',
                }}
              >
                {connected ? 'ยกเลิกเชื่อมต่อ MT5' : 'เชื่อมต่อ MT5'}
              </Button>
            </Box>
          </Box>
        </Toolbar>
      </AppBar>

      {/* --- Main Dashboard Container --- */}
      <Box
        component="main"
        sx={{
          flexGrow: 1,
          px: { xs: 2, sm: 4 },
          pb: { xs: 4, sm: 6 },
          pt: { xs: 11, sm: 12 },
          minHeight: '100vh',
          bgcolor: 'background.default',
        }}
      >
        <Box sx={{ display: 'flex', flexDirection: 'column', gap: 3.5, maxWidth: '1440px', mx: 'auto' }}>
          
          {/* 1. Quick Statistics Strip */}
          <QuickOverview
            connected={connected}
            account={account}
            price={price}
            positions={positions}
            risk={risk}
          />

          {/* 2. Main content layout */}
          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 3.5 }}>
            {/* Active Positions */}
            <PositionsTable positions={positions} onRefresh={fetchAll} />
            
            {/* Signals Tracker */}
            <SignalsTracker signals={signals} loading={loading} onRefresh={fetchAll} />
          </Box>
        </Box>
      </Box>

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
          <Typography variant="h6" sx={{ fontWeight: 800 }}>คู่มือระบบ & การทำงาน</Typography>
          <IconButton onClick={() => setGuideOpen(false)} size="small" sx={{ color: 'text.secondary' }}>
            <CloseIcon />
          </IconButton>
        </DialogTitle>
        <DialogContent dividers sx={{ borderColor: 'rgba(255,255,255,0.05)', px: { xs: 2, sm: 3 } }}>
          <WebhookGuide serverStatus={connected} />
        </DialogContent>
        <DialogActions sx={{ p: 2 }}>
          <Button variant="contained" onClick={() => setGuideOpen(false)} sx={{ px: 3, borderRadius: 1.5 }}>
            ปิดหน้าต่าง
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
          <Typography variant="h6" sx={{ fontWeight: 800 }}>ประวัติการทำรายการล่าสุด</Typography>
          <IconButton onClick={() => setHistoryOpen(false)} size="small" sx={{ color: 'text.secondary' }}>
            <CloseIcon />
          </IconButton>
        </DialogTitle>
        <DialogContent dividers sx={{ borderColor: 'rgba(255,255,255,0.05)', p: 0 }}>
          <TradeHistoryTable history={history} loading={false} />
        </DialogContent>
        <DialogActions sx={{ p: 2 }}>
          <Button variant="contained" onClick={() => setHistoryOpen(false)} sx={{ px: 3, borderRadius: 1.5 }}>
            ปิดหน้าต่าง
          </Button>
        </DialogActions>
      </Dialog>
    </ThemeProvider>
  );
}
