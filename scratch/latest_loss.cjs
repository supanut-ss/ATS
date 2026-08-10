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

  const [rows] = await conn.query(`
    SELECT * 
    FROM signals 
    WHERE status='LOSS'
    ORDER BY timestamp DESC 
    LIMIT 3
  `);
  console.log('=== LATEST 3 LOSING TRADES ===');
  console.log(JSON.stringify(rows, null, 2));

  await conn.end();
}

main().catch(console.error);
