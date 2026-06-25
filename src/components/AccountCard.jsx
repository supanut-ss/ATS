import React from 'react';
import {
  Box, Paper, Typography, Chip, Button,
  LinearProgress, Tooltip, Divider,
} from '@mui/material';
import { AccountBalance, TrendingUp, TrendingDown, ShowChart, LinkOff } from '@mui/icons-material';

const fmt = (v, d = 2) =>
  v == null ? '—' : Number(v).toLocaleString('en-US', { minimumFractionDigits: d, maximumFractionDigits: d });

const H = 360; // shared card height

function Metric({ label, value, color, sub }) {
  return (
    <Box>
      <Typography sx={{ fontSize: '0.62rem', fontWeight: 700, color: 'text.secondary', textTransform: 'uppercase', letterSpacing: 0.6 }}>
        {label}
      </Typography>
      <Typography sx={{ fontSize: '1.2rem', fontWeight: 800, color: color || 'text.primary', lineHeight: 1.3, mt: 0.2, whiteSpace: 'nowrap' }}>
        {value}
      </Typography>
      {sub && (
        <Typography sx={{ fontSize: '0.68rem', color: 'text.disabled', mt: 0.1 }}>{sub}</Typography>
      )}
    </Box>
  );
}

export default function AccountCard({ account, connected, onConnect, onDisconnect }) {
  /* ── Disconnected ── */
  if (!connected) {
    return (
      <Paper sx={{
        height: H, minHeight: H, boxSizing: 'border-box',
        display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 2.5,
        borderColor: 'rgba(255,255,255,0.06)',
        background: 'radial-gradient(ellipse at 50% 0%, rgba(99,102,241,0.08) 0%, transparent 70%)',
      }}>
        <Box sx={{
          width: 64, height: 64, borderRadius: '50%',
          bgcolor: 'rgba(255,255,255,0.03)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          border: '1px dashed rgba(255,255,255,0.12)',
        }}>
          <LinkOff sx={{ fontSize: 26, color: 'text.disabled' }} />
        </Box>
        <Box sx={{ textAlign: 'center' }}>
          <Typography variant="subtitle1" sx={{ fontWeight: 700, color: 'text.secondary' }}>
            MT5 ยังไม่เชื่อมต่อ
          </Typography>
          <Typography variant="caption" sx={{ color: 'text.disabled' }}>
            กด "เชื่อมต่อ MT5" เพื่อเริ่มใช้งาน
          </Typography>
        </Box>
        <Button
          variant="contained" size="medium" onClick={onConnect}
          sx={{
            px: 4, borderRadius: 2,
            background: 'linear-gradient(135deg,#6366f1,#4f46e5)',
            boxShadow: '0 4px 20px rgba(99,102,241,0.4)',
            fontWeight: 700,
          }}
        >
          เชื่อมต่อ MT5
        </Button>
      </Paper>
    );
  }

  /* ── No data yet (first load) ── */
  if (!account) {
    return (
      <Paper sx={{
        height: H, minHeight: H, boxSizing: 'border-box',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        borderColor: 'rgba(255,255,255,0.06)',
      }}>
        <Box sx={{ textAlign: 'center' }}>
          <LinearProgress sx={{ width: 120, mb: 1.5, bgcolor: 'rgba(255,255,255,0.04)', '& .MuiLinearProgress-bar': { bgcolor: '#6366f1' } }} />
          <Typography variant="caption" sx={{ color: 'text.disabled' }}>กำลังโหลด…</Typography>
        </Box>
      </Paper>
    );
  }

  /* ── Normal ── */
  const profitColor = account.profit >= 0 ? '#10b981' : '#f43f5e';
  const equityPct = account.balance > 0 ? Math.min((account.equity / account.balance) * 100, 100) : 100;
  const barColor = equityPct >= 100 ? '#10b981' : equityPct >= 80 ? '#f59e0b' : '#f43f5e';

  return (
    <Paper sx={{
      height: H, minHeight: H, boxSizing: 'border-box',
      display: 'flex', flexDirection: 'column',
      borderColor: 'rgba(255,255,255,0.06)',
      overflow: 'hidden',
    }}>
      {/* ── Gradient header band ── */}
      <Box sx={{
        px: 3, py: 2,
        background: 'linear-gradient(135deg,rgba(99,102,241,0.12) 0%,rgba(168,85,247,0.06) 100%)',
        borderBottom: '1px solid rgba(255,255,255,0.06)',
        display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 1,
      }}>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, minWidth: 0 }}>
          <Box sx={{
            width: 38, height: 38, borderRadius: 2, flexShrink: 0,
            background: 'linear-gradient(135deg,#6366f1,#a855f7)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <AccountBalance sx={{ fontSize: 18, color: '#fff' }} />
          </Box>
          <Box sx={{ minWidth: 0 }}>
            <Typography sx={{ fontWeight: 700, fontSize: '0.95rem', lineHeight: 1.2, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
              {account.name || 'Demo Account'}
            </Typography>
            <Typography sx={{ fontSize: '0.68rem', color: 'text.secondary', whiteSpace: 'nowrap' }}>
              #{account.login} · {account.server} · {account.currency}
            </Typography>
          </Box>
        </Box>
        <Box sx={{ display: 'flex', gap: 0.75, alignItems: 'center', flexShrink: 0 }}>
          <Chip label="DEMO" size="small" sx={{ bgcolor: 'rgba(99,102,241,0.15)', color: '#818cf8', fontWeight: 700, fontSize: '0.62rem', height: 20 }} />
          <Chip
            label={<Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
              <Box sx={{ width: 6, height: 6, borderRadius: '50%', bgcolor: '#10b981', animation: 'pulse 2s infinite' }} />
              LIVE
            </Box>}
            size="small"
            sx={{ bgcolor: 'rgba(16,185,129,0.12)', color: '#10b981', fontWeight: 700, fontSize: '0.62rem', height: 20 }}
          />
          <Tooltip title="Disconnect MT5">
            <Button
              variant="outlined" size="small" onClick={onDisconnect}
              sx={{
                minWidth: 28, width: 28, height: 24, p: 0, fontSize: '0.7rem',
                borderColor: 'rgba(244,63,94,0.3)', color: '#f43f5e',
                '&:hover': { bgcolor: 'rgba(244,63,94,0.08)', borderColor: '#f43f5e' },
              }}
            >
              ✕
            </Button>
          </Tooltip>
        </Box>
      </Box>

      {/* ── 4 main metrics ── */}
      <Box sx={{ px: 3, py: 2.5, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 2.5, flexGrow: 1 }}>
        <Metric
          label="Balance"
          value={`$${fmt(account.balance)}`}
          color="#f3f4f6"
        />
        <Metric
          label="Equity"
          value={`$${fmt(account.equity)}`}
          color="#818cf8"
          sub={`${fmt(equityPct, 1)}% of Balance`}
        />
        <Metric
          label="Free Margin"
          value={`$${fmt(account.free_margin)}`}
          color="#94a3b8"
        />
        <Metric
          label="Float P/L"
          value={`${account.profit >= 0 ? '+' : ''}$${fmt(account.profit)}`}
          color={profitColor}
          sub={account.profit >= 0 ? 'กำไรลอยตัว' : 'ขาดทุนลอยตัว'}
        />
      </Box>

      {/* ── Equity bar ── */}
      <Box sx={{ px: 3, pb: 2.5 }}>
        <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 0.75 }}>
          <Typography sx={{ fontSize: '0.68rem', color: 'text.secondary', fontWeight: 600 }}>
            Equity / Balance Ratio
          </Typography>
          <Typography sx={{ fontSize: '0.68rem', fontWeight: 800, color: barColor }}>
            {fmt(equityPct, 2)}%
          </Typography>
        </Box>
        <LinearProgress
          variant="determinate"
          value={equityPct}
          sx={{
            height: 5, borderRadius: 3,
            bgcolor: 'rgba(255,255,255,0.05)',
            '& .MuiLinearProgress-bar': { bgcolor: barColor, borderRadius: 3, transition: 'transform 0.6s ease' },
          }}
        />
      </Box>
    </Paper>
  );
}
