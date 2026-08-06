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

  // DISTINCT STATUS VALUES  
  const [statuses] = await conn.query(`SELECT DISTINCT status, COUNT(*) as cnt FROM signals GROUP BY status`);
  console.log('=== STATUS VALUES ===');
  console.table(statuses);

  // Win rate
  const [winrate] = await conn.query(`
    SELECT 
      COUNT(*) as total,
      SUM(CASE WHEN status = 'WIN' THEN 1 ELSE 0 END) as wins,
      SUM(CASE WHEN status = 'LOSS' THEN 1 ELSE 0 END) as losses,
      ROUND(SUM(CASE WHEN status = 'WIN' THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) as win_rate_pct,
      ROUND(SUM(profit), 2) as total_pnl,
      ROUND(AVG(CASE WHEN profit > 0 THEN profit END), 2) as avg_win_usd,
      ROUND(AVG(CASE WHEN profit < 0 THEN profit END), 2) as avg_loss_usd
    FROM signals
    WHERE status IN ('WIN', 'LOSS')
  `);
  console.log('\n=== WIN RATE ===');
  console.table(winrate);

  // BUY vs SELL performance
  const [byAction] = await conn.query(`
    SELECT 
      action,
      COUNT(*) as total,
      SUM(CASE WHEN status = 'WIN' THEN 1 ELSE 0 END) as wins,
      SUM(CASE WHEN status = 'LOSS' THEN 1 ELSE 0 END) as losses,
      ROUND(SUM(profit), 2) as total_pnl
    FROM signals
    WHERE status IN ('WIN', 'LOSS')
    GROUP BY action
  `);
  console.log('\n=== BY ACTION (BUY vs SELL) ===');
  console.table(byAction);

  // Check for currently open positions
  const [open] = await conn.query(`
    SELECT * FROM signals WHERE status NOT IN ('WIN','LOSS') ORDER BY timestamp DESC LIMIT 5
  `);
  console.log('\n=== CURRENTLY OPEN / PENDING ===');
  console.table(open);

  await conn.end();
}

main().catch(err => { console.error(err); process.exit(1); });
