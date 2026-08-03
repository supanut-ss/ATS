import React, { useState } from 'react';
import {
  Box, Paper, Typography, TextField, Divider,
  Stepper, Step, StepLabel, StepContent, Chip, IconButton, Tooltip,
  Alert, Button, Grid, Card, CardContent, Table, TableBody, TableCell,
  TableContainer, TableHead, TableRow
} from '@mui/material';
import {
  ContentCopy, CheckCircle, Construction, Description,
  TrendingUp, ShowChart, Warning, Shield, Security, Info, Settings
} from '@mui/icons-material';

const EA_STEPS = [
  {
    label: '1. อนุญาต WebRequest ในโปรแกรม MT5 (สำคัญมาก)',
    content: (
      <Box>
        <Typography variant="body2" sx={{ color: 'text.secondary', mb: 1 }}>
          เพื่อให้ EA สามารถดึงข้อมูลสัญญาณจากระบบหลังบ้านไปเปิดออเดอร์ในพอร์ตจริงได้:<br />
          1. ในโปรแกรม MT5 ไปที่เมนู <strong>Tools ➡️ Options</strong> (หรือกด <code>Ctrl + O</code>)<br />
          2. เลือกแท็บ <strong>Expert Advisors</strong><br />
          3. ติ๊กถูกที่ช่อง <strong>Allow WebRequest for listed URL:</strong><br />
          4. ดับเบิ้ลคลิกเพิ่ม URL ของหลังบ้านของคุณ (เช่น <code>https://ats.thaipesleague.com</code> หรือโดเมนที่รันจริง)<br />
          5. กด <strong>OK</strong> เพื่อบันทึก
        </Typography>
      </Box>
    ),
  },
  {
    label: '2. นำเข้าและคอมไพล์สคริปต์ EA ใน MT5',
    content: (
      <Box>
        <Typography variant="body2" sx={{ color: 'text.secondary', mb: 1 }}>
          1. ในโปรแกรม MT5 กดปุ่ม <strong>F4</strong> เพื่อเปิดโปรแกรม <strong>MetaEditor</strong><br />
          2. ในแถบ Navigator ด้านซ้าย ให้คลิกขวาที่โฟลเดอร์ <strong>Experts</strong> ➡️ เลือก <strong>Open Folder</strong><br />
          3. คัดลอกสคริปต์ EA จากโครงการของเราไปวาง: <code style={{ color: '#818cf8' }}>tradingview/ATS_MT5_EA.mq5</code><br />
          4. ดับเบิ้ลคลิกเปิดไฟล์นั้นใน MetaEditor แล้วกดปุ่ม <strong>Compile</strong> (หรือกด <code>F7</code>) ที่แถบเครื่องมือด้านบน<br />
          5. ตรวจสอบว่าไม่มีขึ้น Error แดงในหน้าต่าง Toolbox ด้านล่าง
        </Typography>
      </Box>
    ),
  },
  {
    label: '3. ติดตั้ง EA ลงบนชาร์ตทองคำ (XAUUSD)',
    content: (
      <Box>
        <Typography variant="body2" sx={{ color: 'text.secondary', mb: 1.5 }}>
          1. กลับมาที่โปรแกรม MT5 เปิดชาร์ตคู่เงิน <strong>XAUUSD (ทองคำ)</strong> ไทม์เฟรม <strong>M5</strong><br />
          2. ลากตัว EA <strong>ATS_MT5_EA</strong> จาก Navigator ด้านซ้ายมาวางบนชาร์ตทองคำ<br />
          3. ในแท็บ <strong>Inputs</strong> ปรับแต่งค่าพารามิเตอร์หลักดังนี้:
        </Typography>
        <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1, pl: 1, mb: 1.5 }}>
          <Box sx={{ fontSize: '0.8rem', color: 'text.primary', borderLeft: '3px solid #6366f1', pl: 1.5 }}>
            <strong>InpEnableWebhookPolling</strong> ➡️ เปลี่ยนเป็น <span style={{ color: '#10b981', fontWeight: 700 }}>true</span> (เปิดการรับสัญญาณผ่าน Webhook)
          </Box>
          <Box sx={{ fontSize: '0.8rem', color: 'text.primary', borderLeft: '3px solid #6366f1', pl: 1.5 }}>
            <strong>InpBackendURL</strong> ➡️ ใส่ลิงก์ API หลังบ้านของคุณ (เช่น <code>https://ats.thaipesleague.com</code>)
          </Box>
          <Box sx={{ fontSize: '0.8rem', color: 'text.primary', borderLeft: '3px solid #6366f1', pl: 1.5 }}>
            <strong>InpAuthToken</strong> ➡️ โทเค็นยืนยันตัวตน (ตรงกับ <code>appsettings.json</code>)
          </Box>
          <Box sx={{ fontSize: '0.8rem', color: 'text.primary', borderLeft: '3px solid #6366f1', pl: 1.5 }}>
            <strong>InpFixedSLPips</strong> ➡️ ระยะ SL แบบคงที่ Default <code>5000</code> Points ($5.00)
          </Box>
          <Box sx={{ fontSize: '0.8rem', color: 'text.primary', borderLeft: '3px solid #6366f1', pl: 1.5 }}>
            <strong>InpBEPips</strong> ➡️ ระยะกำไรที่เริ่มล็อกทุน Breakeven Default <code>5000</code> Points ($5.00)
          </Box>
          <Box sx={{ fontSize: '0.8rem', color: 'text.primary', borderLeft: '3px solid #6366f1', pl: 1.5 }}>
            <strong>InpTPPips</strong> ➡️ ระยะกำไรสูงสุด Take Profit Default <code>20000</code> Points ($20.00)
          </Box>
        </Box>
        <Typography variant="body2" sx={{ color: 'text.secondary', mb: 1.5 }}>
          💡 <strong>คำอธิบาย Points บน MT5:</strong> สำหรับ XAUUSD บนโบรกเกอร์ Exness 1 Point = $0.001 (100 Points = $0.10 / 10 Pips, 1,000 Points = $1.00, 5,000 Points = $5.00, 20,000 Points = $20.00)
        </Typography>
        <Typography variant="body2" sx={{ color: 'text.secondary' }}>
          4. กด <strong>OK</strong>
        </Typography>
      </Box>
    ),
  },
  {
    label: '4. เปิดใช้งานระบบเทรดอัตโนมัติ (Algo Trading)',
    content: (
      <Box>
        <Typography variant="body2" sx={{ color: 'text.secondary', mb: 1 }}>
          1. คลิกปุ่ม <strong>Algo Trading</strong> ที่แถบเครื่องมือด้านบนของโปรแกรม MT5 ให้ปุ่มเปลี่ยนเป็น <strong>สีเขียว (Play)</strong><br />
          2. สังเกตที่มุมขวาบนของชาร์ตทองคำ จะต้องมีสัญลักษณ์รูปหมวกคริสต์มาสหรือไอคอน EA เป็น <strong>สีฟ้า / มีรอยยิ้ม</strong><br />
          3. ดูแถบ <strong>Journal/Experts</strong> ด้านล่างเพื่อดูประวัติการเชื่อมต่อ (ควรขึ้นว่า <code>Initialized successfully</code>)<br />
          4. เมื่อมีสัญญาณใหม่เข้ามา EA จะยิงออเดอร์เข้า Exness ทันทีตามค่า SL/TP และปริมาณล็อตที่กำหนด
        </Typography>
      </Box>
    ),
  },
];

const EA_PARAMETERS = [
  { group: '== Webhook Connection Settings ==', param: 'InpEnableWebhookPolling', defaultVal: 'false (เปลี่ยนเป็น true)', desc: 'เปิด/ปิด ระบบดึงสัญญาณเทรดผ่าน Webhook หลังบ้าน' },
  { group: '== Webhook Connection Settings ==', param: 'InpBackendURL', defaultVal: 'https://ats.thaipesleague.com', desc: 'URL API หลังบ้านสำหรับดึงสัญญาณและส่งสถานะ' },
  { group: '== Webhook Connection Settings ==', param: 'InpAuthToken', defaultVal: 'ats_sec_9f5c4b8e2a1d7f0e3c6b8a9f', desc: 'โทเค็นลับยืนยันตัวตนกับหลังบ้าน' },
  { group: '== Webhook Connection Settings ==', param: 'InpPollInterval', defaultVal: '10000 (10 วินาที)', desc: 'รอบเวลาดึงข้อมูลจากหลังบ้าน (มิลลิวินาที)' },

  { group: '== Trade Settings ==', param: 'InpSlippage', defaultVal: '30 Points ($0.03)', desc: 'ระยะ Slippage สูงสุดที่ยอมรับได้' },
  { group: '== Trade Settings ==', param: 'InpMagic', defaultVal: '88188', desc: 'Magic Number ประจำตัว EA สำหรับแยกแยกออเดอร์' },

  { group: '== Algorithm & Entry Logic ==', param: 'InpPivotLength', defaultVal: '5 Bars', desc: 'จำนวนแท่งย้อนหลังสำหรับหาจุดสวิงกลับตัว Pivot High / Low' },
  { group: '== Algorithm & Entry Logic ==', param: 'InpSLBuffer', defaultVal: '1.0 Point', desc: 'ระยะเผื่อ Structural SL คูณด้วย SYMBOL_POINT (ไม่ใช่หน่วยราคาโดยตรง)' },
  { group: '== Algorithm & Entry Logic ==', param: 'InpPDThreshold', defaultVal: '0.618', desc: 'ระดับราคาเกณฑ์ Premium / Discount (Fibonacci 61.8%)' },
  { group: '== Algorithm & Entry Logic ==', param: 'InpEntryMode', defaultVal: 'ENTRY_MODE_DISCOUNT_ONLY (0)', desc: '0 = Discount/Premium Only, 1 = Any FVG/OB, 2 = Strict ICT' },
  { group: '== Algorithm & Entry Logic ==', param: 'InpRequireCHoCH', defaultVal: 'true', desc: 'BUY ต้องมี Bullish CHoCH และ SELL ต้องมี Bearish CHoCH ในโครงสร้างปัจจุบัน' },

  { group: '== Scalping Risk & Fixed SL ==', param: 'InpUseFixedSL', defaultVal: 'true', desc: 'เปิดใช้งาน Stop Loss แบบคงที่ (Points)' },
  { group: '== Scalping Risk & Fixed SL ==', param: 'InpFixedSLPips', defaultVal: '5000 Points ($5.00)', desc: 'ระยะ Stop Loss แบบคงที่จากจุดเข้า' },

  { group: '== Daily Loss Guard ==', param: 'InpUseDailyLossGuard', defaultVal: 'true', desc: 'หยุดเปิดไม้ใหม่เมื่อจำนวนไม้แพ้ของวันถึงขีดจำกัด' },
  { group: '== Daily Loss Guard ==', param: 'InpMaxDailyLossCount', defaultVal: '4', desc: 'จำนวนสถานะขาดทุนสูงสุดต่อวัน แยกตาม Symbol และ Magic Number' },
  { group: '== Daily Loss Guard ==', param: 'InpDailyLossTimezone', defaultVal: 'Asia/Bangkok', desc: 'เขตเวลาที่ใช้ตัดวันและรีเซ็ตตัวนับ' },

  { group: '== M5 Anti Fake-PA ==', param: 'InpPABodyMin', defaultVal: '0.35 (35%)', desc: 'สัดส่วนเนื้อเทียนขั้นต่ำเทียบกับความยาวแท่ง' },
  { group: '== M5 Anti Fake-PA ==', param: 'InpPAWickMax', defaultVal: '0.60 (60%)', desc: 'สัดส่วนไส้เทียนสูงสุดที่ยอมรับได้' },
  { group: '== M5 Anti Fake-PA ==', param: 'InpPACloseMin', defaultVal: '0.45 (45%)', desc: 'ตำแหน่งราคาปิดขั้นต่ำ (ชิดขอบแท่ง)' },
  { group: '== M5 Anti Fake-PA ==', param: 'InpPAEngulf', defaultVal: 'true', desc: 'บังคับให้เกิดแท่งกลืนกิน (Engulfing Close)' },

  { group: '== Position Sizing ==', param: 'InpFixedLot', defaultVal: '0.05 Lot', desc: 'ขนาดสัญญาในการเปิดออเดอร์แต่ละครั้ง' },

  { group: '== Trend Filters ==', param: 'InpUseEMA', defaultVal: 'true (EMA 200 M5)', desc: 'กรองเทรนด์ M5 ด้วยเส้น EMA 200' },
  { group: '== Trend Filters ==', param: 'InpUseH1Trend', defaultVal: 'true (EMA 21 H1)', desc: 'กรองเทรนด์หลักด้วย EMA 21 ในไทม์เฟรม H1' },
  { group: '== Trend Filters ==', param: 'InpUseH4Trend', defaultVal: 'true (EMA 21 H4)', desc: 'กรองเทรนด์หลักด้วย EMA 21 ในไทม์เฟรม H4' },
  { group: '== Trend Filters ==', param: 'InpFilterCounterTrend', defaultVal: 'false', desc: 'พิจารณาการสวนเทรนด์หลังผ่านตัวกรอง H1/H4 ที่เปิดใช้งานแล้ว' },

  { group: '== News & Volume Filters ==', param: 'InpUseNewsFilter', defaultVal: 'true', desc: 'เปิดใช้งานตัวกรองช่วงเวลาข่าวใหญ่' },
  { group: '== News & Volume Filters ==', param: 'InpNewsSession', defaultVal: '0300-0500,1930-2030:23456', desc: 'ช่วงเวลาบล็อกการเทรด (UTC Time)' },
  { group: '== News & Volume Filters ==', param: 'InpUseVolFilter', defaultVal: 'true', desc: 'เปิดใช้งานตัวกรองวอลลุ่มผิดปกติ (Volume Spike)' },
  { group: '== News & Volume Filters ==', param: 'InpVolSpikeMult', defaultVal: '2.0x (SMA 20)', desc: 'เกณฑ์ตัวคูณความสูงวอลลุ่มกะทันหัน' },

  { group: '== Sideway & Range Filters ==', param: 'InpUseADXFilter', defaultVal: 'true (ADX >= 20.0)', desc: 'กรองความแรงเทรนด์ (ADX ต้องไม่อยู่ในจุดซบเซา)' },
  { group: '== Sideway & Range Filters ==', param: 'InpUseChopFilter', defaultVal: 'true (CHOP <= 60.0)', desc: 'กรองตลาดไซด์เวย์บีบตัว (Choppiness Index)' },
  { group: '== Sideway & Range Filters ==', param: 'InpUseATRFilter', defaultVal: 'true (Ratio >= 0.80)', desc: 'กรองภาวะตลาดบีบตัวด้วย ATR Ratio 50 วัน' },

  { group: '== Loss Cooldown Filter ==', param: 'InpUseLossCooldown', defaultVal: 'true', desc: 'พักเปิดไม้ใหม่หลังจากสถานะล่าสุดปิดขาดทุน' },
  { group: '== Loss Cooldown Filter ==', param: 'InpLossCooldownMins', defaultVal: '60 นาที', desc: 'ระยะเวลาพักหลังไม้แพ้ ทั้งสัญญาณอัตโนมัติและ Webhook' },

  { group: '== Early Exit Management ==', param: 'InpUseEarlyExit', defaultVal: 'true', desc: 'ปิดสถานะก่อนถึง Hard SL เมื่อโครงสร้างเสีย โดย Hard SL ยังคงทำงาน' },
  { group: '== Early Exit Management ==', param: 'InpExitOnOppositeCHoCH', defaultVal: 'true', desc: 'ปิดเมื่อเกิด CHoCH ฝั่งตรงข้ามตามจำนวนแท่งยืนยัน' },
  { group: '== Early Exit Management ==', param: 'InpExitOnStructureBreak', defaultVal: 'true', desc: 'ปิดเมื่อแท่งปิดทะลุ Pivot ฝั่งป้องกัน' },
  { group: '== Early Exit Management ==', param: 'InpExitConfirmBars', defaultVal: '2 Bars', desc: 'จำนวนแท่งปิดที่ต้องยืนยันก่อน Early Exit' },
  { group: '== Early Exit Management ==', param: 'InpExitOnHTFReversal', defaultVal: 'false', desc: 'เลือกเปิดเพื่อปิดเมื่อ H1/H4 ที่ใช้งานกลับทิศพร้อมกัน' },
  { group: '== Early Exit Management ==', param: 'InpUseTimeStop / InpTimeStopBars', defaultVal: 'true / 12 Bars', desc: 'ปิดสถานะที่ยังไม่มีกำไรเมื่อถือครบจำนวนแท่ง' },
  { group: '== Early Exit Management ==', param: 'InpEarlyExitRiskR', defaultVal: '0.70R', desc: 'เมื่อมีสัญญาณเสียและขาดทุนถึงระดับนี้ ให้ปิดโดยไม่รอครบแท่งยืนยัน' },

  { group: '== Breakeven & Trailing Stop ==', param: 'InpBEPips', defaultVal: '5000 Points ($5.00)', desc: 'ระยะกำไรเริ่มย้าย SL เลื่อนมาล็อกทุน Breakeven (+10 Points)' },
  { group: '== Breakeven & Trailing Stop ==', param: 'InpTrailLevel1Pips', defaultVal: '10000 Points ($10.00)', desc: 'ระยะกำไรเริ่มเปิดใช้งาน Trailing Stop' },
  { group: '== Breakeven & Trailing Stop ==', param: 'InpTrailLevel1LockPips', defaultVal: '5000 Points ($5.00)', desc: 'ระยะล็อกกำไรขั้นต่ำของ Trailing Stop' },
  { group: '== Breakeven & Trailing Stop ==', param: 'InpUseSteppedTrail', defaultVal: 'true', desc: 'เปิด = ขยับล็อกกำไรทีละขั้นตามระยะราคา (Stepped Trailing)' },
  { group: '== Breakeven & Trailing Stop ==', param: 'InpTPPips', defaultVal: '20000 Points ($20.00)', desc: 'เป้าหมายกำไรสูงสุด Take Profit' },

  { group: '== Force Close Settings ==', param: 'InpUseForceClose', defaultVal: 'true', desc: 'เปิดใช้งานระบบบังคับปิดไม้ทั้งหมดตามเวลา' },
  { group: '== Force Close Settings ==', param: 'InpForceCloseSession', defaultVal: '0400-0405:23456 (BKK Time)', desc: 'ช่วงเวลาบังคับปิดออเดอร์เพื่อล้างความเสี่ยงข้ามคืน' },
];

function CopyField({ label, value }) {
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
      <Tooltip title={copied ? 'คัดลอกแล้ว!' : 'คัดลอก'}>
        <IconButton onClick={copy} size="small" sx={{ color: copied ? '#10b981' : 'text.secondary' }}>
          {copied ? <CheckCircle sx={{ fontSize: 18 }} /> : <ContentCopy sx={{ fontSize: 18 }} />}
        </IconButton>
      </Tooltip>
    </Box>
  );
}

export default function WebhookGuide({ serverStatus, environment = 'main', backendUrl = '' }) {
  const isDemo = environment === 'demo';
  const localUrl = isDemo ? 'http://localhost:5000/demo' : 'http://localhost:5000';
  const liveUrl = backendUrl || (isDemo ? `${window.location.origin}/demo` : window.location.origin);

  return (
    <Box sx={{ display: 'flex', flexDirection: 'column', gap: 3 }}>
      {isDemo && (
        <Alert severity="warning" variant="outlined" sx={{ borderWidth: 2 }}>
          คู่มือนี้เป็นของ <strong>Demo/Test namespace /demo บน Backend เดียวกัน</strong> ห้ามใช้ URL นี้กับ EA ระบบหลัก และควรตั้ง
          <strong> InpMagic</strong> คนละค่ากับ EA หลัก (หรือใช้บัญชี MT5 Demo แยก)
        </Alert>
      )}
      {/* --- Section 1: Guide Details --- */}
      <Paper sx={{ p: 3, border: '1px solid rgba(255,255,255,0.06)', bgcolor: 'background.paper' }}>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, mb: 2, flexWrap: 'wrap' }}>
          <Construction sx={{ color: '#6366f1', fontSize: 24 }} />
          <Typography variant="h6" sx={{ fontWeight: 700, flexGrow: 1 }}>คู่มือการติดตั้ง & ตั้งค่า EA ใน MT5</Typography>
          <Chip label="โหมดการทำงาน: MT5 Polling (v2.2)" size="small" sx={{ bgcolor: 'rgba(99,102,241,0.12)', color: '#818cf8', fontWeight: 700 }} />
          <Chip
            label={serverStatus ? '● Server Online' : '○ Server Offline'}
            size="small"
            sx={{
              bgcolor: serverStatus ? 'rgba(16,185,129,0.1)' : 'rgba(244,63,94,0.1)',
              color:   serverStatus ? '#10b981' : '#f43f5e',
              fontWeight: 700,
            }}
          />
        </Box>

        <Alert severity="warning" sx={{ mb: 3, bgcolor: 'rgba(245,158,11,0.08)', border: '1px solid rgba(245,158,11,0.2)', color: '#fbbf24', fontSize: '0.85rem' }}>
          <strong>ข้อสำคัญ:</strong> คุณจำเป็นต้องเข้าไปเปลี่ยนค่าพารามิเตอร์ <strong>InpEnableWebhookPolling</strong> ให้เป็น <strong>true</strong> ในส่วนของ Inputs ตอนติดตั้ง EA บนชาร์ต เพราะค่าเริ่มต้นคือ false หากไม่เปลี่ยนตัว EA จะไม่ดึงสัญญาณการซื้อขายจากหลังบ้าน
        </Alert>

        <Typography variant="subtitle2" sx={{ fontWeight: 700, mb: 2 }}>คัดลอกลิงก์เพื่อใส่ใน InpBackendURL</Typography>
        <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1.5, mb: 3 }}>
          <CopyField label="Backend Base URL (Local)" value={localUrl} />
          <CopyField label="Backend Base URL (เซิร์ฟเวอร์จริง)" value={liveUrl} />
          <CopyField label="TradingView Webhook URL" value={`${liveUrl}/webhook`} />
        </Box>

        <Divider sx={{ my: 3 }} />

        <Typography variant="subtitle2" sx={{ fontWeight: 700, mb: 2 }}>ลำดับขั้นตอนการติดตั้ง</Typography>
        <Stepper orientation="vertical" nonLinear sx={{ '& .MuiStepLabel-label': { fontWeight: 600 } }}>
          {EA_STEPS.map((step, i) => (
            <Step key={i} active>
              <StepLabel>{step.label}</StepLabel>
              <StepContent sx={{ borderLeft: '1px solid rgba(255,255,255,0.08)' }}>
                {step.content}
              </StepContent>
            </Step>
          ))}
        </Stepper>
      </Paper>

      {/* --- Section 2: Strategy Logic Summary --- */}
      <Paper sx={{ p: 3, border: '1px solid rgba(255,255,255,0.06)', bgcolor: 'background.paper' }}>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, mb: 2.5 }}>
          <Description sx={{ color: '#10b981', fontSize: 24 }} />
          <Typography variant="h6" sx={{ fontWeight: 700 }}>สรุปตรรกะการคำนวณและเทรดของ EA (Pure Structure v2.2)</Typography>
        </Box>

        <Typography variant="body2" sx={{ color: 'text.secondary', mb: 3 }}>
          สคริปต์ EA (<code style={{ color: '#818cf8' }}>ATS_MT5_EA.mq5</code>) รวบรวมอัลกอริทึมการวิเคราะห์โครงสร้างตลาดและโซนราคาแบบอัจฉริยะ (SMC/ICT) บนกราฟ M5 โดยมีตรรกะการเทรดที่ทำงาน 6 ชั้นดังนี้:
        </Typography>

        <Grid container spacing={2}>
          <Grid item xs={12} sm={6}>
            <Card sx={{ bgcolor: 'rgba(255,255,255,0.01)', border: '1px solid rgba(255,255,255,0.03)', height: '100%' }}>
              <CardContent sx={{ p: 2 }}>
                <Typography variant="subtitle2" sx={{ fontWeight: 700, color: '#818cf8', display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
                  <TrendingUp sx={{ fontSize: 18 }} />
                  1. โครงสร้างตลาดระดับย่อย (Market Structure)
                </Typography>
                <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block', mt: 0.5 }}>
                  ตรวจจับ Pivot High / Low 5 แท่นเทียนย้อนหลัง เพื่อหาจุด <strong>BOS (Break of Structure)</strong> ตามเทรนด์ และ <strong>CHoCH (Change of Character)</strong> จับสัญญาณเปลี่ยนเทรนด์
                </Typography>
              </CardContent>
            </Card>
          </Grid>

          <Grid item xs={12} sm={6}>
            <Card sx={{ bgcolor: 'rgba(255,255,255,0.01)', border: '1px solid rgba(255,255,255,0.03)', height: '100%' }}>
              <CardContent sx={{ p: 2 }}>
                <Typography variant="subtitle2" sx={{ fontWeight: 700, color: '#818cf8', display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
                  <ShowChart sx={{ fontSize: 18 }} />
                  2. โซนราคา FVG & Order Block (OB)
                </Typography>
                <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block', mt: 0.5 }}>
                  วางกรอบ <strong>Fair Value Gap (FVG)</strong> และ <strong>Order Blocks (OB)</strong> รองรับการเลือกโหมดเข้าเทรด (`InpEntryMode`): Discount Only, Any FVG/OB, หรือ Strict ICT
                </Typography>
              </CardContent>
            </Card>
          </Grid>

          <Grid item xs={12} sm={6}>
            <Card sx={{ bgcolor: 'rgba(255,255,255,0.01)', border: '1px solid rgba(255,255,255,0.03)', height: '100%' }}>
              <CardContent sx={{ p: 2 }}>
                <Typography variant="subtitle2" sx={{ fontWeight: 700, color: '#818cf8', display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
                  <Security sx={{ fontSize: 18 }} />
                  3. พื้นที่ Premium / Discount Zone
                </Typography>
                <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block', mt: 0.5 }}>
                  กรองราคาสวิงด้วย Fibonacci 0.618: BUY เมื่อราคายูในเขต <strong>Discount</strong> (ต่ำกว่า 61.8%) และ SELL เมื่อราคาอยู่ในเขต <strong>Premium</strong> (สูงกว่า 61.8%)
                </Typography>
              </CardContent>
            </Card>
          </Grid>

          <Grid item xs={12} sm={6}>
            <Card sx={{ bgcolor: 'rgba(255,255,255,0.01)', border: '1px solid rgba(255,255,255,0.03)', height: '100%' }}>
              <CardContent sx={{ p: 2 }}>
                <Typography variant="subtitle2" sx={{ fontWeight: 700, color: '#818cf8', display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
                  <Info sx={{ fontSize: 18 }} />
                  4. ตัวกรองตลาด Multi-Filter
                </Typography>
                <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block', mt: 0.5 }}>
                  กรอง 5 ชั้น: <strong>M5 EMA 200 + H1/H4 EMA 21</strong>, <strong>ADX &ge; 20</strong>, <strong>Choppiness &le; 60</strong> (เลี่ยง Sideway), <strong>ATR Ratio &ge; 0.80</strong> และ <strong>News/Volume Spike Filter</strong>
                </Typography>
              </CardContent>
            </Card>
          </Grid>

          <Grid item xs={12} sm={6}>
            <Card sx={{ bgcolor: 'rgba(255,255,255,0.01)', border: '1px solid rgba(255,255,255,0.03)', height: '100%' }}>
              <CardContent sx={{ p: 2 }}>
                <Typography variant="subtitle2" sx={{ fontWeight: 700, color: '#818cf8', display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
                  <Shield sx={{ fontSize: 18 }} />
                  5. Anti Fake-PA Candle Confirmation
                </Typography>
                <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block', mt: 0.5 }}>
                  คำนวณ 4 สัดส่วนแท่งเทียนก่อนเข้า: <strong>Body Min 35%</strong>, <strong>Wick Max 60%</strong>, <strong>Close Position Min 45%</strong> และ <strong>Engulfing Close</strong> ป้องกันจุดเข้าหลอก
                </Typography>
              </CardContent>
            </Card>
          </Grid>

          <Grid item xs={12} sm={6}>
            <Card sx={{ bgcolor: 'rgba(255,255,255,0.01)', border: '1px solid rgba(255,255,255,0.03)', height: '100%' }}>
              <CardContent sx={{ p: 2 }}>
                <Typography variant="subtitle2" sx={{ fontWeight: 700, color: '#818cf8', display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
                  <Warning sx={{ fontSize: 18 }} />
                  6. ระบบจัดการความเสี่ยง (Risk & Exit Rules)
                </Typography>
                <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block', mt: 0.5 }}>
                  <strong>SL 5,000 Points ($5.00)</strong>, <strong>Breakeven SL (+10 pts)</strong> เมื่อกำไรถึง 5,000 Points ($5.00), <strong>Stepped Trailing Stop</strong> เริ่มรันที่ 10,000 Points ($10.00) ล็อกขั้นต่ำ $5.00, <strong>Hard TP 20,000 Points ($20.00)</strong> และระบบ Force Close 04:00-04:05 น.
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
          <Typography variant="h6" sx={{ fontWeight: 700 }}>ตารางค่าพารามิเตอร์ทั้งหมดใน EA (ATS_MT5_EA.mq5 Reference)</Typography>
        </Box>
        <Typography variant="body2" sx={{ color: 'text.secondary', mb: 2.5 }}>
          รายละเอียดและค่าเริ่มต้นของพารามิเตอร์ทั้งหมดในไฟล์ <code style={{ color: '#818cf8' }}>ATS_MT5_EA.mq5</code> ที่สามารถปรับแต่งได้ในหน้าต่าง Inputs ของ MT5:
        </Typography>

        <TableContainer sx={{ border: '1px solid rgba(255,255,255,0.06)', borderRadius: 1.5 }}>
          <Table size="small">
            <TableHead sx={{ bgcolor: 'rgba(255,255,255,0.03)' }}>
              <TableRow>
                <TableCell sx={{ fontWeight: 700, color: 'text.primary' }}>กลุ่ม / พารามิเตอร์ (Parameter Name)</TableCell>
                <TableCell sx={{ fontWeight: 700, color: 'text.primary' }}>ค่าเริ่มต้น (Default)</TableCell>
                <TableCell sx={{ fontWeight: 700, color: 'text.primary' }}>คำอธิบายและหน้าที่การทำงาน (Description)</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {EA_PARAMETERS.map((row, idx) => (
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
