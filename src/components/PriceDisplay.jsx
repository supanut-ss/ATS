import React from 'react';
import { Box, Paper, Typography, Chip, Skeleton, Grid } from '@mui/material';
import { MonetizationOn } from '@mui/icons-material';

const fmt = (v, d = 2) =>
  v == null ? '—' : Number(v).toFixed(d);

export default function PriceDisplay({ price, loading, compact = false }) {
  if (loading || !price) {
    return (
      <Paper sx={{ p: compact ? 2 : 2.5 }}>
        <Skeleton variant="rectangular" height={compact ? 40 : 50} sx={{ borderRadius: 2 }} />
      </Paper>
    );
  }

  if (compact) {
    return (
      <Paper sx={{ p: 2 }}>
        <Grid container spacing={2} alignItems="center">
          <Grid item xs={12} sm={4}>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
              <MonetizationOn sx={{ color: '#fbbf24', fontSize: 22 }} />
              <Box>
                <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>XAUUSD</Typography>
                <Typography variant="h5" sx={{ fontWeight: 800, color: '#fbbf24', lineHeight: 1.1 }}>
                  ${fmt(price.ask)}
                </Typography>
              </Box>
            </Box>
          </Grid>
          <Grid item xs={4} sm={2}>
            <Typography variant="caption" sx={{ color: 'text.secondary' }}>Bid</Typography>
            <Typography variant="subtitle1" sx={{ fontWeight: 700, color: '#f43f5e' }}>${fmt(price.bid)}</Typography>
          </Grid>
          <Grid item xs={4} sm={2}>
            <Typography variant="caption" sx={{ color: 'text.secondary' }}>Ask</Typography>
            <Typography variant="subtitle1" sx={{ fontWeight: 700, color: '#10b981' }}>${fmt(price.ask)}</Typography>
          </Grid>
          <Grid item xs={4} sm={2}>
            <Typography variant="caption" sx={{ color: 'text.secondary' }}>Spread</Typography>
            <Chip
              label={`${fmt(price.spread, 1)} pips`}
              size="small"
              sx={{
                bgcolor: price.spread < 3 ? 'rgba(16,185,129,0.12)' : 'rgba(245,158,11,0.12)',
                color:   price.spread < 3 ? '#10b981' : '#f59e0b',
                fontWeight: 700, mt: 0.3,
              }}
            />
          </Grid>
          <Grid item xs={12} sm={2} sx={{ textAlign: { sm: 'right' } }}>
            <Box sx={{ display: 'inline-flex', alignItems: 'center', gap: 0.5 }}>
              <Box sx={{ width: 8, height: 8, borderRadius: '50%', bgcolor: '#10b981', animation: 'pulse 2s infinite' }} />
              <Typography variant="caption" sx={{ color: '#10b981', fontWeight: 600 }}>LIVE</Typography>
            </Box>
            <Typography variant="caption" sx={{ color: 'text.disabled', display: 'block' }}>
              {price.time ? new Date(price.time).toLocaleTimeString('th-TH') : ''}
            </Typography>
          </Grid>
        </Grid>
      </Paper>
    );
  }

  return (
    <Paper sx={{ p: 2.5 }}>
      <Typography variant="subtitle2" sx={{ color: 'text.secondary', mb: 2, fontWeight: 600 }}>
        ราคาตลาดแบบเรียลไทม์
      </Typography>
      <Box sx={{ display: 'flex', flexWrap: 'wrap', alignItems: 'stretch', gap: 2 }}>
        <Box sx={{
          flex: '1 1 140px', p: 2, borderRadius: 2,
          bgcolor: 'rgba(244,63,94,0.06)', border: '1px solid rgba(244,63,94,0.15)',
        }}>
          <Typography variant="caption" sx={{ color: '#f43f5e', fontWeight: 700 }}>BID — ขาย</Typography>
          <Typography variant="h4" sx={{ fontWeight: 800, color: '#f43f5e', mt: 0.5 }}>
            ${fmt(price.bid)}
          </Typography>
        </Box>
        <Box sx={{
          flex: '1 1 140px', p: 2, borderRadius: 2,
          bgcolor: 'rgba(16,185,129,0.06)', border: '1px solid rgba(16,185,129,0.15)',
        }}>
          <Typography variant="caption" sx={{ color: '#10b981', fontWeight: 700 }}>ASK — ซื้อ</Typography>
          <Typography variant="h4" sx={{ fontWeight: 800, color: '#10b981', mt: 0.5 }}>
            ${fmt(price.ask)}
          </Typography>
        </Box>
        <Box sx={{
          flex: '0 1 auto', p: 2, borderRadius: 2, display: 'flex', flexDirection: 'column', justifyContent: 'center',
          bgcolor: 'rgba(255,255,255,0.02)', border: '1px solid rgba(255,255,255,0.06)',
        }}>
          <Typography variant="caption" sx={{ color: 'text.secondary' }}>Spread</Typography>
          <Chip
            label={`${fmt(price.spread, 1)} pips`}
            size="small"
            sx={{
              bgcolor: price.spread < 3 ? 'rgba(16,185,129,0.12)' : 'rgba(245,158,11,0.12)',
              color:   price.spread < 3 ? '#10b981' : '#f59e0b',
              fontWeight: 700, mt: 0.5,
            }}
          />
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5, mt: 1 }}>
            <Box sx={{ width: 8, height: 8, borderRadius: '50%', bgcolor: '#10b981', animation: 'pulse 2s infinite' }} />
            <Typography variant="caption" sx={{ color: '#10b981', fontWeight: 600 }}>
              LIVE · {price.time ? new Date(price.time).toLocaleTimeString('th-TH') : ''}
            </Typography>
          </Box>
        </Box>
      </Box>
    </Paper>
  );
}
