import React, { useState, useEffect, useCallback } from 'react';
import {
  ThemeProvider, createTheme, CssBaseline, Box,
  AppBar, Toolbar, Typography, IconButton, Drawer, List, ListItem,
  ListItemButton, ListItemIcon, ListItemText, Badge, Chip,
  Grid, Button, Tooltip, CircularProgress,
} from '@mui/material';
import {
  Dashboard as DashboardIcon,
  SwapVert as PositionsIcon,
  History as HistoryIcon,
  Settings as SettingsIcon,
  Menu as MenuIcon,
  Refresh as RefreshIcon,
  MonetizationOn,
  Webhook,
  Toll,
  Link as LinkIcon,
  LinkOff,
} from '@mui/icons-material';

import AccountCard       from './components/AccountCard';

import PositionsTable    from './components/PositionsTable';
import TradeHistoryTable from './components/TradeHistoryTable';
import ManualTradePanel  from './components/ManualTradePanel';
import WebhookGuide      from './components/WebhookGuide';
import SignalsTracker    from './components/SignalsTracker';
import QuickOverview     from './components/QuickOverview';

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

const DRAWER_WIDTH = 220;

const NAV_ITEMS = [
  { id: 'dashboard', label: 'ภาพรวม & เทรด', icon: <DashboardIcon />, desc: 'บัญชี สถิติ และการส่งคำสั่ง' },
  { id: 'signals',   label: 'สัญญาณ',     icon: <Toll />,        desc: 'ผลลัพธ์สัญญาณ' },
  { id: 'history',   label: 'ประวัติ',    icon: <HistoryIcon />, desc: 'ประวัติการเทรด' },
  { id: 'settings',  label: 'คู่มือตั้งค่า', icon: <Webhook />, desc: 'Webhook & MT5' },
];

export default function App() {
  const [page, setPage]             = useState('dashboard');
  const [mobileOpen, setMobileOpen] = useState(false);

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
  }, []);

  useEffect(() => {
    fetchAll(false);
    const id = setInterval(() => fetchAll(true), 5000);
    return () => clearInterval(id);
  }, [fetchAll]);

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

  const currentNav = NAV_ITEMS.find(n => n.id === page);

  const sidebarContent = (
    <Box sx={{ height: '100%', display: 'flex', flexDirection: 'column', bgcolor: '#0d1117' }}>
      <Toolbar sx={{ gap: 1.5, borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
        <Box sx={{
          p: 0.7, borderRadius: 1.5,
          background: 'linear-gradient(135deg,#f59e0b,#d97706)',
        }}>
          <MonetizationOn sx={{ fontSize: 20, color: '#fff' }} />
        </Box>
        <Box>
          <Typography variant="subtitle1" sx={{ fontWeight: 800, lineHeight: 1.1, background: 'linear-gradient(90deg,#fbbf24,#f59e0b)', WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent' }}>
            XAUUSD Bot
          </Typography>
          <Typography variant="caption" sx={{ color: 'text.secondary' }}>Exness · Demo</Typography>
        </Box>
      </Toolbar>

      <List sx={{ px: 1.5, pt: 1.5, flexGrow: 1 }}>
        {NAV_ITEMS.map(item => (
          <ListItem key={item.id} disablePadding sx={{ mb: 0.5 }}>
            <ListItemButton
              selected={page === item.id}
              onClick={() => { setPage(item.id); setMobileOpen(false); }}
              sx={{
                borderRadius: 2,
                py: 1.2,
                '&.Mui-selected': {
                  bgcolor: 'rgba(99,102,241,0.12)',
                  borderLeft: '3px solid #6366f1',
                  '& .MuiListItemIcon-root': { color: '#818cf8' },
                  '& .MuiListItemText-primary': { color: '#fff', fontWeight: 700 },
                },
                '&:hover': { bgcolor: 'rgba(255,255,255,0.03)' },
              }}
            >
              <ListItemIcon sx={{ minWidth: 36, color: 'text.secondary' }}>
                {item.id === 'dashboard'
                  ? <Badge badgeContent={positions.length || null} color="primary" max={9}>
                      {item.icon}
                    </Badge>
                  : item.icon}
              </ListItemIcon>
              <ListItemText
                primary={item.label}
                secondary={item.desc}
                primaryTypographyProps={{ variant: 'body2', fontWeight: 500 }}
                secondaryTypographyProps={{ variant: 'caption', sx: { fontSize: '0.65rem', lineHeight: 1.2 } }}
              />
            </ListItemButton>
          </ListItem>
        ))}
      </List>

      <Box sx={{ p: 2, borderTop: '1px solid rgba(255,255,255,0.05)', display: 'flex', flexDirection: 'column', gap: 1 }}>
        <Chip
          label={connected ? '● MT5 เชื่อมต่อแล้ว' : '○ MT5 ยังไม่เชื่อมต่อ'}
          size="small"
          sx={{
            width: '100%',
            bgcolor: connected ? 'rgba(16,185,129,0.08)' : 'rgba(244,63,94,0.08)',
            color:   connected ? '#10b981' : '#f43f5e',
            fontWeight: 700, borderRadius: 1.5,
          }}
        />
        {!connected ? (
          <Button
            variant="contained"
            size="small"
            fullWidth
            startIcon={<LinkIcon />}
            onClick={handleConnect}
            sx={{ background: 'linear-gradient(135deg,#6366f1,#4f46e5)' }}
          >
            เชื่อมต่อ MT5
          </Button>
        ) : (
          <Button
            variant="outlined"
            size="small"
            fullWidth
            startIcon={<LinkOff />}
            onClick={handleDisconnect}
            sx={{ borderColor: 'rgba(244,63,94,0.3)', color: '#f43f5e' }}
          >
            ตัดการเชื่อมต่อ
          </Button>
        )}
      </Box>
    </Box>
  );

  const renderPage = () => {
    switch (page) {
      case 'dashboard':
        return (
          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2.5 }}>
            {/* Stats strip — fixed 72px */}
            <QuickOverview
              connected={connected}
              account={account}
              price={price}
              positions={positions}
              risk={risk}
            />

            {/* 3-column row — always horizontal, equal 360px height */}
            <Box sx={{ display: 'flex', gap: 2.5, alignItems: 'stretch', minWidth: 0 }}>
              {/* Account (30%) */}
              <Box sx={{ flex: '0 0 30%', minWidth: 0 }}>
                <AccountCard
                  account={account}
                  connected={connected}
                  onConnect={handleConnect}
                  onDisconnect={handleDisconnect}
                />
              </Box>
              {/* Trade Panel (30%) */}
              <Box sx={{ flex: '0 0 30%', minWidth: 0 }}>
                <ManualTradePanel price={price} risk={risk} onRefresh={fetchAll} />
              </Box>
              {/* Positions Table (40%) */}
              <Box sx={{ flex: '1 1 0', minWidth: 0 }}>
                <PositionsTable positions={positions} onRefresh={fetchAll} />
              </Box>
            </Box>
          </Box>
        );

      case 'signals':
        return <SignalsTracker signals={signals} loading={loading} onRefresh={fetchAll} />;

      case 'history':
        return <TradeHistoryTable history={history} loading={false} />;

      case 'settings':
        return <WebhookGuide serverStatus={connected} onRefresh={fetchAll} />;

      default:
        return null;
    }
  };

  return (
    <ThemeProvider theme={theme}>
      <CssBaseline />

      <style>{`
        @keyframes pulse {
          0%, 100% { opacity: 1; transform: scale(1); }
          50% { opacity: 0.5; transform: scale(0.85); }
        }
      `}</style>

      <Box sx={{ display: 'flex', minHeight: '100vh', bgcolor: 'background.default' }}>
        <AppBar
          position="fixed"
          sx={{
            width: { md: `calc(100% - ${DRAWER_WIDTH}px)` },
            ml: { md: `${DRAWER_WIDTH}px` },
            bgcolor: 'rgba(11,15,25,0.75)',
            backdropFilter: 'blur(12px)',
            borderBottom: '1px solid rgba(255,255,255,0.05)',
            boxShadow: 'none',
          }}
        >
          <Toolbar sx={{ gap: 1 }}>
            <IconButton sx={{ display: { md: 'none' } }} onClick={() => setMobileOpen(true)}>
              <MenuIcon />
            </IconButton>
            <Box sx={{ flexGrow: 1 }}>
              <Typography variant="h6" sx={{ fontWeight: 700, lineHeight: 1.2 }}>
                {currentNav?.label}
              </Typography>
              {currentNav?.desc && (
                <Typography variant="caption" sx={{ color: 'text.secondary', display: { xs: 'none', sm: 'block' } }}>
                  {currentNav.desc}
                </Typography>
              )}
            </Box>

            {lastRefresh && (
              <Typography variant="caption" sx={{ color: 'text.secondary', display: { xs: 'none', sm: 'block' } }}>
                อัปเดต {lastRefresh.toLocaleTimeString('th-TH')}
              </Typography>
            )}

            <Tooltip title="รีเฟรชข้อมูล">
              <IconButton onClick={fetchAll} disabled={loading} size="small">
                {loading
                  ? <CircularProgress size={18} sx={{ color: 'text.secondary' }} />
                  : <RefreshIcon sx={{ fontSize: 20 }} />
                }
              </IconButton>
            </Tooltip>

            {account && (
              <Chip
                label={`${account.profit >= 0 ? '+' : ''}$${Number(account.profit).toFixed(2)}`}
                size="small"
                sx={{
                  bgcolor: account.profit >= 0 ? 'rgba(16,185,129,0.12)' : 'rgba(244,63,94,0.12)',
                  color:   account.profit >= 0 ? '#10b981' : '#f43f5e',
                  fontWeight: 700,
                }}
              />
            )}
          </Toolbar>
        </AppBar>

        <Drawer
          variant="temporary"
          open={mobileOpen}
          onClose={() => setMobileOpen(false)}
          ModalProps={{ keepMounted: true }}
          sx={{ display: { xs: 'block', md: 'none' }, '& .MuiDrawer-paper': { width: DRAWER_WIDTH, backgroundImage: 'none' } }}
        >
          {sidebarContent}
        </Drawer>

        <Drawer
          variant="permanent"
          sx={{
            display: { xs: 'none', md: 'block' },
            '& .MuiDrawer-paper': { width: DRAWER_WIDTH, borderRight: '1px solid rgba(255,255,255,0.05)', backgroundImage: 'none' },
          }}
          open
        >
          {sidebarContent}
        </Drawer>

        <Box
          component="main"
          sx={{
            flexGrow: 1,
            p: { xs: 2, sm: 3 },
            pt: { xs: 9, sm: 10 },
            width: { md: `calc(100% - ${DRAWER_WIDTH}px)` },
            ml: { md: `${DRAWER_WIDTH}px` },
            minHeight: '100vh',
          }}
        >
          {renderPage()}
        </Box>
      </Box>
    </ThemeProvider>
  );
}
