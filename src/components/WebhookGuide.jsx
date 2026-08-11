import React, { useState } from 'react';
import {
  Box, Paper, Typography, TextField, Divider,
  Stepper, Step, StepLabel, StepContent, Chip, IconButton, Tooltip,
  Alert, Grid, Card, CardContent, Table, TableBody, TableCell,
  TableContainer, TableHead, TableRow, ToggleButton, ToggleButtonGroup
} from '@mui/material';
import {
  ContentCopy, CheckCircle, Construction, Description,
  TrendingUp, ShowChart, Warning, Shield, Security, Info, Settings,
  Language
} from '@mui/icons-material';

const EA_PARAMETERS_TH = [
  { group: '== Connection Settings ==', param: 'InpEnableWebhookPolling', defaultVal: 'true', desc: 'เปิด/ปิด ระบบดึงสัญญาณเทรดผ่าน Webhook หลังบ้าน' },
  { group: '== Connection Settings ==', param: 'InpBackendURL', defaultVal: 'https://ats.thaipesleague.com', desc: 'URL API หลังบ้านสำหรับดึงสัญญาณและส่งสถานะ (/demo สำหรับ Demo)' },
  { group: '== Connection Settings ==', param: 'InpAuthToken', defaultVal: 'กำหนดใน MT5 Inputs', desc: 'โทเค็นลับยืนยันตัวตนกับหลังบ้าน' },
  { group: '== Connection Settings ==', param: 'InpPollInterval', defaultVal: '10000 (10 วินาที)', desc: 'รอบเวลาดึงข้อมูลจากหลังบ้าน (มิลลิวินาที)' },

  { group: '== Trade Settings ==', param: 'InpSlippage', defaultVal: '30 Points ($0.03)', desc: 'ระยะ Slippage สูงสุดที่ยอมรับได้' },
  { group: '== Trade Settings ==', param: 'InpMagic', defaultVal: '88188', desc: 'หมายเลข Magic Number ของ EA สำหรับแยกแยะออเดอร์' },

  { group: '== Algorithm & Entry Logic ==', param: 'InpPivotLength', defaultVal: '5 Bars', desc: 'จำนวนแท่งย้อนหลังสำหรับหาจุดกลับตัว Pivot' },
  { group: '== Algorithm & Entry Logic ==', param: 'InpSLBuffer', defaultVal: '1.0 Point', desc: 'ระยะเผื่อ Structural SL' },
  { group: '== Algorithm & Entry Logic ==', param: 'InpPDThreshold', defaultVal: '0.618', desc: 'ระดับราคาเกณฑ์ Premium / Discount (Fibonacci 61.8%)' },
  { group: '== Algorithm & Entry Logic ==', param: 'InpEntryMode', defaultVal: 'ENTRY_MODE_DISCOUNT_ONLY (0)', desc: '0 = Discount/Premium Only, 1 = Any FVG/OB, 2 = Strict ICT' },
  { group: '== Algorithm & Entry Logic ==', param: 'InpRequireCHoCH', defaultVal: 'true', desc: 'บังคับให้เกิด CHoCH ตามทิศทางก่อนเปิดออเดอร์' },

  { group: '== Risk & Fixed SL ==', param: 'InpUseFixedSL', defaultVal: 'true', desc: 'เปิดใช้งาน Stop Loss แบบคงที่ (Points)' },
  { group: '== Risk & Fixed SL ==', param: 'InpFixedSLPips', defaultVal: '5000 Points ($5.00)', desc: 'ระยะ Stop Loss แบบคงที่จากจุดเข้า' },

  { group: '== Daily Loss Guard ==', param: 'InpUseDailyLossGuard', defaultVal: 'true', desc: 'หยุดเปิดไม้ใหม่เมื่อจำนวนไม้แพ้ของวันถึงขีดจำกัด' },
  { group: '== Daily Loss Guard ==', param: 'InpMaxDailyLossCount', defaultVal: '4', desc: 'จำนวนสถานะขาดทุนสูงสุดต่อวัน' },
  { group: '== Daily Loss Guard ==', param: 'InpDailyLossTimezone', defaultVal: 'Asia/Bangkok', desc: 'เขตเวลาที่ใช้ตัดวันและรีเซ็ตตัวนับ' },

  { group: '== M5 Anti Fake-PA ==', param: 'InpPABodyMin', defaultVal: '0.35 (35%)', desc: 'สัดส่วนเนื้อเทียนขั้นต่ำ' },
  { group: '== M5 Anti Fake-PA ==', param: 'InpPAWickMax', defaultVal: '0.60 (60%)', desc: 'สัดส่วนไส้เทียนสูงสุด' },
  { group: '== M5 Anti Fake-PA ==', param: 'InpPACloseMin', defaultVal: '0.45 (45%)', desc: 'ตำแหน่งราคาปิดขั้นต่ำ' },
  { group: '== M5 Anti Fake-PA ==', param: 'InpPAEngulf', defaultVal: 'true', desc: 'บังคับให้เกิดแท่งกลืนกิน (Engulfing Close)' },

  { group: '== Position Sizing ==', param: 'InpFixedLot', defaultVal: '0.05 Lot', desc: 'ขนาดสัญญาในการเปิดออเดอร์แต่ละครั้ง' },

  { group: '== Trend Filters ==', param: 'InpUseEMA', defaultVal: 'true (EMA 200 M5)', desc: 'กรองเทรนด์ M5 ด้วยเส้น EMA 200' },
  { group: '== Trend Filters ==', param: 'InpUseH1Trend', defaultVal: 'true (EMA 21 H1)', desc: 'กรองเทรนด์หลักด้วย EMA 21 ในไทม์เฟรม H1' },
  { group: '== Trend Filters ==', param: 'InpUseH4Trend', defaultVal: 'true (EMA 21 H4)', desc: 'กรองเทรนด์หลักด้วย EMA 21 ในไทม์เฟรม H4' },

  { group: '== News & Volume Filters ==', param: 'InpUseNewsFilter', defaultVal: 'true', desc: 'เปิดใช้งานตัวกรองช่วงเวลาข่าวใหญ่' },
  { group: '== News & Volume Filters ==', param: 'InpNewsSession', defaultVal: '0300-0500,1930-2030:23456', desc: 'ช่วงเวลาบล็อกการเทรด (UTC Time)' },
  { group: '== News & Volume Filters ==', param: 'InpUseVolFilter', defaultVal: 'true', desc: 'เปิดใช้งานตัวกรองวอลลุ่มผิดปกติ (Volume Spike)' },

  { group: '== Early Exit Management ==', param: 'InpUseEarlyExit', defaultVal: 'true', desc: 'ปิดสถานะก่อนถึง Hard SL เมื่อโครงสร้างเสีย' },
  { group: '== Early Exit Management ==', param: 'InpExitOnOppositeCHoCH', defaultVal: 'true', desc: 'ปิดเมื่อเกิด CHoCH ฝั่งตรงข้ามตามจำนวนแท่งยืนยัน' },

  { group: '== Breakeven & Trailing Stop ==', param: 'InpBEPips', defaultVal: '5000 Points ($5.00)', desc: 'ระยะกำไรเริ่มย้าย SL เลื่อนมาล็อกทุน Breakeven (+10 Points)' },
  { group: '== Breakeven & Trailing Stop ==', param: 'InpTrailLevel1Pips', defaultVal: '10000 Points ($10.00)', desc: 'ระยะกำไรเริ่มเปิดใช้งาน Trailing Stop' },
  { group: '== Breakeven & Trailing Stop ==', param: 'InpTPPips', defaultVal: '20000 Points ($20.00)', desc: 'เป้าหมายกำไรสูงสุด Take Profit' },
];

const EA_PARAMETERS_EN = [
  { group: '== Connection Settings ==', param: 'InpEnableWebhookPolling', defaultVal: 'true', desc: 'Enable signal polling from backend' },
  { group: '== Connection Settings ==', param: 'InpBackendURL', defaultVal: 'https://ats.thaipesleague.com', desc: 'Backend API URL for signals and status sync (add /demo for Demo)' },
  { group: '== Connection Settings ==', param: 'InpAuthToken', defaultVal: 'Configured in MT5 Inputs', desc: 'Secret authentication token' },
  { group: '== Connection Settings ==', param: 'InpPollInterval', defaultVal: '10000 (10s)', desc: 'Polling interval in milliseconds' },

  { group: '== Trade Settings ==', param: 'InpSlippage', defaultVal: '30 Points ($0.03)', desc: 'Maximum allowable slippage' },
  { group: '== Trade Settings ==', param: 'InpMagic', defaultVal: '88188', desc: 'Unique EA Magic ID for trade tracking' },

  { group: '== Algorithm & Entry Logic ==', param: 'InpPivotLength', defaultVal: '5 Bars', desc: 'Lookback bars for Pivot High / Low reversal detection' },
  { group: '== Algorithm & Entry Logic ==', param: 'InpSLBuffer', defaultVal: '1.0 Point', desc: 'Structural SL buffer multiplier' },
  { group: '== Algorithm & Entry Logic ==', param: 'InpPDThreshold', defaultVal: '0.618', desc: 'Premium / Discount Fibonacci threshold (61.8%)' },
  { group: '== Algorithm & Entry Logic ==', param: 'InpEntryMode', defaultVal: 'ENTRY_MODE_DISCOUNT_ONLY (0)', desc: '0 = Discount/Premium Only, 1 = Any FVG/OB, 2 = Strict ICT' },
  { group: '== Algorithm & Entry Logic ==', param: 'InpRequireCHoCH', defaultVal: 'true', desc: 'Require Bullish CHoCH for BUY and Bearish CHoCH for SELL' },

  { group: '== Risk & Fixed SL ==', param: 'InpUseFixedSL', defaultVal: 'true', desc: 'Enable fixed Stop Loss (Points)' },
  { group: '== Risk & Fixed SL ==', param: 'InpFixedSLPips', defaultVal: '5000 Points ($5.00)', desc: 'Fixed Stop Loss distance from entry' },

  { group: '== Daily Loss Guard ==', param: 'InpUseDailyLossGuard', defaultVal: 'true', desc: 'Stop opening new trades when daily loss count reaches limit' },
  { group: '== Daily Loss Guard ==', param: 'InpMaxDailyLossCount', defaultVal: '4', desc: 'Maximum allowed losing trades per day' },
  { group: '== Daily Loss Guard ==', param: 'InpDailyLossTimezone', defaultVal: 'Asia/Bangkok', desc: 'Timezone used to reset daily loss counters' },

  { group: '== M5 Anti Fake-PA ==', param: 'InpPABodyMin', defaultVal: '0.35 (35%)', desc: 'Minimum candle body ratio' },
  { group: '== M5 Anti Fake-PA ==', param: 'InpPAWickMax', defaultVal: '0.60 (60%)', desc: 'Maximum allowable wick ratio' },
  { group: '== M5 Anti Fake-PA ==', param: 'InpPACloseMin', defaultVal: '0.45 (45%)', desc: 'Minimum close position ratio' },
  { group: '== M5 Anti Fake-PA ==', param: 'InpPAEngulf', defaultVal: 'true', desc: 'Require Engulfing candle confirmation' },

  { group: '== Position Sizing ==', param: 'InpFixedLot', defaultVal: '0.05 Lot', desc: 'Fixed lot size per position' },

  { group: '== Trend Filters ==', param: 'InpUseEMA', defaultVal: 'true (EMA 200 M5)', desc: 'M5 trend filter via 200 EMA' },
  { group: '== Trend Filters ==', param: 'InpUseH1Trend', defaultVal: 'true (EMA 21 H1)', desc: 'H1 trend filter via 21 EMA' },
  { group: '== Trend Filters ==', param: 'InpUseH4Trend', defaultVal: 'true (EMA 21 H4)', desc: 'H4 trend filter via 21 EMA' },

  { group: '== News & Volume Filters ==', param: 'InpUseNewsFilter', defaultVal: 'true', desc: 'Enable major news blackout filter' },
  { group: '== News & Volume Filters ==', param: 'InpNewsSession', defaultVal: '0300-0500,1930-2030:23456', desc: 'Trading blackout session hours (UTC)' },
  { group: '== News & Volume Filters ==', param: 'InpUseVolFilter', defaultVal: 'true', desc: 'Enable volume spike filter' },

  { group: '== Early Exit Management ==', param: 'InpUseEarlyExit', defaultVal: 'true', desc: 'Close positions early on structural invalidation' },
  { group: '== Early Exit Management ==', param: 'InpExitOnOppositeCHoCH', defaultVal: 'true', desc: 'Exit on opposite CHoCH confirmation' },

  { group: '== Breakeven & Trailing Stop ==', param: 'InpBEPips', defaultVal: '5000 Points ($5.00)', desc: 'Breakeven trigger distance (+10 Points lock)' },
  { group: '== Breakeven & Trailing Stop ==', param: 'InpTrailLevel1Pips', defaultVal: '10000 Points ($10.00)', desc: 'Trailing stop activation distance' },
  { group: '== Breakeven & Trailing Stop ==', param: 'InpTPPips', defaultVal: '20000 Points ($20.00)', desc: 'Hard Take Profit target distance' },
];

function CopyField({ label, value, copyText = 'Copy', copiedText = 'Copied!' }) {
  const [copied, setCopied] = useState(false);
  const copy = () => {
    navigator.clipboard.writeText(value);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };
  return (
    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
      <TextField
        label={label}
        value={value}
        size="small"
        fullWidth
        InputProps={{ readOnly: true, sx: { fontFamily: 'monospace', fontSize: '0.85rem' } }}
      />
      <Tooltip title={copied ? copiedText : copyText}>
        <IconButton onClick={copy} size="small" sx={{ color: copied ? '#10b981' : 'text.secondary' }}>
          {copied ? <CheckCircle sx={{ fontSize: 18 }} /> : <ContentCopy sx={{ fontSize: 18 }} />}
        </IconButton>
      </Tooltip>
    </Box>
  );
}

export default function WebhookGuide({ serverStatus, environment = 'main', backendUrl = '' }) {
  const [lang, setLang] = useState('th'); // Default to Thai for Setup Guide
  const isDemo = environment === 'demo';

  const rawBase = backendUrl || window.location.origin;
  const cleanBase = rawBase.replace(/\/demo\/?$/, '').replace(/\/$/, '');

  const localUrl = isDemo ? 'http://localhost:5000/demo' : 'http://localhost:5000';
  const liveUrl  = isDemo ? `${cleanBase}/demo` : cleanBase;

  const isTh = lang === 'th';
  const paramsList = isTh ? EA_PARAMETERS_TH : EA_PARAMETERS_EN;

  return (
    <Box sx={{ display: 'flex', flexDirection: 'column', gap: 3 }}>
      {/* 2-Language Switcher Toolbar */}
      <Paper sx={{
        p: 2,
        bgcolor: 'rgba(255,255,255,0.02)',
        border: '1px solid rgba(99,102,241,0.25)',
        borderRadius: 2.5,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        flexWrap: 'wrap',
        gap: 2
      }}>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5 }}>
          <Language sx={{ color: '#818cf8', fontSize: 24 }} />
          <Box>
            <Typography variant="subtitle2" sx={{ fontWeight: 800, color: 'text.primary' }}>
              {isTh ? 'เลือกภาษาคู่มือการใช้งาน (Guide Language)' : 'Setup Guide Display Language'}
            </Typography>
            <Typography variant="caption" sx={{ color: 'text.secondary' }}>
              {isTh ? 'สลับการแสดงผลคู่มือระหว่าง ภาษาไทย และ English' : 'Switch guide display language between Thai and English'}
            </Typography>
          </Box>
        </Box>

        <ToggleButtonGroup
          value={lang}
          exclusive
          onChange={(e, newLang) => { if (newLang) setLang(newLang); }}
          size="small"
          sx={{
            bgcolor: 'rgba(0,0,0,0.3)',
            p: 0.5,
            borderRadius: 2,
            '& .MuiToggleButton-root': {
              border: 'none',
              borderRadius: 1.5,
              px: 2, py: 0.6,
              fontWeight: 800,
              fontSize: '0.75rem',
              color: 'text.secondary',
              '&.Mui-selected': {
                bgcolor: 'rgba(99,102,241,0.2)',
                color: '#818cf8',
                boxShadow: '0 2px 8px rgba(0,0,0,0.3)',
              }
            }
          }}
        >
          <ToggleButton value="th">
            ภาษาไทย (TH)
          </ToggleButton>
          <ToggleButton value="en">
            ENGLISH (EN)
          </ToggleButton>
        </ToggleButtonGroup>
      </Paper>

      {isDemo && (
        <Alert severity="warning" variant="outlined" sx={{ borderWidth: 2, borderRadius: 2.5 }}>
          {isTh ? (
            <>
              <strong>คู่มือการตั้งค่า EA Adaptive_SR_Dashboard_EA.mq5 บนบัญชี Demo:</strong><br />
              1. <strong>InpEnableDemoAnalytics:</strong> ต้องเปลี่ยนเป็น <code>true</code> (ค่าเริ่มต้นคือ false)<br />
              2. <strong>InpAnalyticsBaseURL:</strong> <code>https://ats.thaipesleague.com/demo</code><br />
              3. <strong>InpAnalyticsToken:</strong> <code>demo_sec_9f5c4b8e2a1d7f0e3c6b8a9f</code><br />
              4. <strong>InpAnalyticsAccountRef:</strong> <code>demo-sr</code><br />
              5. <strong>บัญชี MT5:</strong> ต้องเป็นบัญชี Demo เท่านั้น (หากสลับไปบัญชีจริง EA จะปิดการส่ง Analytics อัตโนมัติ)<br />
              6. <strong>MT5 Allowed WebRequest URL:</strong> ใน Tools ➡️ Options ➡️ Expert Advisors ให้ใส่เฉพาะ <code>https://ats.thaipesleague.com</code> (ห้ามใส่ /demo ในหน้าต่าง Options)
            </>
          ) : (
            <>
              <strong>Adaptive_SR_Dashboard_EA.mq5 Demo Settings:</strong><br />
              1. <strong>InpEnableDemoAnalytics:</strong> Set to <code>true</code> (default is false).<br />
              2. <strong>InpAnalyticsBaseURL:</strong> <code>https://ats.thaipesleague.com/demo</code><br />
              3. <strong>InpAnalyticsToken:</strong> <code>demo_sec_9f5c4b8e2a1d7f0e3c6b8a9f</code><br />
              4. <strong>InpAnalyticsAccountRef:</strong> <code>demo-sr</code><br />
              5. <strong>MT5 Account:</strong> Must be a Demo account.<br />
              6. <strong>MT5 Allowed WebRequest:</strong> Add <code>https://ats.thaipesleague.com</code> in Tools ➡️ Options ➡️ Expert Advisors.
            </>
          )}
        </Alert>
      )}

      {/* --- Section 1: Guide Details --- */}
      <Paper sx={{ p: 3, border: '1px solid rgba(255,255,255,0.06)', bgcolor: 'background.paper' }}>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, mb: 2, flexWrap: 'wrap' }}>
          <Construction sx={{ color: '#6366f1', fontSize: 24 }} />
          <Typography variant="h6" sx={{ fontWeight: 700, flexGrow: 1 }}>
            {isTh ? 'คู่มือการติดตั้ง & ตั้งค่า EA ใน MT5' : 'EA Installation & Setup Guide'}
          </Typography>
          <Chip label={isTh ? 'โหมดการทำงาน: MT5 Polling (v2.2)' : 'Mode: MT5 Polling (v2.2)'} size="small" sx={{ bgcolor: 'rgba(99,102,241,0.12)', color: '#818cf8', fontWeight: 700 }} />
          <Chip
            label={serverStatus ? (isTh ? '● Server Online' : '● Server Online') : (isTh ? '○ Server Offline' : '○ Server Offline')}
            size="small"
            sx={{
              bgcolor: serverStatus ? 'rgba(16,185,129,0.1)' : 'rgba(244,63,94,0.1)',
              color:   serverStatus ? '#10b981' : '#f43f5e',
              fontWeight: 700,
            }}
          />
        </Box>

        <Alert severity="warning" sx={{ mb: 3, bgcolor: 'rgba(245,158,11,0.08)', border: '1px solid rgba(245,158,11,0.2)', color: '#fbbf24', fontSize: '0.85rem' }}>
          {isTh ? (
            <>
              <strong>ข้อสำคัญ:</strong> คุณจำเป็นต้องเข้าไปเปลี่ยนค่าพารามิเตอร์ <strong>InpEnableWebhookPolling</strong> ให้เป็น <strong>true</strong> ในส่วนของ Inputs ตอนติดตั้ง EA บนชาร์ต เพราะค่าเริ่มต้นคือ false หากไม่เปลี่ยนตัว EA จะไม่ดึงสัญญาณการซื้อขายจากหลังบ้าน
            </>
          ) : (
            <>
              <strong>Important:</strong> Set <strong>InpEnableWebhookPolling</strong> to <strong>true</strong> in the EA Inputs tab during installation.
            </>
          )}
        </Alert>

        <Typography variant="subtitle2" sx={{ fontWeight: 700, mb: 2 }}>
          {isTh ? 'คัดลอกค่าสำหรับใส่ใน EA Inputs' : 'Copy Values for EA Inputs'}
        </Typography>
        <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1.5, mb: 3 }}>
          <CopyField label={isTh ? 'Backend Base URL (Local)' : 'Backend Base URL (Local)'} value={localUrl} copyText={isTh ? 'คัดลอก' : 'Copy'} copiedText={isTh ? 'คัดลอกแล้ว!' : 'Copied!'} />
          <CopyField label={isTh ? 'Backend Base URL (เซิร์ฟเวอร์จริง)' : 'Backend Base URL (Live Server)'} value={liveUrl} copyText={isTh ? 'คัดลอก' : 'Copy'} copiedText={isTh ? 'คัดลอกแล้ว!' : 'Copied!'} />
          <CopyField
            label={isDemo ? (isTh ? 'InpAuthToken สำหรับโหมด Demo' : 'InpAuthToken for Demo Mode') : (isTh ? 'InpAuthToken สำหรับโหมด Main' : 'InpAuthToken for Main Mode')}
            value={isDemo ? 'demo_sec_9f5c4b8e2a1d7f0e3c6b8a9f' : 'ats_sec_9f5c4b8e2a1d7f0e3c6b8a9f'}
            copyText={isTh ? 'คัดลอก' : 'Copy'}
            copiedText={isTh ? 'คัดลอกแล้ว!' : 'Copied!'}
          />
          <CopyField label={isTh ? 'Webhook Endpoint URL' : 'Webhook Endpoint URL'} value={`${liveUrl}/webhook`} copyText={isTh ? 'คัดลอก' : 'Copy'} copiedText={isTh ? 'คัดลอกแล้ว!' : 'Copied!'} />
        </Box>

        <Divider sx={{ my: 3 }} />

        <Typography variant="subtitle2" sx={{ fontWeight: 700, mb: 2 }}>
          {isTh ? 'ลำดับขั้นตอนการติดตั้ง' : 'Installation Steps'}
        </Typography>
        <Stepper orientation="vertical" nonLinear sx={{ '& .MuiStepLabel-label': { fontWeight: 600 } }}>
          <Step active>
            <StepLabel>
              {isTh ? '1. อนุญาต WebRequest ในโปรแกรม MT5 (สำคัญมาก)' : '1. Allow WebRequest in MetaTrader 5 (Required)'}
            </StepLabel>
            <StepContent sx={{ borderLeft: '1px solid rgba(255,255,255,0.08)' }}>
              <Typography variant="body2" sx={{ color: 'text.secondary', mb: 1 }}>
                {isTh ? (
                  <>
                    เพื่อให้ EA สามารถดึงข้อมูลสัญญาณจากระบบหลังบ้านไปเปิดออเดอร์ในพอร์ตจริงได้:<br />
                    1. ในโปรแกรม MT5 ไปที่เมนู <strong>Tools ➡️ Options</strong> (หรือกด <code>Ctrl + O</code>)<br />
                    2. เลือกแท็บ <strong>Expert Advisors</strong><br />
                    3. ติ๊กถูกที่ช่อง <strong>Allow WebRequest for listed URL:</strong><br />
                    4. ดับเบิ้ลคลิกเพิ่มโดเมนหลังบ้านของคุณ (เช่น <code>https://ats.thaipesleague.com</code> หรือ <code>http://localhost:5000</code>)<br />
                    <span style={{ color: '#f59e0b', fontWeight: 600 }}>⚠️ ข้อสำคัญ: ในหน้าต่าง Options ให้ใส่เฉพาะโดเมนหลักเท่านั้น (ห้ามใส่ /demo ในหน้าต่าง Options ให้ใส่ /demo เฉพาะตอนตั้งค่า InpBackendURL บนชาร์ตเท่านั้น)</span><br />
                    5. กด <strong>OK</strong> เพื่อบันทึก
                  </>
                ) : (
                  <>
                    Enables the MT5 Expert Advisor to fetch signals and sync trade positions with your backend server:<br />
                    1. In MetaTrader 5, go to <strong>Tools ➡️ Options</strong> (or press <code>Ctrl + O</code>)<br />
                    2. Open the <strong>Expert Advisors</strong> tab<br />
                    3. Check <strong>Allow WebRequest for listed URL:</strong><br />
                    4. Double-click to add your domain (e.g. <code>https://ats.thaipesleague.com</code> or <code>http://localhost:5000</code>)<br />
                    <span style={{ color: '#f59e0b', fontWeight: 600 }}>⚠️ Note: In the Options dialog, add only the main domain (do NOT append /demo here. Add /demo only in the EA InpBackendURL parameter on the chart).</span><br />
                    5. Click <strong>OK</strong> to save
                  </>
                )}
              </Typography>
            </StepContent>
          </Step>

          <Step active>
            <StepLabel>
              {isTh ? '2. นำเข้าและคอมไพล์สคริปต์ EA ใน MT5' : '2. Import & Compile Expert Advisor in MT5'}
            </StepLabel>
            <StepContent sx={{ borderLeft: '1px solid rgba(255,255,255,0.08)' }}>
              <Typography variant="body2" sx={{ color: 'text.secondary', mb: 1 }}>
                {isTh ? (
                  <>
                    1. ในโปรแกรม MT5 กดปุ่ม <strong>F4</strong> เพื่อเปิดโปรแกรม <strong>MetaEditor</strong><br />
                    2. ในแถบ Navigator ด้านซ้าย ให้คลิกขวาที่โฟลเดอร์ <strong>Experts</strong> ➡️ เลือก <strong>Open Folder</strong><br />
                    3. คัดลอกสคริปต์ EA จากโครงการของเราไปวาง: <code style={{ color: '#818cf8' }}>ATS_MT5_EA.mq5</code><br />
                    4. ดับเบิ้ลคลิกเปิดไฟล์นั้นใน MetaEditor แล้วกดปุ่ม <strong>Compile</strong> (หรือกด <code>F7</code>) ที่แถบเครื่องมือด้านบน<br />
                    5. ตรวจสอบว่าไม่มีขึ้น Error แดงในหน้าต่าง Toolbox ด้านล่าง
                  </>
                ) : (
                  <>
                    1. In MT5, press <strong>F4</strong> to open <strong>MetaEditor</strong><br />
                    2. In the left Navigator pane, right-click <strong>Experts</strong> ➡️ select <strong>Open Folder</strong><br />
                    3. Copy the EA script file: <code style={{ color: '#818cf8' }}>ATS_MT5_EA.mq5</code> into the folder<br />
                    4. Double-click the file in MetaEditor and click <strong>Compile</strong> (or press <code>F7</code>)<br />
                    5. Verify that no compilation errors appear in the bottom Toolbox pane
                  </>
                )}
              </Typography>
            </StepContent>
          </Step>

          <Step active>
            <StepLabel>
              {isTh ? '3. ติดตั้ง EA ลงบนชาร์ตทองคำ (XAUUSD)' : '3. Attach EA to XAUUSD Chart'}
            </StepLabel>
            <StepContent sx={{ borderLeft: '1px solid rgba(255,255,255,0.08)' }}>
              <Typography variant="body2" sx={{ color: 'text.secondary', mb: 1.5 }}>
                {isTh ? (
                  <>
                    1. กลับมาที่โปรแกรม MT5 เปิดชาร์ตคู่เงิน <strong>XAUUSD (ทองคำ)</strong> ไทม์เฟรม <strong>M5</strong><br />
                    2. ลากตัว EA <strong>ATS_MT5_EA</strong> จาก Navigator ด้านซ้ายมาวางบนชาร์ตทองคำ<br />
                    3. ในแท็บ <strong>Inputs</strong> ปรับแต่งค่าพารามิเตอร์หลักดังนี้:
                  </>
                ) : (
                  <>
                    1. In MT5, open the <strong>XAUUSD (Gold)</strong> chart on <strong>M5</strong> timeframe<br />
                    2. Drag <strong>ATS_MT5_EA</strong> from the left Navigator onto the XAUUSD chart<br />
                    3. In the <strong>Inputs</strong> tab, configure the following parameters:
                  </>
                )}
              </Typography>
              <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1, pl: 1, mb: 1.5 }}>
                <Box sx={{ fontSize: '0.8rem', color: 'text.primary', borderLeft: '3px solid #6366f1', pl: 1.5 }}>
                  <strong>InpEnableWebhookPolling</strong> ➡️ {isTh ? 'เปลี่ยนเป็น true (เปิดการรับสัญญาณผ่าน Webhook)' : 'Set to true (Enables signal polling)'}
                </Box>
                <Box sx={{ fontSize: '0.8rem', color: 'text.primary', borderLeft: '3px solid #6366f1', pl: 1.5 }}>
                  <strong>InpBackendURL</strong> ➡️ {isTh ? 'ใส่ลิงก์ API หลังบ้านของคุณ (เช่น https://ats.thaipesleague.com หรือใส่ /demo สำหรับโหมด Demo)' : 'Enter your backend API URL (e.g. https://ats.thaipesleague.com or add /demo for Demo mode)'}
                </Box>
                <Box sx={{ fontSize: '0.8rem', color: 'text.primary', borderLeft: '3px solid #6366f1', pl: 1.5 }}>
                  <strong>InpAuthToken</strong> ➡️ {isTh ? 'โทเค็นยืนยันตัวตนสำหรับเชื่อมต่อหลังบ้าน' : 'Auth token matching your backend configuration'}
                </Box>
                <Box sx={{ fontSize: '0.8rem', color: 'text.primary', borderLeft: '3px solid #6366f1', pl: 1.5 }}>
                  <strong>InpFixedSLPips</strong> ➡️ {isTh ? 'ระยะ SL แบบคงที่ Default 5000 Points ($5.00)' : 'Fixed Stop Loss Default 5000 Points ($5.00)'}
                </Box>
                <Box sx={{ fontSize: '0.8rem', color: 'text.primary', borderLeft: '3px solid #6366f1', pl: 1.5 }}>
                  <strong>InpBEPips</strong> ➡️ {isTh ? 'ระยะกำไรที่เริ่มล็อกทุน Breakeven Default 5000 Points ($5.00)' : 'Breakeven Trigger Default 5000 Points ($5.00)'}
                </Box>
                <Box sx={{ fontSize: '0.8rem', color: 'text.primary', borderLeft: '3px solid #6366f1', pl: 1.5 }}>
                  <strong>InpTPPips</strong> ➡️ {isTh ? 'ระยะกำไรสูงสุด Take Profit Default 20000 Points ($20.00)' : 'Hard Take Profit Default 20000 Points ($20.00)'}
                </Box>
              </Box>
              <Typography variant="body2" sx={{ color: 'text.secondary', mb: 1.5 }}>
                {isTh ? (
                  <>💡 <strong>คำอธิบาย Points บน MT5:</strong> สำหรับ XAUUSD บนโบรกเกอร์ Exness 1 Point = $0.001 (1,000 Points = $1.00, 5,000 Points = $5.00, 20,000 Points = $20.00)</>
                ) : (
                  <>💡 <strong>Points Conversion Note:</strong> For XAUUSD, 1 Point = $0.001 (1,000 Points = $1.00, 5,000 Points = $5.00, 20,000 Points = $20.00)</>
                )}
              </Typography>
              <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                {isTh ? '4. กด OK' : '4. Click OK'}
              </Typography>
            </StepContent>
          </Step>

          <Step active>
            <StepLabel>
              {isTh ? '4. เปิดใช้งานระบบเทรดอัตโนมัติ (Algo Trading)' : '4. Enable Algo Trading'}
            </StepLabel>
            <StepContent sx={{ borderLeft: '1px solid rgba(255,255,255,0.08)' }}>
              <Typography variant="body2" sx={{ color: 'text.secondary', mb: 1 }}>
                {isTh ? (
                  <>
                    1. คลิกปุ่ม <strong>Algo Trading</strong> ที่แถบเครื่องมือด้านบนของโปรแกรม MT5 ให้ปุ่มเปลี่ยนเป็น <strong>สีเขียว (Play)</strong><br />
                    2. สังเกตที่มุมขวาบนของชาร์ตทองคำ จะต้องมีสัญลักษณ์รูปไอคอน EA เป็น <strong>สีฟ้า / มีรอยยิ้ม</strong><br />
                    3. ดูแถบ <strong>Journal/Experts</strong> ด้านล่างเพื่อดูประวัติการเชื่อมต่อ (ควรขึ้นว่า <code>Initialized successfully</code>)<br />
                    4. เมื่อมีสัญญาณใหม่เข้ามา EA จะยิงออเดอร์เข้าพอร์ตทันทีตามค่า SL/TP และปริมาณล็อตที่กำหนด
                  </>
                ) : (
                  <>
                    1. Click the <strong>Algo Trading</strong> button on the MT5 top toolbar so it turns <strong>Green (Play)</strong><br />
                    2. Verify the top right of the XAUUSD chart shows a <strong>blue hat / smiling EA icon</strong><br />
                    3. Check the bottom <strong>Journal / Experts</strong> tab to verify connection status (should display <code>Initialized successfully</code>)<br />
                    4. When signals arrive, orders will be executed automatically with your configured SL/TP and Lot sizes
                  </>
                )}
              </Typography>
            </StepContent>
          </Step>
        </Stepper>
      </Paper>

      {/* --- Section 2: Strategy Logic Summary --- */}
      <Paper sx={{ p: 3, border: '1px solid rgba(255,255,255,0.06)', bgcolor: 'background.paper' }}>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, mb: 2.5 }}>
          <Description sx={{ color: '#10b981', fontSize: 24 }} />
          <Typography variant="h6" sx={{ fontWeight: 700 }}>
            {isTh ? 'สรุปตรรกะการคำนวณและเทรดของ EA (Pure Structure v2.2)' : 'EA Trading Logic Summary (Pure Structure v2.2)'}
          </Typography>
        </Box>

        <Typography variant="body2" sx={{ color: 'text.secondary', mb: 3 }}>
          {isTh
            ? 'สคริปต์ EA (ATS_MT5_EA.mq5) รวบรวมอัลกอริทึมการวิเคราะห์โครงสร้างตลาดและโซนราคาแบบอัจฉริยะ (SMC/ICT) บนกราฟ M5 โดยมีตรรกะการเทรดที่ทำงาน 6 ชั้นดังนี้:'
            : 'The Expert Advisor script (ATS_MT5_EA.mq5) evaluates market structure and pricing zones on M5 charts:'}
        </Typography>

        <Grid container spacing={2}>
          <Grid item xs={12} sm={6}>
            <Card sx={{ bgcolor: 'rgba(255,255,255,0.01)', border: '1px solid rgba(255,255,255,0.03)', height: '100%' }}>
              <CardContent sx={{ p: 2 }}>
                <Typography variant="subtitle2" sx={{ fontWeight: 700, color: '#818cf8', display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
                  <TrendingUp sx={{ fontSize: 18 }} />
                  {isTh ? '1. โครงสร้างตลาดระดับย่อย (Market Structure)' : '1. Market Structure Analysis'}
                </Typography>
                <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block', mt: 0.5 }}>
                  {isTh
                    ? 'ตรวจจับ Pivot High / Low 5 แท่งเทียนย้อนหลัง เพื่อหาจุด BOS (Break of Structure) ตามเทรนด์ และ CHoCH (Change of Character) จับสัญญาณเปลี่ยนเทรนด์'
                    : 'Detects 5-bar Pivot High/Low points for BOS (Break of Structure) and CHoCH (Change of Character).'}
                </Typography>
              </CardContent>
            </Card>
          </Grid>

          <Grid item xs={12} sm={6}>
            <Card sx={{ bgcolor: 'rgba(255,255,255,0.01)', border: '1px solid rgba(255,255,255,0.03)', height: '100%' }}>
              <CardContent sx={{ p: 2 }}>
                <Typography variant="subtitle2" sx={{ fontWeight: 700, color: '#818cf8', display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
                  <ShowChart sx={{ fontSize: 18 }} />
                  {isTh ? '2. โซนราคา FVG & Order Block (OB)' : '2. FVG & Order Block Zones'}
                </Typography>
                <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block', mt: 0.5 }}>
                  {isTh
                    ? 'วางกรอบ Fair Value Gap (FVG) และ Order Blocks (OB) รองรับการเลือกโหมดเข้าเทรด (InpEntryMode): Discount Only, Any FVG/OB, หรือ Strict ICT'
                    : 'Identifies Fair Value Gaps (FVG) and Order Blocks (OB) based on entry mode settings.'}
                </Typography>
              </CardContent>
            </Card>
          </Grid>

          <Grid item xs={12} sm={6}>
            <Card sx={{ bgcolor: 'rgba(255,255,255,0.01)', border: '1px solid rgba(255,255,255,0.03)', height: '100%' }}>
              <CardContent sx={{ p: 2 }}>
                <Typography variant="subtitle2" sx={{ fontWeight: 700, color: '#818cf8', display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
                  <Security sx={{ fontSize: 18 }} />
                  {isTh ? '3. พื้นที่ Premium / Discount Zone' : '3. Premium / Discount Zone Filter'}
                </Typography>
                <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block', mt: 0.5 }}>
                  {isTh
                    ? 'กรองราคาสวิงด้วย Fibonacci 0.618: BUY เมื่อราคาอยู่ในเขต Discount (ต่ำกว่า 61.8%) และ SELL เมื่อราคาอยู่ในเขต Premium (สูงกว่า 61.8%)'
                    : 'Filters entries via 61.8% Fibonacci levels: BUY in Discount zone, SELL in Premium zone.'}
                </Typography>
              </CardContent>
            </Card>
          </Grid>

          <Grid item xs={12} sm={6}>
            <Card sx={{ bgcolor: 'rgba(255,255,255,0.01)', border: '1px solid rgba(255,255,255,0.03)', height: '100%' }}>
              <CardContent sx={{ p: 2 }}>
                <Typography variant="subtitle2" sx={{ fontWeight: 700, color: '#818cf8', display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
                  <Info sx={{ fontSize: 18 }} />
                  {isTh ? '4. ตัวกรองตลาด Multi-Filter' : '4. Multi-Layer Filter Engine'}
                </Typography>
                <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block', mt: 0.5 }}>
                  {isTh
                    ? 'กรอง 5 ชั้น: M5 EMA 200 + H1/H4 EMA 21, ADX >= 20, Choppiness <= 60 (เลี่ยง Sideway), ATR Ratio >= 0.80 และ News/Volume Spike Filter'
                    : 'Multi-tier filter: M5 EMA 200 + H1/H4 EMA 21, ADX >= 20, and Choppiness Index <= 60.'}
                </Typography>
              </CardContent>
            </Card>
          </Grid>

          <Grid item xs={12} sm={6}>
            <Card sx={{ bgcolor: 'rgba(255,255,255,0.01)', border: '1px solid rgba(255,255,255,0.03)', height: '100%' }}>
              <CardContent sx={{ p: 2 }}>
                <Typography variant="subtitle2" sx={{ fontWeight: 700, color: '#818cf8', display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
                  <Shield sx={{ fontSize: 18 }} />
                  {isTh ? '5. Anti Fake-PA Candle Confirmation' : '5. Anti Fake-PA Candle Confirmation'}
                </Typography>
                <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block', mt: 0.5 }}>
                  {isTh
                    ? 'คำนวณ 4 สัดส่วนแท่งเทียนก่อนเข้า: Body Min 35%, Wick Max 60%, Close Position Min 45% และ Engulfing Close ป้องกันจุดเข้าหลอก'
                    : 'Validates candlestick body, wick, and close ratios (Body Min 35%, Engulfing Close) to prevent false breakouts.'}
                </Typography>
              </CardContent>
            </Card>
          </Grid>

          <Grid item xs={12} sm={6}>
            <Card sx={{ bgcolor: 'rgba(255,255,255,0.01)', border: '1px solid rgba(255,255,255,0.03)', height: '100%' }}>
              <CardContent sx={{ p: 2 }}>
                <Typography variant="subtitle2" sx={{ fontWeight: 700, color: '#818cf8', display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
                  <Warning sx={{ fontSize: 18 }} />
                  {isTh ? '6. ระบบจัดการความเสี่ยง (Risk & Exit Rules)' : '6. Risk & Position Management'}
                </Typography>
                <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block', mt: 0.5 }}>
                  {isTh
                    ? 'SL 5,000 Points ($5.00), Breakeven SL (+10 pts) เมื่อกำไรถึง 5,000 Points ($5.00), Stepped Trailing Stop เริ่มรันที่ 10,000 Points ($10.00) ล็อกขั้นต่ำ $5.00, Hard TP 20,000 Points ($20.00)'
                    : 'SL 5,000 Points ($5.00), Breakeven (+10 pts) at $5.00 profit, and Hard TP 20,000 Points ($20.00).'}
                </Typography>
              </CardContent>
            </Card>
          </Grid>
        </Grid>
      </Paper>

      {/* --- Section 3: Full EA Input Parameter Reference Table --- */}
      <Paper sx={{ p: 3, border: '1px solid rgba(255,255,255,0.06)', bgcolor: 'background.paper' }}>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, mb: 2 }}>
          <Settings sx={{ color: '#6366f1', fontSize: 24 }} />
          <Typography variant="h6" sx={{ fontWeight: 700 }}>
            {isTh ? 'ตารางค่าพารามิเตอร์ทั้งหมดใน EA (ATS_MT5_EA.mq5)' : 'EA Input Parameters Reference (ATS_MT5_EA.mq5)'}
          </Typography>
        </Box>
        <Typography variant="body2" sx={{ color: 'text.secondary', mb: 2.5 }}>
          {isTh
            ? 'รายละเอียดและค่าเริ่มต้นของพารามิเตอร์ทั้งหมดในไฟล์ ATS_MT5_EA.mq5 ที่สามารถปรับแต่งได้ในหน้าต่าง Inputs ของ MT5:'
            : 'Complete list of configurable input parameters for ATS_MT5_EA.mq5:'}
        </Typography>

        <TableContainer sx={{ border: '1px solid rgba(255,255,255,0.06)', borderRadius: 1.5 }}>
          <Table size="small">
            <TableHead sx={{ bgcolor: 'rgba(255,255,255,0.03)' }}>
              <TableRow>
                <TableCell sx={{ fontWeight: 700, color: 'text.primary' }}>
                  {isTh ? 'กลุ่ม / พารามิเตอร์ (Parameter Name)' : 'Group / Parameter Name'}
                </TableCell>
                <TableCell sx={{ fontWeight: 700, color: 'text.primary' }}>
                  {isTh ? 'ค่าเริ่มต้น (Default)' : 'Default'}
                </TableCell>
                <TableCell sx={{ fontWeight: 700, color: 'text.primary' }}>
                  {isTh ? 'คำอธิบายและหน้าที่การทำงาน (Description)' : 'Description'}
                </TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {paramsList.map((row, idx) => (
                <TableRow key={idx} sx={{ '&:nth-of-type(odd)': { bgcolor: 'rgba(255,255,255,0.01)' } }}>
                  <TableCell sx={{ fontSize: '0.8rem', fontFamily: 'monospace' }}>
                    <Typography variant="caption" sx={{ color: '#818cf8', display: 'block', fontWeight: 600, fontSize: '0.7rem' }}>{row.group}</Typography>
                    <strong>{row.param}</strong>
                  </TableCell>
                  <TableCell sx={{ fontSize: '0.8rem', color: '#10b981', fontWeight: 600 }}>{row.defaultVal}</TableCell>
                  <TableCell sx={{ fontSize: '0.8rem', color: 'text.secondary' }}>{row.desc}</TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      </Paper>
    </Box>
  );
}
