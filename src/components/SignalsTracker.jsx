import React, { useState } from 'react';
import {
  Box, Paper, Typography, Grid, Table, TableBody, TableCell,
  TableContainer, TableHead, TableRow, Chip, CircularProgress, Button,
} from '@mui/material';
import {
  ShowChart, CheckCircle, HourglassEmpty,
  TrendingUp, TrendingDown, Toll, DeleteSweep,
} from '@mui/icons-material';
import { clearSignals } from '../services/api';

const fmt = (v, d = 2) =>
  v == null ? '—' : Number(v).toLocaleString('en-US', { minimumFractionDigits: d, maximumFractionDigits: d });

const ensureUtcIso = (dateStr) => {
  if (!dateStr) return '';
  if (typeof dateStr === 'string' && !dateStr.endsWith('Z') && !dateStr.includes('+') && !/-\d{2}:\d{2}$/.test(dateStr)) {
    return dateStr + 'Z';
  }
  return dateStr;
};

function StatCard({ label, value, color, icon, subtitle }) {
  return (
    <Paper sx={{ p: 1.5, height: '100%', borderColor: 'rgba(255,255,255,0.05)' }}>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <Box sx={{ minWidth: 0 }}>
          <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 700, letterSpacing: 0.5, textTransform: 'uppercase', fontSize: '0.62rem', lineHeight: 1 }}>
            {label}
          </Typography>
          <Typography sx={{ fontWeight: 800, mt: 0.5, color: color || 'text.primary', fontSize: '1.25rem', lineHeight: 1.2 }}>
            {value}
          </Typography>
          {subtitle && (
            <Typography variant="caption" sx={{ color: 'text.disabled', mt: 0.25, display: 'block', fontSize: '0.65rem', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
              {subtitle}
            </Typography>
          )}
        </Box>
        {icon && (
          <Box sx={{
            width: 32, height: 32, borderRadius: 1.5, flexShrink: 0,
            bgcolor: `${color ? color : '#fff'}12`,
            display: 'flex', alignItems: 'center', justifyContent: 'center'
          }}>
            {React.cloneElement(icon, { sx: { fontSize: 16, color: color || 'text.primary' } })}
          </Box>
        )}
      </Box>
    </Paper>
  );
}

export default function SignalsTracker({ signals, loading, onRefresh }) {
  const [clearing, setClearing] = useState(false);

  const handleClear = async () => {
    if (!confirm('ล้างสัญญาณทั้งหมด?')) return;
    setClearing(true);
    try {
      const res = await clearSignals();
      if (res.ok) {
        onRefresh?.();
      } else {
        alert(res.data?.error || 'ล้างสัญญาณไม่สำเร็จ');
      }
    } finally {
      setClearing(false);
    }
  };
  if (loading && signals.length === 0) {
    return (
      <Paper sx={{ p: 3, display: 'flex', justifyContent: 'center', alignItems: 'center', minHeight: 200 }}>
        <CircularProgress size={30} />
      </Paper>
    );
  }

  // Calculate statistics
  const totalTrades = signals.length;
  const closedTrades = signals.filter(s => s.status === 'WIN' || s.status === 'LOSS');
  const winTrades = signals.filter(s => s.status === 'WIN');
  const lossTrades = signals.filter(s => s.status === 'LOSS');
  const openTrades = signals.filter(s => s.status === 'OPEN');

  const winRate = closedTrades.length > 0 ? (winTrades.length / closedTrades.length) * 100 : 0;
  const totalProfit = signals.reduce((sum, s) => sum + (s.profit || 0), 0);

  const profitColor = totalProfit >= 0 ? '#10b981' : '#f43f5e';

  return (
    <Box>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2, flexWrap: 'wrap', gap: 1 }}>
        <Typography variant="h6" sx={{ fontWeight: 700, display: 'flex', alignItems: 'center', gap: 1 }}>
          <Toll sx={{ color: '#6366f1' }} />
          ผลการเทรดจากสัญญาณ
        </Typography>
        {signals.length > 0 && (
          <Button
            size="small"
            color="error"
            variant="outlined"
            startIcon={<DeleteSweep />}
            disabled={clearing}
            onClick={handleClear}
            sx={{ borderColor: 'rgba(244,63,94,0.4)' }}
          >
            {clearing ? 'กำลังล้าง…' : 'ล้างสัญญาณทั้งหมด'}
          </Button>
        )}
      </Box>

      {/* Metrics Row */}
      <Box sx={{
        display: 'flex',
        flexWrap: 'wrap',
        gap: 2,
        mb: 3,
      }}>
        <Box sx={{ flex: { xs: '1 1 calc(50% - 8px)', md: '1 1 0' }, minWidth: { xs: 140, md: 0 } }}>
          <StatCard
            label="อัตราชนะ"
            value={`${fmt(winRate, 1)}%`}
            color="#10b981"
            icon={<CheckCircle />}
            subtitle={`${winTrades.length} Wins / ${lossTrades.length} Losses`}
          />
        </Box>
        <Box sx={{ flex: { xs: '1 1 calc(50% - 8px)', md: '1 1 0' }, minWidth: { xs: 140, md: 0 } }}>
          <StatCard
            label="กำไร/ขาดทุนรวม"
            value={`${totalProfit >= 0 ? '+' : ''}$${fmt(totalProfit)}`}
            color={profitColor}
            icon={totalProfit >= 0 ? <TrendingUp /> : <TrendingDown />}
            subtitle="Accumulated strategy profit"
          />
        </Box>
        <Box sx={{ flex: { xs: '1 1 calc(50% - 8px)', md: '1 1 0' }, minWidth: { xs: 140, md: 0 } }}>
          <StatCard
            label="สัญญาณทั้งหมด"
            value={totalTrades}
            color="#818cf8"
            icon={<ShowChart />}
            subtitle={`${openTrades.length} Active (Open)`}
          />
        </Box>
        <Box sx={{ flex: { xs: '1 1 calc(50% - 8px)', md: '1 1 0' }, minWidth: { xs: 140, md: 0 } }}>
          <StatCard
            label="สัญญาณที่ยังเปิด"
            value={openTrades.length}
            color="#f59e0b"
            icon={<HourglassEmpty />}
            subtitle="Waiting for SL/TP exit"
          />
        </Box>
      </Box>

      {/* History Table */}
      <TableContainer component={Paper}>
        <Table sx={{ minWidth: { xs: 650, lg: '100%' } }}>
          <TableHead sx={{ bgcolor: 'rgba(255,255,255,0.02)' }}>
            <TableRow>
              <TableCell sx={{ fontWeight: 700 }}>Time</TableCell>
              <TableCell sx={{ fontWeight: 700 }}>Signal</TableCell>
              <TableCell sx={{ fontWeight: 700 }}>Type</TableCell>
              <TableCell sx={{ fontWeight: 700 }}>Entry Price</TableCell>
              <TableCell sx={{ fontWeight: 700 }}>SL / TP</TableCell>
              <TableCell sx={{ fontWeight: 700 }}>Exit Price</TableCell>
              <TableCell sx={{ fontWeight: 700 }}>Profit ($)</TableCell>
              <TableCell sx={{ fontWeight: 700 }}>Status</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {signals.length === 0 ? (
              <TableRow>
                <TableCell colSpan={8} align="center" sx={{ py: 6, color: 'text.secondary' }}>
                  ยังไม่มีสัญญาณ — ทดสอบด้วย Test BUY ใน Pine Script หรือรอสัญญาณจริงจาก TradingView
                </TableCell>
              </TableRow>
            ) : (
              signals.slice().reverse().map((sig) => {
                const isBuy = sig.action === 'BUY';
                const statusColor =
                  sig.status === 'WIN' ? 'success' :
                  sig.status === 'LOSS' ? 'error' : 'warning';
                
                const timeStr = new Date(ensureUtcIso(sig.timestamp)).toLocaleString('th-TH', {
                  month: 'short',
                  day: 'numeric',
                  hour: '2-digit',
                  minute: '2-digit',
                  second: '2-digit'
                });

                return (
                  <TableRow key={sig.id} sx={{ '&:hover': { bgcolor: 'rgba(255,255,255,0.01)' } }}>
                    <TableCell variant="body2">{timeStr}</TableCell>
                    <TableCell>
                      <Chip
                        label={sig.action}
                        size="small"
                        sx={{
                          bgcolor: isBuy ? 'rgba(16,185,129,0.1)' : 'rgba(244,63,94,0.1)',
                          color: isBuy ? '#10b981' : '#f43f5e',
                          fontWeight: 800,
                          borderRadius: 1.5,
                        }}
                      />
                    </TableCell>
                    <TableCell variant="body2" sx={{ fontWeight: 700 }}>{sig.symbol}</TableCell>
                    <TableCell variant="body2" sx={{ fontWeight: 600 }}>${fmt(sig.entryPrice)}</TableCell>
                    <TableCell variant="body2" sx={{ color: 'text.secondary' }}>
                      <span style={{ color: '#f43f5e' }}>{fmt(sig.sl)}</span>
                      {' / '}
                      <span style={{ color: '#10b981' }}>{fmt(sig.tp)}</span>
                    </TableCell>
                    <TableCell variant="body2" sx={{ fontWeight: 600 }}>
                      {sig.status !== 'OPEN' ? `$${fmt(sig.exitPrice)}` : '—'}
                    </TableCell>
                    <TableCell
                      variant="body2"
                      sx={{
                        fontWeight: 700,
                        color: sig.profit > 0 ? '#10b981' : sig.profit < 0 ? '#f43f5e' : 'text.secondary'
                      }}
                    >
                      {sig.status !== 'OPEN' ? `${sig.profit >= 0 ? '+' : ''}$${fmt(sig.profit)}` : '—'}
                    </TableCell>
                    <TableCell>
                      <Chip
                        label={sig.status}
                        size="small"
                        color={statusColor}
                        sx={{ fontWeight: 700, borderRadius: 1 }}
                      />
                    </TableCell>
                  </TableRow>
                );
              })
            )}
          </TableBody>
        </Table>
      </TableContainer>
    </Box>
  );
}
