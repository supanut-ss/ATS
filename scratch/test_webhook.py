import urllib.request
import json
import time

url = "http://localhost:5000/webhook"
headers = {'Content-Type': 'application/json'}

# 1. Send BUY Signal
buy_payload = {
    "token": "ats_sec_9f5c4b8e2a1d7f0e3c6b8a9f",
    "action": "BUY",
    "symbol": "XAUUSD",
    "entry_price": 2320.50,
    "sl": 2310.00,
    "tp": 2340.00,
    "comment": "Local Sweep BUY"
}

print("--- Sending BUY Signal to Localhost ---")
req = urllib.request.Request(url, data=json.dumps(buy_payload).encode('utf-8'), headers=headers)
try:
    with urllib.request.urlopen(req) as res:
        print("BUY Response:", res.read().decode('utf-8'))
except Exception as e:
    print("Error:", e)

time.sleep(1)

# 2. Send CLOSE_SIGNAL (Win)
close_payload = {
    "token": "ats_sec_9f5c4b8e2a1d7f0e3c6b8a9f",
    "action": "CLOSE_SIGNAL",
    "symbol": "XAUUSD",
    "entry_price": 2320.50,
    "exit_price": 2340.00,
    "profit": 195.0,
    "result": "WIN"
}

print("--- Sending CLOSE_SIGNAL to Localhost ---")
req = urllib.request.Request(url, data=json.dumps(close_payload).encode('utf-8'), headers=headers)
try:
    with urllib.request.urlopen(req) as res:
        print("CLOSE Response:", res.read().decode('utf-8'))
except Exception as e:
    print("Error:", e)

# 3. Check signals list
print("--- Fetching Signals List from Localhost ---")
try:
    with urllib.request.urlopen("http://localhost:5000/api/signals") as res:
        print("Signals DB:", res.read().decode('utf-8'))
except Exception as e:
    print("Error:", e)
