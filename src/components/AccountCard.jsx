import React from 'react';
import {
  Box, Paper, Typography, Chip, Button, Grid,
  LinearProgress, Skeleton, Tooltip,
} from '@mui/material';
import {
  AccountBalance, TrendingUp, TrendingDown,
  ShowChart, LinkOff,
} from '@mui/icons-material';

const fmt = (v, d = 2) =>
  v == null ? '—' : Number(v).toLocaleString('en-US', { minimumFractionDigits: d, maximumFractionDigits: d });

function StatItem({ label, value, color, icon, suffix = '' }) {
  return (
    <Box>
      <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600, letterSpacing: 0.5, textTransform: 'uppercase' }}>
        {label}
      </Typography>
      <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5, mt: 0.3 }}>
        {icon && React.cloneElement(icon, { sx: { fontSize: 16, color } })}
        <Typography variant="h5" sx={{ fontWeight: 700, color: color || 'text.primary' }}>
          {value}{suffix}
        </Typography>
      </Box>
    </Box>
  );
}

export default function AccountCard({ account, connected, onConnect, onDisconnect }) {
  if (!connected) {
    return (
      <Paper sx={{ p: 3, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2, borderColor: 'rgba(255,255,255,0.06)' }}>
        <LinkOff sx={{ fontSize: 40, color: 'text.disabled' }} />
        <Typography variant="subtitle1" sx={{ color: 'text.secondary' }}>MT5 Not Connected</Typography>
        <Button variant="contained" color="primary" onClick={onConnect} sx={{ background: 'linear-gradient(135deg,#6366f1,#4f46e5)' }}>
          Connect to MT5
        </Button>
      </Paper>
    );
  }

  if (!account) {
    return (
      <Paper sx={{ p: 3 }}>
        <Skeleton variant="text" width="40%" height={32} />
        <Skeleton variant="text" width="70%" height={24} />
        <Box sx={{ display: 'flex', gap: 2, mt: 2 }}>
          {[1, 2, 3, 4].map(i => <Skeleton key={i} variant="rectangular" width={120} height={60} sx={{ borderRadius: 2 }} />)}
        </Box>
      </Paper>
    );
  }

  const profitColor = account.profit >= 0 ? '#10b981' : '#f43f5e';
  const equityPct = account.balance > 0 ? (account.equity / account.balance) * 100 : 100;

  return (
    <Paper sx={{ p: 3 }}>
      {/* Header */}
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', mb: 2.5, flexWrap: 'wrap', gap: 1 }}>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5 }}>
          <Box sx={{
            p: 1, borderRadius: 2,
            background: 'linear-gradient(135deg,#6366f1,#a855f7)',
            display: 'flex', alignItems: 'center',
          }}>
            <AccountBalance sx={{ fontSize: 20, color: '#fff' }} />
          </Box>
          <Box>
            <Typography variant="h6" sx={{ fontWeight: 700, lineHeight: 1.1 }}>
              {account.name || 'Demo Account'}
            </Typography>
            <Typography variant="caption" sx={{ color: 'text.secondary' }}>
              #{account.login} · {account.server} · {account.currency} · 1:{account.leverage}
            </Typography>
          </Box>
        </Box>
        <Box sx={{ display: 'flex', gap: 1 }}>
          <Chip label="DEMO" size="small" sx={{ bgcolor: 'rgba(99,102,241,0.12)', color: '#818cf8', fontWeight: 700 }} />
          <Chip label="● LIVE" size="small" sx={{ bgcolor: 'rgba(16,185,129,0.1)', color: '#10b981', fontWeight: 700 }} />
          <Tooltip title="Disconnect MT5">
            <Button variant="outlined" color="error" size="small" onClick={onDisconnect}
              sx={{ borderColor: 'rgba(244,63,94,0.3)', color: '#f43f5e', minWidth: 0, px: 1.5 }}>
              ✕
            </Button>
          </Tooltip>
        </Box>
      </Box>

      {/* Stats Grid */}
      <Grid container spacing={3} sx={{ mb: 2.5 }}>
        <Grid item xs={6} sm={3}>
          <StatItem label="Balance" value={`$${fmt(account.balance)}`} color="#f3f4f6" icon={<ShowChart />} />
        </Grid>
        <Grid item xs={6} sm={3}>
          <StatItem label="Equity" value={`$${fmt(account.equity)}`} color="#818cf8" />
        </Grid>
        <Grid item xs={6} sm={3}>
          <StatItem label="Free Margin" value={`$${fmt(account.free_margin)}`} color="#94a3b8" />
        </Grid>
        <Grid item xs={6} sm={3}>
          <StatItem
            label="Float P/L"
            value={`${account.profit >= 0 ? '+' : ''}$${fmt(account.profit)}`}
            color={profitColor}
            icon={account.profit >= 0 ? <TrendingUp /> : <TrendingDown />}
          />
        </Grid>
      </Grid>

      {/* Equity bar */}
      <Box>
        <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 0.5 }}>
          <Typography variant="caption" sx={{ color: 'text.secondary' }}>Equity / Balance</Typography>
          <Typography variant="caption" sx={{ color: equityPct >= 100 ? '#10b981' : '#f59e0b', fontWeight: 700 }}>
            {fmt(equityPct, 1)}%
          </Typography>
        </Box>
        <LinearProgress
          variant="determinate"
          value={Math.min(equityPct, 100)}
          sx={{
            height: 6, borderRadius: 3,
            bgcolor: 'rgba(255,255,255,0.05)',
            '& .MuiLinearProgress-bar': {
              bgcolor: equityPct >= 100 ? '#10b981' : equityPct >= 80 ? '#f59e0b' : '#f43f5e',
              borderRadius: 3,
            },
          }}
        />
      </Box>
    </Paper>
  );
}
