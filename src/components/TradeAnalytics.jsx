import React, { useMemo } from 'react';
import {
  Box, Paper, Typography, Grid, Chip
} from '@mui/material';
import {
  AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip as RechartsTooltip, ResponsiveContainer
} from 'recharts';
import { Timeline, AccessTime } from '@mui/icons-material';

const fmt = (v, d = 2) => v == null ? '—' : Number(v).toLocaleString('en-US', { minimumFractionDigits: d, maximumFractionDigits: d });

export default function TradeAnalytics({ signals = [], initialCapital = 300 }) {
  // 1. Process data for Equity Curve
  const equityData = useMemo(() => {
    const closed = signals.filter(s => s.status === 'WIN' || s.status === 'LOSS');
    // Sort chronological (oldest first)
    const sorted = [...closed].sort((a, b) => new Date(a.time).getTime() - new Date(b.time).getTime());

    let currentEquity = initialCapital;
    const data = [{
      timeLabel: 'Start',
      equity: currentEquity,
      profit: 0
    }];

    sorted.forEach(trade => {
      const pnl = trade.profit || 0;
      currentEquity += pnl;
      
      const d = new Date(trade.time);
      // Format label as DD/MM HH:mm
      const label = `${d.getDate().toString().padStart(2, '0')}/${(d.getMonth() + 1).toString().padStart(2, '0')} ${d.getHours().toString().padStart(2, '0')}:${d.getMinutes().toString().padStart(2, '0')}`;
      
      data.push({
        timeLabel: label,
        equity: currentEquity,
        profit: pnl
      });
    });

    return data;
  }, [signals, initialCapital]);

  // 2. Process data for Session Analytics
  const sessionStats = useMemo(() => {
    const closed = signals.filter(s => s.status === 'WIN' || s.status === 'LOSS');
    
    // Initialize session buckets
    const sessions = {
      Asia: { name: 'Asia (07:00 - 15:00 TH)', trades: 0, wins: 0, profit: 0, color: '#f59e0b' },
      Europe: { name: 'Europe (15:00 - 20:00 TH)', trades: 0, wins: 0, profit: 0, color: '#38bdf8' },
      US: { name: 'New York (20:00 - 05:00 TH)', trades: 0, wins: 0, profit: 0, color: '#8b5cf6' },
      Other: { name: 'Other', trades: 0, wins: 0, profit: 0, color: '#9ca3af' }
    };

    closed.forEach(trade => {
      const utcHour = new Date(trade.time).getUTCHours();
      const pnl = trade.profit || 0;
      const isWin = trade.status === 'WIN';

      let key = 'Other';
      if (utcHour >= 0 && utcHour < 8) key = 'Asia';
      else if (utcHour >= 8 && utcHour < 13) key = 'Europe';
      else if (utcHour >= 13 && utcHour < 22) key = 'US';
      else key = 'Other';

      sessions[key].trades++;
      sessions[key].profit += pnl;
      if (isWin) sessions[key].wins++;
    });

    return Object.values(sessions).filter(s => s.trades > 0);
  }, [signals]);

  // Custom tooltip for chart
  const CustomTooltip = ({ active, payload }) => {
    if (active && payload && payload.length) {
      const eq = payload[0].value;
      const pnl = payload[0].payload.profit;
      const tLabel = payload[0].payload.timeLabel;
      return (
        <Box sx={{ bgcolor: 'rgba(17,24,39,0.9)', border: '1px solid rgba(255,255,255,0.1)', p: 1.5, borderRadius: 2 }}>
          <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block', mb: 0.5 }}>{tLabel}</Typography>
          <Typography variant="body2" sx={{ fontWeight: 800, color: '#fff' }}>
            Equity: ${fmt(eq)}
          </Typography>
          {tLabel !== 'Start' && (
            <Typography variant="body2" sx={{ fontWeight: 700, color: pnl >= 0 ? '#10b981' : '#f43f5e' }}>
              Trade P/L: {pnl >= 0 ? '+' : ''}${fmt(pnl)}
            </Typography>
          )}
        </Box>
      );
    }
    return null;
  };

  return (
    <Box sx={{ mb: 3 }}>
      <Box sx={{ display: 'flex', flexDirection: { xs: 'column', lg: 'row' }, gap: 3 }}>
        {/* Equity Curve Chart */}
        <Box sx={{ flex: { xs: '1 1 100%', lg: '2 1 0%' }, minWidth: 0 }}>
          <Paper sx={{ p: 3, height: '100%', display: 'flex', flexDirection: 'column' }}>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 3 }}>
              <Timeline sx={{ color: '#6366f1' }} />
              <Typography variant="h6" sx={{ fontWeight: 700 }}>Equity Curve</Typography>
              <Chip label="Net P/L Growth" size="small" sx={{ ml: 'auto', bgcolor: 'rgba(99,102,241,0.1)', color: '#818cf8', fontWeight: 700 }} />
            </Box>
            <Box sx={{ flexGrow: 1, minHeight: 300, width: '100%' }}>
              {equityData.length <= 1 ? (
                <Box sx={{ height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <Typography sx={{ color: 'text.disabled' }}>ไม่พบข้อมูลการเทรดที่ปิดแล้ว</Typography>
                </Box>
              ) : (
                <ResponsiveContainer width="100%" height={300}>
                  <AreaChart data={equityData} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                    <defs>
                      <linearGradient id="colorEquity" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="5%" stopColor="#6366f1" stopOpacity={0.4}/>
                        <stop offset="95%" stopColor="#6366f1" stopOpacity={0}/>
                      </linearGradient>
                    </defs>
                    <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" vertical={false} />
                    <XAxis 
                      dataKey="timeLabel" 
                      tick={{ fill: '#9ca3af', fontSize: 11 }}
                      tickLine={false}
                      axisLine={false}
                      minTickGap={30}
                    />
                    <YAxis 
                      domain={['auto', 'auto']}
                      tick={{ fill: '#9ca3af', fontSize: 11 }}
                      tickLine={false}
                      axisLine={false}
                      tickFormatter={(val) => `$${val}`}
                    />
                    <RechartsTooltip content={<CustomTooltip />} />
                    <Area 
                      type="monotone" 
                      dataKey="equity" 
                      stroke="#818cf8" 
                      strokeWidth={3}
                      fillOpacity={1} 
                      fill="url(#colorEquity)" 
                    />
                  </AreaChart>
                </ResponsiveContainer>
              )}
            </Box>
          </Paper>
        </Box>

        {/* Session Analytics */}
        <Box sx={{ flex: { xs: '1 1 100%', lg: '1 1 0%' }, minWidth: 0 }}>
          <Paper sx={{ p: 3, height: '100%' }}>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 3 }}>
              <AccessTime sx={{ color: '#f59e0b' }} />
              <Typography variant="h6" sx={{ fontWeight: 700 }}>Session Analytics</Typography>
            </Box>
            
            {sessionStats.length === 0 ? (
              <Box sx={{ py: 5, textAlign: 'center' }}>
                <Typography sx={{ color: 'text.disabled' }}>No session data yet.</Typography>
              </Box>
            ) : (
              <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                {sessionStats.map((sess) => {
                  const winRate = (sess.wins / sess.trades) * 100;
                  const isProfit = sess.profit >= 0;
                  return (
                    <Box key={sess.name} sx={{ 
                      p: 2, 
                      borderRadius: 2, 
                      border: '1px solid rgba(255,255,255,0.05)',
                      bgcolor: 'rgba(0,0,0,0.15)',
                      borderLeft: `4px solid ${sess.color}`
                    }}>
                      <Typography variant="subtitle2" sx={{ fontWeight: 800, mb: 1, color: sess.color }}>
                        {sess.name}
                      </Typography>
                      <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 0.5 }}>
                        <Typography variant="caption" sx={{ color: 'text.secondary' }}>Win Rate ({sess.wins}/{sess.trades})</Typography>
                        <Typography variant="caption" sx={{ fontWeight: 700, color: '#fff' }}>{winRate.toFixed(1)}%</Typography>
                      </Box>
                      <Box sx={{ display: 'flex', justifyContent: 'space-between' }}>
                        <Typography variant="caption" sx={{ color: 'text.secondary' }}>Net P/L</Typography>
                        <Typography variant="caption" sx={{ fontWeight: 800, color: isProfit ? '#10b981' : '#f43f5e' }}>
                          {isProfit ? '+' : ''}${fmt(sess.profit)}
                        </Typography>
                      </Box>
                    </Box>
                  );
                })}
              </Box>
            )}
          </Paper>
        </Box>
      </Box>
    </Box>
  );
}
