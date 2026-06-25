import React, { useState } from 'react';
import {
  Box, Paper, Typography, Table, TableBody, TableCell, TableContainer,
  TableHead, TableRow, Chip, Button, IconButton, Dialog, DialogTitle,
  DialogContent, DialogActions, TextField, Tooltip,
} from '@mui/material';
import { Close, Edit, TrendingUp, TrendingDown } from '@mui/icons-material';
import { closePosition, closeAllPositions, modifyPosition } from '../services/api';

const fmt = (v, d = 2) => v == null ? '—' : Number(v).toFixed(d);
const fmtPnl = (v) => {
  const n = Number(v);
  return (n >= 0 ? '+' : '') + '$' + Math.abs(n).toFixed(2);
};

const H = 360;

export default function PositionsTable({ positions = [], onRefresh }) {
  const [modifyDialog, setModifyDialog] = useState(null);
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
    <Paper sx={{
      height: H, minHeight: H, boxSizing: 'border-box',
      display: 'flex', flexDirection: 'column',
      borderColor: 'rgba(255,255,255,0.06)',
      overflow: 'hidden',
    }}>
      {/* Header — has horizontal padding */}
      <Box sx={{
        px: 2.5, py: 1.75,
        background: 'linear-gradient(135deg,rgba(99,102,241,0.08) 0%,rgba(139,92,246,0.04) 100%)',
        borderBottom: '1px solid rgba(255,255,255,0.06)',
        display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 1,
        flexShrink: 0,
      }}>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
          <Typography sx={{ fontWeight: 700, fontSize: '0.88rem' }}>ออเดอร์ที่เปิดอยู่</Typography>
          <Chip
            label={positions.length}
            size="small"
            sx={{ bgcolor: 'rgba(99,102,241,0.15)', color: '#818cf8', fontWeight: 800, height: 18, fontSize: '0.68rem', minWidth: 24 }}
          />
          {positions.length > 0 && (
            <Chip
              label={`Float ${fmtPnl(totalPnl)}`}
              size="small"
              sx={{
                bgcolor: totalPnl >= 0 ? 'rgba(16,185,129,0.1)' : 'rgba(244,63,94,0.1)',
                color:   totalPnl >= 0 ? '#10b981' : '#f43f5e',
                fontWeight: 700, height: 18, fontSize: '0.68rem',
              }}
            />
          )}
        </Box>
        {positions.length > 0 && (
          <Button
            variant="outlined" color="error" size="small"
            onClick={handleCloseAll}
            sx={{
              borderColor: 'rgba(244,63,94,0.35)', color: '#f43f5e', fontSize: '0.68rem',
              py: 0.3, px: 1.25,
              '&:hover': { bgcolor: 'rgba(244,63,94,0.06)', borderColor: '#f43f5e' },
            }}
          >
            Close All
          </Button>
        )}
      </Box>

      {/* Table — edge to edge, no side padding */}
      {positions.length === 0 ? (
        <Box sx={{
          flexGrow: 1, display: 'flex', flexDirection: 'column',
          alignItems: 'center', justifyContent: 'center', gap: 1,
        }}>
          <Box sx={{
            width: 44, height: 44, borderRadius: '50%',
            bgcolor: 'rgba(255,255,255,0.03)', border: '1px dashed rgba(255,255,255,0.1)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <TrendingUp sx={{ fontSize: 20, color: 'text.disabled' }} />
          </Box>
          <Typography sx={{ color: 'text.disabled', fontSize: '0.78rem' }}>ไม่มีออเดอร์เปิดอยู่</Typography>
        </Box>
      ) : (
        /* TableContainer fills remaining height, no extra px padding */
        <TableContainer sx={{ flexGrow: 1, overflow: 'auto' }}>
          <Table size="small" stickyHeader sx={{ tableLayout: 'fixed', width: '100%', minWidth: { xs: 600, lg: '100%' } }}>
            <TableHead>
              <TableRow>
                {[
                  { label: 'Ticket',  width: '22%' },
                  { label: 'Type',    width: '12%' },
                  { label: 'Lot',     width: '8%'  },
                  { label: 'Open',    width: '13%' },
                  { label: 'Current', width: '13%' },
                  { label: 'SL',      width: '10%' },
                  { label: 'TP',      width: '10%' },
                  { label: 'P/L',     width: '10%' },
                  { label: '',        width: '12%' },
                ].map(({ label, width }) => (
                  <TableCell
                    key={label}
                    sx={{
                      width, color: 'text.secondary', fontWeight: 700,
                      fontSize: '0.6rem', py: 0.9,
                      pl: label === 'Ticket' ? 2.5 : 1,
                      pr: label === '' ? 1.5 : 1,
                      bgcolor: '#0d1421',
                      borderBottom: '1px solid rgba(255,255,255,0.06)',
                      textTransform: 'uppercase', letterSpacing: 0.5,
                      whiteSpace: 'nowrap',
                    }}
                  >
                    {label}
                  </TableCell>
                ))}
              </TableRow>
            </TableHead>
            <TableBody>
              {positions.map((p) => (
                <TableRow
                  key={p.ticket}
                  sx={{ '&:hover': { bgcolor: 'rgba(255,255,255,0.015)' } }}
                >
                  <TableCell sx={{ fontFamily: 'monospace', fontSize: '0.7rem', color: 'text.disabled', py: 1, pl: 2.5, pr: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {p.ticket}
                  </TableCell>
                  <TableCell sx={{ py: 1, px: 1 }}>
                    <Chip
                      label={p.type}
                      size="small"
                      icon={p.type === 'BUY'
                        ? <TrendingUp sx={{ fontSize: '11px !important' }} />
                        : <TrendingDown sx={{ fontSize: '11px !important' }} />}
                      sx={{
                        bgcolor: p.type === 'BUY' ? 'rgba(16,185,129,0.12)' : 'rgba(244,63,94,0.12)',
                        color:   p.type === 'BUY' ? '#10b981' : '#f43f5e',
                        fontWeight: 800, fontSize: '0.6rem', height: 18,
                      }}
                    />
                  </TableCell>
                  <TableCell sx={{ fontWeight: 700, fontSize: '0.72rem', py: 1, px: 1 }}>{p.volume}</TableCell>
                  <TableCell sx={{ fontFamily: 'monospace', fontSize: '0.72rem', py: 1, px: 1 }}>{fmt(p.open_price)}</TableCell>
                  <TableCell sx={{ fontFamily: 'monospace', fontSize: '0.72rem', py: 1, px: 1, color: '#f3f4f6', fontWeight: 600 }}>{fmt(p.current_price)}</TableCell>
                  <TableCell sx={{ fontFamily: 'monospace', fontSize: '0.7rem', color: '#f43f5e', py: 1, px: 1 }}>
                    {p.sl ? fmt(p.sl) : <span style={{ color: '#374151' }}>—</span>}
                  </TableCell>
                  <TableCell sx={{ fontFamily: 'monospace', fontSize: '0.7rem', color: '#10b981', py: 1, px: 1 }}>
                    {p.tp ? fmt(p.tp) : <span style={{ color: '#374151' }}>—</span>}
                  </TableCell>
                  <TableCell sx={{ py: 1, px: 1 }}>
                    <Typography sx={{
                      fontWeight: 800, fontSize: '0.78rem',
                      color: p.profit >= 0 ? '#10b981' : '#f43f5e',
                      whiteSpace: 'nowrap',
                    }}>
                      {fmtPnl(p.profit)}
                    </Typography>
                  </TableCell>
                  <TableCell sx={{ py: 1, pl: 0.5, pr: 1.5, textAlign: 'right' }}>
                    <Box sx={{ display: 'flex', gap: 0.25, justifyContent: 'flex-end' }}>
                      <Tooltip title="Modify SL/TP">
                        <IconButton
                          size="small"
                          onClick={() => setModifyDialog({ ticket: p.ticket, sl: p.sl || '', tp: p.tp || '' })}
                          sx={{ color: 'text.disabled', '&:hover': { color: '#818cf8' }, p: 0.4 }}
                        >
                          <Edit sx={{ fontSize: 13 }} />
                        </IconButton>
                      </Tooltip>
                      <Tooltip title="Close Position">
                        <IconButton
                          size="small"
                          disabled={closing === p.ticket}
                          onClick={() => handleClose(p.ticket)}
                          sx={{ color: 'text.disabled', '&:hover': { color: '#f43f5e' }, p: 0.4 }}
                        >
                          <Close sx={{ fontSize: 13 }} />
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
      <Dialog
        open={!!modifyDialog} onClose={() => setModifyDialog(null)} maxWidth="xs" fullWidth
        PaperProps={{ sx: { bgcolor: '#111827', border: '1px solid rgba(255,255,255,0.08)' } }}
      >
        <DialogTitle sx={{ fontWeight: 700, fontSize: '0.95rem' }}>
          Modify SL / TP — #{modifyDialog?.ticket}
        </DialogTitle>
        <DialogContent sx={{ display: 'flex', flexDirection: 'column', gap: 2, pt: '12px !important' }}>
          <TextField label="Stop Loss (price)" type="number" value={modifyDialog?.sl ?? ''} size="small" fullWidth
            onChange={e => setModifyDialog(d => ({ ...d, sl: e.target.value }))}
            inputProps={{ step: 0.01 }} helperText="Leave 0 to remove SL" />
          <TextField label="Take Profit (price)" type="number" value={modifyDialog?.tp ?? ''} size="small" fullWidth
            onChange={e => setModifyDialog(d => ({ ...d, tp: e.target.value }))}
            inputProps={{ step: 0.01 }} helperText="Leave 0 to remove TP" />
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2 }}>
          <Button onClick={() => setModifyDialog(null)} color="inherit">Cancel</Button>
          <Button onClick={handleModify} variant="contained">Apply</Button>
        </DialogActions>
      </Dialog>
    </Paper>
  );
}
