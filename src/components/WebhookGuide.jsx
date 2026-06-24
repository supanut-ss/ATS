import React, { useState } from 'react';
import {
  Box, Paper, Typography, TextField, Divider,
  Stepper, Step, StepLabel, StepContent, Chip, IconButton, Tooltip,
  Alert, Button, Tabs, Tab
} from '@mui/material';
import { ContentCopy, CheckCircle, Webhook, DeleteSweep, Science, PlayCircleFilled } from '@mui/icons-material';
import { clearSignals, sendTestWebhook } from '../services/api';

const STEPS = [
  {
    label: 'ทดสอบง่ายสุด — ใช้ ATS Webhook Test (แนะนำ)',
    content: (
      <Box>
        <Typography variant="body2" sx={{ color: 'text.secondary', mb: 1 }}>
          1. เปิด Pine Editor ➡️ วางไฟล์ <code style={{ color: '#818cf8' }}>tradingview/webhook_test.pine</code><br />
          2. Add to chart (indicator ทดสอบ — ไม่ใช่ strategy)<br />
          3. สร้าง Alert ➡️ Condition: <strong>🔬 Fire Test BUY</strong><br />
          4. ติ๊ก <strong>Webhook URL</strong> ➡️ <code>https://ats.thaipesleague.com/webhook</code> (หรือ ngrok)<br />
          5. Create Alert ➡️ เปลี่ยน <strong>Fire counter</strong> จาก 0 เป็น 1 เพื่อยิงทดสอบ<br />
          6. ถ้าเห็น label <strong>SENT</strong> บนกราฟ = script ส่งสัญญาณสำเร็จแล้ว
        </Typography>
      </Box>
    ),
  },
  {
    label: 'รัน .NET Backend (โหมดทดสอบ)',
    content: (
      <Box>
        <Typography variant="body2" sx={{ color: 'text.secondary', mb: 1 }}>
          รันหลังบ้านเพื่อพร้อมรอรับสัญญาณจาก TradingView:
        </Typography>
        <Box sx={{ p: 1.5, borderRadius: 1.5, bgcolor: 'rgba(0,0,0,0.4)', fontFamily: 'monospace', fontSize: '0.8rem', color: '#a5f3fc', mb: 1 }}>
          <div>cd backend</div>
          <div>dotnet run</div>
          <div style={{ color: '#94a3b8' }}># Server: http://localhost:5000</div>
        </Box>
      </Box>
    ),
  },
  {
    label: 'ใส่ Pine Script บน TradingView',
    content: (
      <Box>
        <Typography variant="body2" sx={{ color: 'text.secondary', mb: 1 }}>
          1. เปิด TradingView ➡️ Pine Editor<br />
          2. วางโค้ดจากไฟล์ <code style={{ color: '#818cf8' }}>tradingview/pure_structure.pine</code> หรือ <code style={{ color: '#818cf8' }}>xauusd_liquidity_sweep.pine</code><br />
          3. ตรวจว่า <strong>Webhook Auth Token</strong> ตรงกันกับหลังบ้าน<br />
          4. กด <strong>Add to chart</strong>
        </Typography>
      </Box>
    ),
  },
  {
    label: 'ทดสอบจาก Strategy หลัก',
    content: (
      <Box>
        <Typography variant="body2" sx={{ color: '#fbbf24', mb: 1, fontWeight: 700 }}>
          ต้องสร้าง Alert บนชาร์ตก่อน — การเปลี่ยนตั้งค่าใน Settings เฉยๆ จะไม่ยิง webhook
        </Typography>
        <Typography variant="body2" sx={{ color: 'text.secondary', mb: 1 }}>
          สร้าง Alert แล้วเลือก Condition:<br />
          • เลือกชื่อของ <strong>Strategy</strong> ➡️ ตั้งค่าเป็น <strong>alert() function calls only</strong><br />
          • ติ๊กช่อง Webhook URL ➡️ ใส่ลิงก์หลังบ้านของคุณ<br />
          • เมื่อเกิดจุดเทรดจริง สัญญาณจะส่งเข้าคิว PENDING ในระบบหลังบ้านทันที
        </Typography>
      </Box>
    ),
  },
  {
    label: '(Optional) ใช้ ngrok หากเปิดรันในคอมตัวเอง',
    content: (
      <Box>
        <Typography variant="body2" sx={{ color: 'text.secondary', mb: 1 }}>
          เนื่องจาก TradingView เป็นระบบคลาวด์ จึงส่งเข้า IP คอมคุณตรงๆ ไม่ได้ ต้องเชื่อมท่อ ngrok:
        </Typography>
        <Box sx={{ p: 1.5, borderRadius: 1.5, bgcolor: 'rgba(0,0,0,0.4)', fontFamily: 'monospace', fontSize: '0.8rem', color: '#a5f3fc', mb: 1 }}>
          <div>ngrok http 5000</div>
          <div style={{ color: '#fbbf24' }}># ใช้ลิงก์ https://xxxx.ngrok-free.app/webhook ในช่อง Webhook URL</div>
        </Box>
      </Box>
    ),
  },
  {
    label: 'ตรวจผลสัญญาณเข้าคิว',
    content: (
      <Box>
        <Typography variant="body2" sx={{ color: 'text.secondary' }}>
          เปิดมาที่เมนู <strong>สัญญาณ (Signals)</strong> ด้านซ้าย จะเห็นสถานะ `PENDING_BUY` หรือ `PENDING_SELL` รอให้ EA บน MT5 มาหยิบไปรัน
        </Typography>
      </Box>
    ),
  },
];

const EA_STEPS = [
  {
    label: '1. อนุญาต WebRequest ในโปรแกรม MT5 (สำคัญมาก)',
    content: (
      <Box>
        <Typography variant="body2" sx={{ color: 'text.secondary', mb: 1 }}>
          เพื่อให้ EA ส่ง/รับข้อมูลสัญญาณจากระบบหลังบ้านได้:<br />
          1. ในโปรแกรม MT5 ไปที่เมนู <strong>Tools ➡️ Options</strong> (หรือกด <code>Ctrl + O</code>)<br />
          2. เลือกแท็บ <strong>Expert Advisors</strong><br />
          3. ติ๊กถูกที่ช่อง <strong>Allow WebRequest for listed URL:</strong><br />
          4. ดับเบิ้ลคลิกเพิ่ม URL ของหลังบ้าน C# ของคุณ (เช่น <code>http://localhost:5000</code> หรือโดเมนที่รันจริง)<br />
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
          5. ตรวจสอบว่าไม่มีขึ้น Error แดงที่หน้าต่างด้านล่าง
        </Typography>
      </Box>
    ),
  },
  {
    label: '3. ติดตั้ง EA ลงบนชาร์ตทองคำ (XAUUSD)',
    content: (
      <Box>
        <Typography variant="body2" sx={{ color: 'text.secondary', mb: 1 }}>
          1. กลับมาที่โปรแกรม MT5 เปิดชาร์ตคู่เงิน <strong>XAUUSD (ทองคำ)</strong> ไทม์เฟรม <strong>M5</strong><br />
          2. ลากตัว EA <strong>ATS_MT5_EA</strong> จาก Navigator ด้านซ้ายมาวางบนชาร์ต<br />
          3. ในแท็บ <strong>Inputs</strong> ให้กรอกข้อมูลการตั้งค่า:<br />
          &nbsp;&nbsp;&bull; <code>InpBackendURL</code>: ลิงก์ API หลังบ้านของคุณ (เช่น <code>http://localhost:5000</code>)<br />
          &nbsp;&nbsp;&bull; <code>InpAuthToken</code>: โทเค็นยืนยันตัวตน (ต้องตรงกันกับ <code>appsettings.json</code>)<br />
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

export default function WebhookGuide({ serverStatus, onRefresh }) {
  const webhookUrl = `${window.location.origin}/webhook`;
  const localUrl   = 'http://localhost:5000/webhook';
  const [testing, setTesting] = useState(false);
  const [testMsg, setTestMsg] = useState(null);
  const [tabIndex, setTabIndex] = useState(0);

  const examplePayload = JSON.stringify({
    token: 'ats_sec_9f5c4b8e2a1d7f0e3c6b8a9f',
    action: 'BUY',
    symbol: 'XAUUSD',
    signal_id: '1700000000000_BUY',
    entry_price: 2400.50,
    sl: 2390.50,
    tp: 2415.50,
    volume: 0.01,
    rr: 1.5,
    timeframe: '5',
    bar_time: 1700000000000,
    comment: 'Pure Structure BUY',
  }, null, 2);

  const handleClear = async () => {
    if (!confirm('ล้างสัญญาณทั้งหมด?')) return;
    const res = await clearSignals();
    if (res.ok) {
      onRefresh?.();
    } else {
      alert(res.data?.error || 'ล้างสัญญาณไม่สำเร็จ');
    }
  };

  const handleDashboardTest = async (action) => {
    setTesting(true);
    setTestMsg(null);
    try {
      const res = await sendTestWebhook(action);
      if (res.ok && res.data?.ok) {
        setTestMsg({ ok: true, text: res.data.message || 'ส่งสำเร็จ — ดูที่หน้าสัญญาณ' });
        onRefresh?.();
      } else {
        setTestMsg({ ok: false, text: res.data?.error || 'ส่งไม่สำเร็จ' });
      }
    } finally {
      setTesting(false);
    }
  };

  return (
    <Paper sx={{ p: 3 }}>
      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, mb: 2, flexWrap: 'wrap' }}>
        <Webhook sx={{ color: '#818cf8', fontSize: 24 }} />
        <Typography variant="h6" sx={{ fontWeight: 700, flexGrow: 1 }}>คู่มือการเชื่อมต่อ & ตั้งค่าระบบ</Typography>
        <Chip label="โหมดการทำงาน: MQL5 EA" size="small" sx={{ bgcolor: 'rgba(99,102,241,0.12)', color: '#818cf8', fontWeight: 700 }} />
        <Chip
          label={serverStatus ? '● Backend Online' : '○ Backend Offline'}
          size="small"
          sx={{
            bgcolor: serverStatus ? 'rgba(16,185,129,0.1)' : 'rgba(244,63,94,0.1)',
            color:   serverStatus ? '#10b981' : '#f43f5e',
            fontWeight: 700,
          }}
        />
      </Box>

      <Tabs value={tabIndex} onChange={(e, val) => setTabIndex(val)} sx={{ borderBottom: '1px solid rgba(255,255,255,0.08)', mb: 3 }}>
        <Tab label="1. ตั้งค่า Webhook (TradingView)" sx={{ fontWeight: 700 }} />
        <Tab label="2. ติดตั้ง EA (บน MT5)" sx={{ fontWeight: 700 }} />
      </Tabs>

      {tabIndex === 0 ? (
        <Box>
          <Alert severity="warning" sx={{ mb: 2, bgcolor: 'rgba(245,158,11,0.08)', border: '1px solid rgba(245,158,11,0.25)', color: '#fbbf24', fontSize: '0.85rem' }}>
            เมื่อกดส่งข้อความใน TradingView ต้องระบุเป็น <strong>alert() function calls</strong> หรือ <strong>Strategy Alert</strong> เท่านั้น
          </Alert>

          <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap', mb: 2 }}>
            <Button size="small" variant="contained" startIcon={<Science />} disabled={testing} onClick={() => handleDashboardTest('BUY')}>
              ทดสอบ BUY (เข้าคิว PENDING_BUY)
            </Button>
            <Button size="small" variant="outlined" color="success" disabled={testing} onClick={() => handleDashboardTest('WIN')}>
              ทดสอบ CLOSE (เข้าคิว PENDING_CLOSE)
            </Button>
          </Box>
          {testMsg && (
            <Alert severity={testMsg.ok ? 'success' : 'error'} sx={{ mb: 2, fontSize: '0.8rem' }}>
              {testMsg.text}
            </Alert>
          )}

          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1.5, mb: 3 }}>
            <CopyField label="Webhook URL (Local)" value={localUrl} />
            <CopyField label="Webhook URL (เมื่อ deploy)" value={webhookUrl} />
          </Box>

          <Divider sx={{ my: 2 }} />

          <Typography variant="subtitle2" sx={{ fontWeight: 700, mb: 1.5 }}>ขั้นตอนการส่งคำสั่ง Webhook</Typography>
          <Stepper orientation="vertical" nonLinear sx={{ '& .MuiStepLabel-label': { fontWeight: 600 } }}>
            {STEPS.map((step, i) => (
              <Step key={i} active>
                <StepLabel>{step.label}</StepLabel>
                <StepContent sx={{ borderLeft: '1px solid rgba(255,255,255,0.08)' }}>
                  {step.content}
                </StepContent>
              </Step>
            ))}
          </Stepper>

          <Divider sx={{ my: 2 }} />

          <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 1 }}>
            <Typography variant="subtitle2" sx={{ fontWeight: 700 }}>Webhook JSON Payload ตัวอย่าง</Typography>
            <Button size="small" color="error" startIcon={<DeleteSweep />} onClick={handleClear}>
              ล้างสัญญาณทั้งหมด
            </Button>
          </Box>
          <Box sx={{
            p: 2, borderRadius: 2, bgcolor: 'rgba(0,0,0,0.4)',
            fontFamily: 'monospace', fontSize: '0.78rem', color: '#a5f3fc',
            border: '1px solid rgba(255,255,255,0.06)', whiteSpace: 'pre',
            overflow: 'auto',
          }}>
            {examplePayload}
          </Box>
        </Box>
      ) : (
        <Box>
          <Alert severity="info" sx={{ mb: 3, bgcolor: 'rgba(99,102,241,0.08)', border: '1px solid rgba(99,102,241,0.2)', color: '#a5b4fc', fontSize: '0.85rem' }}>
            ตัว EA จะรันอยู่บน MT5 เพื่อคอยดึงสัญญาณจากหลังบ้าน C# ไปเปิด-ปิดออเดอร์ในพอร์ตจริงแบบอัตโนมัติ
          </Alert>

          <Typography variant="subtitle2" sx={{ fontWeight: 700, mb: 1.5 }}>ขั้นตอนการติดตั้ง EA บนโปรแกรม MetaTrader 5</Typography>
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
        </Box>
      )}
    </Paper>
  );
}
