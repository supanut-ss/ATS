import React, { useState } from 'react';
import {
  Box, Paper, Typography, Button, TextField, Grid,
  Divider, Alert,
} from '@mui/material';
import { TrendingUp, TrendingDown, Warning } from '@mui/icons-material';
import { openTrade } from '../services/api';

const H = 360;

export default function ManualTradePanel({ price, risk, onRefresh }) {
  const [sl, setSl] = useState('');
  const [tp, setTp] = useState('');
  const [loading, setLoading] = useState(null);
  const [result, setResult] = useState(null);

  const execute = async (action) => {
    setLoading(action);
    setResult(null);
    try {
      const res = await openTrade(action, parseFloat(sl) || 0, parseFloat(tp) || 0);
      if (res.ok && res.data?.ok) {
        setResult({ ok: true, message: `✓ ${action} queued · #${res.data.signalId}` });
        setSl(''); setTp('');
        onRefresh?.();
      } else {
        setResult({ ok: false, message: res.data?.error || 'Trade failed' });
      }
    } catch (e) {
      setResult({ ok: false, message: e.message });
    } finally {
      setLoading(null);
    }
  };

  const slDist = sl && price ? Math.abs((price.ask || 0) - parseFloat(sl)) : 0;
  const tpDist = tp && price ? Math.abs(parseFloat(tp) - (price.ask || 0)) : 0;
  const pnlEst = (dist) => `$${(dist * 5).toFixed(2)}`;

  return (
    <Paper sx={{
      height: H, minHeight: H, boxSizing: 'border-box',
      display: 'flex', flexDirection: 'column',
      borderColor: 'rgba(255,255,255,0.06)',
      overflow: 'hidden',
    }}>
      {/* ── Header ── */}
      <Box sx={{
        px: 2.5, py: 1.75,
        background: 'linear-gradient(135deg,rgba(16,185,129,0.08) 0%,rgba(244,63,94,0.04) 100%)',
        borderBottom: '1px solid rgba(255,255,255,0.06)',
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        flexShrink: 0,
      }}>
        <Box>
          <Typography sx={{ fontWeight: 700, fontSize: '0.88rem', lineHeight: 1.3 }}>
            เทรดด้วยตนเอง
          </Typography>
          <Typography sx={{ fontSize: '0.66rem', color: 'text.secondary', mt: 0.15 }}>
            Lot <Box component="strong" sx={{ color: '#f3f4f6' }}>0.05</Box> · XAUUSD
            {risk && (
              <>
                <Box component="span" sx={{ mx: 0.75, color: 'rgba(255,255,255,0.18)' }}>|</Box>
                Pos <Box component="span" sx={{ fontWeight: 700, color: '#818cf8' }}>{risk.open_positions}/{risk.max_positions}</Box>
                <Box component="span" sx={{ mx: 0.75, color: 'rgba(255,255,255,0.18)' }}>|</Box>
                P/L <Box component="span" sx={{ fontWeight: 700, color: risk.daily_pnl >= 0 ? '#10b981' : '#f43f5e' }}>
                  {risk.daily_pnl >= 0 ? '+' : ''}${Number(risk.daily_pnl).toFixed(2)}
                </Box>
              </>
            )}
          </Typography>
        </Box>
        {price && (
          <Box sx={{
            px: 1.5, py: 0.6, borderRadius: 1.5,
            bgcolor: 'rgba(251,191,36,0.08)', border: '1px solid rgba(251,191,36,0.15)',
            textAlign: 'right', flexShrink: 0,
          }}>
            <Typography sx={{ fontSize: '0.55rem', color: '#fbbf24', fontWeight: 700, letterSpacing: 0.5 }}>XAUUSD</Typography>
            <Typography sx={{ fontSize: '0.95rem', fontWeight: 800, color: '#fbbf24', lineHeight: 1.2 }}>
              ${price.ask?.toFixed(2)}
            </Typography>
          </Box>
        )}
      </Box>

      {/* ── Center section: SL/TP + warning + buttons ── */}
      <Box sx={{
        flexGrow: 1,
        display: 'flex', flexDirection: 'column', justifyContent: 'center',
        px: 2.5, gap: 1.5,
      }}>
        {/* SL / TP inputs */}
        <Grid container spacing={1.5}>
          <Grid item xs={6}>
            <TextField
              label="Stop Loss"
              type="number"
              value={sl}
              onChange={e => setSl(e.target.value)}
              size="small"
              fullWidth
              inputProps={{ step: 0.01 }}
              sx={{ '& .MuiOutlinedInput-root': { '&.Mui-focused fieldset': { borderColor: '#f43f5e' } } }}
              helperText={slDist > 0 ? `Risk ≈ ${pnlEst(slDist)}` : 'ต้องกำหนด SL'}
              FormHelperTextProps={{ sx: { color: slDist > 0 ? '#f43f5e' : 'text.disabled', mx: 0, fontSize: '0.62rem' } }}
            />
          </Grid>
          <Grid item xs={6}>
            <TextField
              label="Take Profit"
              type="number"
              value={tp}
              onChange={e => setTp(e.target.value)}
              size="small"
              fullWidth
              inputProps={{ step: 0.01 }}
              sx={{ '& .MuiOutlinedInput-root': { '&.Mui-focused fieldset': { borderColor: '#10b981' } } }}
              helperText={tpDist > 0 && slDist > 0
                ? `Gain ≈ ${pnlEst(tpDist)} · R:R ${(tpDist / slDist).toFixed(1)}:1`
                : tpDist > 0 ? `Gain ≈ ${pnlEst(tpDist)}` : 'ไม่บังคับ'}
              FormHelperTextProps={{ sx: { color: tpDist > 0 ? '#10b981' : 'text.disabled', mx: 0, fontSize: '0.62rem' } }}
            />
          </Grid>
        </Grid>

        {/* Warning / result — fixed height slot so buttons don't jump */}
        <Box sx={{ height: 32, display: 'flex', alignItems: 'center' }}>
          {result ? (
            <Alert
              severity={result.ok ? 'success' : 'error'}
              sx={{
                py: 0.2, px: 1.25, fontSize: '0.68rem', width: '100%',
                bgcolor: result.ok ? 'rgba(16,185,129,0.06)' : 'rgba(244,63,94,0.06)',
                border: `1px solid ${result.ok ? 'rgba(16,185,129,0.2)' : 'rgba(244,63,94,0.2)'}`,
                color: result.ok ? '#10b981' : '#f43f5e',
                '& .MuiAlert-icon': { mr: 0.75, py: 0, fontSize: 14 },
              }}
            >
              {result.message}
            </Alert>
          ) : !sl ? (
            <Alert
              severity="warning" icon={<Warning sx={{ fontSize: 13 }} />}
              sx={{
                py: 0.2, px: 1.25, fontSize: '0.68rem', width: '100%',
                bgcolor: 'rgba(245,158,11,0.05)', border: '1px solid rgba(245,158,11,0.15)',
                color: '#f59e0b',
                '& .MuiAlert-icon': { mr: 0.75, py: 0, fontSize: 13 },
              }}
            >
              กำหนด Stop Loss ก่อนเทรด
            </Alert>
          ) : null}
        </Box>

        {/* BUY / SELL buttons — centered, fixed size */}
        <Box sx={{ display: 'flex', gap: 1.5, justifyContent: 'center' }}>
          <Box sx={{ flex: 1, maxWidth: 200 }}>
            <Button
              fullWidth variant="contained" disabled={!!loading}
              onClick={() => execute('BUY')}
              startIcon={<TrendingUp sx={{ fontSize: '15px !important' }} />}
              sx={{
                py: 1.1, fontWeight: 800, fontSize: '0.78rem',
                background: 'linear-gradient(135deg,#059669,#10b981)',
                boxShadow: '0 3px 12px rgba(16,185,129,0.28)',
                letterSpacing: 0.5,
                '&:hover': { background: 'linear-gradient(135deg,#047857,#059669)', boxShadow: '0 5px 16px rgba(16,185,129,0.38)' },
                '&:disabled': { opacity: 0.45 },
              }}
            >
              {loading === 'BUY' ? 'Placing…' : `BUY ${price?.ask?.toFixed(2) ?? ''}`}
            </Button>
            <Typography sx={{ fontSize: '0.6rem', textAlign: 'center', color: '#10b981', mt: 0.4, fontWeight: 600, opacity: 0.8 }}>
              ASK · ซื้อที่ราคาตลาด
            </Typography>
          </Box>
          <Box sx={{ flex: 1, maxWidth: 200 }}>
            <Button
              fullWidth variant="contained" disabled={!!loading}
              onClick={() => execute('SELL')}
              startIcon={<TrendingDown sx={{ fontSize: '15px !important' }} />}
              sx={{
                py: 1.1, fontWeight: 800, fontSize: '0.78rem',
                background: 'linear-gradient(135deg,#be123c,#f43f5e)',
                boxShadow: '0 3px 12px rgba(244,63,94,0.28)',
                letterSpacing: 0.5,
                '&:hover': { background: 'linear-gradient(135deg,#9f1239,#be123c)', boxShadow: '0 5px 16px rgba(244,63,94,0.38)' },
                '&:disabled': { opacity: 0.45 },
              }}
            >
              {loading === 'SELL' ? 'Placing…' : `SELL ${price?.bid?.toFixed(2) ?? ''}`}
            </Button>
            <Typography sx={{ fontSize: '0.6rem', textAlign: 'center', color: '#f43f5e', mt: 0.4, fontWeight: 600, opacity: 0.8 }}>
              BID · ขายที่ราคาตลาด
            </Typography>
          </Box>
        </Box>
      </Box>
    </Paper>
  );
}
