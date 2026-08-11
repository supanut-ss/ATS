//+------------------------------------------------------------------+
//|                              Adaptive_SR_Dashboard_EA.mq5        |
//|  EA implementation based on Adaptive S/R Zones [BigBeluga].     |
//|  Original indicator: CC BY-NC-SA 4.0                            |
//|  https://creativecommons.org/licenses/by-nc-sa/4.0/              |
//|  Updated: Retest & Rejection candle entry strategy             |
//+------------------------------------------------------------------+
#property copyright "Derived from Adaptive S/R Zones [BigBeluga]"
#property link      "https://creativecommons.org/licenses/by-nc-sa/4.0/"
#property version   "1.10"
#property strict

#include <Trade\Trade.mqh>

input group "== Adaptive S/R signal =="
input int      InpPivotLength        = 5;       // Bars on each side of a pivot
input int      InpATRPeriod          = 14;      // ATR period
input double   InpMinATRStrength     = 0.10;    // Minimum pivot strength (ATR x)
input int      InpMaxLevelAgeBars    = 300;     // Remove a level after this many bars
input int      InpMaxLevelsEachSide  = 5;       // Maximum active support/resistance levels
input double   InpMergeThresholdATR  = 0.50;    // Do not add nearby same-side levels (ATR x)
input double   InpBreakSensitivityATR= 0.10;    // Close beyond level by this ATR amount breaks it
input double   InpZoneWidthATR       = 0.40;    // S/R Zone boundary width (ATR x)
input bool     InpRequireRejection   = true;    // Require rejection candle (pinbar/reversal close)
input double   InpMaxCandleATRRatio  = 2.0;     // Max candle body vs ATR (0 = disabled)

input group "== Order and money targets =="
input double   InpFixedLot           = 0.05;    // Volume per signal
input int      InpStopLossPips       = 600;     // Stop Loss in pips/points (e.g. 600 pips = 6.00 USD on XAUUSD)
input int      InpTakeProfitPips     = 1000;    // Take Profit in pips/points (e.g. 1000 pips = 10.00 USD on XAUUSD)
input double   InpTakeProfitMoney    = 50.0;    // Gross TP in USD/account currency (fallback if InpTakeProfitPips <= 0)
input double   InpStopLossMoney      = 30.0;    // Gross SL in USD/account currency (fallback if InpStopLossPips <= 0)
input bool     InpRequireUSDAccount  = true;    // Reject non-USD accounts to preserve dollar targets
input int      InpMaxOpenPositions   = 1;       // Maximum open positions (1 position at a time)
input int      InpMaxSpreadPoints    = 0;       // 0 disables spread filter
input ulong    InpMagicNumber        = 26080601;
input int      InpDeviationPoints    = 30;

input group "== Dashboard API heartbeat =="
input bool     InpEnableHeartbeat    = true;    // Send MT5 state to the dashboard API
input string   InpBackendURL         = "https://ats.thaipesleague.com";
input string   InpAuthToken          = "ats_sec_9f5c4b8e2a1d7f0e3c6b8a9f";
input int      InpHeartbeatSeconds   = 30;      // Heartbeat interval in seconds
input int      InpWebRequestTimeoutMs= 3000;

struct SRLevel
{
   double price;
   int    type;             // 1=resistance, -1=support
   long   pivot_bar_serial;
   datetime pivot_time;
};

CTrade   g_trade;
int      g_atr_handle = INVALID_HANDLE;
SRLevel  g_levels[];
long     g_bar_serial = 0;
datetime g_last_open_time = 0;
bool     g_state_ready = false;
string   g_backend_url = "";

//+------------------------------------------------------------------+
double TickSize()
{
   double value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(value <= 0.0)
      value = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   return value;
}

// Normalize an order price to the symbol's executable tick grid.  Rounding
// away from the entry prevents normalization from making a stop too close.
double NormalizeStopPrice(const double price, const bool round_up)
{
   const double tick = TickSize();
   if(tick <= 0.0)
      return 0.0;

   const double ticks = price / tick;
   const double normalized = round_up
                             ? MathCeil(ticks - 1e-10) * tick
                             : MathFloor(ticks + 1e-10) * tick;
   return NormalizeDouble(normalized,
                          (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
}

//+------------------------------------------------------------------+
double NormalizeVolume(const double requested)
{
   const double minimum = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   const double maximum = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   const double step    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0)
      return 0.0;

   double volume = MathRound(requested / step) * step;
   volume = MathMax(minimum, MathMin(maximum, volume));
   return NormalizeDouble(volume, 8);
}

//+------------------------------------------------------------------+
string BuildHeartbeatJson()
{
   const double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   const double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);

   MqlTick quote;
   ZeroMemory(quote);
   SymbolInfoTick(_Symbol, quote);

   string positions = "[";
   int included = 0;
   for(int i = 0; i < PositionsTotal(); ++i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(included > 0)
         positions += ",";

      const string type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                          ? "BUY" : "SELL";
      positions += StringFormat(
         "{\"ticket\":\"%s\",\"symbol\":\"%s\",\"type\":\"%s\","+
         "\"volume\":%s,\"open_price\":%s,\"current_price\":%s,"+
         "\"sl\":%s,\"tp\":%s,\"profit\":%s}",
         IntegerToString((long)ticket),
         PositionGetString(POSITION_SYMBOL), type,
         DoubleToString(PositionGetDouble(POSITION_VOLUME), 8),
         DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN), 8),
         DoubleToString(PositionGetDouble(POSITION_PRICE_CURRENT), 8),
         DoubleToString(PositionGetDouble(POSITION_SL), 8),
         DoubleToString(PositionGetDouble(POSITION_TP), 8),
         DoubleToString(PositionGetDouble(POSITION_PROFIT) +
                        PositionGetDouble(POSITION_SWAP), 2));
      ++included;
   }
   positions += "]";

   return StringFormat(
      "{\"token\":\"%s\",\"balance\":%s,\"equity\":%s,"+
      "\"free_margin\":%s,\"bid\":%s,\"ask\":%s,\"positions\":%s}",
      InpAuthToken,
      DoubleToString(balance, 2), DoubleToString(equity, 2),
      DoubleToString(free_margin, 2), DoubleToString(quote.bid, _Digits),
      DoubleToString(quote.ask, _Digits), positions);
}

//+------------------------------------------------------------------+
bool SendHeartbeat()
{
   if(!InpEnableHeartbeat)
      return true;

   const string url = g_backend_url + "/api/signals/pending";
   const string headers = "Content-Type: application/json\r\n";
   const string payload = BuildHeartbeatJson();
   char request_data[], response_data[];
   string response_headers;
   StringToCharArray(payload, request_data, 0, StringLen(payload), CP_UTF8);

   ResetLastError();
   const int http_status = WebRequest("POST", url, headers,
                                      InpWebRequestTimeoutMs, request_data,
                                      response_data, response_headers);
   if(http_status == 200)
      return true;

   const int error = GetLastError();
   const string response = CharArrayToString(response_data, 0, WHOLE_ARRAY, CP_UTF8);
   if(http_status == -1 && error == 4014)
      PrintFormat("S/R EA heartbeat: allow '%s' in Tools > Options > Expert Advisors > WebRequest.",
                  g_backend_url);
   else
      PrintFormat("S/R EA heartbeat failed: HTTP=%d, error=%d, response=%s",
                  http_status, error, response);
   return false;
}

//+------------------------------------------------------------------+
bool GetATR(const int shift, double &atr)
{
   double buffer[1];
   if(g_atr_handle == INVALID_HANDLE ||
      BarsCalculated(g_atr_handle) <= shift ||
      CopyBuffer(g_atr_handle, 0, shift, 1, buffer) != 1)
      return false;

   atr = buffer[0];
   if(atr <= 0.0)
      atr = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10.0;
   return (atr > 0.0);
}

//+------------------------------------------------------------------+
bool IsPivotHigh(const int shift)
{
   const double candidate = iHigh(_Symbol, _Period, shift);
   if(candidate <= 0.0)
      return false;

   for(int offset = 1; offset <= InpPivotLength; ++offset)
   {
      if(candidate < iHigh(_Symbol, _Period, shift - offset) ||
         candidate < iHigh(_Symbol, _Period, shift + offset))
         return false;
   }
   return true;
}

//+------------------------------------------------------------------+
bool IsPivotLow(const int shift)
{
   const double candidate = iLow(_Symbol, _Period, shift);
   if(candidate <= 0.0)
      return false;

   for(int offset = 1; offset <= InpPivotLength; ++offset)
   {
      if(candidate > iLow(_Symbol, _Period, shift - offset) ||
         candidate > iLow(_Symbol, _Period, shift + offset))
         return false;
   }
   return true;
}

//+------------------------------------------------------------------+
bool PivotIsStrong(const double price, const int type,
                   const int pivot_shift, const double atr)
{
   if(InpMinATRStrength <= 0.0)
      return true;

   if(type == 1)
   {
      const double near_high = MathMax(iHigh(_Symbol, _Period, pivot_shift - 1),
                                       iHigh(_Symbol, _Period, pivot_shift + 1));
      return ((price - near_high) >= InpMinATRStrength * atr);
   }

   const double near_low = MathMin(iLow(_Symbol, _Period, pivot_shift - 1),
                                   iLow(_Symbol, _Period, pivot_shift + 1));
   return ((near_low - price) >= InpMinATRStrength * atr);
}

//+------------------------------------------------------------------+
void RemoveLevel(const int index)
{
   const int count = ArraySize(g_levels);
   if(index < 0 || index >= count)
      return;

   for(int i = index; i < count - 1; ++i)
      g_levels[i] = g_levels[i + 1];
   ArrayResize(g_levels, count - 1);
}

//+------------------------------------------------------------------+
void PruneOldLevels()
{
   for(int i = ArraySize(g_levels) - 1; i >= 0; --i)
      if((g_bar_serial - g_levels[i].pivot_bar_serial) > InpMaxLevelAgeBars)
         RemoveLevel(i);
}

//+------------------------------------------------------------------+
bool AddLevel(const double price, const int type, const double atr,
              const datetime pivot_time)
{
   int same_side_count = 0;
   for(int i = 0; i < ArraySize(g_levels); ++i)
   {
      if(g_levels[i].type != type)
         continue;
      ++same_side_count;
      if(MathAbs(g_levels[i].price - price) < InpMergeThresholdATR * atr)
         return false;
   }

   if(same_side_count >= InpMaxLevelsEachSide)
      return false;

   const int size = ArraySize(g_levels);
   ArrayResize(g_levels, size + 1);
   g_levels[size].price            = price;
   g_levels[size].type             = type;
   g_levels[size].pivot_bar_serial = g_bar_serial - InpPivotLength;
   g_levels[size].pivot_time       = pivot_time;
   return true;
}

//+------------------------------------------------------------------+
void RemoveBrokenLevels(const double close_price, const double atr)
{
   const double buffer = InpBreakSensitivityATR * atr;
   for(int i = ArraySize(g_levels) - 1; i >= 0; --i)
   {
      const bool resistance_broken = (g_levels[i].type == 1 &&
                                      close_price > g_levels[i].price + buffer);
      const bool support_broken    = (g_levels[i].type == -1 &&
                                      close_price < g_levels[i].price - buffer);
      if(resistance_broken || support_broken)
         RemoveLevel(i);
   }
}

//+------------------------------------------------------------------+
int CountOurPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (ulong)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         ++count;
   }
   return count;
}

//+------------------------------------------------------------------+
bool ProfitAtPrice(const ENUM_ORDER_TYPE order_type, const double volume,
                   const double entry, const double exit_price, double &profit)
{
   ResetLastError();
   if(!OrderCalcProfit(order_type, _Symbol, volume, entry, exit_price, profit))
   {
      PrintFormat("S/R EA: OrderCalcProfit failed. error=%d", GetLastError());
      return false;
   }
   return true;
}

// Find an exit price whose gross P/L equals target_money in account currency.
bool FindMoneyPrice(const ENUM_ORDER_TYPE order_type, const double volume,
                    const double entry, const double target_money,
                    const bool take_profit, double &result)
{
   const bool is_buy = (order_type == ORDER_TYPE_BUY);
   const double direction = (take_profit == is_buy) ? 1.0 : -1.0;
   const double wanted = take_profit ? target_money : -target_money;
   const double tick = TickSize();
   if(tick <= 0.0)
      return false;

   double low_distance = 0.0;
   double high_distance = tick;
   double profit = 0.0;
   bool bracketed = false;

   for(int i = 0; i < 60; ++i)
   {
      const double price = entry + direction * high_distance;
      if(price <= 0.0 || !ProfitAtPrice(order_type, volume, entry, price, profit))
         return false;
      if((take_profit && profit >= wanted) || (!take_profit && profit <= wanted))
      {
         bracketed = true;
         break;
      }
      high_distance *= 2.0;
   }
   if(!bracketed)
      return false;

   for(int i = 0; i < 60; ++i)
   {
      const double mid = (low_distance + high_distance) * 0.5;
      const double price = entry + direction * mid;
      if(!ProfitAtPrice(order_type, volume, entry, price, profit))
         return false;
      if((take_profit && profit >= wanted) || (!take_profit && profit <= wanted))
         high_distance = mid;
      else
         low_distance = mid;
   }

   const double raw = entry + direction * high_distance;
   if(direction > 0.0)
      result = MathCeil(raw / tick - 1e-10) * tick;
   else
      result = MathFloor(raw / tick + 1e-10) * tick;
   result = NormalizeDouble(result, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
   return (result > 0.0);
}

//+------------------------------------------------------------------+
bool StopsAreValid(const ENUM_ORDER_TYPE order_type, const double entry,
                   const double sl, const double tp)
{
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double minimum_distance = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;

   if(order_type == ORDER_TYPE_BUY)
   {
      if(sl >= entry || tp <= entry)
         return false;
      if((entry - sl) + 1e-12 < minimum_distance ||
         (tp - entry) + 1e-12 < minimum_distance)
         return false;
   }
   else
   {
      if(sl <= entry || tp >= entry)
         return false;
      if((sl - entry) + 1e-12 < minimum_distance ||
         (entry - tp) + 1e-12 < minimum_distance)
         return false;
   }
   return true;
}

//+------------------------------------------------------------------+
bool OpenSignalTrade(const int direction, const double level_price,
                     const datetime pivot_time)
{
   if(CountOurPositions() >= InpMaxOpenPositions)
   {
      PrintFormat("S/R EA: signal skipped; max positions (%d) reached.", InpMaxOpenPositions);
      return false;
   }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) ||
      !MQLInfoInteger(MQL_TRADE_ALLOWED) ||
      !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
   {
      Print("S/R EA: signal skipped; automated trading is not allowed.");
      return false;
   }

   MqlTick quote;
   if(!SymbolInfoTick(_Symbol, quote))
      return false;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(InpMaxSpreadPoints > 0 && point > 0.0 &&
      (quote.ask - quote.bid) / point > InpMaxSpreadPoints)
   {
      Print("S/R EA: signal skipped by spread filter.");
      return false;
   }

   const double volume = NormalizeVolume(InpFixedLot);
   if(volume <= 0.0 || MathAbs(volume - InpFixedLot) > 1e-8)
   {
      PrintFormat("S/R EA: %.8f lot is not valid for this broker; signal skipped.", InpFixedLot);
      return false;
   }

   const ENUM_ORDER_TYPE order_type = (direction > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   const double entry = (direction > 0) ? quote.ask : quote.bid;
   double sl = 0.0, tp = 0.0;

   if(InpStopLossPips > 0)
   {
      const double sl_distance = InpStopLossPips * point;
      sl = (direction > 0) ? entry - sl_distance : entry + sl_distance;
      sl = NormalizeStopPrice(sl, direction < 0);
   }
   else if(!FindMoneyPrice(order_type, volume, entry, InpStopLossMoney, false, sl))
   {
      Print("S/R EA: cannot convert money SL target to broker price; signal skipped.");
      return false;
   }

   if(InpTakeProfitPips > 0)
   {
      const double tp_distance = InpTakeProfitPips * point;
      tp = (direction > 0) ? entry + tp_distance : entry - tp_distance;
      tp = NormalizeStopPrice(tp, direction > 0);
   }
   else if(!FindMoneyPrice(order_type, volume, entry, InpTakeProfitMoney, true, tp))
   {
      Print("S/R EA: cannot convert money TP target to broker price; signal skipped.");
      return false;
   }
   if(!StopsAreValid(order_type, entry, sl, tp))
   {
      Print("S/R EA: money-based SL/TP is inside the broker minimum stop distance; signal skipped.");
      return false;
   }

   const string side = (direction > 0) ? "SUPPORT_BUY" : "RESIST_SELL";
   const string comment = StringFormat("SR_%s_%I64d", side, (long)pivot_time);
   ResetLastError();
   const bool sent = (direction > 0)
                     ? g_trade.Buy(volume, _Symbol, 0.0, sl, tp, comment)
                     : g_trade.Sell(volume, _Symbol, 0.0, sl, tp, comment);
   const uint retcode = g_trade.ResultRetcode();
   if(!sent || (retcode != TRADE_RETCODE_DONE &&
                retcode != TRADE_RETCODE_DONE_PARTIAL &&
                retcode != TRADE_RETCODE_PLACED))
   {
      PrintFormat("S/R EA: %s failed. retcode=%u (%s), error=%d",
                  side, retcode, g_trade.ResultRetcodeDescription(), GetLastError());
      return false;
   }

   PrintFormat("S/R EA: %s opened, level=%.*f, lot=%.2f, SL=%.*f (~%.2f), TP=%.*f (~%.2f).",
               side, _Digits, level_price, volume, _Digits, sl, InpStopLossMoney,
               _Digits, tp, InpTakeProfitMoney);
   return true;
}

//+------------------------------------------------------------------+
// Check if closed bar shift experienced a Bullish Rejection at Support Zone
bool IsBullishRejection(const int shift, const double support_price,
                        const double zone_width)
{
   const double open_p  = iOpen(_Symbol, _Period, shift);
   const double high_p  = iHigh(_Symbol, _Period, shift);
   const double low_p   = iLow(_Symbol, _Period, shift);
   const double close_p = iClose(_Symbol, _Period, shift);
   if(open_p <= 0.0 || high_p <= 0.0 || low_p <= 0.0 || close_p <= 0.0)
      return false;

   // Price must enter/touch the Support Zone (Low <= Support + ZoneWidth)
   if(low_p > support_price + zone_width)
      return false;

   // Price must close ABOVE or EQUAL to the Support line (Close >= Support)
   if(close_p < support_price)
      return false;

   if(!InpRequireRejection)
      return true;

   const double range = high_p - low_p;
   if(range <= 0.0)
      return false;

   const double lower_shadow = MathMin(open_p, close_p) - low_p;
   const bool is_bullish_close = (close_p > open_p);
   const bool is_pinbar = (lower_shadow / range >= 0.35);

   return (is_bullish_close || is_pinbar);
}

//+------------------------------------------------------------------+
// Check if closed bar shift experienced a Bearish Rejection at Resistance Zone
bool IsBearishRejection(const int shift, const double resist_price,
                        const double zone_width)
{
   const double open_p  = iOpen(_Symbol, _Period, shift);
   const double high_p  = iHigh(_Symbol, _Period, shift);
   const double low_p   = iLow(_Symbol, _Period, shift);
   const double close_p = iClose(_Symbol, _Period, shift);
   if(open_p <= 0.0 || high_p <= 0.0 || low_p <= 0.0 || close_p <= 0.0)
      return false;

   // Price must enter/touch the Resistance Zone (High >= Resistance - ZoneWidth)
   if(high_p < resist_price - zone_width)
      return false;

   // Price must close BELOW or EQUAL to the Resistance line (Close <= Resistance)
   if(close_p > resist_price)
      return false;

   if(!InpRequireRejection)
      return true;

   const double range = high_p - low_p;
   if(range <= 0.0)
      return false;

   const double upper_shadow = high_p - MathMax(open_p, close_p);
   const bool is_bearish_close = (close_p < open_p);
   const bool is_pinbar = (upper_shadow / range >= 0.35);

   return (is_bearish_close || is_pinbar);
}

//+------------------------------------------------------------------+
// Check if candle body is abnormally large compared to ATR
bool IsCandleTooLarge(const int shift, const double atr)
{
   if(InpMaxCandleATRRatio <= 0.0)
      return false;

   const double open_p = iOpen(_Symbol, _Period, shift);
   const double close_p = iClose(_Symbol, _Period, shift);
   const double body = MathAbs(close_p - open_p);

   return (body > (atr * InpMaxCandleATRRatio));
}

// Process one completed confirmation bar. Historical bars rebuild state only.
void ProcessClosedBar(const int confirmation_shift, const bool allow_trade)
{
   double atr = 0.0;
   if(!GetATR(confirmation_shift, atr))
      return;

   ++g_bar_serial;

   PruneOldLevels();

   const int pivot_shift = confirmation_shift + InpPivotLength;
   const datetime pivot_time = iTime(_Symbol, _Period, pivot_shift);
   const double close_price = iClose(_Symbol, _Period, confirmation_shift);

   // 1. Detect and register new pivot levels
   if(IsPivotHigh(pivot_shift))
   {
      const double resistance_price = iHigh(_Symbol, _Period, pivot_shift);
      if(PivotIsStrong(resistance_price, 1, pivot_shift, atr))
         AddLevel(resistance_price, 1, atr, pivot_time);
   }
   if(IsPivotLow(pivot_shift))
   {
      const double support_price = iLow(_Symbol, _Period, pivot_shift);
      if(PivotIsStrong(support_price, -1, pivot_shift, atr))
         AddLevel(support_price, -1, atr, pivot_time);
   }

   // 2. Remove broken levels before evaluating signal entries
   RemoveBrokenLevels(close_price, atr);

   if(!allow_trade)
      return;

   // 3. Trade Entry Logic: Check active levels for Retest & Rejection at confirmation_shift (bar 1)
   if(CountOurPositions() >= InpMaxOpenPositions)
      return;

   if(IsCandleTooLarge(confirmation_shift, atr))
   {
      PrintFormat("S/R EA: Signal skipped. Candle body at shift %d is too large (Momentum filter).", confirmation_shift);
      return;
   }

   const double zone_width = InpZoneWidthATR * atr;
   for(int i = ArraySize(g_levels) - 1; i >= 0; --i)
   {
      if(CountOurPositions() >= InpMaxOpenPositions)
         break;

      if(g_levels[i].type == -1) // Active Support level
      {
         if(IsBullishRejection(confirmation_shift, g_levels[i].price, zone_width))
         {
            if(OpenSignalTrade(1, g_levels[i].price, g_levels[i].pivot_time))
               break;
         }
      }
      else if(g_levels[i].type == 1) // Active Resistance level
      {
         if(IsBearishRejection(confirmation_shift, g_levels[i].price, zone_width))
         {
            if(OpenSignalTrade(-1, g_levels[i].price, g_levels[i].pivot_time))
               break;
         }
      }
   }
}

//+------------------------------------------------------------------+
bool RebuildLevelState()
{
   ArrayResize(g_levels, 0);
   g_bar_serial = 0;

   const int bars = Bars(_Symbol, _Period);
   const int required = InpPivotLength * 2 + InpATRPeriod + 5;
   if(bars < required)
      return false;

   int oldest_shift = InpMaxLevelAgeBars + InpPivotLength + InpATRPeriod + 10;
   // IsPivotHigh/Low inspect PivotLength bars on both sides of pivot_shift.
   oldest_shift = MathMin(oldest_shift, bars - (InpPivotLength * 2) - 1);
   if(oldest_shift < 1)
      return false;
   if(BarsCalculated(g_atr_handle) <= oldest_shift)
      return false;

   for(int shift = oldest_shift; shift >= 1; --shift)
      ProcessClosedBar(shift, false);
   return true;
}

//+------------------------------------------------------------------+
int OnInit()
{
   if(InpPivotLength < 2 || InpATRPeriod < 1 || InpMaxLevelAgeBars < 20 ||
      InpMaxLevelsEachSide < 1 || InpMergeThresholdATR < 0.0 ||
      InpBreakSensitivityATR < 0.0 || InpZoneWidthATR < 0.0 ||
      InpFixedLot <= 0.0 || InpMaxOpenPositions < 1 ||
      (InpStopLossPips <= 0 && InpStopLossMoney <= 0.0) ||
      (InpTakeProfitPips <= 0 && InpTakeProfitMoney <= 0.0) ||
      (InpEnableHeartbeat &&
       (StringLen(InpBackendURL) == 0 || StringLen(InpAuthToken) == 0 ||
        InpHeartbeatSeconds < 1 || InpWebRequestTimeoutMs < 100)))
   {
      Print("S/R EA: invalid inputs.");
      return INIT_PARAMETERS_INCORRECT;
   }

   const long margin_mode = AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   if(margin_mode != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
   {
      Print("S/R EA: this version requires a hedging account so every signal keeps its own $30 SL and $50-$100 TP.");
      return INIT_FAILED;
   }

   const string account_currency = AccountInfoString(ACCOUNT_CURRENCY);
   if(InpRequireUSDAccount && account_currency != "USD")
   {
      PrintFormat("S/R EA: account currency is %s, not USD. Dollar targets cannot be guaranteed.",
                  account_currency);
      return INIT_FAILED;
   }

   const double normalized_lot = NormalizeVolume(InpFixedLot);
   if(normalized_lot <= 0.0 || MathAbs(normalized_lot - InpFixedLot) > 1e-8)
   {
      PrintFormat("S/R EA: %.8f lot is not supported by this symbol.", InpFixedLot);
      return INIT_PARAMETERS_INCORRECT;
   }

   g_atr_handle = iATR(_Symbol, _Period, InpATRPeriod);
   if(g_atr_handle == INVALID_HANDLE)
   {
      PrintFormat("S/R EA: cannot create ATR handle. error=%d", GetLastError());
      return INIT_FAILED;
   }

   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(InpDeviationPoints);
   g_trade.SetTypeFillingBySymbol(_Symbol);
   g_trade.SetAsyncMode(false);

   g_backend_url = InpBackendURL;
   while(StringLen(g_backend_url) > 0 &&
         StringSubstr(g_backend_url, StringLen(g_backend_url) - 1, 1) == "/")
      g_backend_url = StringSubstr(g_backend_url, 0, StringLen(g_backend_url) - 1);

   if(InpEnableHeartbeat)
   {
      if(MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION))
         Print("S/R EA heartbeat: disabled in Strategy Tester/optimization.");
      else
      {
         if(!EventSetTimer(InpHeartbeatSeconds))
         {
            PrintFormat("S/R EA heartbeat: cannot start timer. error=%d", GetLastError());
            return INIT_FAILED;
         }
         // Send immediately; the dashboard does not need to wait for tick/bar logic.
         SendHeartbeat();
      }
   }

   g_last_open_time = iTime(_Symbol, _Period, 0);
   g_state_ready = RebuildLevelState();
   if(!g_state_ready)
      Print("S/R EA: waiting for enough price history to rebuild S/R state.");

   PrintFormat("S/R EA (Rejection Strategy) ready on %s %s. Lot=%.2f, SL=%.2f, TP=%.2f account currency.",
               _Symbol, EnumToString(_Period), InpFixedLot,
               InpStopLossMoney, InpTakeProfitMoney);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   if(g_atr_handle != INVALID_HANDLE)
      IndicatorRelease(g_atr_handle);
}

//+------------------------------------------------------------------+
void OnTimer()
{
   if(MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION))
      return;
   SendHeartbeat();
}

//+------------------------------------------------------------------+
void OnTick()
{
   const datetime current_open_time = iTime(_Symbol, _Period, 0);
   if(current_open_time <= 0)
      return;

   if(!g_state_ready)
   {
      g_state_ready = RebuildLevelState();
      if(!g_state_ready)
         return;
      // State reconstruction never opens historical trades.
      g_last_open_time = current_open_time;
      Print("S/R EA: S/R history reconstruction completed.");
      return;
   }

   if(current_open_time == g_last_open_time)
      return;

   int closed_bars = iBarShift(_Symbol, _Period, g_last_open_time, true);
   if(closed_bars < 1)
      closed_bars = 1;
   closed_bars = MathMin(closed_bars, InpMaxLevelAgeBars);

   // Do not advance the bar cursor until ATR data for every missed bar is
   // available. Otherwise a transient CopyBuffer failure loses that signal.
   double atr_ready[];
   if(BarsCalculated(g_atr_handle) <= closed_bars ||
      CopyBuffer(g_atr_handle, 0, 1, closed_bars, atr_ready) != closed_bars)
      return;

   // Rebuild missed closed bars in order, but only the latest signal may trade.
   for(int shift = closed_bars; shift >= 1; --shift)
      ProcessClosedBar(shift, shift == 1);

   g_last_open_time = current_open_time;
}
//+------------------------------------------------------------------+
