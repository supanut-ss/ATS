const mysql = require('mysql2/promise');

async function main() {
  const conn = await mysql.createConnection({
    host: '94.237.76.153',
    port: 3306,
    user: 'thaipes_sa',
    password: 'Soulmate@2108',
    database: 'thaipes_ats',
    connectTimeout: 15000,
  });

  // Actual status values in DB
  console.log('=== DISTINCT STATUS VALUES ===\n');
  const [statuses] = await conn.query(`SELECT DISTINCT status, COUNT(*) as cnt FROM signals GROUP BY status`);
  console.table(statuses);

  // Win/Loss with correct statuses
  console.log('\n=== WIN/LOSS SUMMARY (all time) ===\n');
  const [summary] = await conn.query(`
    SELECT 
      COUNT(*) as total_trades,
      SUM(CASE WHEN profit > 0 THEN 1 ELSE 0 END) as wins,
      SUM(CASE WHEN profit < 0 THEN 1 ELSE 0 END) as losses,
      SUM(CASE WHEN profit >= 0 AND profit <= 0.1 THEN 1 ELSE 0 END) as breakeven,
      ROUND(SUM(profit), 2) as total_profit,
      ROUND(AVG(CASE WHEN profit > 0 THEN profit END), 2) as avg_win,
      ROUND(AVG(CASE WHEN profit < 0 THEN profit END), 2) as avg_loss,
      ROUND(AVG(CASE WHEN profit > 0 THEN profit END) / ABS(AVG(CASE WHEN profit < 0 THEN profit END)), 2) as payoff_ratio
    FROM signals 
    WHERE status IN ('WIN', 'LOSS')
  `);
  console.table(summary);

  // Detail for last losing trade
  console.log('\n=== LAST LOSING TRADE DETAIL ===\n');
  const [lastLoss] = await conn.query(`
    SELECT * FROM signals WHERE profit < 0 ORDER BY updated_at DESC LIMIT 1
  `);
  console.log(JSON.stringify(lastLoss[0], null, 2));

  // SL distance analysis
  console.log('\n=== SL/TP DISTANCE ANALYSIS (Losses) ===\n');
  const [slAnalysis] = await conn.query(`
    SELECT 
      id, action, entry_price, sl, tp, exit_price, profit, status,
      ROUND(ABS(entry_price - sl), 2) as sl_distance,
      ROUND(ABS(tp - entry_price), 2) as tp_distance,
      ROUND(ABS(tp - entry_price) / NULLIF(ABS(entry_price - sl), 0), 2) as actual_rr,
      ROUND(ABS(exit_price - entry_price), 2) as price_move
    FROM signals
    WHERE status IN ('WIN','LOSS')
    ORDER BY updated_at DESC
    LIMIT 15
  `);
  console.table(slAnalysis);

  // Check if all losses hit SL exactly
  console.log('\n=== DID LOSSES HIT SL EXACTLY? ===\n');
  const [slHits] = await conn.query(`
    SELECT 
      id, action, entry_price, sl, exit_price, profit,
      CASE 
        WHEN ABS(exit_price - sl) < 0.5 THEN 'SL HIT'
        ELSE 'CLOSED BEFORE SL'
      END as exit_type,
      ROUND(ABS(exit_price - sl), 2) as distance_from_sl
    FROM signals
    WHERE profit < 0
    ORDER BY updated_at DESC
    LIMIT 10
  `);
  console.table(slHits);

  // Consecutive losses streak
  console.log('\n=== TRADE SEQUENCE (last 15) ===\n');
  const [sequence] = await conn.query(`
    SELECT id, timestamp, action, entry_price, exit_price, profit, status
    FROM signals
    WHERE status IN ('WIN','LOSS')
    ORDER BY updated_at DESC
    LIMIT 15
  `);
  console.table(sequence);

  await conn.end();
}

main().catch(err => { console.error(err); process.exit(1); });
