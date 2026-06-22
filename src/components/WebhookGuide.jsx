import React, { useState } from 'react';
import {
  Box, Paper, Typography, TextField, Divider,
  Stepper, Step, StepLabel, StepContent, Chip, IconButton, Tooltip,
  Alert, Button,
} from '@mui/material';
import { ContentCopy, CheckCircle, Webhook, DeleteSweep, Science } from '@mui/icons-material';
import { clearSignals, sendTestWebhook } from '../services/api';

const STEPS = [
  {
    label: 'ทดสอบง่ายสุด — ใช้ ATS Webhook Test (แนะนำ)',
    content: (
      <Box>
        <Typography variant="body2" sx={{ color: 'text.secondary', mb: 1 }}>
          1. เปิด Pine Editor → วางไฟล์ <code style={{ color: '#818cf8' }}>tradingview/webhook_test.pine</code><br />
          2. Add to chart (indicator ทดสอบ — ไม่ใช่ strategy)<br />
          3. สร้าง Alert → Condition: <strong>🔬 Fire Test BUY</strong><br />
          4. ติ๊ก <strong>Webhook URL</strong> → <code>https://ats.thaipesleague.com/webhook</code><br />
          5. Create Alert → เปลี่ยน <strong>Fire counter</strong> จาก 0 เป็น 1<br />
          6. ถ้าเห็น label <strong>SENT</strong> บนกราฟ = script ทำงานแล้ว
        </Typography>
      </Box>
    ),
  },
  {
    label: 'รัน .NET Backend (โหมดทดสอบสัญญาณ)',
    content: (
      <Box>
        <Typography variant="body2" sx={{ color: 'text.secondary', mb: 1 }}>
          โหมดนี้รับ webhook จาก TradingView และบันทึกสัญญาณเท่านั้น — <strong>ยังไม่เปิด MT5</strong>
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
    label: 'Copy Pine Script ไปใส่ใน TradingView',
    content: (
      <Box>
        <Typography variant="body2" sx={{ color: 'text.secondary', mb: 1 }}>
          1. เปิด TradingView → Pine Editor<br />
          2. วางจากไฟล์ <code style={{ color: '#818cf8' }}>tradingview/xauusd_liquidity_sweep.pine</code><br />
          3. ตรวจว่า <strong>Webhook Auth Token</strong> ตรงกับ backend/appsettings.json<br />
          4. กด <strong>Add to chart</strong>
        </Typography>
      </Box>
    ),
  },
  {
    label: 'ทดสอบจาก Strategy หลัก (LS+Vol Bot)',
    content: (
      <Box>
        <Typography variant="body2" sx={{ color: '#fbbf24', mb: 1, fontWeight: 700 }}>
          ต้องสร้าง Alert ก่อน — กด Test ใน Settings อย่างเดียวไม่ส่ง webhook
        </Typography>
        <Typography variant="body2" sx={{ color: 'text.secondary', mb: 1 }}>
          สร้าง Alert แล้วเลือก Condition อย่างใดอย่างหนึ่ง:<br />
          • <strong>🔬 Test BUY Webhook</strong> ← แนะนำ (เลือกจาก dropdown ได้เลย)<br />
          • หรือ <strong>alert() function calls only</strong><br />
          ติ๊ก Webhook URL → <code>https://ats.thaipesleague.com/webhook</code><br />
          เปลี่ยนเลข <strong>Test BUY</strong> จาก 0 → 1 ใน Settings
        </Typography>
      </Box>
    ),
  },
  {
    label: '(Optional) ใช้ ngrok ถ้า TV ส่ง webhook จาก cloud',
    content: (
      <Box>
        <Typography variant="body2" sx={{ color: 'text.secondary', mb: 1 }}>
          TradingView ส่ง webhook จาก server ของตัวเอง — localhost ใช้ได้เฉพาะบางกรณี แนะนำ ngrok:
        </Typography>
        <Box sx={{ p: 1.5, borderRadius: 1.5, bgcolor: 'rgba(0,0,0,0.4)', fontFamily: 'monospace', fontSize: '0.8rem', color: '#a5f3fc', mb: 1 }}>
          <div>ngrok http 5000</div>
          <div style={{ color: '#fbbf24' }}># ใช้ https://xxxx.ngrok-free.app/webhook ใน Alert</div>
        </Box>
      </Box>
    ),
  },
  {
    label: 'ตรวจผลที่หน้า "สัญญาณ"',
    content: (
      <Box>
        <Typography variant="body2" sx={{ color: 'text.secondary' }}>
          เปิด Dashboard → เมนู <strong>สัญญาณ</strong> จะเห็น BUY/SELL ที่บันทึก<br />
          ทดสอบ CLOSE: เปิด toggle <strong>Test CLOSE WIN/LOSS</strong> หลัง Test BUY<br />
          ข้อมูลเก็บที่ <code style={{ color: '#818cf8' }}>backend/signals_db.json</code>
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

  const examplePayload = JSON.stringify({
    token: 'ats_sec_9f5c4b8e2a1d7f0e3c6b8a9f',
    action: 'BUY',
    symbol: 'XAUUSD',
    signal_id: '1700000000000_BUY',
    entry_price: 2650.50,
    sl: 2645.00,
    tp: 2661.00,
    rr: 2.0,
    timeframe: '5',
    bar_time: 1700000000000,
    comment: 'Sweep+MSS+Vol BUY',
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
        <Typography variant="h6" sx={{ fontWeight: 700, flexGrow: 1 }}>คู่มือทดสอบสัญญาณ (Webhook)</Typography>
        <Chip label="โหมดทดสอบ — ไม่เปิด MT5" size="small" sx={{ bgcolor: 'rgba(99,102,241,0.12)', color: '#818cf8', fontWeight: 700 }} />
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

      <Alert severity="warning" sx={{ mb: 2, bgcolor: 'rgba(245,158,11,0.08)', border: '1px solid rgba(245,158,11,0.25)', color: '#fbbf24', fontSize: '0.85rem' }}>
        ถ้ากด Test ใน TradingView แล้วไม่มีข้อมูล → ตรวจว่าสร้าง <strong>Alert แบบ alert() function calls</strong> และใส่ <strong>Webhook URL</strong> แล้วหรือยัง
      </Alert>

      <Alert severity="info" sx={{ mb: 3, bgcolor: 'rgba(99,102,241,0.08)', border: '1px solid rgba(99,102,241,0.2)', color: '#a5b4fc', fontSize: '0.8rem' }}>
        ขั้นตอนนี้ทดสอบเฉพาะ <strong>การส่งและบันทึกสัญญาณ</strong> — เมื่อมั่นใจแล้วค่อยเชื่อม MT5 + Python ในขั้นถัดไป
      </Alert>

      <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap', mb: 2 }}>
        <Button size="small" variant="contained" startIcon={<Science />} disabled={testing} onClick={() => handleDashboardTest('BUY')}>
          ทดสอบ BUY (จาก Dashboard)
        </Button>
        <Button size="small" variant="outlined" color="success" disabled={testing} onClick={() => handleDashboardTest('WIN')}>
          ทดสอบ CLOSE WIN
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

      <Typography variant="subtitle2" sx={{ fontWeight: 700, mb: 1.5 }}>ขั้นตอนการตั้งค่า</Typography>
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
        <Typography variant="subtitle2" sx={{ fontWeight: 700 }}>Webhook Payload ตัวอย่าง</Typography>
        <Button size="small" color="error" startIcon={<DeleteSweep />} onClick={handleClear}>
          ล้างสัญญาณทดสอบ
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
    </Paper>
  );
}
