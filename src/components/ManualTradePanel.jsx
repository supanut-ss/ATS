import React, { useState } from 'react';
import {
  Box, Paper, Typography, Button, TextField, Grid,
  Divider, Chip, Alert, Collapse,
} from '@mui/material';
import { TrendingUp, TrendingDown, Warning } from '@mui/icons-material';
import { openTrade } from '../services/api';

export default function ManualTradePanel({ price, risk, onRefresh }) {
  const [sl, setSl] = useState('');
  const [tp, setTp] = useState('');
  const [loading, setLoading] = useState(null); // 'BUY' | 'SELL' | null
  const [result, setResult] = useState(null);   // {ok, message}

  const execute = async (action) => {
    setLoading(action);
    setResult(null);
    try {
      const res = await openTrade(action, parseFloat(sl) || 0, parseFloat(tp) || 0);
      if (res.ok && res.data?.ok) {
        setResult({ ok: true, message: `${action} opened @ ${res.data.price} | Ticket #${res.data.ticket}` });
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

  const calcPnl = (action) => {
    if (!sl || !price) return null;
    const entry = action === 'BUY' ? price.ask : price.bid;
    const slDist = Math.abs(entry - parseFloat(sl));
    const tpDist = tp ? Math.abs(parseFloat(tp) - entry) : null;
    // 0.05 lot XAUUSD: 1 USD move = 0.05 * 100 = $5 per lot
    const pnlPerUsd = 0.05 * 100; // $5 per $1 move
    return {
      slLoss: (slDist * pnlPerUsd).toFixed(2),
      tpGain: tpDist ? (tpDist * pnlPerUsd).toFixed(2) : null,
      rr:     tpDist && slDist > 0 ? (tpDist / slDist).toFixed(1) : null,
    };
  };

  const buyCalc  = calcPnl('BUY');
  const sellCalc = calcPnl('SELL');

  return (
    <Paper sx={{ p: 3 }}>
      <Typography variant="h6" sx={{ fontWeight: 700, mb: 0.5 }}>เทรดด้วยตนเอง</Typography>
      <Typography variant="body2" sx={{ color: 'text.secondary', mb: 2 }}>
        Lot คงที่: <strong>0.05</strong> · XAUUSD
      </Typography>

      {/* Risk Status */}
      {risk && (
        <Box sx={{ mb: 2, p: 1.5, borderRadius: 2, bgcolor: 'rgba(255,255,255,0.02)', border: '1px solid rgba(255,255,255,0.05)' }}>
          <Box sx={{ display: 'flex', gap: 2, flexWrap: 'wrap' }}>
            <Box>
              <Typography variant="caption" sx={{ color: 'text.secondary' }}>Open Positions</Typography>
              <Typography variant="subtitle2" sx={{ fontWeight: 700 }}>
                {risk.open_positions} / {risk.max_positions}
              </Typography>
            </Box>
            <Box>
              <Typography variant="caption" sx={{ color: 'text.secondary' }}>Daily P/L</Typography>
              <Typography variant="subtitle2" sx={{ fontWeight: 700, color: risk.daily_pnl >= 0 ? '#10b981' : '#f43f5e' }}>
                {risk.daily_pnl >= 0 ? '+' : ''}${Number(risk.daily_pnl).toFixed(2)}
              </Typography>
            </Box>
            <Box>
              <Typography variant="caption" sx={{ color: 'text.secondary' }}>Daily Loss Limit</Typography>
              <Typography variant="subtitle2" sx={{ fontWeight: 700, color: '#f43f5e' }}>
                -${risk.max_daily_loss}
              </Typography>
            </Box>
          </Box>
        </Box>
      )}

      <Divider sx={{ mb: 2 }} />

      {/* SL / TP Inputs */}
      <Grid container spacing={2} sx={{ mb: 2 }}>
        <Grid item xs={6}>
          <TextField
            label="Stop Loss (price)"
            type="number"
            value={sl}
            onChange={e => setSl(e.target.value)}
            size="small"
            fullWidth
            inputProps={{ step: 0.01 }}
            helperText={buyCalc ? `Loss: ~$${buyCalc.slLoss}` : 'Required'}
            FormHelperTextProps={{ sx: { color: '#f43f5e' } }}
          />
        </Grid>
        <Grid item xs={6}>
          <TextField
            label="Take Profit (price)"
            type="number"
            value={tp}
            onChange={e => setTp(e.target.value)}
            size="small"
            fullWidth
            inputProps={{ step: 0.01 }}
            helperText={buyCalc?.tpGain ? `Gain: ~$${buyCalc.tpGain} | R:R ${buyCalc.rr}:1` : 'Optional'}
            FormHelperTextProps={{ sx: { color: '#10b981' } }}
          />
        </Grid>
      </Grid>

      {!sl && (
        <Alert severity="warning" icon={<Warning />} sx={{ mb: 2, bgcolor: 'rgba(245,158,11,0.08)', border: '1px solid rgba(245,158,11,0.2)', color: '#fbbf24', fontSize: '0.8rem' }}>
          Entering without a Stop Loss is high risk. Set SL before trading.
        </Alert>
      )}

      {/* BUY / SELL Buttons */}
      <Grid container spacing={2}>
        <Grid item xs={6}>
          <Button
            fullWidth variant="contained" size="large"
            disabled={!!loading}
            onClick={() => execute('BUY')}
            startIcon={<TrendingUp />}
            sx={{
              background: 'linear-gradient(135deg,#059669,#10b981)',
              color: '#fff', fontWeight: 700, fontSize: '1rem', py: 1.5,
              boxShadow: '0 4px 15px rgba(16,185,129,0.35)',
              '&:hover': { background: 'linear-gradient(135deg,#047857,#059669)' },
              '&:disabled': { opacity: 0.5 },
            }}
          >
            {loading === 'BUY' ? 'Placing…' : `BUY ${price?.ask ? price.ask.toFixed(2) : ''}`}
          </Button>
          <Typography variant="caption" sx={{ display: 'block', textAlign: 'center', color: '#10b981', mt: 0.5 }}>
            Market ASK
          </Typography>
        </Grid>
        <Grid item xs={6}>
          <Button
            fullWidth variant="contained" size="large"
            disabled={!!loading}
            onClick={() => execute('SELL')}
            startIcon={<TrendingDown />}
            sx={{
              background: 'linear-gradient(135deg,#be123c,#f43f5e)',
              color: '#fff', fontWeight: 700, fontSize: '1rem', py: 1.5,
              boxShadow: '0 4px 15px rgba(244,63,94,0.35)',
              '&:hover': { background: 'linear-gradient(135deg,#9f1239,#be123c)' },
              '&:disabled': { opacity: 0.5 },
            }}
          >
            {loading === 'SELL' ? 'Placing…' : `SELL ${price?.bid ? price.bid.toFixed(2) : ''}`}
          </Button>
          <Typography variant="caption" sx={{ display: 'block', textAlign: 'center', color: '#f43f5e', mt: 0.5 }}>
            Market BID
          </Typography>
        </Grid>
      </Grid>

      {/* Result message */}
      <Collapse in={!!result} sx={{ mt: 2 }}>
        {result && (
          <Alert
            severity={result.ok ? 'success' : 'error'}
            sx={{
              bgcolor: result.ok ? 'rgba(16,185,129,0.08)' : 'rgba(244,63,94,0.08)',
              border: `1px solid ${result.ok ? 'rgba(16,185,129,0.2)' : 'rgba(244,63,94,0.2)'}`,
              color: result.ok ? '#10b981' : '#f43f5e',
              fontSize: '0.8rem',
            }}
          >
            {result.message}
          </Alert>
        )}
      </Collapse>
    </Paper>
  );
}
