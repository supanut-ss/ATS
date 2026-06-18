import React, { useEffect, useRef } from 'react';
import { Box, Paper } from '@mui/material';

export default function TradingViewChart() {
  const containerRef = useRef(null);

  useEffect(() => {
    if (!containerRef.current) return;
    // Clear previous widget
    containerRef.current.innerHTML = '';

    const script = document.createElement('script');
    script.src = 'https://s3.tradingview.com/external-embedding/embed-widget-advanced-chart.js';
    script.async = true;
    script.innerHTML = JSON.stringify({
      autosize:        true,
      symbol:          'OANDA:XAUUSD',
      interval:        'M5',
      timezone:        'Asia/Bangkok',
      theme:           'dark',
      style:           '1',
      locale:          'en',
      allow_symbol_change: false,
      save_image:      true,
      calendar:        false,
      hide_side_toolbar: false,
      studies: [
        'STD;Volume',
        'STD;EMA',
        'STD;RSI',
      ],
      support_host: 'https://www.tradingview.com',
    });

    const container = document.createElement('div');
    container.className = 'tradingview-widget-container__widget';
    container.style.height = '100%';
    container.style.width = '100%';

    containerRef.current.appendChild(container);
    containerRef.current.appendChild(script);

    return () => {
      if (containerRef.current) {
        containerRef.current.innerHTML = '';
      }
    };
  }, []);

  return (
    <Paper sx={{ p: 0, overflow: 'hidden', height: 520, border: '1px solid rgba(255,255,255,0.06)' }}>
      <Box
        ref={containerRef}
        className="tradingview-widget-container"
        sx={{ height: '100%', width: '100%' }}
      />
    </Paper>
  );
}
