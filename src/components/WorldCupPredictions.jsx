import React, { useState, useEffect } from 'react';
import {
  Box, Paper, Typography, Grid, Card, CardContent, Avatar,
  Table, TableBody, TableCell, TableContainer, TableHead, TableRow,
  Button, Tooltip, Chip, Select, MenuItem, FormControl,
  LinearProgress, Alert, Zoom, Fade
} from '@mui/material';
import {
  EmojiEvents, Sync, MilitaryTech,
  TrendingUp, BarChart, Info, SportsSoccer
} from '@mui/icons-material';

// ─── Constants & Data Definitions ─────────────────────────────────────

const TEAMS_INFO = {
  argentina: { nameTh: 'อาร์เจนตินา', nameEn: 'Argentina', flag: '🇦🇷', code: 'ar', color: '#74acdf' },
  brazil:    { nameTh: 'บราซิล',      nameEn: 'Brazil',    flag: '🇧🇷', code: 'br', color: '#fcd116' },
  france:    { nameTh: 'ฝรั่งเศส',     nameEn: 'France',    flag: '🇫🇷', code: 'fr', color: '#4176f2' },
  spain:     { nameTh: 'สเปน',        nameEn: 'Spain',     flag: '🇪🇸', code: 'es', color: '#ff2e2e' },
  england:   { nameTh: 'อังกฤษ',      nameEn: 'England',   flag: '🏴󠁧󠁢󠁥󠁮󠁧󠁿', code: 'gb-eng', color: '#ffffff' },
  germany:   { nameTh: 'เยอรมนี',     nameEn: 'Germany',   flag: '🇩🇪', code: 'de', color: '#ffcf00' },
  portugal:  { nameTh: 'โปรตุเกส',    nameEn: 'Portugal',  flag: '🇵🇹', code: 'pt', color: '#ff3b3b' },
  belgium:   { nameTh: 'เบลเยียม',     nameEn: 'Belgium',   flag: '🇧🇪', code: 'be', color: '#ffd900' },
  japan:     { nameTh: 'ญี่ปุ่น',       nameEn: 'Japan',     flag: '🇯🇵', code: 'jp', color: '#bc002d' },
  morocco:   { nameTh: 'โมร็อกโก',    nameEn: 'Morocco',   flag: '🇲🇦', code: 'ma', color: '#c1272d' }
};

const PREDICTORS = [
  { name: 'DEAW', key: 'deaw', teams: ['spain', 'france', 'argentina', 'england'] },
  { name: 'POOH', key: 'pooh', teams: ['germany', 'portugal', 'england', 'argentina'] },
  { name: 'CHAMP', key: 'champ', teams: ['france', 'belgium', 'japan', 'argentina'] },
  { name: 'ZAY', key: 'zay', teams: ['brazil', 'argentina', 'spain', 'france'] },
  { name: 'BANK', key: 'bank', teams: ['argentina', 'england', 'morocco', 'spain'] },
  { name: 'AOT', key: 'aot', teams: ['belgium', 'brazil', 'argentina', 'england'] },
  { name: 'SAM', key: 'sam', teams: ['france', 'brazil', 'argentina', 'portugal'] }
];

const ROUNDS = [
  { value: 0, label: 'Group Stage', short: 'GS', points: 0, gradient: 'linear-gradient(135deg, #475569 0%, #334155 100%)', shadow: 'none' },
  { value: 1, label: 'Round of 32', short: 'R32', points: 0, gradient: 'linear-gradient(135deg, #64748b 0%, #475569 100%)', shadow: 'none' },
  { value: 2, label: 'Round of 16', short: 'R16', points: 1, gradient: 'linear-gradient(135deg, #10b981 0%, #059669 100%)', shadow: '0 2px 10px rgba(16,185,129,0.2)' },
  { value: 3, label: 'Quarter-finals', short: 'QF', points: 2, gradient: 'linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%)', shadow: '0 2px 10px rgba(59,130,246,0.2)' },
  { value: 4, label: 'Semi-finals', short: 'SF', points: 3, gradient: 'linear-gradient(135deg, #8b5cf6 0%, #6d28d9 100%)', shadow: '0 2px 10px rgba(139,92,246,0.2)' },
  { value: 5, label: 'Finals (Finalist)', short: 'F', points: 4, gradient: 'linear-gradient(135deg, #ec4899 0%, #be185d 100%)', shadow: '0 2px 10px rgba(236,72,153,0.2)' },
  { value: 6, label: 'Champion 🏆', short: 'CHAMP', points: 5, gradient: 'linear-gradient(135deg, #f59e0b 0%, #d97706 100%)', shadow: '0 4px 15px rgba(245,158,11,0.4)' }
];

// Initial state for World Cup 2026 teams round progression (as of early July 2026)
const INITIAL_TEAM_STATUS = {
  argentina: 1, // Round of 32 (0 pts)
  brazil:    2, // Round of 16 (1 pt)
  france:    2, // Round of 16 (1 pt)
  spain:     1, // Round of 32 (0 pts)
  england:   2, // Round of 16 (1 pt)
  germany:   1, // Round of 32 (eliminated or ongoing)
  portugal:  1, // Round of 32 (0 pts)
  belgium:   2, // Round of 16 (1 pt)
  japan:     1, // Round of 32 (0 pts)
  morocco:   2  // Round of 16 (1 pt)
};

export default function WorldCupPredictions() {
  const [teamStatus, setTeamStatus] = useState(() => {
    const saved = localStorage.getItem('wc2026_team_status');
    return saved ? JSON.parse(saved) : INITIAL_TEAM_STATUS;
  });
  
  const [syncing, setSyncing] = useState(false);
  const [syncMessage, setSyncMessage] = useState(null);

  useEffect(() => {
    localStorage.setItem('wc2026_team_status', JSON.stringify(teamStatus));
  }, [teamStatus]);

  // Calculate scores
  const getTeamPoints = (teamKey) => {
    const roundVal = teamStatus[teamKey] || 0;
    const roundInfo = ROUNDS.find(r => r.value === roundVal);
    return roundInfo ? roundInfo.points : 0;
  };

  const getTeamRoundLabel = (teamKey) => {
    const roundVal = teamStatus[teamKey] || 0;
    return ROUNDS.find(r => r.value === roundVal);
  };

  const calculatePredictorScore = (predictor) => {
    return predictor.teams.reduce((sum, team) => sum + getTeamPoints(team), 0);
  };

  // Sort predictors by score (descending)
  const rankedPredictors = PREDICTORS.map(p => ({
    ...p,
    score: calculatePredictorScore(p)
  })).sort((a, b) => b.score - a.score);

  // Statistics calculation
  const totalPredictors = PREDICTORS.length;
  const highestScore = Math.max(...rankedPredictors.map(p => p.score));
  const lowestScore = Math.min(...rankedPredictors.map(p => p.score));
  const avgScore = (rankedPredictors.reduce((sum, p) => sum + p.score, 0) / totalPredictors).toFixed(1);

  // Count team selections
  const teamPickCounts = {};
  PREDICTORS.forEach(p => {
    p.teams.forEach(t => {
      teamPickCounts[t] = (teamPickCounts[t] || 0) + 1;
    });
  });

  const sortedTeamPicks = Object.keys(teamPickCounts).map(t => ({
    key: t,
    count: teamPickCounts[t],
    info: TEAMS_INFO[t]
  })).sort((a, b) => b.count - a.count);

  // Handle status update
  const handleStatusChange = (teamKey, newRound) => {
    setTeamStatus(prev => ({
      ...prev,
      [teamKey]: newRound
    }));
  };

  // Helper to parse live match results from worldcup26.ir API
  const parseLiveGames = (gamesList) => {
    const status = {
      argentina: 1,
      brazil: 1,
      france: 1,
      spain: 1,
      england: 1,
      germany: 1,
      portugal: 1,
      belgium: 1,
      japan: 1,
      morocco: 1
    };

    const teamNameToKey = (name) => {
      if (!name) return null;
      const lower = name.toLowerCase().trim();
      if (lower === 'argentina') return 'argentina';
      if (lower === 'brazil') return 'brazil';
      if (lower === 'france') return 'france';
      if (lower === 'spain') return 'spain';
      if (lower === 'england') return 'england';
      if (lower === 'germany') return 'germany';
      if (lower === 'portugal') return 'portugal';
      if (lower === 'belgium') return 'belgium';
      if (lower === 'japan') return 'japan';
      if (lower === 'morocco') return 'morocco';
      return null;
    };

    const gameTypeToRound = (type) => {
      if (!type) return 0;
      const t = type.toLowerCase().trim();
      if (t === 'group') return 0;
      if (t === 'r32') return 1;
      if (t === 'r16') return 2;
      if (t === 'qf') return 3;
      if (t === 'sf') return 4;
      if (t === 'final') return 5;
      return 0;
    };

    gamesList.forEach(game => {
      const type = game.type;
      const roundVal = gameTypeToRound(type);
      
      const homeKey = teamNameToKey(game.home_team_name_en);
      const awayKey = teamNameToKey(game.away_team_name_en);

      if (homeKey) status[homeKey] = Math.max(status[homeKey], roundVal);
      if (awayKey) status[awayKey] = Math.max(status[awayKey], roundVal);

      if (game.finished === 'TRUE' && roundVal > 0) {
        const homeScore = parseInt(game.home_score) || 0;
        const awayScore = parseInt(game.away_score) || 0;
        let homeWon = false;
        let awayWon = false;

        if (homeScore > awayScore) {
          homeWon = true;
        } else if (awayScore > homeScore) {
          awayWon = true;
        } else {
          const homePen = parseInt(game.home_penalty_score) || 0;
          const awayPen = parseInt(game.away_penalty_score) || 0;
          if (homePen > awayPen) homeWon = true;
          else if (awayPen > homePen) awayWon = true;
        }

        if (homeKey && homeWon) status[homeKey] = Math.max(status[homeKey], roundVal + 1);
        if (awayKey && awayWon) status[awayKey] = Math.max(status[awayKey], roundVal + 1);
      }
    });

    return status;
  };

  // Fetch team round progression data from live API with local fallback
  const handleSyncData = async () => {
    setSyncing(true);
    setSyncMessage(null);
    try {
      // 1. Attempt to fetch from the live World Cup REST API
      const liveRes = await fetch('https://worldcup26.ir/get/games');
      if (!liveRes.ok) throw new Error('Live API server responded with an error');
      
      const liveData = await liveRes.json();
      if (!liveData.games || !Array.isArray(liveData.games)) {
        throw new Error('Invalid API response format');
      }

      const parsedStatus = parseLiveGames(liveData.games);
      setTeamStatus(parsedStatus);
      setSyncMessage({
        type: 'success',
        text: 'Live Match Center sync completed successfully! Real-time bracket data loaded.'
      });
    } catch (e) {
      console.warn('Live API fetch failed, falling back to local JSON: ', e.message);
      // 2. Fallback to local server backup json file
      try {
        const backupRes = await fetch('/worldcup_status.json');
        if (!backupRes.ok) throw new Error('Failed to load backup data.');
        const backupData = await backupRes.json();
        setTeamStatus(backupData);
        setSyncMessage({
          type: 'info',
          text: 'Synced from backup database. (Live API was unavailable/blocked)'
        });
      } catch (backupErr) {
        setSyncMessage({
          type: 'error',
          text: 'Sync failed: ' + backupErr.message
        });
      }
    } finally {
      setSyncing(false);
    }
  };

  const resetToDefault = () => {
    if (window.confirm('Reset all team stages back to the default values?')) {
      setTeamStatus(INITIAL_TEAM_STATUS);
      setSyncMessage(null);
    }
  };

  return (
    <Fade in={true} timeout={600}>
      <Box sx={{ display: 'flex', flexDirection: 'column', gap: 3, pb: 6 }}>
        
        {/* ── Header Banner ── */}
        <Box sx={{
          position: 'relative',
          p: 4, borderRadius: 4,
          overflow: 'hidden',
          background: 'linear-gradient(135deg, rgba(30, 27, 75, 0.6) 0%, rgba(15, 23, 42, 0.8) 100%)',
          border: '1px solid rgba(99, 102, 241, 0.15)',
          boxShadow: '0 8px 32px 0 rgba(0, 0, 0, 0.37)',
          backdropFilter: 'blur(8px)',
          display: 'flex', flexWrap: 'wrap', justifyContent: 'space-between', alignItems: 'center', gap: 3
        }}>
          {/* Subtle glowing orb inside the header */}
          <Box sx={{
            position: 'absolute', top: '-40%', left: '-10%',
            width: '350px', height: '350px',
            borderRadius: '50%',
            background: 'radial-gradient(circle, rgba(99, 102, 241, 0.15) 0%, rgba(99, 102, 241, 0) 70%)',
            pointerEvents: 'none',
            zIndex: 0
          }} />

          <Box sx={{ display: 'flex', alignItems: 'center', gap: 2.5, zIndex: 1 }}>
            <Avatar sx={{
              bgcolor: 'rgba(245, 158, 11, 0.08)',
              border: '1px solid rgba(245, 158, 11, 0.25)',
              width: 56, height: 56,
              boxShadow: '0 0 20px rgba(245, 158, 11, 0.15)',
            }}>
              <EmojiEvents sx={{ color: '#fbbf24', fontSize: 32, filter: 'drop-shadow(0 0 8px rgba(251,191,36,0.5))' }} />
            </Avatar>
            <Box>
              <Typography variant="h5" sx={{ fontWeight: 900, letterSpacing: -0.5, mb: 0.5, background: 'linear-gradient(90deg, #ffffff 0%, #cbd5e1 100%)', WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent' }}>
                FIFA World Cup 2026 Predictions
              </Typography>
              <Typography variant="body2" sx={{ color: 'text.secondary', fontWeight: 500, fontSize: '0.8rem', opacity: 0.85 }}>
                Friendship league tracker. Points: R16 (+1 pt) · QF (+2 pts) · SF (+3 pts) · Finals (+4 pts) · Champion (+5 pts). R32/GS (0 pts).
              </Typography>
            </Box>
          </Box>
          <Box sx={{ display: 'flex', gap: 1.5, zIndex: 1 }}>
            <Button
              variant="contained" size="medium" startIcon={<Sync />}
              onClick={handleSyncData} disabled={syncing}
              sx={{
                background: 'linear-gradient(135deg, #4f46e5 0%, #6366f1 100%)',
                boxShadow: '0 4px 14px rgba(79, 70, 229, 0.4)',
                '&:hover': {
                  background: 'linear-gradient(135deg, #4338ca 0%, #4f46e5 100%)',
                  boxShadow: '0 6px 20px rgba(79, 70, 229, 0.5)',
                }
              }}
            >
              {syncing ? 'Syncing...' : 'Sync Live Data'}
            </Button>
            <Button
              variant="outlined" size="medium" onClick={resetToDefault}
              sx={{
                borderColor: 'rgba(255,255,255,0.08)',
                color: 'text.secondary',
                '&:hover': {
                  borderColor: 'rgba(255,255,255,0.2)',
                  color: 'text.primary',
                  bgcolor: 'rgba(255,255,255,0.02)'
                }
              }}
            >
              Reset
            </Button>
          </Box>
        </Box>

        {syncMessage && (
          <Zoom in={!!syncMessage}>
            <Alert
              severity={syncMessage.type}
              onClose={() => setSyncMessage(null)}
              sx={{
                bgcolor: syncMessage.type === 'success' ? 'rgba(16,185,129,0.06)' : 'rgba(244,63,94,0.06)',
                border: `1px solid ${syncMessage.type === 'success' ? 'rgba(16,185,129,0.2)' : 'rgba(244,63,94,0.2)'}`,
                color: syncMessage.type === 'success' ? '#10b981' : '#f43f5e',
                borderRadius: 2.5
              }}
            >
              {syncMessage.text}
            </Alert>
          </Zoom>
        )}

        {/* ── Quick Stats Panel ── */}
        <Grid container spacing={2}>
          {[
            { title: 'Total Predictors', value: `${totalPredictors} Players`, icon: <SportsSoccer />, color: '#818cf8', bg: 'rgba(99,102,241,0.04)', border: 'rgba(99,102,241,0.1)' },
            { title: 'Leader Score', value: `${highestScore} pts`, icon: <TrendingUp />, color: '#10b981', bg: 'rgba(16,185,129,0.04)', border: 'rgba(16,185,129,0.1)' },
            { title: 'Lowest Score', value: `${lowestScore} pts`, icon: <MilitaryTech />, color: '#f43f5e', bg: 'rgba(244,63,94,0.04)', border: 'rgba(244,63,94,0.1)' },
            { title: 'Average Score', value: `${avgScore} pts`, icon: <BarChart />, color: '#fbbf24', bg: 'rgba(251,191,36,0.04)', border: 'rgba(251,191,36,0.1)' }
          ].map((stat, idx) => (
            <Grid item xs={12} sm={6} md={3} key={idx}>
              <Card sx={{
                bgcolor: 'rgba(30, 41, 59, 0.2)',
                border: `1px solid ${stat.border}`,
                borderRadius: 3.5,
                backdropFilter: 'blur(10px)',
                position: 'relative',
                overflow: 'hidden',
                transition: 'all 0.3s ease',
                '&:hover': {
                  transform: 'translateY(-2px)',
                  boxShadow: `0 8px 24px -4px ${stat.border}`,
                  borderColor: stat.color
                }
              }}>
                <CardContent sx={{ display: 'flex', alignItems: 'center', p: '20px !important' }}>
                  <Avatar sx={{
                    bgcolor: stat.bg,
                    color: stat.color,
                    border: `1px solid ${stat.border}`,
                    mr: 2, width: 46, height: 46,
                  }}>
                    {stat.icon}
                  </Avatar>
                  <Box>
                    <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600, textTransform: 'uppercase', letterSpacing: 0.8, fontSize: '0.62rem' }}>
                      {stat.title}
                    </Typography>
                    <Typography variant="h5" sx={{ fontWeight: 900, mt: 0.2, color: '#f3f4f6' }}>
                      {stat.value}
                    </Typography>
                  </Box>
                </CardContent>
              </Card>
            </Grid>
          ))}
        </Grid>

        {/* ── Main Viewports ── */}
        <Grid container spacing={3}>
          
          {/* LEFT: Standings Leaderboard */}
          <Grid item xs={12} lg={7.5}>
            <Paper sx={{
              p: 3,
              borderRadius: 4,
              bgcolor: 'rgba(17, 24, 39, 0.4)',
              border: '1px solid rgba(255,255,255,0.05)',
              backdropFilter: 'blur(10px)',
              boxShadow: '0 4px 30px rgba(0,0,0,0.2)',
              display: 'flex', flexDirection: 'column', height: '100%'
            }}>
              <Typography variant="subtitle1" sx={{ fontWeight: 800, mb: 2.5, display: 'flex', alignItems: 'center', gap: 1.2, letterSpacing: -0.2 }}>
                <EmojiEvents sx={{ color: '#fbbf24', fontSize: 24, filter: 'drop-shadow(0 0 6px rgba(251,191,36,0.3))' }} /> 
                Leaderboard Standings
              </Typography>
              
              <TableContainer sx={{ borderRadius: 3, overflow: 'hidden', border: '1px solid rgba(255,255,255,0.03)' }}>
                <Table size="medium">
                  <TableHead sx={{ bgcolor: 'rgba(255,255,255,0.015)' }}>
                    <TableRow>
                      <TableCell align="center" sx={{ width: 70, fontWeight: 800, fontSize: '0.72rem', color: 'text.secondary', borderBottom: '1px solid rgba(255,255,255,0.04)' }}>RANK</TableCell>
                      <TableCell sx={{ fontWeight: 800, fontSize: '0.72rem', color: 'text.secondary', borderBottom: '1px solid rgba(255,255,255,0.04)' }}>PREDICTOR</TableCell>
                      <TableCell sx={{ fontWeight: 800, fontSize: '0.72rem', color: 'text.secondary', borderBottom: '1px solid rgba(255,255,255,0.04)' }}>SELECTED TEAMS</TableCell>
                      <TableCell align="right" sx={{ fontWeight: 800, pr: 3, fontSize: '0.72rem', color: 'text.secondary', borderBottom: '1px solid rgba(255,255,255,0.04)' }}>POINTS</TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {rankedPredictors.map((predictor, index) => {
                      const isTop = index === 0;
                      const isSecond = index === 1;
                      const isThird = index === 2;
                      
                      let rankBg = 'rgba(255,255,255,0.02)';
                      let rankColor = '#94a3b8';
                      let rankBorder = 'rgba(255,255,255,0.05)';
                      let rowBg = 'transparent';

                      if (isTop) { 
                        rankBg = 'linear-gradient(135deg, #fbbf24 0%, #f59e0b 100%)'; 
                        rankColor = '#1e1b4b';
                        rankBorder = '#fbbf24';
                        rowBg = 'rgba(251,191,36,0.02)';
                      } else if (isSecond) { 
                        rankBg = 'linear-gradient(135deg, #e2e8f0 0%, #cbd5e1 100%)'; 
                        rankColor = '#0f172a';
                        rankBorder = '#cbd5e1';
                        rowBg = 'rgba(255,255,255,0.01)';
                      } else if (isThird) { 
                        rankBg = 'linear-gradient(135deg, #ffedd5 0%, #d97706 100%)'; 
                        rankColor = '#1e1b4b';
                        rankBorder = '#d97706';
                        rowBg = 'rgba(217,119,6,0.01)';
                      }

                      return (
                        <TableRow 
                          key={predictor.key} 
                          sx={{ 
                            bgcolor: rowBg,
                            transition: 'all 0.2s ease',
                            '&:hover': { bgcolor: 'rgba(255,255,255,0.03)' },
                            '& td': { borderBottom: '1px solid rgba(255,255,255,0.02)' }
                          }}
                        >
                          {/* Rank Circle */}
                          <TableCell align="center">
                            <Avatar sx={{
                              width: 26, height: 26, fontSize: '0.78rem', fontWeight: 900,
                              background: rankBg, color: rankColor, 
                              border: `1.5px solid ${rankBorder}`,
                              boxShadow: isTop ? '0 0 10px rgba(251,191,36,0.3)' : 'none',
                              mx: 'auto'
                            }}>
                              {index + 1}
                            </Avatar>
                          </TableCell>

                          {/* Predictor Name */}
                          <TableCell sx={{ fontWeight: 800, color: isTop ? '#fbbf24' : '#f3f4f6', fontSize: '0.85rem' }}>
                            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                              {predictor.name}
                              {isTop && <span>👑</span>}
                            </Box>
                          </TableCell>

                          {/* Predictions Badges */}
                          <TableCell>
                            <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 0.8, py: 1 }}>
                              {predictor.teams.map(teamKey => {
                                const t = TEAMS_INFO[teamKey];
                                const r = getTeamRoundLabel(teamKey);
                                
                                return (
                                  <Tooltip
                                    key={teamKey}
                                    title={`${t.nameEn} · ${r.label} (+${r.points} pts)`}
                                    arrow
                                    TransitionComponent={Zoom}
                                  >
                                    <Chip
                                      avatar={
                                        <Avatar 
                                          src={`https://flagcdn.com/w40/${t.code}.png`} 
                                          variant="rounded" 
                                          sx={{ width: 18, height: 13, borderRadius: '2px', border: '1px solid rgba(255,255,255,0.1)' }} 
                                        />
                                      }
                                      label={`${t.nameEn} ${r.points > 0 ? `+${r.points}` : ''}`}
                                      size="small"
                                      sx={{
                                        background: r.points > 0 ? r.gradient : 'rgba(30, 41, 59, 0.25)',
                                        color: r.points > 0 ? '#ffffff' : '#94a3b8',
                                        border: `1px solid ${r.points > 0 ? 'transparent' : 'rgba(255,255,255,0.05)'}`,
                                        boxShadow: r.shadow,
                                        fontSize: '0.68rem',
                                        fontWeight: r.points > 0 ? 800 : 500,
                                        height: 24,
                                        transition: 'all 0.2s ease',
                                        '&:hover': { 
                                          transform: 'scale(1.03)',
                                          opacity: 0.95
                                        }
                                      }}
                                    />
                                  </Tooltip>
                                );
                              })}
                            </Box>
                          </TableCell>

                          {/* Total Score */}
                          <TableCell align="right" sx={{ pr: 3, fontWeight: 900, fontSize: '1.15rem', color: isTop ? '#fbbf24' : '#ffffff' }}>
                            {predictor.score} <Typography component="span" sx={{ fontSize: '0.68rem', fontWeight: 600, color: 'text.secondary' }}>pts</Typography>
                          </TableCell>
                        </TableRow>
                      );
                    })}
                  </TableBody>
                </Table>
              </TableContainer>

              {/* Selection Trends */}
              <Typography variant="subtitle2" sx={{ fontWeight: 800, mt: 4, mb: 1.8, display: 'flex', alignItems: 'center', gap: 0.8, fontSize: '0.85rem' }}>
                <BarChart sx={{ color: '#fbbf24', fontSize: 18 }} />
                Selection Trend Analysis
              </Typography>
              <Box sx={{ border: '1px solid rgba(255,255,255,0.03)', borderRadius: 3.5, p: 2.5, bgcolor: 'rgba(255,255,255,0.005)' }}>
                <Grid container spacing={2.5}>
                  {sortedTeamPicks.slice(0, 5).map(pick => {
                    const percent = (pick.count / totalPredictors) * 100;
                    return (
                      <Grid item xs={12} key={pick.key}>
                        <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 0.6 }}>
                          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                            <Box 
                              component="img" 
                              src={`https://flagcdn.com/w40/${pick.info.code}.png`} 
                              alt={pick.info.nameEn} 
                              sx={{ width: 22, height: 15, borderRadius: '2px', border: '1px solid rgba(255,255,255,0.1)', objectFit: 'cover' }} 
                            />
                            <Typography sx={{ fontSize: '0.78rem', fontWeight: 800, color: '#f3f4f6' }}>{pick.info.nameEn}</Typography>
                          </Box>
                          <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 700, fontSize: '0.65rem' }}>
                            Picked by {pick.count} players ({percent.toFixed(0)}%)
                          </Typography>
                        </Box>
                        <LinearProgress
                          variant="determinate"
                          value={percent}
                          sx={{
                            height: 6,
                            borderRadius: 3,
                            bgcolor: 'rgba(255,255,255,0.02)',
                            border: '1px solid rgba(255,255,255,0.02)',
                            '& .MuiLinearProgress-bar': {
                              borderRadius: 3,
                              background: `linear-gradient(90deg, ${pick.info.color || '#6366f1'} 0%, #818cf8 100%)`,
                              boxShadow: `0 0 8px ${pick.info.color || '#6366f1'}80`
                            }
                          }}
                        />
                      </Grid>
                    );
                  })}
                </Grid>
              </Box>
            </Paper>
          </Grid>

          {/* RIGHT: Match Center & Simulation */}
          <Grid item xs={12} lg={4.5}>
            <Paper sx={{
              p: 3,
              borderRadius: 4,
              bgcolor: 'rgba(17, 24, 39, 0.4)',
              border: '1px solid rgba(255,255,255,0.05)',
              backdropFilter: 'blur(10px)',
              boxShadow: '0 4px 30px rgba(0,0,0,0.2)',
              display: 'flex', flexDirection: 'column'
            }}>
              <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2.5 }}>
                <Typography variant="subtitle1" sx={{ fontWeight: 800, display: 'flex', alignItems: 'center', gap: 1, letterSpacing: -0.1 }}>
                  <Info sx={{ color: '#10b981', fontSize: 20 }} /> Team Progression Settings (Simulator)
                </Typography>
                <Chip
                  label="LIVE SIMULATOR"
                  size="small"
                  sx={{
                    height: 18, fontSize: '0.55rem', fontWeight: 900,
                    bgcolor: 'rgba(99,102,241,0.1)', color: '#818cf8',
                    border: '1px solid rgba(99,102,241,0.25)',
                    letterSpacing: 0.5
                  }}
                />
              </Box>
              
              <Alert 
                severity="info" 
                icon={<Info sx={{ color: '#818cf8' }} />}
                sx={{
                  py: 0.4, px: 2, mb: 3, fontSize: '0.72rem',
                  border: '1px solid rgba(99,102,241,0.15)', 
                  bgcolor: 'rgba(99,102,241,0.03)',
                  color: '#cbd5e1',
                  borderRadius: 2.5
                }}
              >
                Simulate match progress below. The standings will shift live and persist locally.
              </Alert>

              <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1.5 }}>
                {Object.keys(TEAMS_INFO).map(teamKey => {
                  const team = TEAMS_INFO[teamKey];
                  const currentRound = teamStatus[teamKey] || 0;
                  const roundDetails = ROUNDS.find(r => r.value === currentRound);
                  
                  return (
                    <Box
                      key={teamKey}
                      sx={{
                        display: 'flex', alignItems: 'center',
                        p: 1.5, borderRadius: 3,
                        bgcolor: 'rgba(30, 41, 59, 0.15)',
                        border: '1px solid rgba(255,255,255,0.02)',
                        transition: 'all 0.2s ease',
                        '&:hover': { 
                          bgcolor: 'rgba(30, 41, 59, 0.25)', 
                          borderColor: 'rgba(99, 102, 241, 0.1)',
                          transform: 'translateX(2px)'
                        }
                      }}
                    >
                      {/* Team Flag & Name */}
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.8, flexGrow: 1, minWidth: 0 }}>
                        <Box 
                          component="img" 
                          src={`https://flagcdn.com/w80/${team.code}.png`} 
                          alt={team.nameEn} 
                          sx={{ 
                            width: 38, height: 26, 
                            borderRadius: '3px', 
                            border: '1px solid rgba(255,255,255,0.1)',
                            filter: 'drop-shadow(0 2px 4px rgba(0,0,0,0.3))',
                            transition: 'transform 0.2s ease',
                            '&:hover': { transform: 'scale(1.15)' }
                          }} 
                        />
                        <Box sx={{ minWidth: 0 }}>
                          <Typography sx={{ fontSize: '0.85rem', fontWeight: 800, color: '#f3f4f6' }}>
                            {team.nameEn}
                          </Typography>
                          <Typography sx={{ fontSize: '0.62rem', color: 'text.secondary', fontWeight: 500 }}>
                            {team.nameTh}
                          </Typography>
                        </Box>
                      </Box>

                      {/* Selector Widget */}
                      <FormControl size="small" sx={{ width: 160, flexShrink: 0 }}>
                        <Select
                          value={currentRound}
                          onChange={(e) => handleStatusChange(teamKey, Number(e.target.value))}
                          sx={{
                            fontSize: '0.7rem',
                            fontWeight: 800,
                            borderRadius: 2.5,
                            bgcolor: 'rgba(15, 23, 42, 0.4)',
                            '& .MuiOutlinedInput-notchedOutline': {
                              borderColor: 'rgba(255,255,255,0.06)'
                            },
                            '&:hover .MuiOutlinedInput-notchedOutline': {
                              borderColor: 'rgba(255,255,255,0.15)'
                            },
                            '&.Mui-focused .MuiOutlinedInput-notchedOutline': {
                              borderColor: '#6366f1'
                            }
                          }}
                        >
                          {ROUNDS.map(r => (
                            <MenuItem
                              key={r.value}
                              value={r.value}
                              sx={{ 
                                fontSize: '0.72rem', 
                                fontWeight: 700, 
                                py: 1,
                                '&.Mui-selected': { bgcolor: 'rgba(99,102,241,0.15)' }
                              }}
                            >
                              <Box sx={{ display: 'flex', alignItems: 'center', width: '100%' }}>
                                <span>{r.label}</span>
                                {r.points > 0 && (
                                  <Chip
                                    label={`+${r.points} pts`}
                                    size="small"
                                    sx={{
                                      ml: 'auto',
                                      height: 16,
                                      fontSize: '0.58rem',
                                      fontWeight: 800,
                                      background: r.gradient,
                                      color: '#ffffff',
                                      boxShadow: r.shadow
                                    }}
                                  />
                                )}
                              </Box>
                            </MenuItem>
                          ))}
                        </Select>
                      </FormControl>
                    </Box>
                  );
                })}
              </Box>
            </Paper>
          </Grid>

        </Grid>
      </Box>
    </Fade>
  );
}
