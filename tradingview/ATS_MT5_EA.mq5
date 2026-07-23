//+------------------------------------------------------------------+
//|                                                   ATS_MT5_EA.mq5 |
//|                                  Copyright 2026, Antigravity AI  |
//|                                             https://ats.info.com |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, Antigravity AI"
#property link        "https://ats.info.com"
#property version     "2.00"
#property description "ATS MT5 EA v2 - Pure Structure (Liquidity+CHoCH+BOS+FVG/OB)"
#property strict

#include <Trade\Trade.mqh>

//--- Input Parameters
input group "== Webhook Connection Settings =="
input bool     InpEnableWebhookPolling = false;
input string   InpBackendURL           = "https://ats.thaipesleague.com";
input string   InpAuthToken            = "ats_sec_9f5c4b8e2a1d7f0e3c6b8a9f";
input int      InpPollInterval         = 10000;

input group "== Trade Settings =="
input int      InpSlippage             = 30;
input int      InpMagic                = 88188;

input group "== Algorithm Settings (Pure Structure + Liquidity/CHoCH/BOS/FVG/OB) =="
input int      InpPivotLength          = 5;
input double   InpSLBuffer             = 1.0;
input int      InpMaxSLPips            = 10000;
input double   InpPDThreshold          = 0.618;

enum ENUM_ENTRY_MODE {
   ENTRY_MODE_DISCOUNT_ONLY = 0, // Discount/Premium Only (Original 54% WR)
   ENTRY_MODE_ANY_FVG = 1,       // Any FVG/OB (High Frequency)
   ENTRY_MODE_STRICT_ICT = 2     // FVG/OB Inside Discount/Premium (Strict ICT)
};
input group "== Entry Logic =="
input ENUM_ENTRY_MODE InpEntryMode = ENTRY_MODE_DISCOUNT_ONLY;

input group "== Scalping Risk =="
input bool     InpUseFixedSL           = true;
input int      InpFixedSLPips          = 5000;          // Fixed SL (Points/Pips)

input group "== M5 Anti Fake-PA =="
input double   InpPABodyMin            = 0.35;         // Min Body Ratio (0.0-1.0)
input double   InpPAWickMax            = 0.60;         // Max Wick Ratio (0.0-1.0)
input double   InpPACloseMin           = 0.45;         // Min Close Position (0.0-1.0)
input bool     InpPAEngulf             = true;         // Require Engulfing Close

input group "== Position Sizing (Fixed 0.05 lot per trade) =="
input double   InpFixedLot             = 0.05;         // 0.05 lot in MT5 = 5 contracts in TV

input group "== Trend Filters =="
input bool     InpUseEMA               = true;
input int      InpEMALength            = 200;
input bool     InpUseH1Trend           = true;
input int      InpH1EMALen             = 21;
input bool     InpUseH4Trend           = true;
input int      InpH4EMALen             = 21;
input bool     InpFilterCounterTrend   = false;

input group "== News & Volume Filters =="
input bool     InpUseNewsFilter        = true;         // Enable News Filter
input string   InpNewsSession          = "0300-0500,1930-2030:23456"; // News block session (UTC)
input string   InpNewsTimezone         = "Asia/Bangkok";        // News Timezone (UTC, America/New_York, Asia/Bangkok, Exchange)
input bool     InpUseVolFilter         = true;         // Enable Volume Spike Filter
input double   InpVolSpikeMult         = 2.0;          // Volume Spike Multiplier
input int      InpVolSmaLen            = 20;           // Volume SMA Length
input int      InpVolSpikeLookback     = 3;            // Block Duration (Bars)

input group "== Sideway & Range Filters =="
input bool     InpUseADXFilter         = true;         // Enable ADX Trend Filter
input int      InpADXLen               = 14;           // ADX Lookback Length
input double   InpADXMinThreshold      = 20.0;         // Min ADX Threshold
input bool     InpUseChopFilter        = true;         // Enable Choppiness Index Filter
input int      InpChopLen              = 14;           // Choppiness Length
input double   InpChopMaxThreshold     = 60.0;         // Max CHOP Threshold
input bool     InpUseATRFilter         = true;         // Enable ATR Squeeze Filter
input double   InpATRMinRatio          = 0.80;         // Min ATR Ratio vs SMA(50)

input group "== Breakeven & Scaled Trailing Stop =="
input int      InpBEPips               = 5000;
input int      InpTrailLevel1Pips      = 10000;
input int      InpTrailLevel1LockPips  = 5000;
input bool     InpUseSteppedTrail      = true;                  // Use Stepped Trailing (true=Stepped, false=Static)
input int      InpTPPips               = 20000;

input group "== Force Close Settings =="
input bool     InpUseForceClose        = true;                  // Enable Force Close Time
input string   InpForceCloseSession    = "0400-0405:23456";     // Force Close Session (hhmm-hhmm:days)
input string   InpForceCloseTimezone   = "Asia/Bangkok";        // Force Close Timezone (UTC, America/New_York, Asia/Bangkok, Exchange)

//--- Global Variables
CTrade   trade;
string   backend_url = "";
string   auth_token  = "";

//--- Indicator Handles
int adx_handle = INVALID_HANDLE;
int atr_handle = INVALID_HANDLE;

//--- Algorithm State
double last_ph = 0.0, last_pl = 0.0;
double prev_ph = 0.0, prev_pl = 0.0;
int    trend   = 0,   prev_trend = 0;
double swing_high = 0.0, swing_low = 0.0;
bool   touched_discount = false, touched_premium = false;
bool   choch_bull = false, choch_bear = false;

//--- FVG / OB zones
double fvg_bull_low = 0.0, fvg_bull_high = 0.0;
double fvg_bear_low = 0.0, fvg_bear_high = 0.0;
double ob_bull_low  = 0.0, ob_bull_high  = 0.0;
double ob_bear_low  = 0.0, ob_bear_high  = 0.0;

//--- Tracked positions
struct TrackedPosition { ulong ticket; string symbol; string action; double volume; double open_price; double sl; double tp; };
TrackedPosition tracked_positions[];
int tracked_count = 0;

//+------------------------------------------------------------------+
bool IsNewBar()
{
   static datetime last_time = 0;
   datetime ct[];
   if(CopyTime(Symbol(), Period(), 0, 1, ct) < 1) return false;
   if(ct[0] != last_time) { last_time = ct[0]; return true; }
   return false;
}

double GetPositionSize()
{
   double s = 0.0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
      if(PositionGetSymbol(i) == Symbol() && PositionGetInteger(POSITION_MAGIC) == InpMagic)
      {
         double v = PositionGetDouble(POSITION_VOLUME);
         s += (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? v : -v;
      }
   return s;
}

int GetPositionCount()
{
   int c = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
      if(PositionGetSymbol(i) == Symbol() && PositionGetInteger(POSITION_MAGIC) == InpMagic) c++;
   return c;
}

void ForceCloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != Symbol()) continue;
      
      Print("ATS EA: Force Closing position #", ticket, " due to Force Close Time.");
      if(trade.PositionClose(ticket))
      {
         Print("ATS EA: Position #", ticket, " closed successfully.");
      }
      else
      {
         Print("ATS EA ERROR: Failed to close position #", ticket, " error=", GetLastError());
      }
   }
}

void AddTrackedPosition(ulong t, string sym, string act, double vol, double op, double sl, double tp)
{
   ArrayResize(tracked_positions, tracked_count+1);
   tracked_positions[tracked_count].ticket = t;
   tracked_positions[tracked_count].symbol = sym;
   tracked_positions[tracked_count].action = act;
   tracked_positions[tracked_count].volume = vol;
   tracked_positions[tracked_count].open_price = op;
   tracked_positions[tracked_count].sl = sl;
   tracked_positions[tracked_count].tp = tp;
   tracked_count++;
}

void RemoveTrackedPosition(int idx)
{
   if(idx < 0 || idx >= tracked_count) return;
   for(int i = idx; i < tracked_count-1; i++) tracked_positions[i] = tracked_positions[i+1];
   tracked_count--;
   ArrayResize(tracked_positions, tracked_count);
}

void SendLocalTradeToBackend(string id, string action, string symbol, double volume,
                             double entry_price, double sl, double tp, string status,
                             ulong ticket, double exit_price, double profit)
{
   string url  = backend_url + "/api/signals/local";
   string hdr  = "Content-Type: application/json\r\n";
   string pay  = StringFormat("{\"token\":\"%s\",\"id\":\"%s\",\"action\":\"%s\",\"symbol\":\"%s\","
                              "\"volume\":%s,\"entry_price\":%s,\"sl\":%s,\"tp\":%s,"
                              "\"status\":\"%s\",\"ticket\":\"%s\",\"exit_price\":%s,\"profit\":%s}",
                              auth_token, id, action, symbol,
                              DoubleToString(volume,2), DoubleToString(entry_price,2),
                              DoubleToString(sl,2), DoubleToString(tp,2),
                              status, IntegerToString(ticket),
                              DoubleToString(exit_price,2), DoubleToString(profit,2));
   char pd[], rd[]; string rh;
   StringToCharArray(pay, pd, 0, StringLen(pay), CP_UTF8);
   ResetLastError();
   int h = WebRequest("POST", url, hdr, 3000, pd, rd, rh);
   if(h != 200) Print("ATS EA ERROR: Local sync HTTP=", h, " err=", GetLastError());
}

void SyncPositionsWithBackend()
{
   int cur = PositionsTotal();
   ulong cts[]; ArrayResize(cts, cur);
   for(int i = 0; i < cur; i++)
   {
      ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      cts[i] = tk;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != Symbol()) continue;
      bool found = false;
      for(int j = 0; j < tracked_count; j++) if(tracked_positions[j].ticket == tk) { found = true; break; }
      if(!found)
      {
         string sym = PositionGetString(POSITION_SYMBOL);
         string act = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? "BUY" : "SELL";
         double vol = PositionGetDouble(POSITION_VOLUME);
         double op  = PositionGetDouble(POSITION_PRICE_OPEN);
         double sl  = PositionGetDouble(POSITION_SL);
         double tp  = PositionGetDouble(POSITION_TP);
         AddTrackedPosition(tk, sym, act, vol, op, sl, tp);
         SendLocalTradeToBackend(IntegerToString(tk), act, sym, vol, op, sl, tp, "OPEN", tk, 0.0, 0.0);
      }
   }
   for(int j = tracked_count-1; j >= 0; j--)
   {
      ulong tk = tracked_positions[j].ticket;
      bool found = false;
      for(int i = 0; i < cur; i++) if(cts[i] == tk) { found = true; break; }
      if(!found)
      {
         double ep = 0.0, pf = 0.0;
         if(HistorySelectByPosition(tk))
         {
            int nd = HistoryDealsTotal();
            for(int k = nd-1; k >= 0; k--)
            {
               ulong dt = HistoryDealGetTicket(k);
               if(HistoryDealGetInteger(dt, DEAL_ENTRY) == DEAL_ENTRY_OUT)
               {
                  ep = HistoryDealGetDouble(dt, DEAL_PRICE);
                  pf = HistoryDealGetDouble(dt, DEAL_PROFIT)+HistoryDealGetDouble(dt, DEAL_SWAP)+HistoryDealGetDouble(dt, DEAL_COMMISSION);
                  break;
               }
            }
         }
         string stat = (pf >= 0.0) ? "WIN" : "LOSS";
         SendLocalTradeToBackend(IntegerToString(tk), tracked_positions[j].action,
                                 tracked_positions[j].symbol, tracked_positions[j].volume,
                                 tracked_positions[j].open_price, tracked_positions[j].sl,
                                 tracked_positions[j].tp, stat, tk, ep, pf);
         string g1 = "ATS_MAX_PRICE_" + IntegerToString(tk);
         string g2 = "ATS_MIN_PRICE_" + IntegerToString(tk);
         if(GlobalVariableCheck(g1)) GlobalVariableDel(g1);
         if(GlobalVariableCheck(g2)) GlobalVariableDel(g2);
         RemoveTrackedPosition(j);
      }
   }
}

void InitTrackedPositions()
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != Symbol()) continue;
      AddTrackedPosition(tk, PositionGetString(POSITION_SYMBOL),
         (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?"BUY":"SELL",
         PositionGetDouble(POSITION_VOLUME), PositionGetDouble(POSITION_PRICE_OPEN),
         PositionGetDouble(POSITION_SL), PositionGetDouble(POSITION_TP));
   }
   Print("ATS EA: Tracking ", tracked_count, " open positions.");
}

bool GetHTFTrend(ENUM_TIMEFRAMES tf, int ema_len, bool &bull, bool &bear)
{
   bull = bear = true;
   int h = iMA(Symbol(), tf, ema_len, 0, MODE_EMA, PRICE_CLOSE);
   if(h == INVALID_HANDLE) return false;
   double eb[1], cb[1];
   if(CopyBuffer(h,0,1,1,eb)<1 || CopyClose(Symbol(),tf,1,1,cb)<1) { IndicatorRelease(h); return false; }
   bull = (cb[0] > eb[0]); bear = (cb[0] < eb[0]);
   IndicatorRelease(h);
   return true;
}

//+------------------------------------------------------------------+
//| GetTimeInTimezone: Convert UTC time to selected timezone        |
//+------------------------------------------------------------------+
datetime GetTimeInTimezone(string timezone)
{
   datetime utc_time = TimeGMT();
   if(timezone == "UTC")
      return utc_time;
   if(timezone == "Asia/Bangkok")
      return utc_time + 7 * 3600;
   if(timezone == "America/New_York")
   {
      MqlDateTime dt;
      TimeToStruct(utc_time, dt);
      int offset = (dt.mon >= 3 && dt.mon <= 10) ? -4 : -5;
      return utc_time + offset * 3600;
   }
   return TimeCurrent();
}

//+------------------------------------------------------------------+
//| IsInSessionString: Check if time falls inside Pine session string|
//+------------------------------------------------------------------+
bool IsInSessionString(datetime time_val, string session_str)
{
   if(session_str == "") return false;
   
   string time_part = session_str;
   string days_part = "";
   int colon_idx = StringFind(session_str, ":");
   if(colon_idx != -1)
   {
      time_part = StringSubstr(session_str, 0, colon_idx);
      days_part = StringSubstr(session_str, colon_idx + 1);
   }
   
   MqlDateTime dt;
   TimeToStruct(time_val, dt);
   
   if(days_part != "")
   {
      int pine_day = (dt.day_of_week == 0) ? 1 : (dt.day_of_week + 1);
      string day_char = IntegerToString(pine_day);
      if(StringFind(days_part, day_char) == -1)
         return false;
   }
   
   int current_time_mins = dt.hour * 60 + dt.min;
   string ranges[];
   int num_ranges = StringSplit(time_part, ',', ranges);
   if(num_ranges <= 0) return false;
   
   for(int i = 0; i < num_ranges; i++)
   {
      string range = ranges[i];
      StringTrimLeft(range);
      StringTrimRight(range);
      int dash_idx = StringFind(range, "-");
      if(dash_idx == -1) continue;
      
      string start_str = StringSubstr(range, 0, dash_idx);
      string end_str = StringSubstr(range, dash_idx + 1);
      
      int start_h = (int)StringToInteger(StringSubstr(start_str, 0, 2));
      int start_m = (int)StringToInteger(StringSubstr(start_str, 2, 2));
      int end_h = (int)StringToInteger(StringSubstr(end_str, 0, 2));
      int end_m = (int)StringToInteger(StringSubstr(end_str, 2, 2));
      
      int start_mins = start_h * 60 + start_m;
      int end_mins = end_h * 60 + end_m;
      
      if(start_mins <= end_mins)
      {
         if(current_time_mins >= start_mins && current_time_mins < end_mins)
            return true;
      }
      else
      {
         if(current_time_mins >= start_mins || current_time_mins < end_mins)
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| GetATRFilterOk: Check if volatility ratio is above threshold     |
//+------------------------------------------------------------------+
bool GetATRFilterOk()
{
   if(!InpUseATRFilter) return true;
   if(atr_handle == INVALID_HANDLE) return true;
   double atr_buf[];
   ArrayResize(atr_buf, 50);
   ArraySetAsSeries(atr_buf, true);
   if(CopyBuffer(atr_handle, 0, 1, 50, atr_buf) < 50) return true;
   
   double atr_14 = atr_buf[0];
   double sum = 0.0;
   for(int i=0; i<50; i++) sum += atr_buf[i];
   double atr_sma_50 = sum / 50.0;
   
   if(atr_sma_50 > 0)
   {
      double atr_ratio = atr_14 / atr_sma_50;
      return (atr_ratio >= InpATRMinRatio);
   }
   return true;
}

//+------------------------------------------------------------------+
//| CalculateChoppiness: Calculate Choppiness Index (0-100)          |
//+------------------------------------------------------------------+
double CalculateChoppiness(int len)
{
   double hi_arr[], lo_arr[], cl_arr[];
   ArraySetAsSeries(hi_arr, true);
   ArraySetAsSeries(lo_arr, true);
   ArraySetAsSeries(cl_arr, true);
   
   if(CopyHigh(Symbol(), Period(), 1, len, hi_arr) < len ||
      CopyLow(Symbol(), Period(), 1, len, lo_arr) < len ||
      CopyClose(Symbol(), Period(), 1, len + 1, cl_arr) < len + 1)
      return 100.0;
      
   double atr_sum = 0.0;
   double hh = hi_arr[0];
   double ll = lo_arr[0];
   
   for(int i=0; i<len; i++)
   {
      double tr = hi_arr[i] - lo_arr[i];
      double diff1 = MathAbs(hi_arr[i] - cl_arr[i+1]);
      double diff2 = MathAbs(lo_arr[i] - cl_arr[i+1]);
      if(diff1 > tr) tr = diff1;
      if(diff2 > tr) tr = diff2;
      atr_sum += tr;
      
      if(hi_arr[i] > hh) hh = hi_arr[i];
      if(lo_arr[i] < ll) ll = lo_arr[i];
   }
   
   double range = hh - ll;
   if(range > 0)
   {
      double chop = 100.0 * MathLog10(atr_sum / range) / MathLog10(len);
      return chop;
   }
   return 100.0;
}

//+------------------------------------------------------------------+
//| GetADXValue: Retrieve ADX indicator value                        |
//+------------------------------------------------------------------+
double GetADXValue()
{
   if(!InpUseADXFilter) return 100.0;
   if(adx_handle == INVALID_HANDLE) return 0.0;
   double val[1];
   if(CopyBuffer(adx_handle, 0, 1, 1, val) < 1) return 0.0;
   return val[0];
}

//+------------------------------------------------------------------+
//| IsVolumeSpikeActive: Check if there was a volume spike recently  |
//+------------------------------------------------------------------+
bool IsVolumeSpikeActive(int sma_len, double multiplier, int lookback_bars)
{
   long vol_arr[];
   ArraySetAsSeries(vol_arr, true);
   int copied = CopyTickVolume(Symbol(), Period(), 0, sma_len + lookback_bars + 1, vol_arr);
   if(copied < sma_len + lookback_bars + 1)
      return false;

   for(int i = 1; i <= lookback_bars; i++)
   {
      double sum = 0;
      for(int j = 0; j < sma_len; j++)
      {
         sum += (double)vol_arr[i + j];
      }
      double sma = sum / sma_len;
      if(sma > 0 && (double)vol_arr[i] > sma * multiplier)
      {
         Print("ATS EA: Volume spike detected on bar ", i, " Volume=", vol_arr[i], " SMA=", sma, " Multiplier=", multiplier);
         return true;
      }
   }
   return false;
}

// Detect FVG: Bullish FVG = high[2] < low[0]; Bearish FVG = low[2] > high[0]
void DetectFVG(double &highs[], double &lows[])
{
   if(ArraySize(highs) < 4) return;
   if(highs[3] < lows[1]) { fvg_bull_low = highs[3]; fvg_bull_high = lows[1]; }
   if(lows[3]  > highs[1]) { fvg_bear_low = highs[1]; fvg_bear_high = lows[3]; }
}

// Detect Order Block: last opposing candle before impulse move
void DetectOB(double &opens[], double &closes[], double &highs[], double &lows[])
{
   if(ArraySize(opens) < 5) return;
   // Bullish OB: bearish candle[3] before strong bullish candle[1] that closes above high[3]
   if(closes[3]<opens[3] && closes[1]>opens[1] && closes[1]>highs[3])
      { ob_bull_low=lows[3]; ob_bull_high=highs[3]; }
   // Bearish OB: bullish candle[3] before strong bearish candle[1] that closes below low[3]
   if(closes[3]>opens[3] && closes[1]<opens[1] && closes[1]<lows[3])
      { ob_bear_low=lows[3]; ob_bear_high=highs[3]; }
}

void InitStateFromHistory()
{
   int hb = 500;
   double cl[], op[], hi[], lo[];
   ArraySetAsSeries(cl,true); ArraySetAsSeries(op,true);
   ArraySetAsSeries(hi,true); ArraySetAsSeries(lo,true);
   if(CopyClose(Symbol(),Period(),0,hb,cl)<hb || CopyOpen(Symbol(),Period(),0,hb,op)<hb ||
      CopyHigh(Symbol(),Period(),0,hb,hi)<hb  || CopyLow(Symbol(),Period(),0,hb,lo)<hb)
      { Print("ATS EA: History load error."); return; }
   int plt = 0;
   for(int i = hb-2*InpPivotLength-1; i >= 1; i--)
   {
      int ti = i + InpPivotLength;
      bool iph = true, ipl = true;
      for(int j = 1; j <= 2*InpPivotLength+1; j++)
      {
         int ci = i+j-1; if(ci==ti) continue;
         if(hi[ci]>hi[ti]) iph=false;
         if(lo[ci]<lo[ti]) ipl=false;
      }
      if(iph) { prev_ph=last_ph; last_ph=hi[ti];
                 if(trend==1&&prev_ph>0&&last_ph<prev_ph) choch_bear=true; }
      if(ipl) { prev_pl=last_pl; last_pl=lo[ti];
                 if(trend==-1&&prev_pl>0&&last_pl>prev_pl) choch_bull=true; }
      double cv = cl[i];
      if(trend<=0&&last_ph>0&&cv>last_ph) trend=1;
      if(trend>=0&&last_pl>0&&cv<last_pl) trend=-1;
      if(trend==1)  { swing_low=(!swing_low)?last_pl:swing_low; swing_high=MathMax(!swing_high?hi[i]:swing_high,hi[i]); }
      else if(trend==-1) { swing_high=(!swing_high)?last_ph:swing_high; swing_low=MathMin(!swing_low?lo[i]:swing_low,lo[i]); }
      if(trend!=plt)
      {
         if(trend==1)  { swing_low=last_pl; swing_high=hi[i]; choch_bear=false; }
         if(trend==-1) { swing_high=last_ph; swing_low=lo[i]; choch_bull=false; }
         plt=trend;
      }
      double sr=swing_high-swing_low;
      double dl=swing_low+(sr*InpPDThreshold), pl2=swing_high-(sr*InpPDThreshold);
      if(trend==1&&lo[i]<=dl) touched_discount=true; if(trend!=1) touched_discount=false;
      if(trend==-1&&hi[i]>=pl2) touched_premium=true; if(trend!=-1) touched_premium=false;
   }
   Print("ATS EA: History init done. Trend=",trend," SH=",swing_high," SL=",swing_low,
         " CHoCH Bull=",choch_bull," Bear=",choch_bear);
}

//+------------------------------------------------------------------+
//| MAIN STRATEGY: Liquidity + CHoCH + BOS + FVG/OB + PA            |
//+------------------------------------------------------------------+
void ExecuteStrategyLogic()
{
   int hn = MathMax(2*InpPivotLength+4, 8);
   double cl[], op[], hi[], lo[];
   ArraySetAsSeries(cl,true); ArraySetAsSeries(op,true);
   ArraySetAsSeries(hi,true); ArraySetAsSeries(lo,true);
   if(CopyClose(Symbol(),Period(),0,hn,cl)<hn || CopyOpen(Symbol(),Period(),0,hn,op)<hn ||
      CopyHigh(Symbol(),Period(),0,hn,hi)<hn   || CopyLow(Symbol(),Period(),0,hn,lo)<hn) return;

   // 1. Pivot detection
   int ti = InpPivotLength+1;
   bool iph=true, ipl=true;
   for(int j=1; j<=2*InpPivotLength+1; j++)
   {
      if(j==ti) continue;
      if(hi[j]>hi[ti]) iph=false;
      if(lo[j]<lo[ti]) ipl=false;
   }
   if(iph) {
      prev_ph=last_ph; last_ph=hi[ti];
      if(trend==1&&prev_ph>0&&last_ph<prev_ph) { choch_bear=true; Print("ATS EA: Bearish CHoCH PH ",last_ph," < ",prev_ph); }
      Print("ATS EA: Pivot High ",last_ph);
   }
   if(ipl) {
      prev_pl=last_pl; last_pl=lo[ti];
      if(trend==-1&&prev_pl>0&&last_pl>prev_pl) { choch_bull=true; Print("ATS EA: Bullish CHoCH PL ",last_pl," > ",prev_pl); }
      Print("ATS EA: Pivot Low ",last_pl);
   }

   // 2. BOS
   double cc = cl[1]; prev_trend=trend;
   if(trend<=0&&last_ph>0&&cc>last_ph) { trend=1;  choch_bear=false; Print("ATS EA: BOS Bullish trend=1"); }
   if(trend>=0&&last_pl>0&&cc<last_pl) { trend=-1; choch_bull=false; Print("ATS EA: BOS Bearish trend=-1"); }

   // 3. Swing update
   if(trend==1)  { swing_low=(!swing_low)?last_pl:swing_low; swing_high=MathMax(!swing_high?hi[1]:swing_high,hi[1]); }
   if(trend==-1) { swing_high=(!swing_high)?last_ph:swing_high; swing_low=MathMin(!swing_low?lo[1]:swing_low,lo[1]); }
   if(trend!=prev_trend)
   {
      if(trend==1)  { swing_low=last_pl; swing_high=hi[1]; }
      if(trend==-1) { swing_high=last_ph; swing_low=lo[1]; }
   }

   // 4. FVG & OB detection
   DetectFVG(hi, lo);
   DetectOB(op, cl, hi, lo);

   // 5. Premium / Discount
   double sr=swing_high-swing_low;
   double dl=swing_low+(sr*InpPDThreshold), pl2=swing_high-(sr*InpPDThreshold);
   double ps=GetPositionSize();
   if(trend!=1||ps>0) touched_discount=false;
   if(trend!=-1||ps<0) touched_premium=false;
   if(trend==1&&lo[1]<=dl) touched_discount=true;
   if(trend==-1&&hi[1]>=pl2) touched_premium=true;

   // 6. FVG/OB re-entry check
   bool in_bull_fvg = fvg_bull_low>0&&fvg_bull_high>0 && lo[1]<=fvg_bull_high && hi[1]>=fvg_bull_low;
   bool in_bull_ob  = ob_bull_low>0&&ob_bull_high>0   && lo[1]<=ob_bull_high  && hi[1]>=ob_bull_low;
   bool in_bear_fvg = fvg_bear_low>0&&fvg_bear_high>0 && lo[1]<=fvg_bear_high && hi[1]>=fvg_bear_low;
   bool in_bear_ob  = ob_bear_low>0&&ob_bear_high>0   && lo[1]<=ob_bear_high  && hi[1]>=ob_bear_low;

    // 7. PA confirmation (4-layer filter)
    bool bullish_pa_raw = cl[2] < op[2] && cl[1] > op[1];
    bool bearish_pa_raw = cl[2] > op[2] && cl[1] < op[1];

    double bull_body   = cl[1] - op[1];
    double bull_range  = hi[1] - lo[1];
    double bear_body   = op[1] - cl[1];
    double bear_range  = hi[1] - lo[1];

    double bull_body_ratio = bull_range > 0 ? bull_body / bull_range : 0.0;
    double bear_body_ratio = bear_range > 0 ? bear_body / bear_range : 0.0;

    double bull_upper_wick = hi[1] - cl[1];
    double bear_lower_wick = cl[1] - lo[1];
    double bull_wick_ratio = bull_range > 0 ? bull_upper_wick / bull_range : 1.0;
    double bear_wick_ratio = bear_range > 0 ? bear_lower_wick / bear_range : 1.0;

    double bull_close_pos  = bull_range > 0 ? (cl[1] - lo[1]) / bull_range : 0.0;
    double bear_close_pos  = bear_range > 0 ? (hi[1] - cl[1]) / bear_range : 0.0;

    bool bull_engulf = !InpPAEngulf || (cl[1] > op[2]);
    bool bear_engulf = !InpPAEngulf || (cl[1] < op[2]);

    bool bull_pa = bullish_pa_raw
                && bull_body_ratio >= InpPABodyMin
                && bull_wick_ratio  <= InpPAWickMax
                && bull_close_pos   >= InpPACloseMin
                && bull_engulf;

    bool bear_pa = bearish_pa_raw
                && bear_body_ratio >= InpPABodyMin
                && bear_wick_ratio  <= InpPAWickMax
                && bear_close_pos   >= InpPACloseMin
                && bear_engulf;

    // 8. EMA filter
   bool ema_lc=true, ema_sc=true;
   if(InpUseEMA)
   {
      int eh = iMA(Symbol(),Period(),InpEMALength,0,MODE_EMA,PRICE_CLOSE);
      if(eh!=INVALID_HANDLE)
      {
         double eb[1];
         if(CopyBuffer(eh,0,1,1,eb)>0) { ema_lc=(cc>eb[0]); ema_sc=(cc<eb[0]); }
         IndicatorRelease(eh);
      }
   }

   // 9. HTF filter
   bool h1b=true,h1r=true,h4b=true,h4r=true;
   if(InpUseH1Trend) GetHTFTrend(PERIOD_H1,InpH1EMALen,h1b,h1r);
   if(InpUseH4Trend) GetHTFTrend(PERIOD_H4,InpH4EMALen,h4b,h4r);
   bool htfbull=(!InpUseH1Trend||h1b)&&(!InpUseH4Trend||h4b);
   bool htfbear=(!InpUseH1Trend||h1r)&&(!InpUseH4Trend||h4r);
   bool lok = !InpFilterCounterTrend||!htfbear;
   bool sok = !InpFilterCounterTrend||!htfbull;

   // 10. Entry conditions (one trade at a time, frequent entries)
   bool no_pos = (GetPositionCount()==0);
   bool fvg_ob_bull = false;
   bool fvg_ob_bear = false;
   
   if(InpEntryMode == ENTRY_MODE_DISCOUNT_ONLY) {
       fvg_ob_bull = touched_discount;
       fvg_ob_bear = touched_premium;
   } else if(InpEntryMode == ENTRY_MODE_ANY_FVG) {
       fvg_ob_bull = in_bull_fvg || in_bull_ob || touched_discount;
       fvg_ob_bear = in_bear_fvg || in_bear_ob || touched_premium;
   } else if(InpEntryMode == ENTRY_MODE_STRICT_ICT) {
       fvg_ob_bull = (in_bull_fvg || in_bull_ob) && touched_discount;
       fvg_ob_bear = (in_bear_fvg || in_bear_ob) && touched_premium;
   }
   
   // News & Volume filter
    bool filter_blocked = false;
    if(InpUseNewsFilter)
    {
       datetime time_in_tz = GetTimeInTimezone(InpNewsTimezone);
       if(IsInSessionString(time_in_tz, InpNewsSession))
       {
          filter_blocked = true;
          Print("ATS EA: Trade blocked by News Filter (Current Time in Timezone: ", TimeToString(time_in_tz), ")");
       }
    }
    if(!filter_blocked && InpUseVolFilter)
    {
       if(IsVolumeSpikeActive(InpVolSmaLen, InpVolSpikeMult, InpVolSpikeLookback))
       {
          filter_blocked = true;
          Print("ATS EA: Trade blocked by Volume Spike Filter.");
       }
    }
    
    // Sideway & Range Filters
    bool sideway_blocked = false;
    if(InpUseADXFilter)
    {
       double adx = GetADXValue();
       if(adx < InpADXMinThreshold)
       {
          sideway_blocked = true;
       }
    }
    if(!sideway_blocked && InpUseChopFilter)
    {
       double chop = CalculateChoppiness(InpChopLen);
       if(chop > InpChopMaxThreshold)
       {
          sideway_blocked = true;
       }
    }
    if(!sideway_blocked && InpUseATRFilter)
    {
       if(!GetATRFilterOk())
       {
          sideway_blocked = true;
       }
    }

    bool in_force_close = false;
    if(InpUseForceClose)
    {
       datetime time_in_tz = GetTimeInTimezone(InpForceCloseTimezone);
       if(IsInSessionString(time_in_tz, InpForceCloseSession))
          in_force_close = true;
    }

    bool longCond  = (trend==1)  && fvg_ob_bull && bull_pa && ema_lc && lok && no_pos && !filter_blocked && !sideway_blocked && !in_force_close;
    bool shortCond = (trend==-1) && fvg_ob_bear && bear_pa && ema_sc && sok && no_pos && !filter_blocked && !sideway_blocked && !in_force_close;

   double pt   = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   double tp_v = InpTPPips * pt;

   // 11. Execute BUY
   if(longCond)
   {
      double slp = 0.0;
      if(InpUseFixedSL) {
          slp = cc - (InpFixedSLPips * pt);
      } else {
          slp = swing_low - InpSLBuffer;
          if(ob_bull_low>0 && ob_bull_low<slp) slp=ob_bull_low-InpSLBuffer;
      }
      double risk = cc - slp;
      if(!InpUseFixedSL && (risk>InpMaxSLPips*pt||risk<=0)) { risk=InpMaxSLPips*pt; slp=cc-risk; }
      MqlTick tk;
      if(SymbolInfoTick(Symbol(),tk))
      {
         double a=tk.ask, atp=a+tp_v;
         Print("ATS EA: BUY | Ask=",a," SL=",slp," TP=",atp," Lot=",InpFixedLot,
               " Zone=",in_bull_fvg?"FVG":in_bull_ob?"OB":"PD");
         trade.Buy(InpFixedLot, Symbol(), a, slp, atp, "ATS BUY[BOS+FVG/OB]");
      }
   }
   else if(shortCond)
   {
      double slp = 0.0;
      if(InpUseFixedSL) {
          slp = cc + (InpFixedSLPips * pt);
      } else {
          slp = swing_high + InpSLBuffer;
          if(ob_bear_high>0 && ob_bear_high>slp) slp=ob_bear_high+InpSLBuffer;
      }
      double risk = slp - cc;
      if(!InpUseFixedSL && (risk>InpMaxSLPips*pt||risk<=0)) { risk=InpMaxSLPips*pt; slp=cc+risk; }
      MqlTick tk;
      if(SymbolInfoTick(Symbol(),tk))
      {
         double b=tk.bid, btp=b-tp_v;
         Print("ATS EA: SELL | Bid=",b," SL=",slp," TP=",btp," Lot=",InpFixedLot,
               " Zone=",in_bear_fvg?"FVG":in_bear_ob?"OB":"PD");
         trade.Sell(InpFixedLot, Symbol(), b, slp, btp, "ATS SELL[BOS+FVG/OB]");
      }
   }
}

//+------------------------------------------------------------------+
//| Breakeven & Scaled Trailing (every tick)                         |
//| Level 1 : profit >= 500 pip  -> SL = entry (breakeven)          |
//| Level 2 : profit >= 1000 pip -> SL = entry + 500 pip            |
//| TP : hard-coded at 1500 pip from entry                           |
//+------------------------------------------------------------------+
void CheckBEAndTrailing()
{
   if(GetPositionCount()==0)
   {
      int n=GlobalVariablesTotal();
      for(int k=n-1; k>=0; k--)
      {
         string gn=GlobalVariableName(k);
         if(StringFind(gn,"ATS_MAX_PRICE_")==0||StringFind(gn,"ATS_MIN_PRICE_")==0)
            GlobalVariableDel(gn);
      }
      return;
   }
   double pt    = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   double be_d  = InpBEPips * pt;
   double t1_d  = InpTrailLevel1Pips * pt;
   double lk_d  = InpTrailLevel1LockPips * pt;

   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      if(PositionGetSymbol(i)!=Symbol()||PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      ulong  tk   = PositionGetInteger(POSITION_TICKET);
      double ep   = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);
      long   typ  = PositionGetInteger(POSITION_TYPE);
      double cur  = SymbolInfoDouble(Symbol(),(typ==POSITION_TYPE_BUY)?SYMBOL_BID:SYMBOL_ASK);
      double nsl  = sl;
      bool   mod  = false;

      if(typ==POSITION_TYPE_BUY)
      {
         string gk = "ATS_MAX_PRICE_"+IntegerToString(tk);
         double pk = GlobalVariableCheck(gk)?GlobalVariableGet(gk):ep;
         if(cur>pk) { pk=cur; GlobalVariableSet(gk,pk); }
         double pd = pk-ep;
         if(pd>=t1_d)         // Level 2 Trailing Stop
         {
            double ls = ep + lk_d;
            if(InpUseSteppedTrail)
            {
               double step_multiplier = MathFloor(pd / lk_d);
               double locked_profit = (step_multiplier - 1.0) * lk_d;
               ls = ep + locked_profit;
            }
            if(nsl<ls) { nsl=ls; mod=true; Print("ATS BUY #",tk," Trail SL=",nsl); }
         }
         else if(pd>=be_d)    // Level 1: breakeven
         {
            double be_locked = ep + (10 * pt);
            if(nsl<be_locked) { nsl=be_locked; mod=true; Print("ATS BUY #",tk," BE SL=",nsl); }
         }
         if(mod&&nsl>sl) trade.PositionModify(tk,nsl,tp);
      }
      else
      {
         string gk = "ATS_MIN_PRICE_"+IntegerToString(tk);
         double tr = GlobalVariableCheck(gk)?GlobalVariableGet(gk):ep;
         if(cur<tr) { tr=cur; GlobalVariableSet(gk,tr); }
         double pd = ep-tr;
         if(pd>=t1_d)         // Level 2 Trailing Stop
         {
            double ls = ep - lk_d;
            if(InpUseSteppedTrail)
            {
               double step_multiplier = MathFloor(pd / lk_d);
               double locked_profit = (step_multiplier - 1.0) * lk_d;
               ls = ep - locked_profit;
            }
            if(sl==0.0||nsl>ls) { nsl=ls; mod=true; Print("ATS SELL #",tk," Trail SL=",nsl); }
         }
         else if(pd>=be_d)    // Level 1: breakeven
         {
            double be_locked = ep - (10 * pt);
            if(sl==0.0||nsl>be_locked) { nsl=be_locked; mod=true; Print("ATS SELL #",tk," BE SL=",nsl); }
         }
         if(mod&&(sl==0.0||nsl<sl)) trade.PositionModify(tk,nsl,tp);
      }
   }
}

//+------------------------------------------------------------------+
int OnInit()
{
   backend_url = InpBackendURL;
   if(StringSubstr(backend_url,StringLen(backend_url)-1,1)=="/")
      backend_url=StringSubstr(backend_url,0,StringLen(backend_url)-1);
   auth_token=InpAuthToken;
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippage);
   
   // Initialize Indicators
   if(InpUseADXFilter)
   {
      adx_handle = iADX(Symbol(), Period(), InpADXLen);
      if(adx_handle == INVALID_HANDLE) { Print("ATS EA ERROR: Failed to create ADX handle"); return(INIT_FAILED); }
   }
   if(InpUseATRFilter)
   {
      atr_handle = iATR(Symbol(), Period(), 14);
      if(atr_handle == INVALID_HANDLE) { Print("ATS EA ERROR: Failed to create ATR handle"); return(INIT_FAILED); }
   }
   
   InitStateFromHistory();
   InitTrackedPositions();
   EventSetMillisecondTimer(InpPollInterval);
   Print("ATS EA v2.0 | Lot=",InpFixedLot," BE=",InpBEPips,"p Trail@",InpTrailLevel1Pips,"p->",InpTrailLevel1LockPips,"p TP=",InpTPPips,"p");
   Print("ATS EA: Strategy = Liquidity + CHoCH + BOS + FVG/OB re-entry");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   if(adx_handle != INVALID_HANDLE) IndicatorRelease(adx_handle);
   if(atr_handle != INVALID_HANDLE) IndicatorRelease(atr_handle);
   Print("ATS EA: Deinitialized.");
}

void OnTick()
{
   CheckBEAndTrailing();
   SyncPositionsWithBackend();
   
   // Force Close Check
   if(InpUseForceClose)
   {
      datetime time_in_tz = GetTimeInTimezone(InpForceCloseTimezone);
      if(IsInSessionString(time_in_tz, InpForceCloseSession))
      {
         ForceCloseAllPositions();
      }
   }
   
   if(IsNewBar()) ExecuteStrategyLogic();
}

string GetMT5StateJson()
{
   double bal=AccountInfoDouble(ACCOUNT_BALANCE), eq=AccountInfoDouble(ACCOUNT_EQUITY);
   double fm=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double bid=SymbolInfoDouble(Symbol(),SYMBOL_BID), ask=SymbolInfoDouble(Symbol(),SYMBOL_ASK);
   string pj="["; int total=PositionsTotal(), cnt=0;
   for(int i=0;i<total;i++)
   {
      if(PositionGetSymbol(i)=="") continue;
      ulong tk=PositionGetInteger(POSITION_TICKET);
      string sym=PositionGetString(POSITION_SYMBOL);
      string ptyp=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?"BUY":"SELL";
      if(cnt>0) pj+=",";
      pj+=StringFormat("{\"ticket\":\"%s\",\"symbol\":\"%s\",\"type\":\"%s\",\"volume\":%s,"
                       "\"open_price\":%s,\"current_price\":%s,\"sl\":%s,\"tp\":%s,\"profit\":%s}",
         IntegerToString(tk),sym,ptyp,
         DoubleToString(PositionGetDouble(POSITION_VOLUME),2),
         DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN),5),
         DoubleToString(PositionGetDouble(POSITION_PRICE_CURRENT),5),
         DoubleToString(PositionGetDouble(POSITION_SL),5),
         DoubleToString(PositionGetDouble(POSITION_TP),5),
         DoubleToString(PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP),2));
      cnt++;
   }
   pj+="]";
   return StringFormat("{\"token\":\"%s\",\"balance\":%s,\"equity\":%s,\"free_margin\":%s,\"bid\":%s,\"ask\":%s,\"positions\":%s}",
      auth_token,DoubleToString(bal,2),DoubleToString(eq,2),DoubleToString(fm,2),
      DoubleToString(bid,5),DoubleToString(ask,5),pj);
}

void OnTimer()
{
   if(!InpEnableWebhookPolling) return;
   string url=backend_url+"/api/signals/pending", hdr="Content-Type: application/json\r\n";
   string pay=GetMT5StateJson();
   char pd[],rd[]; string rh;
   StringToCharArray(pay,pd,0,StringLen(pay),CP_UTF8);
   ResetLastError();
   int h=WebRequest("POST",url,hdr,3000,pd,rd,rh);
   if(h==-1) { int e=GetLastError(); if(e==4014) Print("ATS EA: Add '",backend_url,"' to Allowed URLs."); return; }
   if(h!=200) return;
   string jr=CharArrayToString(rd,0,WHOLE_ARRAY,CP_UTF8);
   if(jr!=""&&jr!="[]") ProcessSignals(jr);
}

string GetJsonValueString(string json, string key, int sp=0)
{
   string pat="\""+key+"\":\"";
   int st=StringFind(json,pat,sp);
   if(st==-1)
   {
      pat="\""+key+"\":";
      st=StringFind(json,pat,sp);
      if(st==-1) return "";
      st+=StringLen(pat);
      int en=st;
      while(en<StringLen(json)) { ushort c=StringGetCharacter(json,en); if(c==','||c=='}'||c==']'||c==' '||c=='\r'||c=='\n') break; en++; }
      string v=StringSubstr(json,st,en-st); StringTrimLeft(v); StringTrimRight(v); return v;
   }
   st+=StringLen(pat);
   int en=StringFind(json,"\"",st);
   return (en==-1)?"":StringSubstr(json,st,en-st);
}

double GetJsonValueDouble(string json,string key,int sp=0) { return StringToDouble(GetJsonValueString(json,key,sp)); }

void ProcessSignals(string ja)
{
   int pos=0, al=StringLen(ja);
   while(pos<al)
   {
      int os=StringFind(ja,"{",pos); if(os==-1) break;
      int oe=StringFind(ja,"}",os);  if(oe==-1) break;
      string obj=StringSubstr(ja,os,oe-os+1); pos=oe+1;
      string id=GetJsonValueString(obj,"id"), act=GetJsonValueString(obj,"action");
      string stat=GetJsonValueString(obj,"status"), sym=GetJsonValueString(obj,"symbol");
      double lot=GetJsonValueDouble(obj,"volume"), sl=GetJsonValueDouble(obj,"sl"), tp=GetJsonValueDouble(obj,"tp");
      ulong  tick=StringToInteger(GetJsonValueString(obj,"ticket"));
      if(lot<=0) lot=InpFixedLot;
      string es=sym;
      if(sym=="XAUUSD"&&Symbol()!="XAUUSD"&&(StringFind(Symbol(),"XAUUSD")==0||StringFind(Symbol(),"GOLD")==0)) es=Symbol();
      if(stat=="PENDING_BUY")   ExecuteBuy(id,es,lot,sl,tp);
      if(stat=="PENDING_SELL")  ExecuteSell(id,es,lot,sl,tp);
      if(stat=="PENDING_CLOSE") ExecuteClose(id,es,tick);
   }
}

void ExecuteBuy(string id,string sym,double lot,double sl,double tp)
{
   MqlTick tk; if(!SymbolInfoTick(sym,tk)) return;
   if(trade.Buy(lot,sym,tk.ask,sl,tp,"ATS BUY "+id))
   {
      ulong t=trade.ResultOrder(); if(!t) t=trade.ResultDeal();
      double fp=trade.ResultPrice(); if(fp<=0) fp=tk.ask;
      UpdateSignalStatus(id,"OPEN",t,fp,0.0,0.0);
   } else UpdateSignalStatus(id,"FAILED",0,0.0,0.0,0.0);
}

void ExecuteSell(string id,string sym,double lot,double sl,double tp)
{
   MqlTick tk; if(!SymbolInfoTick(sym,tk)) return;
   if(trade.Sell(lot,sym,tk.bid,sl,tp,"ATS SELL "+id))
   {
      ulong t=trade.ResultOrder(); if(!t) t=trade.ResultDeal();
      double fp=trade.ResultPrice(); if(fp<=0) fp=tk.bid;
      UpdateSignalStatus(id,"OPEN",t,fp,0.0,0.0);
   } else UpdateSignalStatus(id,"FAILED",0,0.0,0.0,0.0);
}

void ExecuteClose(string id,string sym,ulong ticket)
{
   if(ticket<=0&&PositionSelect(sym)) ticket=PositionGetInteger(POSITION_TICKET);
   if(ticket>0)
   {
      if(trade.PositionClose(ticket))
      {
         double pf=0.0; ulong dt=trade.ResultDeal();
         if(dt>0&&HistoryDealSelect(dt)) pf=HistoryDealGetDouble(dt,DEAL_PROFIT);
         else if(HistorySelectByPosition(ticket))
         {
            int nd=HistoryDealsTotal();
            for(int i=nd-1;i>=0;i--)
            {
               ulong d=HistoryDealGetTicket(i);
               if(HistoryDealGetInteger(d,DEAL_ENTRY)==DEAL_ENTRY_OUT) { pf=HistoryDealGetDouble(d,DEAL_PROFIT); break; }
            }
         }
         UpdateSignalStatus(id,pf>=0?"WIN":"LOSS",ticket,0.0,trade.ResultPrice(),pf);
      } else UpdateSignalStatus(id,"CLOSE_FAILED",0,0.0,0.0,0.0);
   } else UpdateSignalStatus(id,"CLOSED_NOT_FOUND",0,0.0,0.0,0.0);
}

void UpdateSignalStatus(string id,string status,ulong ticket,double ep,double xp,double pf)
{
   string url=backend_url+"/api/signals/update", hdr="Content-Type: application/json\r\n";
   string pay=StringFormat("{\"token\":\"%s\",\"id\":\"%s\",\"status\":\"%s\",\"ticket\":\"%s\","
                           "\"entry_price\":%s,\"exit_price\":%s,\"profit\":%s}",
      auth_token,id,status,IntegerToString(ticket),
      DoubleToString(ep,2),DoubleToString(xp,2),DoubleToString(pf,2));
   char pd[],rd[]; string rh;
   StringToCharArray(pay,pd,0,StringLen(pay),CP_UTF8);
   ResetLastError();
   int h=WebRequest("POST",url,hdr,3000,pd,rd,rh);
   if(h==200) Print("ATS EA: Status updated -> ",status);
   else Print("ATS EA ERROR: Status update HTTP=",h," err=",GetLastError());
}
//+------------------------------------------------------------------+
