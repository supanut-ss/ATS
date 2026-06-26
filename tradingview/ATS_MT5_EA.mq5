//+------------------------------------------------------------------+
//|                                                   ATS_MT5_EA.mq5 |
//|                                  Copyright 2026, Antigravity AI  |
//|                                             https://ats.info.com |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, Antigravity AI"
#property link        "https://ats.info.com"
#property version     "1.10"
#property description "ATS MetaTrader 5 Self-Trading Expert Advisor & Webhook Connector"
#property strict

#include <Trade\Trade.mqh>

//--- Input Parameters
input group "🔗 Webhook Connection Settings"
input bool     InpEnableWebhookPolling = false;                      // Enable Webhook Polling (default: false)
input string   InpBackendURL           = "https://ats.thaipesleague.com"; // Backend API URL
input string   InpAuthToken            = "ats_sec_9f5c4b8e2a1d7f0e3c6b8a9f"; // Auth Token
input int      InpPollInterval         = 1000;                       // Polling Interval (ms)

input group "🛡 Trade Settings"
input double   InpDefaultLot           = 0.01;                       // Default Lot (fallback)
input int      InpSlippage             = 30;                         // Max Slippage (points)
input int      InpMagic                = 88188;                      // Magic Number

input group "⚙️ Algorithm Settings (Pure Structure)"
input int      InpPivotLength          = 3;                          // Pivot Lookback Length
input double   InpRRRatio              = 2.0;                        // Risk/Reward Ratio (Trend-following)
input double   InpRRRatioCounter       = 1.0;                        // Risk/Reward Ratio (Counter-trend)
input double   InpSLBuffer             = 1.0;                        // SL Buffer (USD)
input double   InpMaxSL                = 20.0;                       // Max SL (USD)
input double   InpPDThreshold          = 0.618;                      // Premium/Discount Fib Threshold (0.618)

enum ENUM_RISK_MODE
{
   RISK_FIXED_CONTRACTS = 0, // Fixed Contracts
   RISK_FIXED_CASH      = 1, // Fixed Cash (USD)
   RISK_PERCENT_EQUITY  = 2  // Percent of Equity
};

input group "🛡 Position Sizing"
input ENUM_RISK_MODE InpRiskMode       = RISK_FIXED_CASH;            // Position Sizing Mode
input double   InpRiskAmount           = 12.0;                       // Risk Amount (USD or %)
input double   InpFixedQty             = 1.0;                        // Fixed Contracts Quantity

input group "📈 Trend Filters"
input bool     InpUseEMA               = true;                       // Use EMA 200 (Current Timeframe)
input int      InpEMALength            = 200;                        // EMA Length
input bool     InpUseH1Trend           = true;                       // Enable H1 Trend Filter (EMA 21)
input int      InpH1EMALen             = 21;                         // H1 EMA Length
input bool     InpUseH4Trend           = false;                      // Enable H4 Trend Filter (EMA 21)
input int      InpH4EMALen             = 21;                         // H4 EMA Length
input bool     InpFilterCounterTrend   = false;                      // Block all Counter-Trend trades

input group "🔄 Breakeven & Trailing Stop"
input bool     InpUseBE                = true;                       // Enable Breakeven (กันทุน)
input double   InpBETrigger            = 1.0;                        // Breakeven Trigger (R-multiple)
input bool     InpUseTrail             = true;                       // Enable Smooth Trailing Stop
input double   InpTrailDist            = 1.0;                        // Smooth Trailing Distance (R-multiple)

//--- Global Variables
CTrade   trade;
string   backend_url = "";
string   auth_token = "";

//--- Algorithm State Variables
double last_ph = 0.0;
double last_pl = 0.0;
double prev_ph = 0.0;
double prev_pl = 0.0;
int    trend = 0;
double swing_high = 0.0;
double swing_low = 0.0;
bool   touched_discount = false;
bool   touched_premium = false;

//--- Tracked positions structure & array for database sync
struct TrackedPosition
{
   ulong ticket;
   string symbol;
   string action;
   double volume;
   double open_price;
   double sl;
   double tp;
};

TrackedPosition tracked_positions[];
int tracked_count = 0;

//+------------------------------------------------------------------+
//| Helper to check if a new bar has opened                          |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   static datetime last_time = 0;
   datetime current_time[];
   if(CopyTime(Symbol(), Period(), 0, 1, current_time) < 1) return false;
   if(current_time[0] != last_time)
   {
      last_time = current_time[0];
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Get current position size of this EA on the current symbol       |
//+------------------------------------------------------------------+
double GetPositionSize()
{
   double total_size = 0.0;
   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == Symbol() && PositionGetInteger(POSITION_MAGIC) == InpMagic)
      {
         double volume = PositionGetDouble(POSITION_VOLUME);
         long type = PositionGetInteger(POSITION_TYPE);
         if(type == POSITION_TYPE_BUY)
            total_size += volume;
         else if(type == POSITION_TYPE_SELL)
            total_size -= volume;
      }
   }
   return total_size;
}

//+------------------------------------------------------------------+
//| Add a position to the tracked list                              |
//+------------------------------------------------------------------+
void AddTrackedPosition(ulong ticket, string symbol, string action, double volume, double open_price, double sl, double tp)
{
   ArrayResize(tracked_positions, tracked_count + 1);
   tracked_positions[tracked_count].ticket = ticket;
   tracked_positions[tracked_count].symbol = symbol;
   tracked_positions[tracked_count].action = action;
   tracked_positions[tracked_count].volume = volume;
   tracked_positions[tracked_count].open_price = open_price;
   tracked_positions[tracked_count].sl = sl;
   tracked_positions[tracked_count].tp = tp;
   tracked_count++;
}

//+------------------------------------------------------------------+
//| Remove a position from the tracked list                          |
//+------------------------------------------------------------------+
void RemoveTrackedPosition(int idx)
{
   if(idx < 0 || idx >= tracked_count) return;
   for(int i = idx; i < tracked_count - 1; i++)
   {
      tracked_positions[i] = tracked_positions[i+1];
   }
   tracked_count--;
   ArrayResize(tracked_positions, tracked_count);
}

//+------------------------------------------------------------------+
//| Send local open/closed trade data to the backend                 |
//+------------------------------------------------------------------+
void SendLocalTradeToBackend(string id, string action, string symbol, double volume, double entry_price, double sl, double tp, string status, ulong ticket, double exit_price, double profit)
{
   string url = backend_url + "/api/signals/local";
   string headers = "Content-Type: application/json\r\n";
   
   string payload = StringFormat(
      "{\"token\":\"%s\",\"id\":\"%s\",\"action\":\"%s\",\"symbol\":\"%s\",\"volume\":%s,\"entry_price\":%s,\"sl\":%s,\"tp\":%s,\"status\":\"%s\",\"ticket\":\"%s\",\"exit_price\":%s,\"profit\":%s}",
      auth_token, id, action, symbol,
      DoubleToString(volume, 2),
      DoubleToString(entry_price, 2),
      DoubleToString(sl, 2),
      DoubleToString(tp, 2),
      status,
      IntegerToString(ticket),
      DoubleToString(exit_price, 2),
      DoubleToString(profit, 2)
   );
   
   Print("ATS EA Debug: Sending Local Trade POST to ", url);
   
   char post_data[];
   StringToCharArray(payload, post_data, 0, StringLen(payload), CP_UTF8);
   
   char result_data[];
   string result_headers;
   
   ResetLastError();
   int http_code = WebRequest("POST", url, headers, 3000, post_data, result_data, result_headers);
   
   if(http_code == 200)
   {
      Print("ATS EA: Local trade status successfully synchronized: ", status);
   }
   else
   {
      Print("ATS EA ERROR: Failed to sync local trade. HTTP Code: ", http_code, " Error Code: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Monitor open and closed trades and sync with backend             |
//+------------------------------------------------------------------+
void SyncPositionsWithBackend()
{
   int current_total = PositionsTotal();
   ulong current_tickets[];
   ArrayResize(current_tickets, current_total);
   
   // 1. Scan for newly opened positions
   for(int i = 0; i < current_total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         current_tickets[i] = ticket;
         
         // Only track positions matching our magic number and symbol
         if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
         if(PositionGetString(POSITION_SYMBOL) != Symbol()) continue;
         
         // Check if already tracked
         bool found = false;
         for(int j = 0; j < tracked_count; j++)
         {
            if(tracked_positions[j].ticket == ticket)
            {
               found = true;
               break;
            }
         }
         
         if(!found)
         {
            // It's a newly opened position!
            string sym = PositionGetString(POSITION_SYMBOL);
            long type = PositionGetInteger(POSITION_TYPE);
            string act = (type == POSITION_TYPE_BUY) ? "BUY" : "SELL";
            double vol = PositionGetDouble(POSITION_VOLUME);
            double open_pr = PositionGetDouble(POSITION_PRICE_OPEN);
            double sl = PositionGetDouble(POSITION_SL);
            double tp = PositionGetDouble(POSITION_TP);
            
            Print("ATS EA: Detected new position #", ticket);
            AddTrackedPosition(ticket, sym, act, vol, open_pr, sl, tp);
            
            // Notify backend
            SendLocalTradeToBackend(IntegerToString(ticket), act, sym, vol, open_pr, sl, tp, "OPEN", ticket, 0.0, 0.0);
         }
      }
   }
   
   // 2. Scan for closed positions
   for(int j = tracked_count - 1; j >= 0; j--)
   {
      ulong ticket = tracked_positions[j].ticket;
      bool found = false;
      for(int i = 0; i < current_total; i++)
      {
         if(current_tickets[i] == ticket)
         {
            found = true;
            break;
         }
      }
      
      if(!found)
      {
         // Position has closed!
         Print("ATS EA: Detected closed position #", ticket);
         
         // Query history to get exit price and profit
         double exit_price = 0.0;
         double profit = 0.0;
         
         if(HistorySelectByPosition(ticket))
         {
            int total_deals = HistoryDealsTotal();
            for(int k = total_deals - 1; k >= 0; k--)
            {
               ulong d_ticket = HistoryDealGetTicket(k);
               if(HistoryDealGetInteger(d_ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
               {
                  exit_price = HistoryDealGetDouble(d_ticket, DEAL_PRICE);
                  profit = HistoryDealGetDouble(d_ticket, DEAL_PROFIT) + HistoryDealGetDouble(d_ticket, DEAL_SWAP) + HistoryDealGetDouble(d_ticket, DEAL_COMMISSION);
                  break;
               }
            }
         }
         
         string status = (profit >= 0.0) ? "WIN" : "LOSS";
         
         // Notify backend
         SendLocalTradeToBackend(
            IntegerToString(ticket), 
            tracked_positions[j].action, 
            tracked_positions[j].symbol, 
            tracked_positions[j].volume, 
            tracked_positions[j].open_price, 
            tracked_positions[j].sl, 
            tracked_positions[j].tp, 
            status, 
            ticket, 
            exit_price, 
            profit
         );
         
         // Delete peak price global variables for this ticket
         string gv_max_p = "ATS_MAX_PRICE_" + IntegerToString(ticket);
         string gv_min_p = "ATS_MIN_PRICE_" + IntegerToString(ticket);
         if(GlobalVariableCheck(gv_max_p)) GlobalVariableDel(gv_max_p);
         if(GlobalVariableCheck(gv_min_p)) GlobalVariableDel(gv_min_p);
         
         // Remove from tracked array
         RemoveTrackedPosition(j);
      }
   }
}

//+------------------------------------------------------------------+
//| Initialize tracked positions array on startup                    |
//+------------------------------------------------------------------+
void InitTrackedPositions()
{
   int current_total = PositionsTotal();
   for(int i = 0; i < current_total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
         if(PositionGetString(POSITION_SYMBOL) != Symbol()) continue;
         
         string sym = PositionGetString(POSITION_SYMBOL);
         long type = PositionGetInteger(POSITION_TYPE);
         string act = (type == POSITION_TYPE_BUY) ? "BUY" : "SELL";
         double vol = PositionGetDouble(POSITION_VOLUME);
         double open_pr = PositionGetDouble(POSITION_PRICE_OPEN);
         double sl = PositionGetDouble(POSITION_SL);
         double tp = PositionGetDouble(POSITION_TP);
         
         AddTrackedPosition(ticket, sym, act, vol, open_pr, sl, tp);
      }
   }
   Print("ATS EA: Initialized tracking for ", tracked_count, " open positions.");
}

//+------------------------------------------------------------------+
//| Helper to query H1/H4 Trend direction                            |
//+------------------------------------------------------------------+
bool GetHTFTrend(ENUM_TIMEFRAMES tf, int ema_len, bool &out_bull, bool &out_bear)
{
   out_bull = true;
   out_bear = true;
   
   int handle = iMA(Symbol(), tf, ema_len, 0, MODE_EMA, PRICE_CLOSE);
   if(handle == INVALID_HANDLE) return false;
   
   double ema_buf[1];
   double close_buf[1];
   
   if(CopyBuffer(handle, 0, 1, 1, ema_buf) < 1 ||
      CopyClose(Symbol(), tf, 1, 1, close_buf) < 1)
   {
      IndicatorRelease(handle);
      return false;
   }
   
   out_bull = (close_buf[0] > ema_buf[0]);
   out_bear = (close_buf[0] < ema_buf[0]);
   
   IndicatorRelease(handle);
   return true;
}

//+------------------------------------------------------------------+
//| Initialize state variables from recent history                   |
//+------------------------------------------------------------------+
void InitStateFromHistory()
{
   int history_bars = 500; // Scan last 500 bars
   double closes[];
   double opens[];
   double highs[];
   double lows[];
   
   ArraySetAsSeries(closes, true);
   ArraySetAsSeries(opens, true);
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);
   
   if(CopyClose(Symbol(), Period(), 0, history_bars, closes) < history_bars ||
      CopyOpen(Symbol(), Period(), 0, history_bars, opens) < history_bars ||
      CopyHigh(Symbol(), Period(), 0, history_bars, highs) < history_bars ||
      CopyLow(Symbol(), Period(), 0, history_bars, lows) < history_bars)
   {
      Print("ATS EA: Error loading history to initialize states.");
      return;
   }
   
   int prev_loop_trend = 0;
   
   // Loop from oldest historical bar to the closed bar (index 1)
   for(int i = history_bars - 2 * InpPivotLength - 1; i >= 1; i--)
   {
      // 1. Calculate Pivot on bar i + InpPivotLength
      int target_idx = i + InpPivotLength;
      bool is_ph = true;
      bool is_pl = true;
      for(int j = 1; j <= 2 * InpPivotLength + 1; j++)
      {
         int check_idx = i + j - 1;
         if(check_idx == target_idx) continue;
         if(highs[check_idx] > highs[target_idx]) is_ph = false;
         if(lows[check_idx] < lows[target_idx]) is_pl = false;
      }
      
      if(is_ph)
      {
         prev_ph = last_ph;
         last_ph = highs[target_idx];
      }
      if(is_pl)
      {
         prev_pl = last_pl;
         last_pl = lows[target_idx];
      }
      
      // 2. Break of Structure
      double close_val = closes[i];
      if(trend <= 0 && last_ph > 0 && close_val > last_ph)
         trend = 1;
      if(trend >= 0 && last_pl > 0 && close_val < last_pl)
         trend = -1;
         
      // 3. Premium/Discount Swings
      if(trend == 1)
      {
         swing_low = (swing_low == 0.0) ? last_pl : swing_low;
         swing_high = MathMax((swing_high == 0.0) ? highs[i] : swing_high, highs[i]);
      }
      else if(trend == -1)
      {
         swing_high = (swing_high == 0.0) ? last_ph : swing_high;
         swing_low = MathMin((swing_low == 0.0) ? lows[i] : swing_low, lows[i]);
      }
      
      if(trend != prev_loop_trend)
      {
         if(trend == 1)
         {
            swing_low = last_pl;
            swing_high = highs[i];
         }
         else if(trend == -1)
         {
            swing_high = last_ph;
            swing_low = lows[i];
         }
         prev_loop_trend = trend;
      }
      
      // 4. Touched Zone Flag
      double swing_range = swing_high - swing_low;
      double discount_level = swing_low + (swing_range * InpPDThreshold);
      double premium_level = swing_high - (swing_range * InpPDThreshold);
      
      if(trend == 1 && lows[i] <= discount_level)
         touched_discount = true;
      if(trend != 1)
         touched_discount = false;
         
      if(trend == -1 && highs[i] >= premium_level)
         touched_premium = true;
      if(trend != -1)
         touched_premium = false;
   }
   
   Print("ATS EA: State synchronized from history. Trend: ", trend, 
         ", Swing High: ", swing_high, ", Swing Low: ", swing_low,
         ", Last PH: ", last_ph, ", Last PL: ", last_pl);
}

//+------------------------------------------------------------------+
//| Calculate Lot Size based on risk parameters                      |
//+------------------------------------------------------------------+
double CalculateQty(double risk_dist)
{
   if(risk_dist <= 0) return InpDefaultLot;
   
   double qty = 0.0;
   double contract_size = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_CONTRACT_SIZE);
   if(contract_size <= 0) contract_size = 1.0;
   
   if(InpRiskMode == RISK_FIXED_CONTRACTS)
   {
      qty = InpFixedQty;
   }
   else if(InpRiskMode == RISK_FIXED_CASH)
   {
      qty = InpRiskAmount / (risk_dist * contract_size);
   }
   else if(InpRiskMode == RISK_PERCENT_EQUITY)
   {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      qty = (equity * (InpRiskAmount / 100.0)) / (risk_dist * contract_size);
   }
   
   // Normalize volume sizes based on broker specifications
   double lot_step = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   double lot_min = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double lot_max = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   
   qty = MathRound(qty / lot_step) * lot_step;
   if(qty < lot_min) qty = lot_min;
   if(qty > lot_max) qty = lot_max;
   
   return qty;
}

//+------------------------------------------------------------------+
//| Main Strategy Logic (Runs at the open of a new bar)              |
//+------------------------------------------------------------------+
void ExecuteStrategyLogic()
{
   int history_needed = 2 * InpPivotLength + 2;
   double closes[];
   double opens[];
   double highs[];
   double lows[];
   
   ArraySetAsSeries(closes, true);
   ArraySetAsSeries(opens, true);
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);
   
   if(CopyClose(Symbol(), Period(), 0, history_needed, closes) < history_needed ||
      CopyOpen(Symbol(), Period(), 0, history_needed, opens) < history_needed ||
      CopyHigh(Symbol(), Period(), 0, history_needed, highs) < history_needed ||
      CopyLow(Symbol(), Period(), 0, history_needed, lows) < history_needed)
   {
      return;
   }
   
   // 1. Detect Pivot High/Low on the completed bar (lookback index InpPivotLength + 1)
   int target_idx = InpPivotLength + 1;
   bool is_ph = true;
   bool is_pl = true;
   for(int j = 1; j <= 2 * InpPivotLength + 1; j++)
   {
      if(j == target_idx) continue;
      if(highs[j] > highs[target_idx]) is_ph = false;
      if(lows[j] < lows[target_idx]) is_pl = false;
   }
   
   if(is_ph)
   {
      prev_ph = last_ph;
      last_ph = highs[target_idx];
      Print("ATS EA: New Pivot High detected at ", last_ph);
   }
   if(is_pl)
   {
      prev_pl = last_pl;
      last_pl = lows[target_idx];
      Print("ATS EA: New Pivot Low detected at ", last_pl);
   }
   
   // 2. Break of Structure (BOS)
   double closed_close = closes[1];
   int prev_trend = trend;
   
   if(trend <= 0 && last_ph > 0.0 && closed_close > last_ph)
   {
      trend = 1;
      Print("ATS EA: Bullish BOS detected. Trend = 1");
   }
   if(trend >= 0 && last_pl > 0.0 && closed_close < last_pl)
   {
      trend = -1;
      Print("ATS EA: Bearish BOS detected. Trend = -1");
   }
   
   // 3. Update Swing Boundaries
   if(trend == 1)
   {
      swing_low = (swing_low == 0.0) ? last_pl : swing_low;
      swing_high = MathMax((swing_high == 0.0) ? highs[1] : swing_high, highs[1]);
   }
   else if(trend == -1)
   {
      swing_high = (swing_high == 0.0) ? last_ph : swing_high;
      swing_low = MathMin((swing_low == 0.0) ? lows[1] : swing_low, lows[1]);
   }
   
   if(trend != prev_trend)
   {
      if(trend == 1)
      {
         swing_low = last_pl;
         swing_high = highs[1];
      }
      else if(trend == -1)
      {
         swing_high = last_ph;
         swing_low = lows[1];
      }
   }
   
   // 4. Calculate Premium/Discount levels
   double swing_range = swing_high - swing_low;
   double discount_level = swing_low + (swing_range * InpPDThreshold);
   double premium_level = swing_high - (swing_range * InpPDThreshold);
   
   double pos_size = GetPositionSize();
   
   // Reset flags when position is open or trend changed
   if(trend != 1 || pos_size > 0)
      touched_discount = false;
   if(trend != -1 || pos_size < 0)
      touched_premium = false;
      
   // Price touches zone
   if(trend == 1 && lows[1] <= discount_level)
      touched_discount = true;
   if(trend == -1 && highs[1] >= premium_level)
      touched_premium = true;
      
   // 5. Confirm Candlestick Price Action
   bool bullish_pa = (closes[2] < opens[2]) && (closes[1] > opens[1]);
   bool bearish_pa = (closes[2] > opens[2]) && (closes[1] < opens[1]);
   
   // 6. Check Local Timeframe EMA Filter
   bool ema_long_cond = true;
   bool ema_short_cond = true;
   if(InpUseEMA)
   {
      int ema_handle = iMA(Symbol(), Period(), InpEMALength, 0, MODE_EMA, PRICE_CLOSE);
      if(ema_handle != INVALID_HANDLE)
      {
         double ema_buf[1];
         if(CopyBuffer(ema_handle, 0, 1, 1, ema_buf) > 0)
         {
            ema_long_cond = (closed_close > ema_buf[0]);
            ema_short_cond = (closed_close < ema_buf[0]);
         }
         IndicatorRelease(ema_handle);
      }
   }
   
   // 7. Check Multi-Timeframe Trend Confirmation (H1 & H4)
   bool h1_bull = true, h1_bear = true;
   if(InpUseH1Trend)
   {
      GetHTFTrend(PERIOD_H1, InpH1EMALen, h1_bull, h1_bear);
   }
   
   bool h4_bull = true, h4_bear = true;
   if(InpUseH4Trend)
   {
      GetHTFTrend(PERIOD_H4, InpH4EMALen, h4_bull, h4_bear);
   }
   
   bool htf_bull = (!InpUseH1Trend || h1_bull) && (!InpUseH4Trend || h4_bull);
   bool htf_bear = (!InpUseH1Trend || h1_bear) && (!InpUseH4Trend || h4_bear);
   
   // Check counter-trend state to select R:R ratio
   bool is_counter_long  = (InpUseH1Trend && h1_bear) || (InpUseH4Trend && h4_bear);
   bool is_counter_short = (InpUseH1Trend && h1_bull) || (InpUseH4Trend && h4_bull);
   
   bool long_trend_ok = !InpFilterCounterTrend || !htf_bear;
   bool short_trend_ok = !InpFilterCounterTrend || !htf_bull;
   
   // Evaluate trigger conditions
   bool longCondition = (trend == 1) && touched_discount && bullish_pa && ema_long_cond && long_trend_ok && (pos_size == 0);
   bool shortCondition = (trend == -1) && touched_premium && bearish_pa && ema_short_cond && short_trend_ok && (pos_size == 0);
   
   // 8. Order Execution
   if(longCondition)
   {
      double sl_price = swing_low - InpSLBuffer;
      double risk = closed_close - sl_price;
      if(risk > 0.0 && risk <= InpMaxSL)
      {
         double active_rr = is_counter_long ? InpRRRatioCounter : InpRRRatio;
         double tp_price = closed_close + (risk * active_rr);
         double qty = CalculateQty(risk);
         
         Print("ATS EA: Entry Signal BUY. Close: ", closed_close, " SL: ", sl_price, " TP: ", tp_price, " Lot: ", qty);
         
         // Set global persistent variables for risk
         string gv_long_risk_name = "ATS_RISK_LONG_" + IntegerToString(InpMagic);
         GlobalVariableSet(gv_long_risk_name, risk);
         
         MqlTick tick;
         if(SymbolInfoTick(Symbol(), tick))
         {
            double ask = tick.ask;
            double actual_risk = ask - sl_price;
            double actual_tp = ask + (actual_risk * active_rr);
            trade.Buy(qty, Symbol(), ask, sl_price, actual_tp, "ATS Local BUY");
         }
      }
   }
   else if(shortCondition)
   {
      double sl_price = swing_high + InpSLBuffer;
      double risk = sl_price - closed_close;
      if(risk > 0.0 && risk <= InpMaxSL)
      {
         double active_rr = is_counter_short ? InpRRRatioCounter : InpRRRatio;
         double tp_price = closed_close - (risk * active_rr);
         double qty = CalculateQty(risk);
         
         Print("ATS EA: Entry Signal SELL. Close: ", closed_close, " SL: ", sl_price, " TP: ", tp_price, " Lot: ", qty);
         
         // Set global persistent variables for risk
         string gv_short_risk_name = "ATS_RISK_SHORT_" + IntegerToString(InpMagic);
         GlobalVariableSet(gv_short_risk_name, risk);
         
         MqlTick tick;
         if(SymbolInfoTick(Symbol(), tick))
         {
            double bid = tick.bid;
            double actual_risk = sl_price - bid;
            double actual_tp = bid - (actual_risk * active_rr);
            trade.Sell(qty, Symbol(), bid, sl_price, actual_tp, "ATS Local SELL");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check and manage Breakeven & Trailing Stop (Runs on every tick)  |
//+------------------------------------------------------------------+
void CheckBEAndTrailing()
{
   // Cleanup persistent variables if no position is open
   if(GetPositionSize() == 0)
   {
      string gv_long = "ATS_RISK_LONG_" + IntegerToString(InpMagic);
      string gv_short = "ATS_RISK_SHORT_" + IntegerToString(InpMagic);
      if(GlobalVariableCheck(gv_long)) GlobalVariableDel(gv_long);
      if(GlobalVariableCheck(gv_short)) GlobalVariableDel(gv_short);
      
      // Cleanup all orphaned max/min peak price variables
      int total_gv = GlobalVariablesTotal();
      for(int k = total_gv - 1; k >= 0; k--)
      {
         string gv_name = GlobalVariableName(k);
         if(StringFind(gv_name, "ATS_MAX_PRICE_") == 0 || StringFind(gv_name, "ATS_MIN_PRICE_") == 0)
         {
            GlobalVariableDel(gv_name);
         }
      }
   }

   if(!InpUseBE && !InpUseTrail) return;
   
   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == Symbol() && PositionGetInteger(POSITION_MAGIC) == InpMagic)
      {
         ulong ticket = PositionGetInteger(POSITION_TICKET);
         double ep = PositionGetDouble(POSITION_PRICE_OPEN);
         double sl = PositionGetDouble(POSITION_SL);
         double tp = PositionGetDouble(POSITION_TP);
         long type = PositionGetInteger(POSITION_TYPE);
         
         string gv_risk_name = (type == POSITION_TYPE_BUY) ? 
            "ATS_RISK_LONG_" + IntegerToString(InpMagic) : 
            "ATS_RISK_SHORT_" + IntegerToString(InpMagic);
            
         if(!GlobalVariableCheck(gv_risk_name)) continue;
         double initial_risk = GlobalVariableGet(gv_risk_name);
         if(initial_risk <= 0.0) continue;
         
         double close_price = SymbolInfoDouble(Symbol(), (type == POSITION_TYPE_BUY) ? SYMBOL_BID : SYMBOL_ASK);
         double new_sl = sl;
         
         if(type == POSITION_TYPE_BUY)
         {
            // 1. Track peak price achieved during the trade
            string gv_max_price = "ATS_MAX_PRICE_" + IntegerToString(ticket);
            double max_price = GlobalVariableCheck(gv_max_price) ? GlobalVariableGet(gv_max_price) : ep;
            if(close_price > max_price)
            {
               max_price = close_price;
               GlobalVariableSet(gv_max_price, max_price);
            }
            
            double profit_r = (max_price - ep) / initial_risk;
            
            // 2. Lock Breakeven (กันทุน)
            if(InpUseBE && profit_r >= InpBETrigger)
            {
               new_sl = MathMax(new_sl, ep);
            }
            
            // 3. Smooth Trailing Stop
            if(InpUseTrail && profit_r >= InpBETrigger)
            {
               double smooth_sl = max_price - (InpTrailDist * initial_risk);
               new_sl = MathMax(new_sl, smooth_sl);
            }
            
            if(new_sl > sl)
            {
               trade.PositionModify(ticket, new_sl, tp);
               Print("ATS EA: Modified SL for Buy position #", ticket, " Old SL: ", sl, " New SL: ", new_sl);
            }
         }
         else if(type == POSITION_TYPE_SELL)
         {
            // 1. Track peak price achieved during the trade
            string gv_min_price = "ATS_MIN_PRICE_" + IntegerToString(ticket);
            double min_price = GlobalVariableCheck(gv_min_price) ? GlobalVariableGet(gv_min_price) : ep;
            if(close_price < min_price)
            {
               min_price = close_price;
               GlobalVariableSet(gv_min_price, min_price);
            }
            
            double profit_r = (ep - min_price) / initial_risk;
            
            // 2. Lock Breakeven (กันทุน)
            if(InpUseBE && profit_r >= InpBETrigger)
            {
               new_sl = (sl == 0.0) ? ep : MathMin(sl, ep);
            }
            
            // 3. Smooth Trailing Stop
            if(InpUseTrail && profit_r >= InpBETrigger)
            {
               double smooth_sl = min_price + (InpTrailDist * initial_risk);
               new_sl = (sl == 0.0) ? smooth_sl : MathMin(sl, smooth_sl);
            }
            
            if(new_sl < sl || sl == 0.0)
            {
               trade.PositionModify(ticket, new_sl, tp);
               Print("ATS EA: Modified SL for Sell position #", ticket, " Old SL: ", sl, " New SL: ", new_sl);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   backend_url = InpBackendURL;
   // Ensure no trailing slash in backend URL
   if(StringSubstr(backend_url, StringLen(backend_url)-1, 1) == "/")
      backend_url = StringSubstr(backend_url, 0, StringLen(backend_url)-1);
      
   auth_token = InpAuthToken;
   
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippage);
   
   // Initialize market structure states from chart history
   InitStateFromHistory();
   
   // Initialize tracked positions for backend sync
   InitTrackedPositions();
   
   // Always start the timer to update the dashboard heartbeat
   EventSetMillisecondTimer(InpPollInterval);
   Print("ATS EA: Heartbeat timer initialized. Interval: ", InpPollInterval, " ms");
   
   if(InpEnableWebhookPolling)
   {
      Print("ATS EA: Webhook Polling enabled. Target URL: ", backend_url);
   }
   else
   {
      Print("ATS EA: Webhook Polling disabled. Running in self-trading mode.");
   }
   
   Print("ATS EA: Initialization completed successfully.");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   Print("ATS EA: Deinitialized.");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // 1. Check Trailing Stop and Breakeven on every tick
   CheckBEAndTrailing();
   
   // 2. Synchronize active and closed positions with the web page on every tick
   SyncPositionsWithBackend();
   
   // 3. Process local algorithm logic once per completed bar
   if(IsNewBar())
   {
      ExecuteStrategyLogic();
   }
}

//+------------------------------------------------------------------+
//| Get current MT5 state as JSON (used by Webhook API if enabled)   |
//+------------------------------------------------------------------+
string GetMT5StateJson()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   
   string positions_json = "[";
   int total = PositionsTotal();
   int count = 0;
   
   for(int i = 0; i < total; i++)
   {
      if(PositionGetSymbol(i) != "")
      {
         ulong ticket = PositionGetInteger(POSITION_TICKET);
         string sym = PositionGetString(POSITION_SYMBOL);
         long type = PositionGetInteger(POSITION_TYPE);
         double vol = PositionGetDouble(POSITION_VOLUME);
         double open_pr = PositionGetDouble(POSITION_PRICE_OPEN);
         double curr_pr = PositionGetDouble(POSITION_PRICE_CURRENT);
         double sl = PositionGetDouble(POSITION_SL);
         double tp = PositionGetDouble(POSITION_TP);
         double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
         
         string pos_type = (type == POSITION_TYPE_BUY) ? "BUY" : "SELL";
         
         if(count > 0) positions_json += ",";
         
         positions_json += StringFormat(
            "{\"ticket\":\"%s\",\"symbol\":\"%s\",\"type\":\"%s\",\"volume\":%s,\"open_price\":%s,\"current_price\":%s,\"sl\":%s,\"tp\":%s,\"profit\":%s}",
            IntegerToString(ticket), sym, pos_type,
            DoubleToString(vol, 2),
            DoubleToString(open_pr, 5),
            DoubleToString(curr_pr, 5),
            DoubleToString(sl, 5),
            DoubleToString(tp, 5),
            DoubleToString(profit, 2)
         );
         count++;
      }
   }
   positions_json += "]";
   
   string json = StringFormat(
      "{\"token\":\"%s\",\"balance\":%s,\"equity\":%s,\"free_margin\":%s,\"bid\":%s,\"ask\":%s,\"positions\":%s}",
      auth_token,
      DoubleToString(balance, 2),
      DoubleToString(equity, 2),
      DoubleToString(free_margin, 2),
      DoubleToString(bid, 5),
      DoubleToString(ask, 5),
      positions_json
   );
   
   return json;
}

//+------------------------------------------------------------------+
//| Timer event function - Poll backend for pending signals          |
//+------------------------------------------------------------------+
void OnTimer()
{
   string url = backend_url + "/api/signals/pending";
   string headers = "Content-Type: application/json\r\n";
   
   string payload = GetMT5StateJson();
   
   char post_data[];
   StringToCharArray(payload, post_data, 0, StringLen(payload), CP_UTF8);
   
   char result_data[];
   string result_headers;
   
   ResetLastError();
   int http_code = WebRequest("POST", url, headers, 3000, post_data, result_data, result_headers);
   
   if(http_code == -1)
   {
      int err = GetLastError();
      if(err == 4014)
      {
         Print("ATS EA ERROR: WebRequest URL not allowed! Add '", backend_url, "' to Allowed URLs list.");
      }
      return;
   }
   
   if(http_code != 200)
   {
      return;
   }
   
   // Only process external signals if webhook polling is enabled
   if(InpEnableWebhookPolling)
   {
      string json_response = CharArrayToString(result_data, 0, WHOLE_ARRAY, CP_UTF8);
      if(json_response != "" && json_response != "[]")
      {
         ProcessSignals(json_response);
      }
   }
}

//+------------------------------------------------------------------+
//| Light-weight JSON Helper Functions                               |
//+------------------------------------------------------------------+
string GetJsonValueString(string json, string key, int start_pos=0)
{
   string pattern = "\"" + key + "\":\"";
   int start = StringFind(json, pattern, start_pos);
   if(start == -1)
   {
      pattern = "\"" + key + "\":";
      start = StringFind(json, pattern, start_pos);
      if(start == -1) return "";
      start += StringLen(pattern);
      
      int end = start;
      while(end < StringLen(json))
      {
         ushort c = StringGetCharacter(json, end);
         if(c == ',' || c == '}' || c == ']' || c == ' ' || c == '\r' || c == '\n') break;
         end++;
      }
      string val = StringSubstr(json, start, end - start);
      StringTrimLeft(val);
      StringTrimRight(val);
      return val;
   }
   
   start += StringLen(pattern);
   int end = StringFind(json, "\"", start);
   if(end == -1) return "";
   return StringSubstr(json, start, end - start);
}

double GetJsonValueDouble(string json, string key, int start_pos=0)
{
   string val = GetJsonValueString(json, key, start_pos);
   return(StringToDouble(val));
}

//+------------------------------------------------------------------+
//| Loop through array and execute signals                           |
//+------------------------------------------------------------------+
void ProcessSignals(string json_array)
{
   int pos = 0;
   int array_len = StringLen(json_array);
   
   while(pos < array_len)
   {
      int obj_start = StringFind(json_array, "{", pos);
      if(obj_start == -1) break;
      
      int obj_end = StringFind(json_array, "}", obj_start);
      if(obj_end == -1) break;
      
      string obj = StringSubstr(json_array, obj_start, obj_end - obj_start + 1);
      pos = obj_end + 1;
      
      string id       = GetJsonValueString(obj, "id");
      string action   = GetJsonValueString(obj, "action");
      string status   = GetJsonValueString(obj, "status");
      string symbol   = GetJsonValueString(obj, "symbol");
      double lot      = GetJsonValueDouble(obj, "volume");
      double sl       = GetJsonValueDouble(obj, "sl");
      double tp       = GetJsonValueDouble(obj, "tp");
      string ticket_s = GetJsonValueString(obj, "ticket");
      ulong  ticket   = StringToInteger(ticket_s);
      
      if(lot <= 0) lot = InpDefaultLot;
      
      string execute_symbol = symbol;
      if(symbol == "XAUUSD" && Symbol() != "XAUUSD")
      {
         if(StringFind(Symbol(), "XAUUSD") == 0 || StringFind(Symbol(), "GOLD") == 0)
            execute_symbol = Symbol();
      }
      
      Print("ATS EA: Received Pending Signal: ", id, " (", action, ") Status: ", status, " Symbol: ", execute_symbol);
      
      if(status == "PENDING_BUY")
      {
         ExecuteBuy(id, execute_symbol, lot, sl, tp);
      }
      else if(status == "PENDING_SELL")
      {
         ExecuteSell(id, execute_symbol, lot, sl, tp);
      }
      else if(status == "PENDING_CLOSE")
      {
         ExecuteClose(id, execute_symbol, ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| Execute BUY Market Order                                         |
//+------------------------------------------------------------------+
void ExecuteBuy(string id, string symbol, double lot, double sl, double tp)
{
   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick))
   {
      Print("ATS EA: Failed to get symbol ticks for ", symbol);
      return;
   }
   
   double price = tick.ask;
   
   Print("ATS EA: Sending BUY order for ", symbol, " Lot: ", lot, " Ask: ", price, " SL: ", sl, " TP: ", tp);
   
   if(trade.Buy(lot, symbol, price, sl, tp, "ATS BUY " + id))
   {
      ulong ticket = trade.ResultOrder();
      if(ticket == 0) ticket = trade.ResultDeal();
      
      double fill_price = trade.ResultPrice();
      if(fill_price <= 0) fill_price = price;
      
      Print("ATS EA: BUY Order Succeeded. Ticket: ", ticket, " Fill: ", fill_price);
      UpdateSignalStatus(id, "OPEN", ticket, fill_price, 0.0, 0.0);
   }
   else
   {
      Print("ATS EA ERROR: BUY execution failed: ", trade.ResultRetcodeDescription());
      UpdateSignalStatus(id, "FAILED", 0, 0.0, 0.0, 0.0);
   }
}

//+------------------------------------------------------------------+
//| Execute SELL Market Order                                        |
//+------------------------------------------------------------------+
void ExecuteSell(string id, string symbol, double lot, double sl, double tp)
{
   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick))
   {
      Print("ATS EA: Failed to get symbol ticks for ", symbol);
      return;
   }
   
   double price = tick.bid;
   
   Print("ATS EA: Sending SELL order for ", symbol, " Lot: ", lot, " Bid: ", price, " SL: ", sl, " TP: ", tp);
   
   if(trade.Sell(lot, symbol, price, sl, tp, "ATS SELL " + id))
   {
      ulong ticket = trade.ResultOrder();
      if(ticket == 0) ticket = trade.ResultDeal();
      
      double fill_price = trade.ResultPrice();
      if(fill_price <= 0) fill_price = price;
      
      Print("ATS EA: SELL Order Succeeded. Ticket: ", ticket, " Fill: ", fill_price);
      UpdateSignalStatus(id, "OPEN", ticket, fill_price, 0.0, 0.0);
   }
   else
   {
      Print("ATS EA ERROR: SELL execution failed: ", trade.ResultRetcodeDescription());
      UpdateSignalStatus(id, "FAILED", 0, 0.0, 0.0, 0.0);
   }
}

//+------------------------------------------------------------------+
//| Close MT5 Position                                               |
//+------------------------------------------------------------------+
void ExecuteClose(string id, string symbol, ulong ticket)
{
   Print("ATS EA: Attempting to close Ticket: ", ticket);
   
   if(ticket <= 0)
   {
      if(PositionSelect(symbol))
      {
         ticket = PositionGetInteger(POSITION_TICKET);
         Print("ATS EA: Found active fallback position. Ticket: ", ticket);
      }
   }
   
   if(ticket > 0)
   {
      if(trade.PositionClose(ticket))
      {
         double profit = 0.0;
         ulong deal_ticket = trade.ResultDeal();
         if(deal_ticket > 0 && HistoryDealSelect(deal_ticket))
         {
            profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
         }
         else
         {
            if(HistorySelectByPosition(ticket))
            {
               int total_deals = HistoryDealsTotal();
               for(int i = total_deals - 1; i >= 0; i--)
               {
                  ulong d_ticket = HistoryDealGetTicket(i);
                  if(HistoryDealGetInteger(d_ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
                  {
                     profit = HistoryDealGetDouble(d_ticket, DEAL_PROFIT);
                     break;
                  }
               }
            }
         }
         double close_price = trade.ResultPrice();
         string result_status = profit >= 0 ? "WIN" : "LOSS";
         
         Print("ATS EA: Position Closed. Ticket: ", ticket, " Close Price: ", close_price, " Profit: ", profit);
         UpdateSignalStatus(id, result_status, ticket, 0.0, close_price, profit);
      }
      else
      {
         Print("ATS EA ERROR: Close execution failed: ", trade.ResultRetcodeDescription());
         UpdateSignalStatus(id, "CLOSE_FAILED", 0, 0.0, 0.0, 0.0);
      }
   }
   else
   {
      Print("ATS EA ERROR: No ticket ID or open position found to close.");
      UpdateSignalStatus(id, "CLOSED_NOT_FOUND", 0, 0.0, 0.0, 0.0);
   }
}

//+------------------------------------------------------------------+
//| Send POST back to Webhook to update database status              |
//+------------------------------------------------------------------+
void UpdateSignalStatus(string id, string status, ulong ticket, double entry_price, double exit_price, double profit)
{
   string url = backend_url + "/api/signals/update";
   string headers = "Content-Type: application/json\r\n";
   
   string payload = StringFormat(
      "{\"token\":\"%s\",\"id\":\"%s\",\"status\":\"%s\",\"ticket\":\"%s\",\"entry_price\":%s,\"exit_price\":%s,\"profit\":%s}",
      auth_token, id, status, IntegerToString(ticket), 
      DoubleToString(entry_price, 2), 
      DoubleToString(exit_price, 2), 
      DoubleToString(profit, 2)
   );
   
   Print("ATS EA Debug: Sending POST to ", url);
   
   char post_data[];
   StringToCharArray(payload, post_data, 0, StringLen(payload), CP_UTF8);
   
   char result_data[];
   string result_headers;
   
   ResetLastError();
   int http_code = WebRequest("POST", url, headers, 3000, post_data, result_data, result_headers);
   
   if(http_code == 200)
   {
      Print("ATS EA: Signal status successfully updated to ", status);
   }
   else
   {
      Print("ATS EA ERROR: Failed to update signal status. HTTP Code: ", http_code, " Error Code: ", GetLastError());
   }
}
//+------------------------------------------------------------------+
