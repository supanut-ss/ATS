import React, { useState } from 'react';
import {
  Box, Paper, Typography, Button, TextField, Grid,
  Divider, Alert, InputAdornment, Tooltip
} from '@mui/material';
import { TrendingUp, TrendingDown, Warning, SwapHoriz } from '@mui/icons-material';
import { productionApi } from '../services/api';

const H = 360;

export default function ManualTradePanel({ price, risk, onRefresh, apiClient = productionApi }) {
  const [sl, setSl] = useState('');
  const [tp, setTp] = useState('');
  const [loading, setLoading] = useState(null);
  const [result, setResult] = useState(null);

  const execute = async (action) => {
    setLoading(action);
    setResult(null);
    try {
      const res = await apiClient.openTrade(action, parseFloat(sl) || 0, parseFloat(tp) || 0);
      if (res.ok && res.data?.ok) {
        setResult({ ok: true, message: `✓ ${action} queued successfully · Ticket #${res.data.signalId || 'Pending'}` });
        setSl(''); setTp('');
        onRefresh?.();
      } else {
        setResult({ ok: false, message: res.data?.error || 'Trade execution failed' });
      }
    } catch (e) {
      setResult({ ok: false, message: e.message });
    } finally {
      setLoading(null);
    }
  };

  const askVal = price?.ask || 0;
  const bidVal = price?.bid || 0;
  const slDist = sl ? Math.abs(askVal - parseFloat(sl)) : 0;
  const tpDist = tp ? Math.abs(parseFloat(tp) - askVal) : 0;
  const pnlEst = (dist) => `$${(dist * 5).toFixed(2)}`; // Assuming 0.05 lot, 1 pip = $0.50, XAUUSD math

  return (
    <Paper sx={{
      height: H, minHeight: H, boxSizing: 'border-box',
      display: 'flex', flexDirection: 'column',
      borderColor: 'rgba(255,255,255,0.06)',
      overflow: 'hidden',
      position: 'relative',
      background: 'linear-gradient(180deg, rgba(17,24,39,0.7) 0%, rgba(10,15,30,0.9) 100%)',
      backdropFilter: 'blur(16px)',
    }}>
      {/* ── Header ── */}
      <Box sx={{
        px: 2.5, py: 2,
        background: 'linear-gradient(135deg, rgba(99,102,241,0.05) 0%, rgba(168,85,247,0.02) 100%)',
        borderBottom: '1px solid rgba(255,255,255,0.06)',
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        flexShrink: 0,
      }}>
        <Box>
          <Typography sx={{ fontWeight: 800, fontSize: '0.85rem', color: '#c7d2fe', letterSpacing: 0.5, textTransform: 'uppercase' }}>
            ส่งคำสั่งเทรดแมนนวล
          </Typography>
          <Typography sx={{ fontSize: '0.68rem', color: 'text.secondary', mt: 0.25 }}>
            Lot: <span style={{ color: '#fbbf24', fontWeight: 800 }}>0.05</span> · XAUUSD
            {risk && (
              <>
                <Box component="span" sx={{ mx: 0.75, color: 'rgba(255,255,255,0.1)' }}>|</Box>
                ออเดอร์: <span style={{ fontWeight: 700, color: '#818cf8' }}>{risk.open_positions}/{risk.max_positions}</span>
              </>
            )}
          </Typography>
        </Box>
        
        {price && (
          <Box sx={{
            px: 1.5, py: 0.5, borderRadius: 1.5,
            bgcolor: 'rgba(251,191,36,0.06)', border: '1px solid rgba(251,191,36,0.15)',
            textAlign: 'right', flexShrink: 0,
          }}>
            <Typography sx={{ fontSize: '0.55rem', color: '#fbbf24', fontWeight: 800, letterSpacing: 0.5, textTransform: 'uppercase' }}>Spread</Typography>
            <Typography sx={{ fontSize: '0.85rem', fontWeight: 800, color: '#fbbf24', fontFamily: 'monospace', lineHeight: 1.2 }}>
              {price.spread?.toFixed(1)} pips
            </Typography>
          </Box>
        )}
      </Box>

      {/* ── Inputs & Execution controls ── */}
      <Box sx={{
        flexGrow: 1,
        display: 'flex', flexDirection: 'column', justifyContent: 'center',
        px: 2.5, gap: 2,
      }}>
        {/* SL / TP inputs */}
        <Grid container spacing={2}>
          <Grid item xs={6}>
            <TextField
              label="Stop Loss (SL)"
              type="number"
              value={sl}
              onChange={e => setSl(e.target.value)}
              size="small"
              fullWidth
              variant="outlined"
              placeholder="0.00"
              InputProps={{
                startAdornment: <InputAdornment position="start"><span style={{ fontSize: '0.75rem', color: '#f43f5e' }}>$</span></InputAdornment>,
                inputProps: { step: 0.01, min: 0 }
              }}
              sx={{
                '& .MuiOutlinedInput-root': {
                  borderRadius: 2,
                  bgcolor: 'rgba(0,0,0,0.15)',
                  '&.Mui-focused fieldset': { borderColor: '#f43f5e' }
                }
              }}
              helperText={slDist > 0 ? `Risk ≈ ${pnlEst(slDist)}` : 'ต้องการค่า SL ป้องกันพอร์ต'}
              FormHelperTextProps={{ sx: { color: slDist > 0 ? '#f43f5e' : 'text.disabled', mx: 0, fontSize: '0.62rem', fontWeight: 600 } }}
            />
          </Grid>
          <Grid item xs={6}>
            <TextField
              label="Take Profit (TP)"
              type="number"
              value={tp}
              onChange={e => setTp(e.target.value)}
              size="small"
              fullWidth
              variant="outlined"
              placeholder="0.00"
              InputProps={{
                startAdornment: <InputAdornment position="start"><span style={{ fontSize: '0.75rem', color: '#10b981' }}>$</span></InputAdornment>,
                inputProps: { step: 0.01, min: 0 }
              }}
              sx={{
                '& .MuiOutlinedInput-root': {
                  borderRadius: 2,
                  bgcolor: 'rgba(0,0,0,0.15)',
                  '&.Mui-focused fieldset': { borderColor: '#10b981' }
                }
              }}
              helperText={tpDist > 0 && slDist > 0
                ? `Gain ≈ ${pnlEst(tpDist)} (R:R ${(tpDist / slDist).toFixed(1)}:1)`
                : tpDist > 0 ? `Gain ≈ ${pnlEst(tpDist)}` : 'ไม่บังคับ'}
              FormHelperTextProps={{ sx: { color: tpDist > 0 ? '#10b981' : 'text.disabled', mx: 0, fontSize: '0.62rem', fontWeight: 600 } }}
            />
          </Grid>
        </Grid>

        {/* Warning / execution result */}
        <Box sx={{ height: 32, display: 'flex', alignItems: 'center' }}>
          {result ? (
            <Alert
              severity={result.ok ? 'success' : 'error'}
              sx={{
                py: 0.1, px: 1.25, fontSize: '0.68rem', width: '100%', borderRadius: 1.5,
                bgcolor: result.ok ? 'rgba(16,185,129,0.08)' : 'rgba(244,63,94,0.08)',
                border: `1px solid ${result.ok ? 'rgba(16,185,129,0.15)' : 'rgba(244,63,94,0.15)'}`,
                color: result.ok ? '#10b981' : '#f43f5e',
                display: 'flex',
                alignItems: 'center',
                '& .MuiAlert-icon': { mr: 0.5, p: 0, fontSize: 14, display: 'flex', alignItems: 'center' },
                '& .MuiAlert-message': { p: 0, display: 'flex', alignItems: 'center', fontWeight: 600 },
              }}
            >
              {result.message}
            </Alert>
          ) : !sl ? (
            <Box
              sx={{
                py: 0.4, px: 1.25, fontSize: '0.65rem', width: '100%',
                bgcolor: 'rgba(245,158,11,0.04)', border: '1px solid rgba(245,158,11,0.15)',
                color: '#fbbf24', borderRadius: 1.5,
                display: 'flex', alignItems: 'center', gap: 0.75,
                fontWeight: 600
              }}
            >
              <Warning sx={{ fontSize: 14 }} />
              <span>กรุณากำหนดราคา Stop Loss ก่อนทำการส่งคำสั่งซื้อขาย</span>
            </Box>
          ) : null}
        </Box>

        {/* BUY / SELL buttons */}
        <Box sx={{ display: 'flex', gap: 2, justifyContent: 'center' }}>
          <Box sx={{ flex: 1 }}>
            <Button
              fullWidth
              variant="contained"
              disabled={!!loading || !sl}
              onClick={() => execute('BUY')}
              startIcon={<TrendingUp />}
              className="glow-card-green"
              sx={{
                py: 1.2,
                fontWeight: 800,
                fontSize: '0.78rem',
                borderRadius: 2,
                background: 'linear-gradient(135deg, #059669 0%, #10b981 100%)',
                boxShadow: '0 4px 12px rgba(16, 185, 129, 0.2)',
                letterSpacing: 0.5,
                '&:hover': {
                  background: 'linear-gradient(135deg, #047857 0%, #059669 100%)',
                },
                '&:disabled': { opacity: 0.4 },
              }}
            >
              {loading === 'BUY' ? 'Placing BUY…' : `BUY @ ${askVal ? askVal.toFixed(2) : 'Market'}`}
            </Button>
            <Typography variant="caption" sx={{ display: 'block', textCenter: 'center', color: '#10b981', mt: 0.5, fontWeight: 700, fontSize: '0.6rem', textAlign: 'center', opacity: 0.8 }}>
              ASK · ซื้อที่ราคาตลาดด้านสูง
            </Typography>
          </Box>
          <Box sx={{ flex: 1 }}>
            <Button
              fullWidth
              variant="contained"
              disabled={!!loading || !sl}
              onClick={() => execute('SELL')}
              startIcon={<TrendingDown />}
              className="glow-card-red"
              sx={{
                py: 1.2,
                fontWeight: 800,
                fontSize: '0.78rem',
                borderRadius: 2,
                background: 'linear-gradient(135deg, #e11d48 0%, #f43f5e 100%)',
                boxShadow: '0 4px 12px rgba(244, 63, 94, 0.2)',
                letterSpacing: 0.5,
                '&:hover': {
                  background: 'linear-gradient(135deg, #be123c 0%, #e11d48 100%)',
                },
                '&:disabled': { opacity: 0.4 },
              }}
            >
              {loading === 'SELL' ? 'Placing SELL…' : `SELL @ ${bidVal ? bidVal.toFixed(2) : 'Market'}`}
            </Button>
            <Typography variant="caption" sx={{ display: 'block', textCenter: 'center', color: '#f43f5e', mt: 0.5, fontWeight: 700, fontSize: '0.6rem', textAlign: 'center', opacity: 0.8 }}>
              BID · ขายที่ราคาตลาดด้านต่ำ
            </Typography>
          </Box>
        </Box>
      </Box>
    </Paper>
  );
}

