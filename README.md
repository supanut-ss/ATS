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

สำหรับ C# Backend ให้คัดลอก `backend/appsettings.example.json` เป็น
`backend/appsettings.json` แล้วกรอก Database, Webhook Secret และ MT5 account
ของเครื่องนั้น ไฟล์จริงถูก `.gitignore` และต้องไม่ commit ขึ้น repository

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

## Isolated Demo dashboard and webhook (same backend/port)

The main dashboard remains at `/` and uses `/api/*` plus `/webhook`.
The second script-test dashboard is available at `/demo` on the same backend and
port, using only `/demo/api/*` plus `/demo/webhook`.

1. Copy `backend/appsettings.Demo.example.json` to
   `backend/appsettings.Demo.json`.
2. Configure `ConnectionStrings:DemoMySql` with a database that is separate from
   the main ATS database, and use a different Demo webhook secret.
3. Start the single backend normally:

```powershell
dotnet run --project backend/ATS.Backend.csproj --launch-profile http
```

4. Set the test EA `InpBackendURL` to `http://localhost:5000/demo` and use a different
   `InpMagic` (or a separate MT5 Demo account).
5. Send the second TradingView alert to `http://localhost:5000/demo/webhook` and view
   its isolated results at `/demo`.

Demo API and webhook requests return `503` when `appsettings.Demo.json`,
`DemoSettings:Isolated=true`, or `ConnectionStrings:DemoMySql` is missing. The
main backend remains available. No additional firewall port or TLS endpoint is
required because Main and Demo share the same HTTPS origin.

## Strategy & EA Parameters Reference (ATS_MT5_EA.mq5)

ดูไฟล์ `tradingview/ATS_MT5_EA.mq5` สำหรับสคริปต์ Expert Advisor ฉบับเต็ม

**Pure Structure v2.2 + Anti Fake-PA Logic:**
1. **Pivot High/Low & BOS/CHoCH** — ตรวจจับโครงสร้างการทำลายราคา (BOS/CHoCH) ย้อนหลัง 5 แท่งเทียน
2. **FVG & Order Block Zones** — วางกรอบโซน Fair Value Gap และ Order Block บน M5
3. **Premium / Discount Area** — กรองจุดซื้อขายด้วย Fibonacci 0.618 (BUY ที่ Discount / SELL ที่ Premium)
4. **Anti Fake-PA Filter** — ตรวจสอบ 4 สัดส่วนแท่งเทียนก่อนเข้า (Body >= 35%, Wick <= 60%, Close Pos >= 45%, Engulfing Close)
5. **Multi-Timeframe & Sideway Filters** — M5 EMA 200 + H1/H4 EMA 21, ADX >= 20, Choppiness Index <= 60, ATR Volatility Ratio >= 0.80, News & Volume Spike Filter
6. **Breakeven & Stepped Trailing Stop** — BE ที่ $5.00 (5,000 pts), Trailing Stop ที่ $10.00 (10,000 pts), Hard TP ที่ $20.00 (20,000 pts)
7. **Risk Guards** — Require directional CHoCH, Daily Loss Guard สูงสุด 4 ไม้แพ้/วัน และพัก 60 นาทีหลังไม้แพ้
8. **Confirmed Early Exit** — ปิดก่อน Hard SL เมื่อเกิด Opposite CHoCH/Structure Break ยืนยัน 2 แท่ง, ขาดทุนถึง 0.70R ขณะมีสัญญาณเสีย หรือถือไม่เดินเกิน 12 แท่ง

---

## EA Input Settings Summary

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| `InpFixedLot` | `0.05` | ขนาดสัญญา Fixed Lot ต่อการเปิดออเดอร์ |
| `InpMagic` | `88188` | Magic Number แยกแยะออเดอร์ของ EA |
| `InpSlippage` | `30 Points` | ระยะ Slippage สูงสุดที่ยอมรับได้ ($0.03) |
| `InpEntryMode` | `0 (Discount Only)` | โหมดการเข้าโซน (0: Discount Only, 1: Any FVG/OB, 2: Strict ICT) |
| `InpRequireCHoCH` | `true` | BUY ต้องมี Bullish CHoCH และ SELL ต้องมี Bearish CHoCH |
| `InpSLBuffer` | `1.0 Point` | ระยะเผื่อ Structural SL คูณด้วย `SYMBOL_POINT` |
| `InpUseFixedSL` | `true` | เปิดใช้งาน Stop Loss แบบคงที่ |
| `InpFixedSLPips` | `5000 Points` | ระยะ Stop Loss แบบคงที่ ($5.00) |
| `InpBEPips` | `5000 Points` | ระยะกำไรเปิดใช้งาน Breakeven SL ($5.00) |
| `InpTrailLevel1Pips` | `10000 Points` | ระยะกำไรเปิดใช้งาน Trailing Stop ($10.00) |
| `InpTrailLevel1LockPips` | `5000 Points` | ระยะล็อกกำไรขั้นต่ำของ Trailing Stop ($5.00) |
| `InpUseSteppedTrail` | `true` | เปิดใช้งาน Trailing Stop แบบขยับตามระยะราคา (Stepped) |
| `InpTPPips` | `20000 Points` | เป้าหมายกำไรสูงสุด Take Profit ($20.00) |
| `InpUseDailyLossGuard` | `true` | หยุดเปิดไม้ใหม่เมื่อแพ้ครบ 4 สถานะในวันเดียวกัน |
| `InpDailyLossTimezone` | `Asia/Bangkok` | เขตเวลาตัดวันของ Daily Loss Guard |
| `InpUseLossCooldown` | `true` | พักเปิดไม้ใหม่หลังสถานะล่าสุดขาดทุน |
| `InpLossCooldownMins` | `60` | ระยะเวลาพักหลังไม้แพ้ (นาที) |
| `InpUseNewsFilter` | `true` | บล็อกการเทรดช่วงเวลาข่าวใหญ่ (`0300-0500,1930-2030:23456` UTC) |
| `InpUseForceClose` | `true` | บังคับปิดออเดอร์ล้างพอร์ตอัตโนมัติ (`0400-0405:23456` BKK Time) |

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
