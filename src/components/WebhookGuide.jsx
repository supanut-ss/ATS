import React, { useState } from 'react';
import {
  Box, Paper, Typography, TextField, Divider,
  Stepper, Step, StepLabel, StepContent, Chip, IconButton, Tooltip,
  Alert, Button, Grid, Card, CardContent
} from '@mui/material';
import {
  ContentCopy, CheckCircle, Construction, Description,
  TrendingUp, ShowChart, Warning, Shield, Security, Info
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
          4. ดับเบิ้ลคลิกเพิ่ม URL ของหลังบ้านของคุณ (เช่น <code>http://localhost:5000</code> หรือโดเมนที่รันจริง)<br />
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
            <strong>InpBackendURL</strong> ➡️ ใส่ลิงก์ API หลังบ้านของคุณ (เช่น <code>http://localhost:5000</code> หรือโดเมนเว็บหลัก)
          </Box>
          <Box sx={{ fontSize: '0.8rem', color: 'text.primary', borderLeft: '3px solid #6366f1', pl: 1.5 }}>
            <strong>InpAuthToken</strong> ➡️ โทเค็นยืนยันตัวตน (ต้องตรงกันกับ <code>appsettings.json</code>)
          </Box>
          <Box sx={{ fontSize: '0.8rem', color: 'text.primary', borderLeft: '3px solid #6366f1', pl: 1.5 }}>
            <strong>InpPollInterval</strong> ➡️ รอบเวลาการดึงข้อมูล (ค่าเริ่มต้น <code>10000</code> ms หรือ 10 วินาที)
          </Box>
        </Box>
        <Typography variant="body2" sx={{ color: 'text.secondary', mb: 1.5 }}>
          💡 <strong>หมายเหตุ:</strong> ตัว EA ได้ใส่คำอธิบายการตั้งค่าพารามิเตอร์เป็นภาษาไทยทั้งหมดไว้เรียบร้อยแล้ว ซึ่งจะแสดงผลทันทีบนหน้าต่าง Inputs ในโปรแกรม MT5 (เช่น Slippage, Magic, Stop Loss, Multi-Timeframe filters, Sideway filters) เพื่อให้ปรับแต่งได้สะดวกยิ่งขึ้น
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
          4. เมื่อมีสัญญาณใหม่เข้ามา EA จะยิงออเดอร์เข้า Exness ทันทีตามค่า SL/TP และปริมาณล็อตที่ TradingView คำนวณส่งมา
        </Typography>
      </Box>
    ),
  },
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

export default function WebhookGuide({ serverStatus }) {
  const localUrl = 'http://localhost:5000';
  const liveUrl = window.location.origin;

  return (
    <Box sx={{ display: 'flex', flexDirection: 'column', gap: 3 }}>
      {/* --- Section 1: Guide Details --- */}
      <Paper sx={{ p: 3, border: '1px solid rgba(255,255,255,0.06)', bgcolor: 'background.paper' }}>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, mb: 2, flexWrap: 'wrap' }}>
          <Construction sx={{ color: '#6366f1', fontSize: 24 }} />
          <Typography variant="h6" sx={{ fontWeight: 700, flexGrow: 1 }}>คู่มือการติดตั้ง & ตั้งค่า EA ใน MT5</Typography>
          <Chip label="โหมดการทำงาน: MT5 Polling" size="small" sx={{ bgcolor: 'rgba(99,102,241,0.12)', color: '#818cf8', fontWeight: 700 }} />
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
          <Typography variant="h6" sx={{ fontWeight: 700 }}>สรุปตรรกะการคำนวณและเทรดของ EA (Pure Structure Logic)</Typography>
        </Box>

        <Typography variant="body2" sx={{ color: 'text.secondary', mb: 3 }}>
          สคริปต์ EA (<code style={{ color: '#818cf8' }}>ATS_MT5_EA.mq5</code>) ได้รวบรวมอัลกอริทึมการวิเคราะห์โครงสร้างตลาดและโซนราคาแบบอัจฉริยะ (SMC/ICT) บนกราฟ M5 โดยมีตรรกะการเทรดที่ทำงานดังต่อไปนี้:
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
                  ตรวจสอบหาจุดกลับตัว Pivot High และ Pivot Low ในระยะ 5 แท่งเทียน เพื่อตรวจจับการทำลายโครงสร้างราคาหลักและย่อย
                  ได้แก่ <strong>BOS (Break of Structure)</strong> เพื่อมองหาจุดรันเทรนด์ต่อเนื่อง และ <strong>CHoCH (Change of Character)</strong> เพื่อจับสัญญาณการกลับตัวของราคาทองคำ
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
                  คำนวณและวางกรอบโซน <strong>Fair Value Gap (FVG)</strong> (ช่องว่างสภาพคล่องราคา) และ <strong>Order Blocks (OB)</strong> จากแท่งเทียนฝั่งตรงข้ามล่าสุดก่อนเกิดการดีดตัวของราคา เพื่อเป็นจุดอ้างอิงในการเข้าเทรดเมื่อราคาย้อนกลับมาทดสอบโซน (Retest)
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
                  กรองจุดซื้อขายด้วย Fibonacci Discount/Premium: จะเปิดสัญญาณ <strong>BUY</strong> เฉพาะเมื่อราคาย่อตัวลงมาสู่เขต <strong>Discount Area</strong> (ต่ำกว่า 61.8% ของกรอบสวิงล่าง) และจะเปิดสัญญาณ <strong>SELL</strong> เฉพาะเมื่อราคาขึ้นไปอยู่เขต <strong>Premium Area</strong> เท่านั้น
                </Typography>
              </CardContent>
            </Card>
          </Grid>

          <Grid item xs={12} sm={6}>
            <Card sx={{ bgcolor: 'rgba(255,255,255,0.01)', border: '1px solid rgba(255,255,255,0.03)', height: '100%' }}>
              <CardContent sx={{ p: 2 }}>
                <Typography variant="subtitle2" sx={{ fontWeight: 700, color: '#818cf8', display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
                  <Info sx={{ fontSize: 18 }} />
                  4. ตัวกรองตลาด & วอลลุ่ม (Market Filters)
                </Typography>
                <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block', mt: 0.5 }}>
                  กรองสัญญาณด้วยอินดิเคเตอร์ 4 ชั้น: <strong>EMA 200 (M5) & H1/H4 Trend</strong> (ห้ามเทรดสวนเทรนด์หลัก), <strong>ADX Filter</strong> (ต้องมีเทรนด์ ADX &ge; 20), <strong>Choppiness Index</strong> (หลีกเลี่ยงไซด์เวย์บีบตัว Chop &le; 60) และ <strong>ATR Volatility Ratio</strong> (ความผันผวนต้องไม่อยู่ในจุด Squeeze ต่ำกว่า 80% ของค่าเฉลี่ย)
                </Typography>
              </CardContent>
            </Card>
          </Grid>

          <Grid item xs={12} sm={6}>
            <Card sx={{ bgcolor: 'rgba(255,255,255,0.01)', border: '1px solid rgba(255,255,255,0.03)', height: '100%' }}>
              <CardContent sx={{ p: 2 }}>
                <Typography variant="subtitle2" sx={{ fontWeight: 700, color: '#818cf8', display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
                  <Shield sx={{ fontSize: 18 }} />
                  5. Price Action คอนเฟิร์ม (Candle confirmation)
                </Typography>
                <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block', mt: 0.5 }}>
                  ใช้สัญญาณรูปแบบแท่งเทียนปิดเพื่อคอนเฟิร์มการกลับตัวที่แท้จริง โดยคำนวณสัดส่วนของเนื้อเทียนเทียบกับไส้เทียน (Body/Wick ratio) และตัวเลือกการเกิด Engulfing เพื่อหลีกเลี่ยงจุดกลับตัวหลอกในไทม์เฟรม M5
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
                  เมื่อเปิดออเดอร์แล้ว EA จะคอยรันระบบป้องกันความเสี่ยง: <strong>Breakeven SL</strong> (เมื่อกำไรพ้น 500 จุด จะเลื่อน SL ล็อคหน้าทุน + 10 จุดทันที) และ <strong>Trailing Stop</strong> (เมื่อมีกำไรสะสม 1000 จุดขึ้นไป จะขยับเลื่อนตามระยะห่างเพื่อล็อคกำไรสูงสุด) พร้อมระบบปิดออเดอร์อัตโนมัติเมื่อหมดวันหรือชนช่วงข่าวใหญ่
                </Typography>
              </CardContent>
            </Card>
          </Grid>
        </Grid>
      </Paper>
    </Box>
  );
}
