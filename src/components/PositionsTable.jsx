import React, { useState } from 'react';
import {
  Box, Paper, Typography, Table, TableBody, TableCell, TableContainer,
  TableHead, TableRow, Chip, Button, IconButton, Dialog, DialogTitle,
  DialogContent, DialogActions, TextField, Tooltip, Skeleton,
} from '@mui/material';
import { Close, Edit, TrendingUp, TrendingDown } from '@mui/icons-material';
import { closePosition, closeAllPositions, modifyPosition } from '../services/api';

const fmt = (v, d = 2) => v == null ? '—' : Number(v).toFixed(d);
const fmtPnl = (v) => {
  const n = Number(v);
  return (n >= 0 ? '+' : '') + '$' + Math.abs(n).toFixed(2);
};

export default function PositionsTable({ positions = [], loading, onRefresh }) {
  const [modifyDialog, setModifyDialog] = useState(null); // {ticket, sl, tp}
  const [closing, setClosing] = useState(null);

  const handleClose = async (ticket) => {
    setClosing(ticket);
    await closePosition(ticket);
    setClosing(null);
    onRefresh?.();
  };

  const handleCloseAll = async () => {
    await closeAllPositions();
    onRefresh?.();
  };

  const handleModify = async () => {
    if (!modifyDialog) return;
    await modifyPosition(modifyDialog.ticket, parseFloat(modifyDialog.sl), parseFloat(modifyDialog.tp));
    setModifyDialog(null);
    onRefresh?.();
  };

  const totalPnl = positions.reduce((s, p) => s + (p.profit || 0), 0);

  return (
    <Paper sx={{ p: 3 }}>
      {/* Header */}
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2, flexWrap: 'wrap', gap: 1 }}>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5 }}>
          <Typography variant="h6" sx={{ fontWeight: 700 }}>ออเดอร์ที่เปิดอยู่</Typography>
          <Chip
            label={positions.length}
            size="small"
            sx={{ bgcolor: 'rgba(99,102,241,0.12)', color: '#818cf8', fontWeight: 700 }}
          />
          {positions.length > 0 && (
            <Chip
              label={`Float: ${fmtPnl(totalPnl)}`}
              size="small"
              sx={{
                bgcolor: totalPnl >= 0 ? 'rgba(16,185,129,0.1)' : 'rgba(244,63,94,0.1)',
                color:   totalPnl >= 0 ? '#10b981' : '#f43f5e',
                fontWeight: 700,
              }}
            />
          )}
        </Box>
        {positions.length > 0 && (
          <Button
            variant="outlined"
            color="error"
            size="small"
            onClick={handleCloseAll}
            sx={{ borderColor: 'rgba(244,63,94,0.4)' }}
          >
            Close All
          </Button>
        )}
      </Box>

      {loading ? (
        <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1 }}>
          {[1, 2].map(i => <Skeleton key={i} variant="rectangular" height={52} sx={{ borderRadius: 1.5 }} />)}
        </Box>
      ) : positions.length === 0 ? (
        <Box sx={{ py: 5, textAlign: 'center' }}>
          <Typography sx={{ color: 'text.disabled' }}>No open positions</Typography>
        </Box>
      ) : (
        <TableContainer>
          <Table size="small">
            <TableHead>
              <TableRow>
                {['Ticket', 'Type', 'Lot', 'Open', 'Current', 'SL', 'TP', 'Profit', ''].map(h => (
                  <TableCell key={h} sx={{ color: 'text.secondary', fontWeight: 600, fontSize: '0.75rem', py: 1 }}>{h}</TableCell>
                ))}
              </TableRow>
            </TableHead>
            <TableBody>
              {positions.map((p) => (
                <TableRow key={p.ticket} sx={{ '&:hover': { bgcolor: 'rgba(255,255,255,0.01)' } }}>
                  <TableCell sx={{ fontFamily: 'monospace', fontSize: '0.8rem', color: 'text.secondary' }}>{p.ticket}</TableCell>
                  <TableCell>
                    <Chip
                      label={p.type}
                      size="small"
                      icon={p.type === 'BUY' ? <TrendingUp sx={{ fontSize: '14px !important' }} /> : <TrendingDown sx={{ fontSize: '14px !important' }} />}
                      sx={{
                        bgcolor: p.type === 'BUY' ? 'rgba(16,185,129,0.1)' : 'rgba(244,63,94,0.1)',
                        color:   p.type === 'BUY' ? '#10b981' : '#f43f5e',
                        fontWeight: 700, border: 0,
                      }}
                    />
                  </TableCell>
                  <TableCell sx={{ fontWeight: 600 }}>{p.volume}</TableCell>
                  <TableCell sx={{ fontFamily: 'monospace' }}>{fmt(p.open_price)}</TableCell>
                  <TableCell sx={{ fontFamily: 'monospace' }}>{fmt(p.current_price)}</TableCell>
                  <TableCell sx={{ fontFamily: 'monospace', color: '#f43f5e', fontSize: '0.8rem' }}>
                    {p.sl ? fmt(p.sl) : '—'}
                  </TableCell>
                  <TableCell sx={{ fontFamily: 'monospace', color: '#10b981', fontSize: '0.8rem' }}>
                    {p.tp ? fmt(p.tp) : '—'}
                  </TableCell>
                  <TableCell>
                    <Typography
                      variant="body2"
                      sx={{ fontWeight: 700, color: p.profit >= 0 ? '#10b981' : '#f43f5e' }}
                    >
                      {fmtPnl(p.profit)}
                    </Typography>
                  </TableCell>
                  <TableCell sx={{ p: 0.5 }}>
                    <Box sx={{ display: 'flex', gap: 0.5 }}>
                      <Tooltip title="Modify SL/TP">
                        <IconButton
                          size="small"
                          onClick={() => setModifyDialog({ ticket: p.ticket, sl: p.sl || '', tp: p.tp || '' })}
                          sx={{ color: 'text.secondary', '&:hover': { color: '#818cf8' } }}
                        >
                          <Edit sx={{ fontSize: 16 }} />
                        </IconButton>
                      </Tooltip>
                      <Tooltip title="Close Position">
                        <IconButton
                          size="small"
                          disabled={closing === p.ticket}
                          onClick={() => handleClose(p.ticket)}
                          sx={{ color: 'text.secondary', '&:hover': { color: '#f43f5e' } }}
                        >
                          <Close sx={{ fontSize: 16 }} />
                        </IconButton>
                      </Tooltip>
                    </Box>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      )}

      {/* Modify Dialog */}
      <Dialog open={!!modifyDialog} onClose={() => setModifyDialog(null)} maxWidth="xs" fullWidth
        PaperProps={{ sx: { bgcolor: '#111827', border: '1px solid rgba(255,255,255,0.08)' } }}>
        <DialogTitle>Modify SL / TP — #{modifyDialog?.ticket}</DialogTitle>
        <DialogContent sx={{ display: 'flex', flexDirection: 'column', gap: 2, pt: '12px !important' }}>
          <TextField
            label="Stop Loss (price)"
            type="number"
            value={modifyDialog?.sl ?? ''}
            onChange={e => setModifyDialog(d => ({ ...d, sl: e.target.value }))}
            size="small"
            fullWidth
            inputProps={{ step: 0.01 }}
            helperText="Leave 0 to remove SL"
          />
          <TextField
            label="Take Profit (price)"
            type="number"
            value={modifyDialog?.tp ?? ''}
            onChange={e => setModifyDialog(d => ({ ...d, tp: e.target.value }))}
            size="small"
            fullWidth
            inputProps={{ step: 0.01 }}
            helperText="Leave 0 to remove TP"
          />
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2 }}>
          <Button onClick={() => setModifyDialog(null)} color="inherit">Cancel</Button>
          <Button onClick={handleModify} variant="contained">Apply</Button>
        </DialogActions>
      </Dialog>
    </Paper>
  );
}
