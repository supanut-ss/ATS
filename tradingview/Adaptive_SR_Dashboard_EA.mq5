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

input group "== Order and money targets =="
input double   InpFixedLot           = 0.05;    // Volume per signal
input double   InpTakeProfitMoney    = 50.0;    // Gross TP in USD/account currency (allowed: 50-100)
input double   InpStopLossMoney      = 30.0;    // Gross SL in USD/account currency
input bool     InpRequireUSDAccount  = true;    // Reject non-USD accounts to preserve dollar targets
input int      InpMaxOpenPositions   = 1;       // Maximum open positions (1 position at a time)
input int      InpMaxSpreadPoints    = 0;       // 0 disables spread filter
input ulong    InpMagicNumber        = 26080601;
input int      InpDeviationPoints    = 30;

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

//+------------------------------------------------------------------+
double TickSize()
{
   double value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(value <= 0.0)
      value = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   return value;
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
   if(!FindMoneyPrice(order_type, volume, entry, InpStopLossMoney, false, sl) ||
      !FindMoneyPrice(order_type, volume, entry, InpTakeProfitMoney, true, tp))
   {
      Print("S/R EA: cannot convert money targets to broker prices; signal skipped.");
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
                        const double zone_width, const double break_buffer)
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

   // Price must not close broken below support (Close >= Support - break_buffer)
   if(close_p < support_price - break_buffer)
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
                        const double zone_width, const double break_buffer)
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

   // Price must not close broken above resistance (Close <= Resistance + break_buffer)
   if(close_p > resist_price + break_buffer)
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

// Process one completed confirmation bar. Historical bars rebuild state only.
void ProcessClosedBar(const int confirmation_shift, const bool allow_trade)
{
   ++g_bar_serial;
   double atr = 0.0;
   if(!GetATR(confirmation_shift, atr))
      return;

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

   const double zone_width = InpZoneWidthATR * atr;
   const double break_buffer = InpBreakSensitivityATR * atr;

   for(int i = ArraySize(g_levels) - 1; i >= 0; --i)
   {
      if(CountOurPositions() >= InpMaxOpenPositions)
         break;

      if(g_levels[i].type == -1) // Active Support level
      {
         if(IsBullishRejection(confirmation_shift, g_levels[i].price, zone_width, break_buffer))
         {
            if(OpenSignalTrade(1, g_levels[i].price, g_levels[i].pivot_time))
               break;
         }
      }
      else if(g_levels[i].type == 1) // Active Resistance level
      {
         if(IsBearishRejection(confirmation_shift, g_levels[i].price, zone_width, break_buffer))
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
   oldest_shift = MathMin(oldest_shift, bars - InpPivotLength - 2);
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
      InpFixedLot <= 0.0 || InpStopLossMoney <= 0.0 ||
      InpTakeProfitMoney < 50.0 || InpTakeProfitMoney > 100.0 ||
      InpMaxOpenPositions < 1)
   {
      Print("S/R EA: invalid inputs. TP Money must be between 50 and 100.");
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
   if(g_atr_handle != INVALID_HANDLE)
      IndicatorRelease(g_atr_handle);
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

   // Rebuild missed closed bars in order, but only the latest signal may trade.
   for(int shift = closed_bars; shift >= 1; --shift)
      ProcessClosedBar(shift, shift == 1);

   g_last_open_time = current_open_time;
}
//+------------------------------------------------------------------+
