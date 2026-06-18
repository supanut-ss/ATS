import React from 'react';
import { Box, Paper, Typography, Chip, Skeleton } from '@mui/material';
import { WaterfallChart } from '@mui/icons-material';

const fmt = (v, d = 2) =>
  v == null ? '—' : Number(v).toFixed(d);

export default function PriceDisplay({ price, loading }) {
  if (loading || !price) {
    return (
      <Paper sx={{ p: 2.5, display: 'flex', alignItems: 'center', gap: 3 }}>
        <Skeleton variant="rectangular" width={180} height={50} sx={{ borderRadius: 2 }} />
        <Skeleton variant="rectangular" width={120} height={40} sx={{ borderRadius: 2 }} />
      </Paper>
    );
  }

  return (
    <Paper sx={{ p: 2.5, display: 'flex', flexWrap: 'wrap', alignItems: 'center', gap: 3 }}>
      {/* Symbol */}
      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
        <Box sx={{
          p: 0.8, borderRadius: 1.5,
          background: 'linear-gradient(135deg,#f59e0b,#d97706)',
          display: 'flex',
        }}>
          <WaterfallChart sx={{ fontSize: 20, color: '#fff' }} />
        </Box>
        <Box>
          <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600, letterSpacing: 1 }}>
            XAUUSD · GOLD
          </Typography>
          <Typography variant="h5" sx={{ fontWeight: 800, lineHeight: 1.1, color: '#fbbf24' }}>
            {fmt(price.ask, 2)}
          </Typography>
        </Box>
      </Box>

      {/* Bid */}
      <Box>
        <Typography variant="caption" sx={{ color: 'text.secondary' }}>Bid</Typography>
        <Typography variant="h6" sx={{ fontWeight: 700, color: '#f43f5e' }}>{fmt(price.bid, 2)}</Typography>
      </Box>

      {/* Ask */}
      <Box>
        <Typography variant="caption" sx={{ color: 'text.secondary' }}>Ask</Typography>
        <Typography variant="h6" sx={{ fontWeight: 700, color: '#10b981' }}>{fmt(price.ask, 2)}</Typography>
      </Box>

      {/* Spread */}
      <Box>
        <Typography variant="caption" sx={{ color: 'text.secondary' }}>Spread</Typography>
        <Chip
          label={`${fmt(price.spread, 1)} pips`}
          size="small"
          sx={{
            bgcolor: price.spread < 3 ? 'rgba(16,185,129,0.12)' : 'rgba(245,158,11,0.12)',
            color:   price.spread < 3 ? '#10b981' : '#f59e0b',
            fontWeight: 700, mt: 0.3, display: 'block',
          }}
        />
      </Box>

      {/* Updated time */}
      <Box sx={{ ml: 'auto' }}>
        <Typography variant="caption" sx={{ color: 'text.disabled' }}>
          {price.time ? new Date(price.time).toLocaleTimeString('th-TH') : ''}
        </Typography>
        <Box sx={{
          display: 'flex', alignItems: 'center', gap: 0.5, mt: 0.2,
          '& span': { width: 8, height: 8, borderRadius: '50%', bgcolor: '#10b981', animation: 'pulse 2s infinite' },
        }}>
          <span />
          <Typography variant="caption" sx={{ color: '#10b981', fontWeight: 600 }}>LIVE</Typography>
        </Box>
      </Box>
    </Paper>
  );
}
