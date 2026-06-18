# XAUUSD Trading Bot — Exness · MT5 + TradingView Essential

ระบบ Semi-Automated Trading สำหรับทองคำ (XAUUSD) ที่รับสัญญาณจาก TradingView (Liquidity Sweep Strategy) และส่ง Order เข้า MT5 ผ่าน Python backend พร้อม Full Control Dashboard ด้วย React + MUI

---

## Architecture

```
TradingView Alert (Pine Script)
    │ HTTP POST Webhook JSON
    ▼
Python Flask Server (server/app.py)
    │ parse signal → risk check → execute
    ▼
MetaTrader5 Python API → Exness Demo MT5
    │
    ▼
React Dashboard (npm run dev)
```

---

## Prerequisites

- **MetaTrader 5** ติดตั้งจาก Exness และ Login Demo Account
- **Python 3.9+**
- **Node.js 18+**
- **TradingView Essential Plan** (สำหรับ Webhook Alert)
- (Optional) **ngrok** สำหรับ Public URL บนเครื่องตัวเอง

---

## Quick Start

### 1. ตั้งค่า Python Backend

```bash
cd server
pip install -r requirements.txt

# Copy และแก้ไข .env
copy .env.example .env
```

แก้ไข `.env`:
```
MT5_LOGIN=ใส่เลข Account MT5 ของคุณ
MT5_PASSWORD=ใส่รหัสผ่าน MT5
MT5_SERVER=Exness-MT5Trial       # สำหรับ Demo
WEBHOOK_SECRET=ตั้ง token ที่คุณต้องการ (ห้ามเป็น default)
FIXED_LOT=0.05
```

### 2. เปิด MT5 Terminal

1. เปิดโปรแกรม MetaTrader 5
2. Login เข้า Exness Demo Account
3. เปิด **AutoTrading** (ปุ่ม Auto Trading บน Toolbar สีเขียว)

### 3. รัน Python Server

```bash
cd server
python app.py
```

เซิร์ฟเวอร์จะขึ้นที่ `http://localhost:5000`

### 4. รัน React Dashboard

```bash
# กลับไปที่โฟลเดอร์หลัก
npm install
npm run dev
```

เปิด browser ที่ `http://localhost:5173`

### 5. ตั้งค่า TradingView Pine Script

1. เปิด TradingView → Chart XAUUSD
2. เปิด **Pine Editor** (Tab ด้านล่าง)
3. วาง code จาก `tradingview/xauusd_liquidity_sweep.pine`
4. กด **Add to chart**
5. ไปที่ Script Settings → ใส่ **Webhook Token** ให้ตรงกับ `.env`

### 6. สร้าง Alert ใน TradingView

1. คลิก **Alert (⏰)** icon
2. Condition: เลือก **LS+Vol Bot** → **alert() function calls**
3. Tab **Notifications** → ติ๊ก **Webhook URL**
4. ใส่ URL: `https://your-ngrok-url.ngrok-free.app/webhook`
5. **Message field**: ปล่อยว่างหรือ `{{strategy.order.alert_message}}` (Script กำหนดเองแล้ว)
6. กด **Create**

---

## API Reference

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/webhook` | รับ Signal จาก TradingView |
| GET | `/api/status` | สถานะ Server + MT5 |
| GET | `/api/account` | ข้อมูล Account Balance/Equity |
| GET | `/api/price` | Live XAUUSD Bid/Ask |
| GET | `/api/positions` | Open Positions |
| GET | `/api/history` | Closed Trade History |
| GET | `/api/risk` | Risk Manager Status |
| POST | `/api/trade` | Manual Trade `{"action":"BUY","sl":2310,"tp":2340}` |
| POST | `/api/close/<ticket>` | Close Position by Ticket |
| POST | `/api/close-all` | Close All Positions |
| POST | `/api/modify/<ticket>` | Modify SL/TP |
| POST | `/api/connect` | Connect MT5 |
| POST | `/api/disconnect` | Disconnect MT5 |

---

## Webhook Payload Format

```json
{
  "token":   "your_secret_token",
  "action":  "BUY",
  "symbol":  "XAUUSD",
  "sl":      2310.50,
  "tp":      2340.00,
  "comment": "Sweep+MSS+Vol BUY"
}
```

Actions: `BUY` | `SELL` | `CLOSE` | `CLOSE_ALL` | `MODIFY`

---

## Strategy: Liquidity Sweep & Volume Confirmation

ดูไฟล์ `tradingview/xauusd_liquidity_sweep.pine` สำหรับ Pine Script เต็ม

**Logic:**
1. **Mark EQH/EQL** — หาจุด Equal Highs/Equal Lows เป็น Liquidity Pool
2. **Wait for Sweep** — รอราคา Sweep ทะลุ EQH/EQL แล้วปิดกลับด้านใน
3. **MSS Detection** — หลัง Sweep ต้องมี Market Structure Shift (BreakOC)
4. **Volume Spike** — Candle ที่ Break โครงสร้างต้องมี Volume > เฉลี่ย × 1.5
5. **Entry at FVG/OB** — เข้า Order ที่จุด confluence
6. **SL** — วางไว้เหนือ/ใต้จุด Sweep + Buffer 2 USD
7. **TP** — R:R 2:1 (กำหนดได้ใน Script Settings)

---

## Risk Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `FIXED_LOT` | 0.05 | Fixed lot size ทุก Trade |
| `MAX_POSITIONS` | 3 | จำนวน Position สูงสุด |
| `MAX_DAILY_LOSS_USD` | $100 | หยุด Trade เมื่อขาดทุนถึงลิมิต |

---

## ⚠️ คำเตือน

> **ทดสอบกับ Demo Account ก่อนเสมอ** ก่อนใช้กับ Live Account จริง
> ระบบนี้เป็นเครื่องมือช่วยเทรด ไม่ใช่การรับประกันกำไร ตลาดทองมีความผันผวนสูง

---

## File Structure

```
ATS/
├── src/
│   ├── components/
│   │   ├── AccountCard.jsx      # Account balance card
│   │   ├── PriceDisplay.jsx     # Live XAUUSD price
│   │   ├── PositionsTable.jsx   # Open positions management
│   │   ├── TradeHistoryTable.jsx # Closed trades history
│   │   ├── ManualTradePanel.jsx # Manual BUY/SELL control
│   │   ├── TradingViewChart.jsx # Embedded TV chart
│   │   └── WebhookGuide.jsx     # Setup guide
│   ├── services/
│   │   └── api.js               # Backend API calls
│   ├── App.jsx                  # Main dashboard
│   └── index.css
├── server/
│   ├── app.py                   # Flask webhook server
│   ├── mt5_bridge.py            # MT5 connection & orders
│   ├── risk_manager.py          # Risk validation
│   ├── signal_handler.py        # Webhook parser
│   ├── config.py                # Settings
│   ├── requirements.txt
│   └── .env.example
├── tradingview/
│   └── xauusd_liquidity_sweep.pine  # Pine Script Strategy
└── README.md
```
