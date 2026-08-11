import React, { useState, useEffect, useRef } from 'react';
import { Box, Paper, Typography, Divider, Chip } from '@mui/material';
import {
  AccountBalance, AccountBalanceWallet, TrendingUp, TrendingDown,
  SwapVert, Shield, MonetizationOn, ShowChart
} from '@mui/icons-material';

const fmt = (v, d = 2) =>
  v == null ? '—' : Number(v).toLocaleString('en-US', { minimumFractionDigits: d, maximumFractionDigits: d });

function StatCell({ label, value, sub, color, icon, divider = true, flashClass = '' }) {
  return (
    <>
      <Box className={`glow-card ${flashClass}`} sx={{
        flex: { xs: '1 1 calc(50% - 12px)', sm: '1 1 calc(25% - 16px)', lg: '1 1 0' },
        minWidth: { xs: 130, lg: 0 },
        px: 2,
        py: 1.5,
        display: 'flex',
        alignItems: 'center',
        gap: 1.5,
        borderRadius: 2,
        transition: 'all 0.2s ease',
      }}>
        {icon && (
          <Box sx={{
            width: 36, height: 36, borderRadius: 2, flexShrink: 0,
            bgcolor: `${color}15`,
            border: `1px solid ${color}30`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            {React.cloneElement(icon, { sx: { fontSize: 18, color } })}
          </Box>
        )}
        <Box sx={{ minWidth: 0 }}>
          <Typography sx={{
            fontSize: '0.62rem', fontWeight: 800, color: 'text.secondary',
            textTransform: 'uppercase', letterSpacing: 0.8,
            whiteSpace: 'nowrap', lineHeight: 1,
          }}>
            {label}
          </Typography>
          <Typography className="mono" sx={{
            fontSize: '1.05rem', fontWeight: 900, color: color || 'text.primary',
            whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
            lineHeight: 1.3, mt: 0.3,
          }}>
            {value}
          </Typography>
          {sub != null && (
            <Typography sx={{
              fontSize: '0.65rem', color: 'text.disabled', fontWeight: 500,
              whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
              lineHeight: 1.2, mt: 0.2,
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
            borderColor: 'rgba(255,255,255,0.06)',
            my: 1,
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

  // Track price changes for animated flashes
  const prevAsk = useRef(price?.ask);
  const [flashClass, setFlashClass] = useState('');

  useEffect(() => {
    if (price && price.ask) {
      if (prevAsk.current !== undefined) {
        if (price.ask > prevAsk.current) {
          setFlashClass('price-flash-up');
        } else if (price.ask < prevAsk.current) {
          setFlashClass('price-flash-down');
        }
      }
      prevAsk.current = price.ask;
      const tid = setTimeout(() => setFlashClass(''), 800);
      return () => clearTimeout(tid);
    }
  }, [price]);

  return (
    <Paper sx={{
      display: 'flex',
      flexWrap: { xs: 'wrap', lg: 'nowrap' },
      alignItems: 'stretch',
      overflow: 'hidden',
      borderColor: 'rgba(255,255,255,0.06)',
      background: 'linear-gradient(180deg, rgba(20,25,40,0.7) 0%, rgba(10,15,30,0.85) 100%)',
      backdropFilter: 'blur(16px)',
      boxShadow: '0 8px 32px rgba(0,0,0,0.3)',
      borderRadius: 3,
      p: 0.75,
    }}>
      <StatCell
        label="XAUUSD Price"
        value={price ? `$${fmt(price.ask)}` : '—'}
        sub={price ? `Bid $${fmt(price.bid)}  ·  Spread ${fmt(price.spread, 1)}` : 'Offline'}
        color="#fbbf24"
        icon={<MonetizationOn />}
        flashClass={flashClass}
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
        sub={account ? `Ratio: ${fmt(account.balance > 0 ? (account.equity / account.balance) * 100 : 0, 1)}%` : '—'}
        color="#818cf8"
        icon={<AccountBalance />}
      />
      <StatCell
        label="Free Margin"
        value={account ? `$${fmt(account.free_margin)}` : '—'}
        sub={account ? `Margin: ${fmt(account.balance > 0 ? (1 - account.free_margin / account.equity) * 100 : 0, 1)}% used` : '—'}
        color="#94a3b8"
        icon={<Shield />}
      />
      <StatCell
        label="Float P/L"
        value={account ? `${pnlSign(account.profit)}$${fmt(account.profit)}` : '—'}
        sub={account ? (account.profit >= 0 ? 'Floating Profit' : 'Floating Loss') : '—'}
        color={profitColor}
        icon={account?.profit >= 0 ? <TrendingUp /> : <TrendingDown />}
      />
      <StatCell
        label="Open Orders"
        value={positions.length}
        sub={positions.length > 0 ? `Float ${pnlSign(totalPnl)}$${fmt(totalPnl)}` : 'No Open Orders'}
        color="#6366f1"
        icon={<SwapVert />}
      />
      <StatCell
        label="Today P/L"
        value={risk ? `${pnlSign(risk.daily_pnl)}$${fmt(risk.daily_pnl)}` : '—'}
        sub={risk ? `Max Loss -$${fmt(risk.max_daily_loss, 0)}` : '—'}
        color={dailyColor}
        icon={<ShowChart />}
        divider={false}
      />
    </Paper>
  );
}




