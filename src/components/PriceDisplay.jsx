import React from 'react';
import { Box, Paper, Typography, Chip } from '@mui/material';
import { MonetizationOn } from '@mui/icons-material';

const fmt = (v, d = 2) => v == null ? '—' : Number(v).toFixed(d);

export default function PriceDisplay({ price }) {
  const isLive = !!price;

  return (
    <Paper sx={{
      px: 3, py: 1.5,
      display: 'flex', alignItems: 'center', gap: 3, flexWrap: 'wrap',
      borderColor: 'rgba(255,255,255,0.06)',
      background: 'linear-gradient(135deg,rgba(251,191,36,0.04),rgba(245,158,11,0.02))',
      minHeight: 60, boxSizing: 'border-box',
    }}>
      {/* Symbol + price */}
      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5 }}>
        <Box sx={{
          p: 0.6, borderRadius: 1.5,
          bgcolor: 'rgba(251,191,36,0.12)',
          display: 'flex', alignItems: 'center',
        }}>
          <MonetizationOn sx={{ color: '#fbbf24', fontSize: 20 }} />
        </Box>
        <Box>
          <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600, display: 'block', lineHeight: 1 }}>
            XAUUSD
          </Typography>
          <Typography variant="h6" sx={{ fontWeight: 800, color: '#fbbf24', lineHeight: 1.2 }}>
            ${isLive ? fmt(price.ask) : '—'}
          </Typography>
        </Box>
      </Box>

      <Box sx={{ display: 'flex', gap: 3, alignItems: 'center', flexWrap: 'wrap', flexGrow: 1 }}>
        <Box>
          <Typography variant="caption" sx={{ color: 'text.secondary' }}>Bid</Typography>
          <Typography variant="subtitle2" sx={{ fontWeight: 700, color: '#f43f5e' }}>
            ${isLive ? fmt(price.bid) : '—'}
          </Typography>
        </Box>
        <Box>
          <Typography variant="caption" sx={{ color: 'text.secondary' }}>Ask</Typography>
          <Typography variant="subtitle2" sx={{ fontWeight: 700, color: '#10b981' }}>
            ${isLive ? fmt(price.ask) : '—'}
          </Typography>
        </Box>
        <Box>
          <Typography variant="caption" sx={{ color: 'text.secondary' }}>Spread</Typography>
          <Box sx={{ mt: 0.2 }}>
            <Chip
              label={isLive ? `${fmt(price.spread, 1)} pips` : '—'}
              size="small"
              sx={{
                bgcolor: isLive && price.spread < 3 ? 'rgba(16,185,129,0.12)' : 'rgba(245,158,11,0.12)',
                color:   isLive && price.spread < 3 ? '#10b981' : '#f59e0b',
                fontWeight: 700, height: 20, fontSize: '0.7rem',
              }}
            />
          </Box>
        </Box>
      </Box>

      {/* Live indicator */}
      <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.75, ml: 'auto' }}>
        <Box sx={{
          width: 7, height: 7, borderRadius: '50%',
          bgcolor: isLive ? '#10b981' : '#6b7280',
          animation: isLive ? 'pulse 2s infinite' : 'none',
        }} />
        <Typography variant="caption" sx={{ color: isLive ? '#10b981' : 'text.disabled', fontWeight: 600 }}>
          {isLive ? 'LIVE' : 'OFFLINE'}
        </Typography>
      </Box>
    </Paper>
  );
}
