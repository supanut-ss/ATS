import React from 'react';
import { Box, Paper, Typography, Divider } from '@mui/material';
import {
  AccountBalance, AccountBalanceWallet, TrendingUp, TrendingDown,
  SwapVert, Shield, MonetizationOn, ShowChart
} from '@mui/icons-material';

const fmt = (v, d = 2) =>
  v == null ? '—' : Number(v).toLocaleString('en-US', { minimumFractionDigits: d, maximumFractionDigits: d });

function StatCell({ label, value, sub, color, icon, divider = true }) {
  return (
    <>
      <Box sx={{
        flex: { xs: '1 1 calc(50% - 12px)', sm: '1 1 calc(25% - 16px)', lg: '1 1 0' },
        minWidth: { xs: 130, lg: 0 },
        px: 2,
        py: 1.25,
        display: 'flex',
        alignItems: 'center',
        gap: 1.25,
      }}>
        {icon && (
          <Box sx={{
            width: 34, height: 34, borderRadius: 1.5, flexShrink: 0,
            bgcolor: `${color}18`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            {React.cloneElement(icon, { sx: { fontSize: 17, color } })}
          </Box>
        )}
        <Box sx={{ minWidth: 0 }}>
          <Typography sx={{
            fontSize: '0.62rem', fontWeight: 700, color: 'text.secondary',
            textTransform: 'uppercase', letterSpacing: 0.6,
            whiteSpace: 'nowrap', lineHeight: 1,
          }}>
            {label}
          </Typography>
          <Typography sx={{
            fontSize: '0.95rem', fontWeight: 800, color: color || 'text.primary',
            whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
            lineHeight: 1.35, mt: 0.25,
          }}>
            {value}
          </Typography>
          {sub != null && (
            <Typography sx={{
              fontSize: '0.62rem', color: 'text.disabled',
              whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
              lineHeight: 1.2, mt: 0.15,
              minHeight: '0.75rem',
            }}>
              {sub}
            </Typography>
          )}
        </Box>
      </Box>
      {divider && (
        <Divider
          orientation="vertical"
          flexItem
          sx={{
            borderColor: 'rgba(255,255,255,0.05)',
            my: 0.75,
            display: { xs: 'none', lg: 'block' }
          }}
        />
      )}
    </>
  );
}

export default function QuickOverview({ connected, account, price, positions, risk }) {
  const totalPnl = positions.reduce((s, p) => s + (p.profit || 0), 0);
  const profitColor = (account?.profit ?? 0) >= 0 ? '#10b981' : '#f43f5e';
  const dailyColor = (risk?.daily_pnl ?? 0) >= 0 ? '#10b981' : '#f43f5e';
  const pnlSign = (v) => (v >= 0 ? '+' : '');

  return (
    <Paper sx={{
      display: 'flex',
      flexWrap: { xs: 'wrap', lg: 'nowrap' },
      alignItems: 'stretch',
      overflow: 'hidden',
      borderColor: 'rgba(255,255,255,0.06)',
      height: { xs: 'auto', lg: 72 },
      minHeight: { xs: 'auto', lg: 72 },
      boxSizing: 'border-box',
      gap: { xs: 1, lg: 0 },
      p: { xs: 1, lg: 0 },
    }}>
      <StatCell
        label="ราคา XAUUSD"
        value={price ? `$${fmt(price.ask)}` : '—'}
        sub={price ? `Bid $${fmt(price.bid)}  ·  Spread ${fmt(price.spread, 1)} pips` : '\u00A0'}
        color="#fbbf24"
        icon={<MonetizationOn />}
      />
      <StatCell
        label="Balance"
        value={account ? `$${fmt(account.balance)}` : '—'}
        sub={account ? `#${account.login} · ${account.currency}` : 'MT5 Offline'}
        color="#f3f4f6"
        icon={<AccountBalanceWallet />}
      />
      <StatCell
        label="Equity"
        value={account ? `$${fmt(account.equity)}` : '—'}
        sub={account ? `Ratio: ${fmt(account.balance > 0 ? (account.equity / account.balance) * 100 : 0, 1)}%` : '\u00A0'}
        color="#818cf8"
        icon={<AccountBalance />}
      />
      <StatCell
        label="Free Margin"
        value={account ? `$${fmt(account.free_margin)}` : '—'}
        sub={account ? `Margin: ${fmt(account.balance > 0 ? (1 - account.free_margin / account.equity) * 100 : 0, 1)}% used` : '\u00A0'}
        color="#94a3b8"
        icon={<Shield />}
      />
      <StatCell
        label="Float P/L"
        value={account ? `${pnlSign(account.profit)}$${fmt(account.profit)}` : '—'}
        sub={account ? (account.profit >= 0 ? 'กำไรลอยตัว' : 'ขาดทุนลอยตัว') : '\u00A0'}
        color={profitColor}
        icon={account?.profit >= 0 ? <TrendingUp /> : <TrendingDown />}
      />
      <StatCell
        label="ออเดอร์เปิด"
        value={positions.length}
        sub={positions.length > 0 ? `Float ${pnlSign(totalPnl)}$${fmt(totalPnl)}` : 'ไม่มีออเดอร์'}
        color="#6366f1"
        icon={<SwapVert />}
      />
      <StatCell
        label="P/L วันนี้"
        value={risk ? `${pnlSign(risk.daily_pnl)}$${fmt(risk.daily_pnl)}` : '—'}
        sub={risk ? `ลิมิต -$${fmt(risk.max_daily_loss, 0)}` : '\u00A0'}
        color={dailyColor}
        icon={<ShowChart />}
        divider={false}
      />
    </Paper>
  );
}
