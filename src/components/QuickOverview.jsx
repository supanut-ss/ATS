import React from 'react';
import { Box, Paper, Typography, Grid, Skeleton } from '@mui/material';
import {
  AccountBalance, TrendingUp, TrendingDown,
  SwapVert, Shield, Wifi, WifiOff,
} from '@mui/icons-material';

const fmt = (v, d = 2) =>
  v == null ? '—' : Number(v).toLocaleString('en-US', { minimumFractionDigits: d, maximumFractionDigits: d });

function StatBox({ label, value, sub, color, icon, loading }) {
  if (loading) {
    return (
      <Paper sx={{ p: 2, height: '100%' }}>
        <Skeleton width="50%" height={14} />
        <Skeleton width="70%" height={32} sx={{ mt: 1 }} />
      </Paper>
    );
  }
  return (
    <Paper sx={{ p: 2, height: '100%', display: 'flex', alignItems: 'flex-start', gap: 1.5 }}>
      {icon && (
        <Box sx={{
          p: 0.8, borderRadius: 1.5, flexShrink: 0,
          bgcolor: `${color}18`,
          display: 'flex', alignItems: 'center',
        }}>
          {React.cloneElement(icon, { sx: { fontSize: 20, color } })}
        </Box>
      )}
      <Box sx={{ minWidth: 0 }}>
        <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600, textTransform: 'uppercase', letterSpacing: 0.4 }}>
          {label}
        </Typography>
        <Typography variant="h6" sx={{ fontWeight: 800, color: color || 'text.primary', lineHeight: 1.2, mt: 0.2 }}>
          {value}
        </Typography>
        {sub && (
          <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block', mt: 0.3 }}>
            {sub}
          </Typography>
        )}
      </Box>
    </Paper>
  );
}

export default function QuickOverview({ connected, account, price, positions, risk, loading }) {
  const totalPnl = positions.reduce((s, p) => s + (p.profit || 0), 0);
  const profitColor = (account?.profit ?? 0) >= 0 ? '#10b981' : '#f43f5e';
  const dailyColor = (risk?.daily_pnl ?? 0) >= 0 ? '#10b981' : '#f43f5e';

  return (
    <Grid container spacing={2}>
      <Grid item xs={6} sm={4} md={2}>
        <StatBox
          label="สถานะ MT5"
          value={connected ? 'เชื่อมต่อแล้ว' : 'ยังไม่เชื่อมต่อ'}
          color={connected ? '#10b981' : '#f43f5e'}
          icon={connected ? <Wifi /> : <WifiOff />}
          loading={loading && !connected}
        />
      </Grid>
      <Grid item xs={6} sm={4} md={2}>
        <StatBox
          label="ราคา XAUUSD"
          value={price ? `$${fmt(price.ask)}` : '—'}
          sub={price ? `Bid $${fmt(price.bid)} · Spread ${fmt(price.spread, 1)}` : null}
          color="#fbbf24"
          icon={<AccountBalance />}
          loading={loading && !price}
        />
      </Grid>
      <Grid item xs={6} sm={4} md={2}>
        <StatBox
          label="ยอด Equity"
          value={account ? `$${fmt(account.equity)}` : '—'}
          sub={account ? `Balance $${fmt(account.balance)}` : null}
          color="#818cf8"
          loading={loading && connected && !account}
        />
      </Grid>
      <Grid item xs={6} sm={4} md={2}>
        <StatBox
          label="กำไร/ขาดทุนลอย"
          value={account ? `${account.profit >= 0 ? '+' : ''}$${fmt(account.profit)}` : '—'}
          color={profitColor}
          icon={account?.profit >= 0 ? <TrendingUp /> : <TrendingDown />}
          loading={loading && connected && !account}
        />
      </Grid>
      <Grid item xs={6} sm={4} md={2}>
        <StatBox
          label="ออเดอร์เปิด"
          value={positions.length}
          sub={positions.length > 0 ? `Float ${totalPnl >= 0 ? '+' : ''}$${fmt(totalPnl)}` : 'ไม่มีออเดอร์'}
          color="#6366f1"
          icon={<SwapVert />}
          loading={false}
        />
      </Grid>
      <Grid item xs={6} sm={4} md={2}>
        <StatBox
          label="P/L วันนี้"
          value={risk ? `${risk.daily_pnl >= 0 ? '+' : ''}$${fmt(risk.daily_pnl)}` : '—'}
          sub={risk ? `ลิมิต -$${fmt(risk.max_daily_loss, 0)}` : null}
          color={dailyColor}
          icon={<Shield />}
          loading={loading && !risk}
        />
      </Grid>
    </Grid>
  );
}
