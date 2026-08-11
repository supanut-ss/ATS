import React, { useState } from 'react';
import {
  Box, Paper, Typography, Divider, Table, TableBody, TableCell,
  TableContainer, TableHead, TableRow, Chip, CircularProgress, Button, TablePagination
} from '@mui/material';
import {
  ShowChart, CheckCircle, HourglassEmpty,
  TrendingUp, TrendingDown, Toll, DeleteSweep, AccountBalanceWallet,
} from '@mui/icons-material';
import { productionApi } from '../services/api';

const fmt = (v, d = 2) =>
  v == null ? '—' : Number(v).toLocaleString('en-US', { minimumFractionDigits: d, maximumFractionDigits: d });

const ensureUtcIso = (dateStr) => {
  if (!dateStr) return '';
  if (typeof dateStr === 'string' && !dateStr.endsWith('Z') && !dateStr.includes('+') && !/-\d{2}:\d{2}$/.test(dateStr)) {
    return dateStr + 'Z';
  }
  return dateStr;
};

function StatCell({ label, value, sub, color, icon, divider = true }) {
  return (
    <>
      <Box className="glow-card" sx={{
        flex: { xs: '1 1 calc(50% - 12px)', sm: '1 1 calc(20% - 16px)', lg: '1 1 0' },
        minWidth: { xs: 130, lg: 0 },
        px: 2,
        py: 1.5,
        display: 'flex',
        alignItems: 'center',
        gap: 1.5,
        borderRadius: 2,
        transition: 'all 0.2s ease',
      }}>
        {icon && (
          <Box sx={{
            width: 36, height: 36, borderRadius: 2, flexShrink: 0,
            bgcolor: `${color}15`,
            border: `1px solid ${color}30`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            {React.cloneElement(icon, { sx: { fontSize: 18, color } })}
          </Box>
        )}
        <Box sx={{ minWidth: 0 }}>
          <Typography sx={{
            fontSize: '0.62rem', fontWeight: 800, color: 'text.secondary',
            textTransform: 'uppercase', letterSpacing: 0.8,
            whiteSpace: 'nowrap', lineHeight: 1,
          }}>
            {label}
          </Typography>
          <Typography className="mono" sx={{
            fontSize: '1.05rem', fontWeight: 900, color: color || 'text.primary',
            whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
            lineHeight: 1.3, mt: 0.3,
          }}>
            {value}
          </Typography>
          {sub != null && (
            <Typography sx={{
              fontSize: '0.65rem', color: 'text.disabled', fontWeight: 500,
              whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
              lineHeight: 1.2, mt: 0.2,
              minHeight: '0.75rem',
            }}>
              {sub}
            </Typography>
          )}
        </Box>
      </Box>
      {divider && (
        <Divider
          orientation="vertical"
          flexItem
          sx={{
            borderColor: 'rgba(255,255,255,0.06)',
            my: 1,
            display: { xs: 'none', lg: 'block' }
          }}
        />
      )}
    </>
  );
}

export default function SignalsTracker({ signals, loading, onRefresh, apiClient = productionApi, actionsDisabled = false, initialCapital = 300 }) {
  const [clearing, setClearing] = useState(false);
  const [filterMode, setFilterMode] = useState('today'); // 'today' | 'all'
  const [page, setPage] = useState(0);
  const [rowsPerPage, setRowsPerPage] = useState(20);

  const handleClear = async () => {
    if (actionsDisabled) return;
    if (!confirm('Are you sure you want to clear all signals?')) return;
    setClearing(true);
    try {
      const res = await apiClient.clearSignals();
      if (res.ok) {
        onRefresh?.();
      } else {
        alert(res.data?.error || 'Failed to clear signals');
      }
    } finally {
      setClearing(false);
    }
  };

  const isToday = (dateStr) => {
    if (!dateStr) return false;
    const d = new Date(ensureUtcIso(dateStr));
    const now = new Date();
    return (
      d.getFullYear() === now.getFullYear() &&
      d.getMonth() === now.getMonth() &&
      d.getDate() === now.getDate()
    );
  };

  const filteredSignals = filterMode === 'today'
    ? signals.filter(s => isToday(s.timestamp))
    : signals;

  if (loading && signals.length === 0) {
    return (
      <Paper sx={{ p: 3, display: 'flex', justifyContent: 'center', alignItems: 'center', minHeight: 200, bgcolor: 'transparent', border: 'none' }}>
        <CircularProgress size={30} sx={{ color: '#6366f1' }} />
      </Paper>
    );
  }

  // Calculate statistics for filtered signals
  const totalTrades = filteredSignals.length;
  const closedTrades = filteredSignals.filter(s => s.status === 'WIN' || s.status === 'LOSS');
  const winTrades = filteredSignals.filter(s => s.status === 'WIN');
  const lossTrades = filteredSignals.filter(s => s.status === 'LOSS');
  const openTrades = filteredSignals.filter(s => s.status === 'OPEN');

  const winRate = closedTrades.length > 0 ? (winTrades.length / closedTrades.length) * 100 : 0;
  const totalProfit = filteredSignals.reduce((sum, s) => sum + (s.profit || 0), 0);

  const reversedSignals = filteredSignals.slice().reverse();
  const displayedSignals = reversedSignals.slice(page * rowsPerPage, page * rowsPerPage + rowsPerPage);

  const profitColor = totalProfit >= 0 ? '#10b981' : '#f43f5e';

  return (
    <Box>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2, flexWrap: 'wrap', gap: 1.5 }}>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, flexWrap: 'wrap' }}>
          <Typography variant="h6" sx={{ fontWeight: 800, display: 'flex', alignItems: 'center', gap: 1.5, fontSize: '0.95rem', letterSpacing: 0.5, color: '#c7d2fe', textTransform: 'uppercase' }}>
            <Toll sx={{ color: '#6366f1', fontSize: 20 }} />
            SIGNALS LOG
          </Typography>
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.75 }}>
            <Chip
              label="Today Only"
              size="small"
              onClick={() => { setFilterMode('today'); setPage(0); }}
              sx={{
                bgcolor: filterMode === 'today' ? 'rgba(99,102,241,0.2)' : 'rgba(255,255,255,0.04)',
                color: filterMode === 'today' ? '#818cf8' : 'text.disabled',
                border: `1px solid ${filterMode === 'today' ? 'rgba(99,102,241,0.4)' : 'rgba(255,255,255,0.08)'}`,
                fontWeight: 800, fontSize: '0.68rem', height: 22, cursor: 'pointer',
                '&:hover': { bgcolor: 'rgba(99,102,241,0.15)' }
              }}
            />
            <Chip
              label="All Signals"
              size="small"
              onClick={() => { setFilterMode('all'); setPage(0); }}
              sx={{
                bgcolor: filterMode === 'all' ? 'rgba(99,102,241,0.2)' : 'rgba(255,255,255,0.04)',
                color: filterMode === 'all' ? '#818cf8' : 'text.disabled',
                border: `1px solid ${filterMode === 'all' ? 'rgba(99,102,241,0.4)' : 'rgba(255,255,255,0.08)'}`,
                fontWeight: 800, fontSize: '0.68rem', height: 22, cursor: 'pointer',
                '&:hover': { bgcolor: 'rgba(99,102,241,0.15)' }
              }}
            />
          </Box>
        </Box>
        {signals.length > 0 && (
          <Button
            size="small"
            color="error"
            variant="outlined"
            startIcon={<DeleteSweep />}
            disabled={actionsDisabled || clearing}
            onClick={handleClear}
            sx={{
              borderColor: 'rgba(244,63,94,0.3)',
              color: '#f43f5e',
              fontSize: '0.7rem',
              fontWeight: 800,
              borderRadius: 1.5,
              px: 1.5,
              '&:hover': { bgcolor: 'rgba(244,63,94,0.06)', borderColor: '#f43f5e' }
            }}
          >
            {clearing ? 'Clearing…' : 'Clear All Signals'}
          </Button>
        )}
      </Box>

      {/* Metrics Strip (Identical to Top Strip Layout) */}
      <Paper sx={{
        display: 'flex',
        flexWrap: { xs: 'wrap', lg: 'nowrap' },
        alignItems: 'stretch',
        overflow: 'hidden',
        borderColor: 'rgba(255,255,255,0.06)',
        background: 'linear-gradient(180deg, rgba(20,25,40,0.7) 0%, rgba(10,15,30,0.85) 100%)',
        backdropFilter: 'blur(16px)',
        boxShadow: '0 8px 32px rgba(0,0,0,0.3)',
        borderRadius: 3,
        p: 0.75,
        mb: 2.5,
      }}>
        <StatCell
          label="Initial Capital"
          value={`$${fmt(initialCapital)}`}
          sub="Initial Capital ($300)"
          color="#38bdf8"
          icon={<AccountBalanceWallet />}
        />
        <StatCell
          label="Win Rate"
          value={`${fmt(winRate, 1)}%`}
          sub={`${winTrades.length} Wins / ${lossTrades.length} Losses`}
          color="#10b981"
          icon={<CheckCircle />}
        />
        <StatCell
          label="Total Profit / Loss"
          value={`${totalProfit >= 0 ? '+' : ''}$${fmt(totalProfit)}`}
          sub={filterMode === 'today' ? "Today's strategy return" : "Accumulated strategy profit"}
          color={profitColor}
          icon={totalProfit >= 0 ? <TrendingUp /> : <TrendingDown />}
        />
        <StatCell
          label="Total Signals"
          value={totalTrades}
          sub={filterMode === 'today' ? `${openTrades.length} Open Today` : `${openTrades.length} Active (Open)`}
          color="#818cf8"
          icon={<ShowChart />}
        />
        <StatCell
          label="Open Signals"
          value={openTrades.length}
          sub="Waiting for SL/TP exit"
          color="#fbbf24"
          icon={<HourglassEmpty />}
          divider={false}
        />
      </Paper>

      {/* History Table Container */}
      <TableContainer component={Paper} className="glow-card" sx={{
        borderColor: 'rgba(255,255,255,0.06)',
        background: 'linear-gradient(180deg, rgba(17,24,39,0.7) 0%, rgba(10,15,30,0.9) 100%)',
        backdropFilter: 'blur(16px)',
        borderRadius: 3,
        overflow: 'hidden'
      }}>
        <Table sx={{ minWidth: { xs: 650, lg: '100%' } }}>
          <TableHead>
            <TableRow>
              {['Time', 'Signal', 'Type', 'Entry Price', 'SL / TP', 'Exit Price', 'Profit ($)', 'Status'].map(h => (
                <TableCell key={h} sx={{
                  color: 'text.secondary', fontWeight: 800, fontSize: '0.62rem',
                  bgcolor: 'rgba(15, 23, 42, 0.95)',
                  borderBottom: '1px solid rgba(255,255,255,0.06)',
                  textTransform: 'uppercase', letterSpacing: 0.8,
                  py: 1.2,
                  pl: h === 'Time' ? 2.5 : 1,
                  pr: h === 'Status' ? 2.5 : 1
                }}>{h}</TableCell>
              ))}
            </TableRow>
          </TableHead>
          <TableBody>
            {filteredSignals.length === 0 ? (
              <TableRow>
                <TableCell colSpan={8} align="center" sx={{ py: 6, color: 'text.secondary', border: 'none' }}>
                  {filterMode === 'today'
                    ? 'No signals recorded for today.'
                    : 'No signals recorded yet.'}
                </TableCell>
              </TableRow>
            ) : (
              displayedSignals.map((sig) => {
                const isBuy = sig.action === 'BUY';
                const statusColor =
                  sig.status === 'WIN' ? '#10b981' :
                  sig.status === 'LOSS' ? '#f43f5e' : '#fbbf24';
                
                const timeStr = new Date(ensureUtcIso(sig.timestamp)).toLocaleString('th-TH', {
                  month: 'short',
                  day: 'numeric',
                  hour: '2-digit',
                  minute: '2-digit',
                  second: '2-digit'
                });

                return (
                  <TableRow key={sig.id} sx={{ '&:hover': { bgcolor: 'rgba(255,255,255,0.015)' }, transition: 'background-color 0.2s ease' }}>
                    <TableCell variant="body2" sx={{ pl: 2.5, py: 1.2, color: 'text.secondary', fontSize: '0.72rem' }}>{timeStr}</TableCell>
                    <TableCell sx={{ py: 1.2 }}>
                      <Chip
                        label={sig.action}
                        size="small"
                        sx={{
                          bgcolor: isBuy ? 'rgba(16,185,129,0.12)' : 'rgba(244,63,94,0.12)',
                          color: isBuy ? '#10b981' : '#f43f5e',
                          fontWeight: 800,
                          borderRadius: 1,
                          fontSize: '0.6rem',
                          height: 18
                        }}
                      />
                    </TableCell>
                    <TableCell variant="body2" sx={{ fontWeight: 800, fontSize: '0.72rem', color: '#f3f4f6' }}>{sig.symbol}</TableCell>
                    <TableCell variant="body2" className="mono" sx={{ fontWeight: 600, fontSize: '0.75rem' }}>${fmt(sig.entryPrice)}</TableCell>
                    <TableCell variant="body2" className="mono" sx={{ fontSize: '0.72rem' }}>
                      <span style={{ color: '#f43f5e', fontWeight: 600 }}>{fmt(sig.sl)}</span>
                      <span style={{ color: 'rgba(255,255,255,0.15)', margin: '0 4px' }}>/</span>
                      <span style={{ color: '#10b981', fontWeight: 600 }}>{fmt(sig.tp)}</span>
                    </TableCell>
                    <TableCell variant="body2" className="mono" sx={{ fontWeight: 600, fontSize: '0.75rem', color: 'text.secondary' }}>
                      {sig.status !== 'OPEN' ? `$${fmt(sig.exitPrice)}` : <span style={{ color: 'rgba(255,255,255,0.15)' }}>—</span>}
                    </TableCell>
                    <TableCell
                      variant="body2"
                      className="mono"
                      sx={{
                        fontWeight: 900,
                        fontSize: '0.78rem',
                        color: sig.profit > 0 ? '#10b981' : sig.profit < 0 ? '#f43f5e' : 'text.secondary'
                      }}
                    >
                      {sig.status !== 'OPEN' ? `${sig.profit >= 0 ? '+' : ''}$${fmt(sig.profit)}` : <span style={{ color: 'rgba(255,255,255,0.15)' }}>—</span>}
                    </TableCell>
                    <TableCell sx={{ pr: 2.5, py: 1.2 }}>
                      <Chip
                        label={sig.status}
                        size="small"
                        sx={{
                          fontWeight: 800,
                          borderRadius: 1,
                          fontSize: '0.6rem',
                          height: 18,
                          bgcolor: `${statusColor}18`,
                          color: statusColor,
                          border: `1px solid ${statusColor}30`
                        }}
                      />
                    </TableCell>
                  </TableRow>
                );
              })
            )}
          </TableBody>
        </Table>
      </TableContainer>
      {signals.length > 0 && (
        <TablePagination
          rowsPerPageOptions={[10, 20, 50]}
          component="div"
          count={signals.length}
          rowsPerPage={rowsPerPage}
          page={page}
          onPageChange={(e, newPage) => setPage(newPage)}
          onRowsPerPageChange={(e) => {
            setRowsPerPage(parseInt(e.target.value, 10));
            setPage(0);
          }}
        />
      )}
    </Box>
  );
}
