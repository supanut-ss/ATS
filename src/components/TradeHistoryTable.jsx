import React from 'react';
import {
  Box, Paper, Typography, Table, TableBody, TableCell,
  TableContainer, TableHead, TableRow, Chip, Skeleton,
} from '@mui/material';

const fmt = (v, d = 2) => v == null ? '—' : Number(v).toFixed(d);
const fmtTime = (iso) => {
  if (!iso) return '—';
  const d = new Date(iso);
  return d.toLocaleDateString('th-TH') + ' ' + d.toLocaleTimeString('th-TH', { hour: '2-digit', minute: '2-digit' });
};

export default function TradeHistoryTable({ history = [], loading }) {
  const totalPnl = history.reduce((s, h) => s + (h.profit || 0), 0);
  const wins     = history.filter(h => h.profit > 0).length;
  const winRate  = history.length > 0 ? ((wins / history.length) * 100).toFixed(1) : '—';

  return (
    <Paper sx={{ p: 3 }}>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2, flexWrap: 'wrap', gap: 1 }}>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5 }}>
          <Typography variant="h6" sx={{ fontWeight: 700 }}>ประวัติการเทรด</Typography>
          <Chip label={`${history.length} trades`} size="small" sx={{ bgcolor: 'rgba(255,255,255,0.05)', color: 'text.secondary' }} />
        </Box>
        <Box sx={{ display: 'flex', gap: 2 }}>
          <Box sx={{ textAlign: 'right' }}>
            <Typography variant="caption" sx={{ color: 'text.secondary' }}>Win Rate</Typography>
            <Typography variant="subtitle2" sx={{ fontWeight: 700, color: '#818cf8' }}>{winRate}%</Typography>
          </Box>
          <Box sx={{ textAlign: 'right' }}>
            <Typography variant="caption" sx={{ color: 'text.secondary' }}>Total P/L</Typography>
            <Typography variant="subtitle2" sx={{ fontWeight: 700, color: totalPnl >= 0 ? '#10b981' : '#f43f5e' }}>
              {totalPnl >= 0 ? '+' : ''}${fmt(totalPnl)}
            </Typography>
          </Box>
        </Box>
      </Box>

      {loading ? (
        <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1 }}>
          {[1, 2, 3].map(i => <Skeleton key={i} variant="rectangular" height={48} sx={{ borderRadius: 1.5 }} />)}
        </Box>
      ) : history.length === 0 ? (
        <Box sx={{ py: 5, textAlign: 'center' }}>
          <Typography sx={{ color: 'text.disabled' }}>No trade history</Typography>
        </Box>
      ) : (
        <TableContainer sx={{ maxHeight: 360 }}>
          <Table size="small" stickyHeader sx={{ minWidth: { xs: 650, lg: '100%' } }}>
            <TableHead>
              <TableRow>
                {['Ticket', 'Type', 'Lot', 'Price', 'Profit', 'Swap', 'Comment', 'Time'].map(h => (
                  <TableCell key={h} sx={{
                    color: 'text.secondary', fontWeight: 600, fontSize: '0.75rem',
                    bgcolor: '#111827', py: 1,
                  }}>{h}</TableCell>
                ))}
              </TableRow>
            </TableHead>
            <TableBody>
              {history.map((h) => (
                <TableRow key={h.ticket} sx={{ '&:hover': { bgcolor: 'rgba(255,255,255,0.01)' } }}>
                  <TableCell sx={{ fontFamily: 'monospace', fontSize: '0.75rem', color: 'text.secondary' }}>{h.ticket}</TableCell>
                  <TableCell>
                    <Chip
                      label={h.type}
                      size="small"
                      sx={{
                        bgcolor: h.type === 'BUY' ? 'rgba(16,185,129,0.1)' : h.type === 'SELL' ? 'rgba(244,63,94,0.1)' : 'rgba(255,255,255,0.05)',
                        color:   h.type === 'BUY' ? '#10b981' : h.type === 'SELL' ? '#f43f5e' : 'text.secondary',
                        fontWeight: 700, height: 20, fontSize: '0.7rem',
                      }}
                    />
                  </TableCell>
                  <TableCell sx={{ fontSize: '0.8rem' }}>{h.volume}</TableCell>
                  <TableCell sx={{ fontFamily: 'monospace', fontSize: '0.8rem' }}>{fmt(h.price)}</TableCell>
                  <TableCell>
                    <Typography variant="body2" sx={{ fontWeight: 700, color: h.profit >= 0 ? '#10b981' : '#f43f5e', fontSize: '0.8rem' }}>
                      {h.profit >= 0 ? '+' : ''}${fmt(h.profit)}
                    </Typography>
                  </TableCell>
                  <TableCell sx={{ fontSize: '0.75rem', color: 'text.secondary' }}>{fmt(h.swap)}</TableCell>
                  <TableCell sx={{ fontSize: '0.75rem', color: 'text.secondary', maxWidth: 120, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {h.comment || '—'}
                  </TableCell>
                  <TableCell sx={{ fontSize: '0.75rem', color: 'text.secondary', whiteSpace: 'nowrap' }}>
                    {fmtTime(h.time)}
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      )}
    </Paper>
  );
}
