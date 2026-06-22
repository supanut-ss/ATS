import urllib.request
import json
import time
import ssl

url = "https://ats.thaipesleague.com/webhook"
headers = {'Content-Type': 'application/json'}
context = ssl._create_unverified_context()

def send_signal(payload, description):
    print(f"\n--- {description} ---")
    req = urllib.request.Request(url, data=json.dumps(payload).encode('utf-8'), headers=headers)
    try:
        with urllib.request.urlopen(req, context=context) as res:
            print("Response:", res.read().decode('utf-8'))
    except Exception as e:
        print("Error:", e)
    time.sleep(1)

# Scenarios
# 1. Trade 1: BUY (WIN)
send_signal({
    "token": "ats_sec_9f5c4b8e2a1d7f0e3c6b8a9f",
    "action": "BUY",
    "symbol": "XAUUSD",
    "entry_price": 2315.00,
    "sl": 2305.00,
    "tp": 2335.00,
    "comment": "Trade 1: Support Sweep"
}, "Sending Trade 1 - BUY")

send_signal({
    "token": "ats_sec_9f5c4b8e2a1d7f0e3c6b8a9f",
    "action": "CLOSE_SIGNAL",
    "symbol": "XAUUSD",
    "entry_price": 2315.00,
    "exit_price": 2335.00,
    "profit": 200.0,
    "result": "WIN"
}, "Sending Trade 1 - CLOSE (WIN)")

# 2. Trade 2: SELL (LOSS)
send_signal({
    "token": "ats_sec_9f5c4b8e2a1d7f0e3c6b8a9f",
    "action": "SELL",
    "symbol": "XAUUSD",
    "entry_price": 2340.00,
    "sl": 2350.00,
    "tp": 2320.00,
    "comment": "Trade 2: Resistance Sweep"
}, "Sending Trade 2 - SELL")

send_signal({
    "token": "ats_sec_9f5c4b8e2a1d7f0e3c6b8a9f",
    "action": "CLOSE_SIGNAL",
    "symbol": "XAUUSD",
    "entry_price": 2340.00,
    "exit_price": 2350.00,
    "profit": -100.0,
    "result": "LOSS"
}, "Sending Trade 2 - CLOSE (LOSS)")

# 3. Trade 3: BUY (OPEN)
send_signal({
    "token": "ats_sec_9f5c4b8e2a1d7f0e3c6b8a9f",
    "action": "BUY",
    "symbol": "XAUUSD",
    "entry_price": 2325.00,
    "sl": 2315.00,
    "tp": 2345.00,
    "comment": "Trade 3: FVG Retest"
}, "Sending Trade 3 - BUY (Remains OPEN)")
