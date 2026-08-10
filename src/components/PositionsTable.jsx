import React, { useState } from 'react';
import {
  Box, Paper, Typography, Table, TableBody, TableCell, TableContainer,
  TableHead, TableRow, Chip, Button, IconButton, Dialog, DialogTitle,
  DialogContent, DialogActions, TextField, Tooltip,
} from '@mui/material';
import { Close, Edit, TrendingUp, TrendingDown } from '@mui/icons-material';
import { productionApi } from '../services/api';

const fmt = (v, d = 2) => v == null ? '—' : Number(v).toFixed(d);
const fmtPnl = (v) => {
  const n = Number(v);
  return (n >= 0 ? '+' : '') + '$' + Math.abs(n).toFixed(2);
};

const H = 240;

export default function PositionsTable({ positions = [], onRefresh, apiClient = productionApi, actionsDisabled = false }) {
  const [modifyDialog, setModifyDialog] = useState(null);
  const [closing, setClosing] = useState(null);

  const handleClose = async (ticket) => {
    if (actionsDisabled) return;
    setClosing(ticket);
    await apiClient.closePosition(ticket);
    setClosing(null);
    onRefresh?.();
  };

  const handleCloseAll = async () => {
    if (actionsDisabled) return;
    await apiClient.closeAllPositions();
    onRefresh?.();
  };

  const handleModify = async () => {
    if (!modifyDialog || actionsDisabled) return;
    await apiClient.modifyPosition(modifyDialog.ticket, parseFloat(modifyDialog.sl), parseFloat(modifyDialog.tp));
    setModifyDialog(null);
    onRefresh?.();
  };

  const totalPnl = positions.reduce((s, p) => s + (p.profit || 0), 0);

  return (
    <Paper className="glow-card" sx={{
      height: H, minHeight: H, boxSizing: 'border-box',
      display: 'flex', flexDirection: 'column',
      borderColor: 'rgba(255,255,255,0.06)',
      overflow: 'hidden',
      background: 'linear-gradient(180deg, rgba(17,24,39,0.7) 0%, rgba(10,15,30,0.9) 100%)',
      backdropFilter: 'blur(16px)',
    }}>
      {/* Header — has horizontal padding */}
      <Box sx={{
        px: 2.5, py: 2,
        background: 'linear-gradient(135deg, rgba(99,102,241,0.08) 0%, rgba(139,92,246,0.04) 100%)',
        borderBottom: '1px solid rgba(255,255,255,0.06)',
        display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 1,
        flexShrink: 0,
      }}>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5 }}>
          <Typography sx={{ fontWeight: 800, fontSize: '0.85rem', color: '#c7d2fe', letterSpacing: 0.5, textTransform: 'uppercase' }}>
            Active Positions
          </Typography>
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
                bgcolor: totalPnl >= 0 ? 'rgba(16,185,129,0.12)' : 'rgba(244,63,94,0.12)',
                color:   totalPnl >= 0 ? '#10b981' : '#f43f5e',
                fontWeight: 800, height: 18, fontSize: '0.68rem',
              }}
            />
          )}
        </Box>
        {positions.length > 0 && (
          <Button
            variant="contained" color="error" size="small"
            disabled={actionsDisabled}
            onClick={handleCloseAll}
            sx={{
              bgcolor: 'linear-gradient(135deg, #e11d48, #be123c)',
              boxShadow: '0 4px 10px rgba(225,29,72,0.15)',
              fontSize: '0.68rem',
              fontWeight: 800,
              py: 0.5, px: 1.5,
              borderRadius: 1.5,
              '&:hover': { bgcolor: '#be123c' },
            }}
          >
            Close All Positions
          </Button>
        )}
      </Box>

      {/* Table — edge to edge, no side padding */}
      {positions.length === 0 ? (
        <Box sx={{
          flexGrow: 1, display: 'flex', flexDirection: 'column',
          alignItems: 'center', justifyContent: 'center', gap: 1.5,
        }}>
          <Box sx={{
            width: 48, height: 48, borderRadius: '50%',
            bgcolor: 'rgba(255,255,255,0.02)', border: '1px dashed rgba(255,255,255,0.1)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <TrendingUp sx={{ fontSize: 22, color: 'text.disabled' }} />
          </Box>
          <Typography sx={{ color: 'text.secondary', fontSize: '0.75rem', fontWeight: 600 }}>
            No Active Positions
          </Typography>
        </Box>
      ) : (
        /* TableContainer fills remaining height, no extra px padding */
        <TableContainer sx={{ flexGrow: 1, overflow: 'auto' }}>
          <Table size="small" stickyHeader sx={{ tableLayout: 'fixed', width: '100%', minWidth: { xs: 700, lg: '100%' } }}>
            <TableHead>
              <TableRow>
                {[
                  { label: 'Ticket',  width: '18%' },
                  { label: 'Type',    width: '13%' },
                  { label: 'Lot',     width: '10%' },
                  { label: 'Open',    width: '13%' },
                  { label: 'Current', width: '13%' },
                  { label: 'SL',      width: '11%' },
                  { label: 'TP',      width: '11%' },
                  { label: 'P/L',     width: '11%' },
                  { label: '',        width: '10%' },
                ].map(({ label, width }) => (
                  <TableCell
                    key={label}
                    sx={{
                      width, color: 'text.secondary', fontWeight: 800,
                      fontSize: '0.62rem', py: 1.2,
                      pl: label === 'Ticket' ? 2.5 : 1,
                      pr: label === '' ? 2 : 1,
                      bgcolor: 'rgba(15, 23, 42, 0.95)',
                      borderBottom: '1px solid rgba(255,255,255,0.06)',
                      textTransform: 'uppercase', letterSpacing: 0.8,
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
                  sx={{ '&:hover': { bgcolor: 'rgba(255,255,255,0.02)' }, transition: 'background-color 0.2s ease' }}
                >
                  <TableCell sx={{ fontFamily: 'monospace', fontSize: '0.72rem', color: 'text.disabled', py: 1.2, pl: 2.5, pr: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {p.ticket}
                  </TableCell>
                  <TableCell sx={{ py: 1.2, px: 1 }}>
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
                        borderRadius: 1
                      }}
                    />
                  </TableCell>
                  <TableCell sx={{ fontWeight: 800, fontSize: '0.75rem', py: 1.2, px: 1, color: '#f3f4f6' }}>{p.volume}</TableCell>
                  <TableCell sx={{ fontFamily: 'monospace', fontSize: '0.75rem', py: 1.2, px: 1, color: 'text.secondary' }}>{fmt(p.open_price)}</TableCell>
                  <TableCell sx={{ fontFamily: 'monospace', fontSize: '0.75rem', py: 1.2, px: 1, color: '#fbbf24', fontWeight: 700 }}>{fmt(p.current_price)}</TableCell>
                  <TableCell sx={{ fontFamily: 'monospace', fontSize: '0.72rem', color: '#f43f5e', py: 1.2, px: 1, fontWeight: 500 }}>
                    {p.sl ? fmt(p.sl) : <span style={{ color: 'rgba(255,255,255,0.15)' }}>—</span>}
                  </TableCell>
                  <TableCell sx={{ fontFamily: 'monospace', fontSize: '0.72rem', color: '#10b981', py: 1.2, px: 1, fontWeight: 500 }}>
                    {p.tp ? fmt(p.tp) : <span style={{ color: 'rgba(255,255,255,0.15)' }}>—</span>}
                  </TableCell>
                  <TableCell sx={{ py: 1.2, px: 1 }}>
                    <Typography className="mono" sx={{
                      fontWeight: 900, fontSize: '0.82rem',
                      color: p.profit >= 0 ? '#10b981' : '#f43f5e',
                      whiteSpace: 'nowrap',
                    }}>
                      {fmtPnl(p.profit)}
                    </Typography>
                  </TableCell>
                  <TableCell sx={{ py: 1.2, pl: 0.5, pr: 2, textAlign: 'right' }}>
                    <Box sx={{ display: 'flex', gap: 0.5, justifyContent: 'flex-end' }}>
                      <Tooltip title="Modify SL/TP">
                        <IconButton
                          size="small"
                          onClick={() => setModifyDialog({ ticket: p.ticket, sl: p.sl || '', tp: p.tp || '' })}
                          disabled={actionsDisabled}
                          sx={{ color: 'text.secondary', bgcolor: 'rgba(255,255,255,0.02)', '&:hover': { color: '#818cf8', bgcolor: 'rgba(99,102,241,0.1)' }, p: 0.5, borderRadius: 1 }}
                        >
                          <Edit sx={{ fontSize: 13 }} />
                        </IconButton>
                      </Tooltip>
                      <Tooltip title="Close Position">
                        <IconButton
                          size="small"
                          disabled={actionsDisabled || closing === p.ticket}
                          onClick={() => handleClose(p.ticket)}
                          sx={{ color: 'text.secondary', bgcolor: 'rgba(255,255,255,0.02)', '&:hover': { color: '#f43f5e', bgcolor: 'rgba(244,63,94,0.1)' }, p: 0.5, borderRadius: 1 }}
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
        PaperProps={{
          sx: {
            bgcolor: 'background.paper',
            borderRadius: 2.5,
            border: '1px solid rgba(255,255,255,0.08)',
            boxShadow: '0 10px 40px rgba(0,0,0,0.5)'
          }
        }}
      >
        <DialogTitle sx={{ fontWeight: 800, fontSize: '0.95rem', borderBottom: '1px solid rgba(255,255,255,0.05)', pb: 1.5 }}>
          Modify SL / TP — Ticket #{modifyDialog?.ticket}
        </DialogTitle>
        <DialogContent sx={{ display: 'flex', flexDirection: 'column', gap: 2.5, pt: '20px !important' }}>
          <TextField
            label="Stop Loss (SL Price)"
            type="number"
            value={modifyDialog?.sl ?? ''}
            size="small"
            fullWidth
            onChange={e => setModifyDialog(d => ({ ...d, sl: e.target.value }))}
            inputProps={{ step: 0.01 }}
            helperText="Set to 0 or leave empty to remove SL protection"
            FormHelperTextProps={{ sx: { mx: 0 } }}
          />
          <TextField
            label="Take Profit (TP Price)"
            type="number"
            value={modifyDialog?.tp ?? ''}
            size="small"
            fullWidth
            onChange={e => setModifyDialog(d => ({ ...d, tp: e.target.value }))}
            inputProps={{ step: 0.01 }}
            helperText="Set to 0 or leave empty to remove TP target"
            FormHelperTextProps={{ sx: { mx: 0 } }}
          />
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2.5, gap: 1 }}>
          <Button onClick={() => setModifyDialog(null)} color="inherit" sx={{ fontWeight: 700 }}>Cancel</Button>
          <Button onClick={handleModify} variant="contained" disabled={actionsDisabled} sx={{ fontWeight: 700, px: 3 }}>Apply Modification</Button>
        </DialogActions>
      </Dialog>
    </Paper>
  );
}
