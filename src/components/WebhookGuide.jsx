import React, { useState } from 'react';
import {
  Box, Paper, Typography, TextField, Button, Divider,
  Stepper, Step, StepLabel, StepContent, Chip, IconButton, Tooltip,
  Alert,
} from '@mui/material';
import { ContentCopy, CheckCircle, Webhook } from '@mui/icons-material';

const STEPS = [
  {
    label: 'Copy Pine Script ไปใส่ใน TradingView',
    content: (
      <Box>
        <Typography variant="body2" sx={{ color: 'text.secondary', mb: 1 }}>
          1. เปิด TradingView → Pine Editor (Tab ด้านล่าง)<br />
          2. วาง Pine Script จากไฟล์{' '}
          <code style={{ color: '#818cf8' }}>tradingview/xauusd_liquidity_sweep.pine</code><br />
          3. กด <strong>Add to chart</strong> (หรือ Publish เป็น Private Script)
        </Typography>
      </Box>
    ),
  },
  {
    label: 'สร้าง Alert บน TradingView',
    content: (
      <Box>
        <Typography variant="body2" sx={{ color: 'text.secondary', mb: 1 }}>
          1. คลิก <strong>Alert (⏰)</strong> บน Toolbar ด้านขวา<br />
          2. เลือก Condition: <strong>LS+Vol Bot</strong> → <strong>alert() function calls</strong><br />
          3. ในแถบ <strong>Notifications</strong> ติ๊ก <strong>Webhook URL</strong><br />
          4. วาง Webhook URL ด้านล่างลงในช่อง<br />
          5. ไม่ต้องแก้ไข Message (Script generate ให้อัตโนมัติ)
        </Typography>
      </Box>
    ),
  },
  {
    label: 'รัน Python Server',
    content: (
      <Box>
        <Typography variant="body2" sx={{ color: 'text.secondary', mb: 1 }}>
          เปิด Terminal ที่โฟลเดอร์ <code style={{ color: '#818cf8' }}>server/</code> และรัน:
        </Typography>
        <Box sx={{ p: 1.5, borderRadius: 1.5, bgcolor: 'rgba(0,0,0,0.4)', fontFamily: 'monospace', fontSize: '0.8rem', color: '#a5f3fc', mb: 1 }}>
          <div>cd server</div>
          <div>pip install -r requirements.txt</div>
          <div>copy .env.example .env</div>
          <div style={{ color: '#fbbf24' }}># แก้ไข .env ใส่ MT5_LOGIN, MT5_PASSWORD</div>
          <div>python app.py</div>
        </Box>
      </Box>
    ),
  },
  {
    label: '(Optional) ใช้ ngrok สำหรับ Public URL',
    content: (
      <Box>
        <Typography variant="body2" sx={{ color: 'text.secondary', mb: 1 }}>
          ถ้าใช้งานบนเครื่องตัวเอง (ไม่ใช่ VPS):
        </Typography>
        <Box sx={{ p: 1.5, borderRadius: 1.5, bgcolor: 'rgba(0,0,0,0.4)', fontFamily: 'monospace', fontSize: '0.8rem', color: '#a5f3fc', mb: 1 }}>
          <div style={{ color: '#94a3b8' }}># ติดตั้ง ngrok จาก https://ngrok.com</div>
          <div>ngrok http 5000</div>
          <div style={{ color: '#fbbf24' }}># Copy URL ที่ได้ เช่น https://xxxx.ngrok-free.app</div>
          <div style={{ color: '#fbbf24' }}># → ใช้ URL นี้ใน TradingView Alert</div>
        </Box>
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
      <Tooltip title={copied ? 'Copied!' : 'Copy'}>
        <IconButton onClick={copy} size="small" sx={{ color: copied ? '#10b981' : 'text.secondary' }}>
          {copied ? <CheckCircle sx={{ fontSize: 18 }} /> : <ContentCopy sx={{ fontSize: 18 }} />}
        </IconButton>
      </Tooltip>
    </Box>
  );
}

export default function WebhookGuide({ serverStatus }) {
  const localUrl   = 'http://localhost:5000/webhook';
  const examplePayload = JSON.stringify({
    token: 'your_secret_token_here',
    action: 'BUY',
    symbol: 'XAUUSD',
    sl: 2310.50,
    tp: 2340.00,
    comment: 'Sweep+MSS+Vol BUY',
  }, null, 2);

  return (
    <Paper sx={{ p: 3 }}>
      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, mb: 2 }}>
        <Webhook sx={{ color: '#818cf8', fontSize: 24 }} />
        <Typography variant="h6" sx={{ fontWeight: 700 }}>Webhook & Setup Guide</Typography>
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

      <Alert severity="info" sx={{ mb: 3, bgcolor: 'rgba(99,102,241,0.08)', border: '1px solid rgba(99,102,241,0.2)', color: '#a5b4fc', fontSize: '0.8rem' }}>
        TradingView <strong>Essential Plan ขึ้นไป</strong> เท่านั้นที่รองรับ Webhook Alert
      </Alert>

      {/* URLs */}
      <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1.5, mb: 3 }}>
        <CopyField label="Local Webhook URL (Dev)" value={localUrl} />
        <CopyField label="Webhook URL Pattern (ngrok/VPS)" value="https://YOUR-DOMAIN/webhook" />
      </Box>

      <Divider sx={{ my: 2 }} />

      {/* Setup Steps */}
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

      {/* Example Payload */}
      <Typography variant="subtitle2" sx={{ fontWeight: 700, mb: 1 }}>Webhook Payload ตัวอย่าง</Typography>
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
