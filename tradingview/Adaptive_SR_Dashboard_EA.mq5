//+------------------------------------------------------------------+
//|                              Adaptive_SR_Dashboard_EA.mq5        |
//|  EA implementation based on Adaptive S/R Zones [BigBeluga].     |
//|  Original indicator: CC BY-NC-SA 4.0                            |
//|  https://creativecommons.org/licenses/by-nc-sa/4.0/              |
//|  Updated: Retest & Rejection candle entry strategy             |
//+------------------------------------------------------------------+
#property copyright "Derived from Adaptive S/R Zones [BigBeluga]"
#property link      "https://creativecommons.org/licenses/by-nc-sa/4.0/"
#property version   "1.90"
#property strict

#include <Trade\Trade.mqh>

input group "== Adaptive S/R signal =="
input int      InpPivotLength        = 4;       // Bars on each side of a pivot
input int      InpATRPeriod          = 14;      // ATR period
input double   InpMinATRStrength     = 0.00;    // Minimum pivot strength (ATR x)
input int      InpMaxLevelAgeBars    = 600;     // Remove a level after this many bars
input int      InpMaxLevelsEachSide  = 15;      // Maximum active support/resistance levels
input double   InpMergeThresholdATR  = 0.15;    // Do not add nearby same-side levels (ATR x)
input double   InpBreakSensitivityATR= 0.25;    // Close beyond level by this ATR amount breaks it
input double   InpZoneWidthATR       = 0.25;    // Total S/R zone width (ATR x), matching the indicator
input int      InpMinRetestDelayBars = 1;       // Bars after level confirmation before it can trade
input int      InpRecoveryStartLossStreak = 2;  // Start Recovery after this many consecutive losses (0 = disabled)
input int      InpRecoveryMinRetestDelayBars = 8;// Require an older level while Recovery Mode is active
input int      InpRecoverySideMode   = 2;       // 0=both sides, 1=BUY only, 2=SELL only
input int      InpMaxTradesPerLevel  = 2;       // Maximum distinct retests traded from one level
input int      InpSameLevelCooldownBars = 12;   // Minimum bars between trades from the same level
input double   InpRearmDistanceATR   = 0.25;    // Price must leave the zone by this ATR before another retest
input bool     InpRequireRejection   = true;    // Require a directional rejection candle
input double   InpMinBodyRangeRatio  = 0.05;    // Minimum candle body/range ratio
input double   InpMinWickRangeRatio  = 0.10;    // Minimum rejection wick/range ratio
input double   InpMinCloseLocation   = 0.55;    // Buy close in top / sell close in bottom of candle
input double   InpMaxCandleATRRatio  = 1.50;    // Max candle body vs ATR (0 = disabled)

input group "== Entry filters =="
input bool     InpAutoDirection      = true;    // Dynamically filter each enabled side from the market regime
input bool     InpEnableBuy          = true;    // Hard BUY kill-switch (also enforced in Auto Direction)
input bool     InpEnableSell         = true;    // Hard SELL kill-switch (also enforced in Auto Direction)
input bool     InpUseEMAFilter       = false;   // Optional EMA trend filter; disabled by high-frequency preset
input int      InpEMAPeriod          = 200;     // EMA period on the chart timeframe
input int      InpEMASlopeBars       = 3;       // EMA slope comparison bars
input int      InpAutoBuyEMAPeriod   = 300;     // Bull-regime EMA used by automatic Support BUY
input int      InpAutoBuySlopeBars   = 6;       // EMA lookback used to confirm rising trend
input double   InpAutoBuyMinSlopeATR = 0.00;    // Minimum EMA rise over lookback (ATR x)
input double   InpAutoBuyMinDistanceATR = 0.00; // Minimum close above EMA (ATR x)
input int      InpAutoBuyStartHour   = 7;       // Automatic BUY session start, server hour
input int      InpAutoBuyEndHour     = 19;      // Automatic BUY session end, server hour
input bool     InpAutoBuyUsePauseWindow = true; // Block BUY during the weaker intraday window
input int      InpAutoBuyPauseStartHour = 13;   // BUY pause start, server hour (inclusive)
input int      InpAutoBuyPauseEndHour   = 15;   // BUY pause end, server hour (exclusive)
input double   InpBuyMinBodyRangeRatio = 0.15;  // BUY-only minimum bullish body/range
input double   InpBuyMinWickRangeRatio = 0.20;  // BUY-only minimum lower wick/range
input double   InpBuyMinCloseLocation  = 0.65;  // BUY-only close location within candle
input int      InpAutoSellRegimeMode = 1;       // 0=all regimes, 1=not strong bull, 2=bear only
input int      InpSessionStartHour   = 7;       // Broker-server hour, inclusive
input int      InpSessionEndHour     = 19;      // Broker-server hour, exclusive
input int      InpCooldownBars       = 3;       // Minimum bars between entries
input int      InpMaxDailyLosses     = 3;       // 0 disables daily loss guard
input int      InpPauseAfterLossMinutes = 60;   // Block new entries after every losing exit
input int      InpMaxConsecutiveLosses = 0;     // 0 disables cross-day loss-streak pause
input int      InpLossStreakPauseBars  = 288;   // Pause after streak (288 M5 bars = 24 hours)
input double   InpBreakEvenThresholdMoney = 1.0;// Result within +/- this amount is break-even
input bool     InpShowStatsDashboard = true;    // Show trades, win rate and break-even count on chart

input group "== Market schedule safety =="
input bool     InpUseBrokerSessions   = true;    // Follow symbol sessions published by the broker
input int      InpCloseBeforeDailyMinutes = 5;   // Close positions before every daily session break
input int      InpCloseBeforeWeekendMinutes = 30;// Close positions before the final Friday session ends
input int      InpBlockEntriesBeforeCloseMinutes = 10; // Stop new entries near a session close
input int      InpBlockAfterSessionOpenMinutes = 15;    // Avoid spreads/gaps just after a session opens
input bool     InpBlockIfScheduleUnavailable = true;   // Fail safe when broker session data is unavailable
input int      InpScheduleTimerSeconds = 5;      // Schedule check frequency while terminal is running
input bool     InpUseHardDailyCutoff = true;     // Fallback close independent of broker session metadata
input int      InpHardDailyCloseHour = 18;       // Daily fallback close, server hour
input int      InpHardDailyCloseMinute = 30;     // Daily fallback close, server minute
input int      InpHardFridayCloseHour = 18;      // Friday fallback close, server hour
input int      InpHardFridayCloseMinute = 15;    // Friday fallback close, server minute
input bool     InpUseHolidayEarlyCutoff = true;  // Earlier fallback on common gold-market holidays
input int      InpHolidayEarlyCloseHour = 16;    // Holiday fallback close, server hour
input int      InpHolidayEarlyCloseMinute = 30;  // Holiday fallback close, server minute

input group "== Order and money targets =="
input double   InpFixedLot           = 0.05;    // Volume per signal
input int      InpStopLossPips       = 0;       // Optional platform-point SL override; 0 uses money target
input int      InpTakeProfitPips     = 0;       // Optional platform-point TP override; 0 uses money target
input double   InpTakeProfitMoney    = 75.0;    // Gross TP in USD/account currency
input double   InpStopLossMoney      = 30.0;    // Gross SL in USD/account currency
input bool     InpUseATRAdjustedStop = false;   // Optional wider SL in high volatility (disabled in validated preset)
input double   InpMinimumStopATR     = 1.50;    // Minimum SL distance as ATR multiple

input group "== Dynamic exit =="
input int      InpExitMode           = 0;       // 0=fixed TP, 1=ATR dynamic, 2=Hybrid S/R + ATR
input double   InpBreakEvenActivationMoney = 45.0; // Start protecting profit at this gross P/L
input double   InpBreakEvenLockMoney = 5.0;     // Gross profit locked when break-even activates
input double   InpTrailActivationMoney = 60.0;  // Start ATR trailing at this gross P/L
input double   InpTrailATRMultiplier = 1.80;    // Trailing distance in ATR
input double   InpStructureExitMinProfitMoney = 35.0; // Hybrid: minimum profit before opposite S/R exit

input group "== Demo trade analytics webhook =="
input bool     InpEnableDemoAnalytics = false; // Enable only in a dedicated Demo/Test preset
input string   InpAnalyticsBaseURL = "https://ats.thaipesleague.com/demo";
input string   InpAnalyticsToken = "";       // Set only in Demo Inputs; never compile secrets into EX5
input string   InpAnalyticsAccountRef = "demo-sr"; // Dataset prefix; EA adds an anonymous account hash
input int      InpAnalyticsRetrySeconds = 15;  // Initial retry delay; failures use capped exponential backoff
input int      InpAnalyticsTimeoutMs = 500;    // Keep the synchronous MT5 request short

input group "== Account/order controls =="
input bool     InpRequireUSDAccount  = true;    // Reject non-USD accounts to preserve dollar targets
input int      InpMaxOpenPositions   = 1;       // Maximum open positions (1 position at a time)
input int      InpMaxSpreadPoints    = 250;     // Maximum entry spread in platform points; 0 disables
input ulong    InpMagicNumber        = 26080601;
input int      InpDeviationPoints    = 30;

struct SRLevel
{
   double price;
   int    type;             // 1=resistance, -1=support
   long   pivot_bar_serial;
   long   created_bar_serial;
   datetime pivot_time;
   int    trade_count;
   long   last_trade_serial;
   bool   rearmed;
};

struct TradeTelemetry
{
   ulong position_id;
   string action;
   string signal_type;
   datetime entry_time;
   double entry_price;
   double volume;
   double initial_sl;
   double initial_tp;
   double level_price;
   datetime pivot_time;
   double spread_points;
   double atr;
   string market_regime;
   string session_name;
   int entry_hour;
   int loss_streak_before;
   double mfe;
   double mae;
   bool closed;
   datetime exit_time;
   double exit_price;
   double profit;
   double commission;
   double swap;
   string exit_reason;
   datetime last_send_attempt;
   int retry_count;
   int broker_utc_offset_seconds;
   string protective_stop_reason;
   string data_quality;
   string account_ref;
   string settings_hash;
   string ea_version;
};

struct ClosedPositionResult
{
   ulong position_id;
   double net_result;
   datetime exit_time;
};

CTrade   g_trade;
int      g_atr_handle = INVALID_HANDLE;
int      g_ema_handle = INVALID_HANDLE;
int      g_auto_buy_ema_handle = INVALID_HANDLE;
SRLevel  g_levels[];
long     g_bar_serial = 0;
long     g_last_trade_serial = -1000000;
datetime g_last_open_time = 0;
bool     g_state_ready = false;
TradeTelemetry g_trade_telemetry[];
string   g_exit_reason_override = "";
ulong    g_exit_reason_position_id = 0;
bool     g_demo_analytics_active = false;
ulong    g_last_close_attempt_position_id = 0;
ulong    g_last_close_attempt_ms = 0;
ulong    g_counted_position_ids[];
ulong    g_pending_exit_position_ids[];
bool     g_level_trade_state_ready = false;
bool     g_outbox_writable = true;
bool     g_pending_entry_active = false;
ulong    g_pending_entry_order = 0;
ulong    g_pending_entry_since_ms = 0;
int      g_pending_entry_direction = 0;
double   g_pending_entry_level_price = 0.0;
datetime g_pending_entry_pivot_time = 0;
double   g_pending_entry_atr = 0.0;
double   g_pending_entry_initial_sl = 0.0;
double   g_pending_entry_initial_tp = 0.0;
double   g_pending_entry_requested_volume = 0.0;
double   g_pending_entry_spread_points = 0.0;

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
double NormalizeVolumeDown(const double requested)
{
   const double minimum = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   const double maximum = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   const double step    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0 || requested < minimum)
      return 0.0;

   double volume = MathFloor(requested / step + 1e-9) * step;
   volume = MathMin(maximum, volume);
   if(volume < minimum)
      return 0.0;
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
   g_levels[size].created_bar_serial = g_bar_serial;
   g_levels[size].pivot_time       = pivot_time;
   g_levels[size].trade_count      = 0;
   g_levels[size].last_trade_serial= -1000000;
   g_levels[size].rearmed          = true;
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
int FindUlongValue(const ulong &values[], const ulong value)
{
   for(int i = 0; i < ArraySize(values); ++i)
      if(values[i] == value)
         return i;
   return -1;
}

//+------------------------------------------------------------------+
bool AddUniqueUlong(ulong &values[], const ulong value)
{
   if(value == 0 || FindUlongValue(values, value) >= 0)
      return (value != 0);
   const int size = ArraySize(values);
   if(ArrayResize(values, size + 1) != size + 1)
      return false;
   values[size] = value;
   return true;
}

//+------------------------------------------------------------------+
void RemoveUlongAt(ulong &values[], const int index)
{
   const int last = ArraySize(values) - 1;
   if(index < 0 || index > last)
      return;
   for(int i = index; i < last; ++i)
      values[i] = values[i + 1];
   ArrayResize(values, last);
}

//+------------------------------------------------------------------+
bool ParseSignalComment(const string comment, int &level_type,
                        datetime &pivot_time)
{
   string prefix = "";
   if(StringFind(comment, "SRB_") == 0)
   {
      level_type = -1;
      prefix = "SRB_";
   }
   else if(StringFind(comment, "SRS_") == 0)
   {
      level_type = 1;
      prefix = "SRS_";
   }
   else if(StringFind(comment, "SR_SUPPORT_BUY_") == 0)
   {
      level_type = -1;
      prefix = "SR_SUPPORT_BUY_";
   }
   else if(StringFind(comment, "SR_RESISTANCE_SELL_") == 0)
   {
      level_type = 1;
      prefix = "SR_RESISTANCE_SELL_";
   }
   else if(StringFind(comment, "SR_RESIST_SELL_") == 0)
   {
      level_type = 1; // Backward-compatible v1.89/v1.90 short label.
      prefix = "SR_RESIST_SELL_";
   }
   else
      return false;

   pivot_time = (datetime)StringToInteger(
      StringSubstr(comment, StringLen(prefix)));
   return (pivot_time > 0);
}

//+------------------------------------------------------------------+
int FindLevelByPivot(const int level_type, const datetime pivot_time)
{
   for(int i = 0; i < ArraySize(g_levels); ++i)
      if(g_levels[i].type == level_type &&
         g_levels[i].pivot_time == pivot_time)
         return i;
   return -1;
}

//+------------------------------------------------------------------+
long EntrySerialFromTime(const datetime entry_time)
{
   const int shift = iBarShift(_Symbol, _Period, entry_time, false);
   if(shift < 0)
      return g_bar_serial;
   const long serial = g_bar_serial - shift;
   return (serial > 0 ? serial : 0);
}

//+------------------------------------------------------------------+
bool LevelRearmedAfterLastTrade(const int level_index)
{
   if(level_index < 0 || level_index >= ArraySize(g_levels) ||
      g_levels[level_index].last_trade_serial < 0)
      return true;
   const long age = g_bar_serial - g_levels[level_index].last_trade_serial;
   if(age <= 1)
      return false;

   const int oldest_shift = (int)MathMin((long)Bars(_Symbol, _Period) - 1,
                                         age - 1);
   for(int shift = oldest_shift; shift >= 1; --shift)
   {
      double atr = 0.0;
      if(!GetATR(shift, atr) || atr <= 0.0)
         continue;
      const double zone_half_width = InpZoneWidthATR * atr * 0.5;
      const double rearm_distance = InpRearmDistanceATR * atr;
      if((g_levels[level_index].type == -1 &&
          iLow(_Symbol, _Period, shift) > g_levels[level_index].price +
                                             zone_half_width + rearm_distance) ||
         (g_levels[level_index].type == 1 &&
          iHigh(_Symbol, _Period, shift) < g_levels[level_index].price -
                                              zone_half_width - rearm_distance))
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
bool ApplyPositionEntryToLevelState(const ulong position_id,
                                    const string comment,
                                    const datetime entry_time)
{
   if(position_id == 0)
      return false;
   if(FindUlongValue(g_counted_position_ids, position_id) >= 0)
      return true; // Multiple partial fills still consume the level only once.

   int level_type = 0;
   datetime pivot_time = 0;
   if(!ParseSignalComment(comment, level_type, pivot_time))
      return false;
   if(!AddUniqueUlong(g_counted_position_ids, position_id))
      return false;

   const long entry_serial = EntrySerialFromTime(entry_time);
   if(entry_serial > g_last_trade_serial)
      g_last_trade_serial = entry_serial;
   const int level_index = FindLevelByPivot(level_type, pivot_time);
   if(level_index < 0)
      return true; // Still restore the global cooldown for an expired level.

   ++g_levels[level_index].trade_count;
   if(entry_serial >= g_levels[level_index].last_trade_serial)
   {
      g_levels[level_index].last_trade_serial = entry_serial;
      g_levels[level_index].rearmed = false;
   }
   return true;
}

//+------------------------------------------------------------------+
bool RestoreLevelTradeStateFromHistory()
{
   ArrayResize(g_counted_position_ids, 0);
   g_last_trade_serial = -1000000;
   for(int i = 0; i < ArraySize(g_levels); ++i)
   {
      g_levels[i].trade_count = 0;
      g_levels[i].last_trade_serial = -1000000;
      g_levels[i].rearmed = true;
   }

   const int seconds_per_bar = PeriodSeconds(_Period);
   if(seconds_per_bar <= 0)
      return false;
   const long bars_to_scan = MathMax((long)InpMaxLevelAgeBars +
                                     InpPivotLength + InpATRPeriod + 20,
                                     (long)MathMax(InpCooldownBars,
                                                   InpSameLevelCooldownBars) + 20);
   const datetime now = TimeCurrent();
   // Use iTime() to correctly account for weekends/holidays instead of
   // multiplying bars * seconds (which underestimates wall-clock distance).
   const int total_bars = Bars(_Symbol, _Period);
   datetime from_time = 0;
   if(bars_to_scan < (long)total_bars)
      from_time = iTime(_Symbol, _Period, (int)bars_to_scan);
   if(!HistorySelect(from_time, now))
      return false;

   for(int i = 0; i < HistoryDealsTotal(); ++i)
   {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0 || HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol ||
         (ulong)HistoryDealGetInteger(deal, DEAL_MAGIC) != InpMagicNumber)
         continue;
      const long entry_type = HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry_type != DEAL_ENTRY_IN && entry_type != DEAL_ENTRY_INOUT)
         continue;
      const ulong position_id =
         (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
      if(FindUlongValue(g_counted_position_ids, position_id) >= 0)
         continue;
      const string comment = HistoryDealGetString(deal, DEAL_COMMENT);
      int parsed_type = 0;
      datetime parsed_pivot = 0;
      if(!ParseSignalComment(comment, parsed_type, parsed_pivot))
         continue;
      if(!ApplyPositionEntryToLevelState(
            position_id, comment,
            (datetime)HistoryDealGetInteger(deal, DEAL_TIME)))
         return false;
   }

   for(int i = 0; i < ArraySize(g_levels); ++i)
      if(g_levels[i].trade_count > 0)
         g_levels[i].rearmed = LevelRearmedAfterLastTrade(i);
   return true;
}

//+------------------------------------------------------------------+
int SecondsOfDay(const datetime value)
{
   MqlDateTime stamp;
   TimeToStruct(value, stamp);
   return stamp.hour * 3600 + stamp.min * 60 + stamp.sec;
}

//+------------------------------------------------------------------+
bool IsKnownHolidayEarlyClose(const MqlDateTime &stamp)
{
   if(stamp.mon == 7 &&
      (stamp.day == 4 ||
       (stamp.day == 3 && stamp.day_of_week == FRIDAY) ||
       (stamp.day == 5 && stamp.day_of_week == MONDAY)))
      return true;

   if(stamp.mon == 11 &&
      ((stamp.day_of_week == THURSDAY && stamp.day >= 22 && stamp.day <= 28) ||
       (stamp.day_of_week == FRIDAY && stamp.day >= 23 && stamp.day <= 29)))
      return true;

   if(stamp.mon == 12 &&
      (stamp.day == 24 || stamp.day == 31 ||
       (stamp.day == 23 && stamp.day_of_week == FRIDAY)))
      return true;
   return false;
}

//+------------------------------------------------------------------+
int HardCutoffSeconds(const MqlDateTime &stamp)
{
   if(InpUseHolidayEarlyCutoff && IsKnownHolidayEarlyClose(stamp))
      return InpHolidayEarlyCloseHour * 3600 + InpHolidayEarlyCloseMinute * 60;
   if(stamp.day_of_week == FRIDAY)
      return InpHardFridayCloseHour * 3600 + InpHardFridayCloseMinute * 60;
   return InpHardDailyCloseHour * 3600 + InpHardDailyCloseMinute * 60;
}

// Locate the broker trading session containing 'moment'. The returned
// remaining time is measured to that exact session end, including sessions
// that cross midnight.
bool GetCurrentBrokerSession(const datetime moment, bool &schedule_available,
                             int &seconds_since_start, int &seconds_until_end)
{
   schedule_available = false;
   seconds_since_start = 0;
   seconds_until_end = 0;
   MqlDateTime stamp;
   TimeToStruct(moment, stamp);
   const int now_seconds = stamp.hour * 3600 + stamp.min * 60 + stamp.sec;

   for(uint index = 0; ; ++index)
   {
      datetime session_from = 0, session_to = 0;
      if(!SymbolInfoSessionTrade(_Symbol, (ENUM_DAY_OF_WEEK)stamp.day_of_week,
                                 index, session_from, session_to))
         break;

      schedule_available = true;
      const int start_seconds = SecondsOfDay(session_from);
      int end_seconds = SecondsOfDay(session_to);
      if(end_seconds == start_seconds)
      {
         seconds_since_start = 86400;
         seconds_until_end = 86400;
         return true;
      }

      if(start_seconds < end_seconds)
      {
         if(now_seconds >= start_seconds && now_seconds < end_seconds)
         {
            seconds_since_start = now_seconds - start_seconds;
            seconds_until_end = end_seconds - now_seconds;
            return true;
         }
      }
      else
      {
         if(now_seconds >= start_seconds)
         {
            seconds_since_start = now_seconds - start_seconds;
            seconds_until_end = 86400 - now_seconds + end_seconds;
            return true;
         }
         if(now_seconds < end_seconds)
         {
            seconds_since_start = 86400 - start_seconds + now_seconds;
            seconds_until_end = end_seconds - now_seconds;
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
int ScheduleCloseLeadSeconds(const datetime moment)
{
   MqlDateTime stamp;
   TimeToStruct(moment, stamp);
   int lead_minutes = InpCloseBeforeDailyMinutes;
   if(stamp.day_of_week == FRIDAY)
      lead_minutes = MathMax(lead_minutes, InpCloseBeforeWeekendMinutes);
   return MathMax(0, lead_minutes) * 60;
}

//+------------------------------------------------------------------+
bool MarketScheduleAllowsEntry(const datetime moment)
{
   MqlDateTime stamp;
   TimeToStruct(moment, stamp);
   if(stamp.day_of_week == SATURDAY || stamp.day_of_week == SUNDAY)
      return false;

   if(InpUseHardDailyCutoff)
   {
      const int now_seconds = stamp.hour * 3600 + stamp.min * 60 + stamp.sec;
      const int cutoff_seconds = HardCutoffSeconds(stamp);
      if(now_seconds >= cutoff_seconds)
         return false;
   }

   if(!InpUseBrokerSessions)
      return true;

   bool schedule_available = false;
   int seconds_since_start = 0;
   int seconds_until_end = 0;
   const bool session_open = GetCurrentBrokerSession(moment, schedule_available,
                                                     seconds_since_start,
                                                     seconds_until_end);
   if(!schedule_available)
      return !InpBlockIfScheduleUnavailable;
   if(!session_open)
      return false;
   if(InpBlockAfterSessionOpenMinutes > 0 &&
      seconds_since_start < InpBlockAfterSessionOpenMinutes * 60)
      return false;

   int block_minutes = InpBlockEntriesBeforeCloseMinutes;
   if(stamp.day_of_week == FRIDAY)
      block_minutes = MathMax(block_minutes, InpCloseBeforeWeekendMinutes);
   return (seconds_until_end > MathMax(0, block_minutes) * 60);
}

//+------------------------------------------------------------------+
bool IsConfirmedTradeRetcode(const uint retcode)
{
   return (retcode == TRADE_RETCODE_DONE ||
           retcode == TRADE_RETCODE_DONE_PARTIAL ||
           retcode == TRADE_RETCODE_PLACED);
}

//+------------------------------------------------------------------+
// A successful CTrade call only confirms that the request was accepted locally.
// This helper also checks the server retcode and verifies that the position no
// longer exists before assigning an EA-specific exit reason.
bool ClosePositionConfirmed(const ulong ticket, const string reason,
                            const string context)
{
   if(!PositionSelectByTicket(ticket))
      return true;

   const ulong position_id = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
   if(position_id == 0)
      return false;

   const ulong now_ms = GetTickCount64();
   if(g_last_close_attempt_position_id == position_id &&
      now_ms >= g_last_close_attempt_ms &&
      now_ms - g_last_close_attempt_ms < 1000)
      return false;
   g_last_close_attempt_position_id = position_id;
   g_last_close_attempt_ms = now_ms;

   g_exit_reason_position_id = position_id;
   g_exit_reason_override = reason;
   ResetLastError();
   const bool sent = g_trade.PositionClose(ticket, (ulong)InpDeviationPoints);
   const uint retcode = g_trade.ResultRetcode();
   const int terminal_error = GetLastError();
   const bool retcode_ok = IsConfirmedTradeRetcode(retcode);
   const bool still_open = PositionIdentifierIsOpen(position_id);
   g_exit_reason_override = "";
   g_exit_reason_position_id = 0;

   if(sent && retcode_ok && !still_open)
   {
      SetTelemetryExitReasonByPositionId(position_id, reason);
      PrintFormat("S/R EA: %s confirmed. ticket=%I64u position=%I64u retcode=%u.",
                  context, ticket, position_id, retcode);
      return true;
   }

   PrintFormat("S/R EA: %s not confirmed; it will retry while the exit condition remains. "
               "ticket=%I64u position=%I64u sent=%s retcode=%u (%s) still_open=%s error=%d",
               context, ticket, position_id, (sent ? "true" : "false"), retcode,
               g_trade.ResultRetcodeDescription(), (still_open ? "true" : "false"),
               terminal_error);
   return false;
}

//+------------------------------------------------------------------+
bool CloseOurPositionsForSchedule(const string reason)
{
   bool all_closed = true;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      const bool closed = ClosePositionConfirmed(ticket, reason, "schedule close");
      if(!closed)
      {
         all_closed = false;
      }
   }
   return all_closed;
}

//+------------------------------------------------------------------+
bool ManageMarketSchedule()
{
   const int open_positions = CountOurPositions();
   const datetime now = TimeCurrent();
   MqlDateTime stamp;
   TimeToStruct(now, stamp);
   if(InpUseHardDailyCutoff)
   {
      const int now_seconds = stamp.hour * 3600 + stamp.min * 60 + stamp.sec;
      const int cutoff_seconds = HardCutoffSeconds(stamp);
      if(now_seconds >= cutoff_seconds)
      {
         const string hard_reason = (stamp.day_of_week == FRIDAY ?
                                     "HARD_FRIDAY_CUTOFF" : "HARD_DAILY_CUTOFF");
         if(open_positions > 0)
            CloseOurPositionsForSchedule(hard_reason);
         return true;
      }
   }

   if(open_positions <= 0)
      return false;

   if(!InpUseBrokerSessions)
      return false;

   bool schedule_available = false;
   int seconds_since_start = 0;
   int seconds_until_end = 0;
   const bool session_open = GetCurrentBrokerSession(now, schedule_available,
                                                     seconds_since_start,
                                                     seconds_until_end);
   if(!schedule_available || !session_open)
      return false; // A broker cannot accept a close after its market is already shut.

   const int close_lead = ScheduleCloseLeadSeconds(now);
   if(close_lead > 0 && seconds_until_end <= close_lead)
   {
      const string reason = (stamp.day_of_week == FRIDAY ?
                             "WEEKEND_MARKET_CLOSE" : "DAILY_MARKET_BREAK");
      CloseOurPositionsForSchedule(reason);
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
bool IsWithinTradingSession(const int shift)
{
   if(InpSessionStartHour == InpSessionEndHour)
      return true;

   MqlDateTime stamp;
   TimeToStruct(iTime(_Symbol, _Period, shift), stamp);
   if(InpSessionStartHour < InpSessionEndHour)
      return (stamp.hour >= InpSessionStartHour && stamp.hour < InpSessionEndHour);
   return (stamp.hour >= InpSessionStartHour || stamp.hour < InpSessionEndHour);
}

//+------------------------------------------------------------------+
bool PassEMAFilter(const int direction, const int shift)
{
   if(!InpUseEMAFilter)
      return true;
   if(g_ema_handle == INVALID_HANDLE || BarsCalculated(g_ema_handle) <= shift + InpEMASlopeBars)
      return false;

   double current_value[1], past_value[1];
   if(CopyBuffer(g_ema_handle, 0, shift, 1, current_value) != 1 ||
      CopyBuffer(g_ema_handle, 0, shift + InpEMASlopeBars, 1, past_value) != 1)
      return false;

   const double close_price = iClose(_Symbol, _Period, shift);
   if(direction > 0)
      return (close_price > current_value[0] && current_value[0] > past_value[0]);
   return (close_price < current_value[0] && current_value[0] < past_value[0]);
}

//+------------------------------------------------------------------+
bool IsHourWithin(const int hour_value, const int start_hour, const int end_hour)
{
   if(start_hour == end_hour)
      return true;
   if(start_hour < end_hour)
      return (hour_value >= start_hour && hour_value < end_hour);
   return (hour_value >= start_hour || hour_value < end_hour);
}

// Automatic direction regime. BUY requires a confirmed rising EMA and price
// above it. SELL can remain available in all regimes or be restricted by input.
bool GetAutoDirectionPermissions(const int shift, const double atr,
                                 bool &buy_allowed, bool &sell_allowed)
{
   buy_allowed = false;
   sell_allowed = false;
   if(g_auto_buy_ema_handle == INVALID_HANDLE ||
      BarsCalculated(g_auto_buy_ema_handle) <= shift + InpAutoBuySlopeBars)
      return false;

   double current_value[1], past_value[1];
   if(CopyBuffer(g_auto_buy_ema_handle, 0, shift, 1, current_value) != 1 ||
      CopyBuffer(g_auto_buy_ema_handle, 0, shift + InpAutoBuySlopeBars, 1, past_value) != 1)
      return false;

   const double close_price = iClose(_Symbol, _Period, shift);
   const double slope = current_value[0] - past_value[0];
   const bool strong_bull = (close_price >= current_value[0] + InpAutoBuyMinDistanceATR * atr &&
                             slope >= InpAutoBuyMinSlopeATR * atr);
   const bool bear = (close_price < current_value[0] && slope < 0.0);

   MqlDateTime stamp;
   TimeToStruct(iTime(_Symbol, _Period, shift), stamp);
   const bool buy_pause = (InpAutoBuyUsePauseWindow &&
                           InpAutoBuyPauseStartHour != InpAutoBuyPauseEndHour &&
                           IsHourWithin(stamp.hour, InpAutoBuyPauseStartHour,
                                       InpAutoBuyPauseEndHour));
   buy_allowed = (strong_bull &&
                  IsHourWithin(stamp.hour, InpAutoBuyStartHour, InpAutoBuyEndHour) &&
                  !buy_pause);

   if(InpAutoSellRegimeMode == 0)
      sell_allowed = true;
   else if(InpAutoSellRegimeMode == 1)
      sell_allowed = !strong_bull;
   else
      sell_allowed = bear;
   return true;
}

//+------------------------------------------------------------------+
int FindClosedPositionResult(ClosedPositionResult &rows[], const ulong position_id)
{
   for(int i = 0; i < ArraySize(rows); ++i)
      if(rows[i].position_id == position_id)
         return i;
   return -1;
}

//+------------------------------------------------------------------+
// Build one realized result per fully closed position.  Entry commissions and
// every partial exit are aggregated, so one position can never consume the
// daily-loss allowance more than once.
bool CollectClosedPositionResults(const datetime from_time, const datetime to_time,
                                  ClosedPositionResult &rows[])
{
   ArrayResize(rows, 0);
   if(!HistorySelect(from_time, to_time))
      return false;

   ClosedPositionResult candidates[];
   for(int i = 0; i < HistoryDealsTotal(); ++i)
   {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0 || HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      const long entry_type = HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry_type != DEAL_ENTRY_OUT && entry_type != DEAL_ENTRY_OUT_BY &&
         entry_type != DEAL_ENTRY_INOUT)
         continue;

      const ulong position_id = (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
      if(position_id == 0)
         continue;
      int index = FindClosedPositionResult(candidates, position_id);
       if(index < 0)
       {
          index = ArraySize(candidates);
          if(ArrayResize(candidates, index + 1) != index + 1)
             return false;
         candidates[index].position_id = position_id;
         candidates[index].net_result = 0.0;
         candidates[index].exit_time = 0;
      }
      const datetime exit_time = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
      if(exit_time > candidates[index].exit_time)
         candidates[index].exit_time = exit_time;
   }

   for(int i = 0; i < ArraySize(candidates); ++i)
   {
      const ulong position_id = candidates[i].position_id;
       if(PositionIdentifierIsOpen(position_id))
          continue;
       if(!HistorySelectByPosition(position_id))
          return false;

      bool belongs_to_ea = false;
      double net_result = 0.0;
      datetime final_exit_time = 0;
      for(int j = 0; j < HistoryDealsTotal(); ++j)
      {
         const ulong deal = HistoryDealGetTicket(j);
         if(deal == 0 || HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
            continue;
         const long entry_type = HistoryDealGetInteger(deal, DEAL_ENTRY);
         if((entry_type == DEAL_ENTRY_IN || entry_type == DEAL_ENTRY_INOUT) &&
            (ulong)HistoryDealGetInteger(deal, DEAL_MAGIC) == InpMagicNumber)
            belongs_to_ea = true;

         net_result += HistoryDealGetDouble(deal, DEAL_PROFIT) +
                       HistoryDealGetDouble(deal, DEAL_COMMISSION) +
                       HistoryDealGetDouble(deal, DEAL_SWAP);
         if(entry_type == DEAL_ENTRY_OUT || entry_type == DEAL_ENTRY_OUT_BY ||
            entry_type == DEAL_ENTRY_INOUT)
         {
            const datetime exit_time = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
            if(exit_time > final_exit_time)
               final_exit_time = exit_time;
         }
      }

      if(!belongs_to_ea || final_exit_time < from_time || final_exit_time > to_time)
         continue;
       const int output_index = ArraySize(rows);
       if(ArrayResize(rows, output_index + 1) != output_index + 1)
          return false;
      rows[output_index].position_id = position_id;
      rows[output_index].net_result = net_result;
      rows[output_index].exit_time = final_exit_time;
   }

   // Newest first makes pause and consecutive-loss calculations deterministic.
   for(int i = 0; i < ArraySize(rows) - 1; ++i)
      for(int j = i + 1; j < ArraySize(rows); ++j)
         if(rows[j].exit_time > rows[i].exit_time)
         {
            const ClosedPositionResult temporary = rows[i];
            rows[i] = rows[j];
            rows[j] = temporary;
         }
   return true;
}

//+------------------------------------------------------------------+
bool CountTodayLosingExits(int &losses)
{
   losses = 0;
   if(InpMaxDailyLosses <= 0)
      return true;

   const datetime now = TimeCurrent();
   MqlDateTime day;
   TimeToStruct(now, day);
   day.hour = 0;
   day.min  = 0;
   day.sec  = 0;
   ClosedPositionResult rows[];
   if(!CollectClosedPositionResults(StructToTime(day), now, rows))
      return false;

   for(int i = 0; i < ArraySize(rows); ++i)
      if(rows[i].net_result < -InpBreakEvenThresholdMoney)
         ++losses;
   return true;
}

//+------------------------------------------------------------------+
bool GetLastLosingExitTime(datetime &last_loss)
{
   last_loss = 0;
   if(InpPauseAfterLossMinutes <= 0)
      return true;
   ClosedPositionResult rows[];
   if(!CollectClosedPositionResults(0, TimeCurrent(), rows))
      return false;
   for(int i = 0; i < ArraySize(rows); ++i)
      if(rows[i].net_result < -InpBreakEvenThresholdMoney)
      {
         last_loss = rows[i].exit_time;
         return true;
      }
   return true;
}

//+------------------------------------------------------------------+
bool LossPauseRemainingSeconds(int &remaining_seconds)
{
   remaining_seconds = 0;
   datetime last_loss = 0;
   if(!GetLastLosingExitTime(last_loss))
      return false;
   if(last_loss <= 0)
      return true;

   const long pause_seconds = (long)InpPauseAfterLossMinutes * 60;
   const long elapsed = (long)TimeCurrent() - (long)last_loss;
   if(elapsed >= pause_seconds)
      return true;
   remaining_seconds = (int)MathMax(0, pause_seconds - elapsed);
   return true;
}

//+------------------------------------------------------------------+
bool GetClosedTradeStats(int &wins, int &losses, int &break_evens,
                         int &current_loss_streak, datetime &last_exit_time)
{
   wins = 0;
   losses = 0;
   break_evens = 0;
   current_loss_streak = 0;
   last_exit_time = 0;
   ClosedPositionResult rows[];
   if(!CollectClosedPositionResults(0, TimeCurrent(), rows))
      return false;

   bool counting_current_streak = true;
   for(int i = 0; i < ArraySize(rows); ++i)
   {
      if(last_exit_time == 0)
         last_exit_time = rows[i].exit_time;

      if(rows[i].net_result < -InpBreakEvenThresholdMoney)
      {
         ++losses;
         if(counting_current_streak)
            ++current_loss_streak;
      }
      else
      {
         if(rows[i].net_result > InpBreakEvenThresholdMoney)
            ++wins;
         else
            ++break_evens;
         counting_current_streak = false;
      }
   }
   return true;
}

//+------------------------------------------------------------------+
string JsonEscape(string value)
{
   StringReplace(value, "\\", "\\\\");
   StringReplace(value, "\"", "\\\"");
   StringReplace(value, "\r", "\\r");
   StringReplace(value, "\n", "\\n");
   StringReplace(value, "\t", "\\t");
   return value;
}

//+------------------------------------------------------------------+
ulong Fnv1a64(const string value)
{
   ulong hash = 0xcbf29ce484222325;
   const ulong prime = 1099511628211;
   for(int i = 0; i < StringLen(value); ++i)
   {
      hash ^= (ulong)StringGetCharacter(value, i);
      hash *= prime;
   }
   return hash;
}

//+------------------------------------------------------------------+
bool IsSafeDatasetPrefix(const string value)
{
   if(StringLen(value) < 1 || StringLen(value) > 40)
      return false;
   for(int i = 0; i < StringLen(value); ++i)
      if(StringGetCharacter(value, i) < 32)
         return false;
   return true;
}

//+------------------------------------------------------------------+
string AutomaticAnalyticsAccountRef()
{
   const string identity = AccountInfoString(ACCOUNT_SERVER) + "|" +
                           IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
   return StringFormat("%s-%016I64X", InpAnalyticsAccountRef, Fnv1a64(identity));
}

//+------------------------------------------------------------------+
string AnalyticsWebhookURL()
{
   string base_url = InpAnalyticsBaseURL;
   while(StringLen(base_url) > 0 &&
         StringSubstr(base_url, StringLen(base_url) - 1, 1) == "/")
      base_url = StringSubstr(base_url, 0, StringLen(base_url) - 1);
   return base_url + "/api/trade-analytics";
}

//+------------------------------------------------------------------+
bool HasDemoWebhookBaseURL()
{
   string base_url = InpAnalyticsBaseURL;
   while(StringLen(base_url) > 0 &&
         StringSubstr(base_url, StringLen(base_url) - 1, 1) == "/")
      base_url = StringSubstr(base_url, 0, StringLen(base_url) - 1);
   return (base_url == "https://ats.thaipesleague.com/demo");
}

//+------------------------------------------------------------------+
bool AnalyticsEnabled()
{
   return (g_demo_analytics_active && !MQLInfoInteger(MQL_TESTER));
}

//+------------------------------------------------------------------+
int CurrentBrokerUtcOffsetSeconds()
{
   const datetime broker_time = TimeTradeServer();
   const datetime utc_time = TimeGMT();
   if(broker_time <= 0 || utc_time <= 0)
      return 0;
   long offset = (long)broker_time - (long)utc_time;
   if(offset > 86400)
      offset = 86400;
   else if(offset < -86400)
      offset = -86400;
   return (int)offset;
}

//+------------------------------------------------------------------+
int FindTelemetryIndex(const ulong position_id)
{
   for(int i = 0; i < ArraySize(g_trade_telemetry); ++i)
      if(g_trade_telemetry[i].position_id == position_id)
         return i;
   return -1;
}

//+------------------------------------------------------------------+
int CreateTelemetry(const ulong position_id)
{
   const int index = ArraySize(g_trade_telemetry);
   if(ArrayResize(g_trade_telemetry, index + 1) != index + 1)
      return -1;
   g_trade_telemetry[index].position_id = position_id;
   g_trade_telemetry[index].mfe = 0.0;
   g_trade_telemetry[index].mae = 0.0;
   g_trade_telemetry[index].closed = false;
   g_trade_telemetry[index].last_send_attempt = 0;
   g_trade_telemetry[index].retry_count = 0;
   g_trade_telemetry[index].broker_utc_offset_seconds = CurrentBrokerUtcOffsetSeconds();
   g_trade_telemetry[index].protective_stop_reason = "";
   g_trade_telemetry[index].data_quality = "LIVE_CAPTURE";
   g_trade_telemetry[index].account_ref = AutomaticAnalyticsAccountRef();
   g_trade_telemetry[index].settings_hash = AnalyticsSettingsHash();
   g_trade_telemetry[index].ea_version = "1.90";
   return index;
}

//+------------------------------------------------------------------+
void RemoveTelemetry(const int index)
{
   const int last = ArraySize(g_trade_telemetry) - 1;
   if(index < 0 || index > last)
      return;
   for(int i = index; i < last; ++i)
      g_trade_telemetry[i] = g_trade_telemetry[i + 1];
   ArrayResize(g_trade_telemetry, last);
}

//+------------------------------------------------------------------+
string SafeFileComponent(string value)
{
   StringReplace(value, "\\", "_");
   StringReplace(value, "/", "_");
   StringReplace(value, ":", "_");
   StringReplace(value, "*", "_");
   StringReplace(value, "?", "_");
   StringReplace(value, "\"", "_");
   StringReplace(value, "<", "_");
   StringReplace(value, ">", "_");
   StringReplace(value, "|", "_");
   return value;
}

//+------------------------------------------------------------------+
string TelemetryOutboxFileName()
{
   return StringFormat("Adaptive_SR_v190_%I64d_%s_%s_%I64u_%s.tsv",
      AccountInfoInteger(ACCOUNT_LOGIN),
      SafeFileComponent(AccountInfoString(ACCOUNT_SERVER)),
      SafeFileComponent(_Symbol), InpMagicNumber,
      SafeFileComponent(EnumToString(_Period)));
}

//+------------------------------------------------------------------+
bool SaveTelemetryOutbox()
{
   if(!AnalyticsEnabled())
      return true;
   if(!g_outbox_writable)
      return false;
   const string target_name = TelemetryOutboxFileName();
   const string temporary_name = target_name +
      StringFormat(".tmp.%I64d", ChartID());
   ResetLastError();
   const int handle = FileOpen(temporary_name,
       FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, '\t', CP_UTF8);
   if(handle == INVALID_HANDLE)
   {
      PrintFormat("S/R EA: cannot persist analytics outbox. error=%d", GetLastError());
      return false;
   }

   bool write_ok = (FileWrite(handle, "SR_TELEMETRY_V3") > 0);
   for(int i = 0; i < ArraySize(g_trade_telemetry); ++i)
   {
      if(FileWrite(handle,
         StringFormat("%I64u", g_trade_telemetry[i].position_id),
         g_trade_telemetry[i].action,
         g_trade_telemetry[i].signal_type,
         IntegerToString((long)g_trade_telemetry[i].entry_time),
         DoubleToString(g_trade_telemetry[i].entry_price, 8),
         DoubleToString(g_trade_telemetry[i].volume, 8),
         DoubleToString(g_trade_telemetry[i].initial_sl, 8),
         DoubleToString(g_trade_telemetry[i].initial_tp, 8),
         DoubleToString(g_trade_telemetry[i].level_price, 8),
         IntegerToString((long)g_trade_telemetry[i].pivot_time),
         DoubleToString(g_trade_telemetry[i].spread_points, 2),
         DoubleToString(g_trade_telemetry[i].atr, 8),
         g_trade_telemetry[i].market_regime,
         g_trade_telemetry[i].session_name,
         IntegerToString(g_trade_telemetry[i].entry_hour),
         IntegerToString(g_trade_telemetry[i].loss_streak_before),
         DoubleToString(g_trade_telemetry[i].mfe, 2),
         DoubleToString(g_trade_telemetry[i].mae, 2),
         (g_trade_telemetry[i].closed ? "1" : "0"),
         IntegerToString((long)g_trade_telemetry[i].exit_time),
         DoubleToString(g_trade_telemetry[i].exit_price, 8),
         DoubleToString(g_trade_telemetry[i].profit, 2),
         DoubleToString(g_trade_telemetry[i].commission, 2),
         DoubleToString(g_trade_telemetry[i].swap, 2),
         g_trade_telemetry[i].exit_reason,
         IntegerToString((long)g_trade_telemetry[i].last_send_attempt),
         IntegerToString(g_trade_telemetry[i].retry_count),
         IntegerToString(g_trade_telemetry[i].broker_utc_offset_seconds),
         g_trade_telemetry[i].protective_stop_reason,
         g_trade_telemetry[i].data_quality,
         g_trade_telemetry[i].account_ref,
         g_trade_telemetry[i].settings_hash,
         g_trade_telemetry[i].ea_version) == 0)
         write_ok = false;
   }
   FileFlush(handle);
   FileClose(handle);
   if(!write_ok)
   {
      PrintFormat("S/R EA: analytics outbox temporary write failed. error=%d", GetLastError());
      FileDelete(temporary_name, FILE_COMMON);
      return false;
   }

   ResetLastError();
   if(!FileMove(temporary_name, FILE_COMMON, target_name,
                FILE_COMMON | FILE_REWRITE))
   {
      PrintFormat("S/R EA: analytics outbox atomic replace failed. error=%d", GetLastError());
      FileDelete(temporary_name, FILE_COMMON);
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
bool LoadTelemetryOutbox()
{
   if(!AnalyticsEnabled())
      return true;
   g_outbox_writable = true;
   ResetLastError();
   const int handle = FileOpen(TelemetryOutboxFileName(),
      FILE_READ | FILE_CSV | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ,
      '\t', CP_UTF8);
   if(handle == INVALID_HANDLE)
   {
      if(GetLastError() != 5004) // ERR_CANNOT_OPEN_FILE is normal on first run.
         PrintFormat("S/R EA: analytics outbox not loaded. error=%d", GetLastError());
      return true;
   }

   const string version = FileReadString(handle);
   const bool version_v2 = (version == "SR_TELEMETRY_V2");
   const bool version_v3 = (version == "SR_TELEMETRY_V3");
   if(!version_v2 && !version_v3)
   {
      PrintFormat("S/R EA: analytics outbox version is unsupported: %s", version);
      FileClose(handle);
      ArrayResize(g_trade_telemetry, 0);
      g_outbox_writable = false;
      return false;
   }

   int loaded = 0;
   bool valid = true;
   while(!FileIsEnding(handle))
   {
      const string position_text = FileReadString(handle);
      if(position_text == "")
         break;
      const ulong position_id = (ulong)StringToInteger(position_text);
      if(position_id == 0)
      {
         valid = false;
         break;
      }

      int index = FindTelemetryIndex(position_id);
      if(index < 0)
         index = CreateTelemetry(position_id);
      if(index < 0)
      {
         valid = false;
         break;
      }

      g_trade_telemetry[index].action = FileReadString(handle);
      g_trade_telemetry[index].signal_type = FileReadString(handle);
      g_trade_telemetry[index].entry_time = (datetime)StringToInteger(FileReadString(handle));
      g_trade_telemetry[index].entry_price = StringToDouble(FileReadString(handle));
      g_trade_telemetry[index].volume = StringToDouble(FileReadString(handle));
      g_trade_telemetry[index].initial_sl = StringToDouble(FileReadString(handle));
      g_trade_telemetry[index].initial_tp = StringToDouble(FileReadString(handle));
      g_trade_telemetry[index].level_price = StringToDouble(FileReadString(handle));
      g_trade_telemetry[index].pivot_time = (datetime)StringToInteger(FileReadString(handle));
      g_trade_telemetry[index].spread_points = StringToDouble(FileReadString(handle));
      g_trade_telemetry[index].atr = StringToDouble(FileReadString(handle));
      g_trade_telemetry[index].market_regime = FileReadString(handle);
      g_trade_telemetry[index].session_name = FileReadString(handle);
      g_trade_telemetry[index].entry_hour = (int)StringToInteger(FileReadString(handle));
      g_trade_telemetry[index].loss_streak_before = (int)StringToInteger(FileReadString(handle));
      g_trade_telemetry[index].mfe = StringToDouble(FileReadString(handle));
      g_trade_telemetry[index].mae = StringToDouble(FileReadString(handle));
      g_trade_telemetry[index].closed = (FileReadString(handle) == "1");
      g_trade_telemetry[index].exit_time = (datetime)StringToInteger(FileReadString(handle));
      g_trade_telemetry[index].exit_price = StringToDouble(FileReadString(handle));
      g_trade_telemetry[index].profit = StringToDouble(FileReadString(handle));
      g_trade_telemetry[index].commission = StringToDouble(FileReadString(handle));
      g_trade_telemetry[index].swap = StringToDouble(FileReadString(handle));
      g_trade_telemetry[index].exit_reason = FileReadString(handle);
      g_trade_telemetry[index].last_send_attempt = (datetime)StringToInteger(FileReadString(handle));
      g_trade_telemetry[index].retry_count = (int)StringToInteger(FileReadString(handle));
      g_trade_telemetry[index].broker_utc_offset_seconds = (int)StringToInteger(FileReadString(handle));
      g_trade_telemetry[index].protective_stop_reason = FileReadString(handle);
      g_trade_telemetry[index].data_quality = FileReadString(handle);
      if(g_trade_telemetry[index].data_quality == "")
         g_trade_telemetry[index].data_quality = "PERSISTED_CAPTURE";
      if(version_v3)
      {
         g_trade_telemetry[index].account_ref = FileReadString(handle);
         g_trade_telemetry[index].settings_hash = FileReadString(handle);
         g_trade_telemetry[index].ea_version = FileReadString(handle);
         if(g_trade_telemetry[index].account_ref == "" ||
            g_trade_telemetry[index].settings_hash == "" ||
            g_trade_telemetry[index].ea_version == "")
         {
            valid = false;
            break;
         }
      }
      else
      {
         g_trade_telemetry[index].account_ref = AutomaticAnalyticsAccountRef();
         g_trade_telemetry[index].settings_hash = AnalyticsSettingsHash();
         g_trade_telemetry[index].ea_version = "1.90";
         g_trade_telemetry[index].data_quality += "_V2_CONFIG_ASSUMED";
      }
      ++loaded;
   }
   FileClose(handle);
   if(!valid)
   {
      Print("S/R EA: analytics outbox is malformed; the original file was preserved and writes were disabled.");
      ArrayResize(g_trade_telemetry, 0);
      g_outbox_writable = false;
      return false;
   }
   if(loaded > 0)
      PrintFormat("S/R EA: restored %d analytics record(s) from the persistent outbox.", loaded);
   return true;
}

//+------------------------------------------------------------------+
string EntrySessionName(const datetime entry_time)
{
   MqlDateTime stamp;
   TimeToStruct(entry_time, stamp);
   if(stamp.hour < 7)
      return "ASIA";
   if(stamp.hour < 13)
      return "LONDON";
   if(stamp.hour < 21)
      return "NEW_YORK";
   return "ROLLOVER";
}

//+------------------------------------------------------------------+
string MarketRegimeLabel(const double atr)
{
   if(g_auto_buy_ema_handle == INVALID_HANDLE ||
      BarsCalculated(g_auto_buy_ema_handle) <= 1 + InpAutoBuySlopeBars)
      return "UNKNOWN";

   double current_value[1], past_value[1];
   if(CopyBuffer(g_auto_buy_ema_handle, 0, 1, 1, current_value) != 1 ||
      CopyBuffer(g_auto_buy_ema_handle, 0, 1 + InpAutoBuySlopeBars, 1, past_value) != 1)
      return "UNKNOWN";

   const double close_price = iClose(_Symbol, _Period, 1);
   const double slope = current_value[0] - past_value[0];
   if(close_price >= current_value[0] + InpAutoBuyMinDistanceATR * atr &&
      slope >= InpAutoBuyMinSlopeATR * atr)
      return "BULL";
   if(close_price < current_value[0] && slope < 0.0)
      return "BEAR";
   return "RANGE";
}

//+------------------------------------------------------------------+
void AppendSetting(string &contract, const string name, const string value)
{
   contract += name + "=" + value + ";";
}

//+------------------------------------------------------------------+
string BoolSetting(const bool value)
{
   return (value ? "1" : "0");
}

//+------------------------------------------------------------------+
string AnalyticsSettingsHash()
{
   // Hash every input that can change signals, sizing, protection or exits.
   string contract = "SR_V190;";
   AppendSetting(contract, "SYMBOL", _Symbol);
   AppendSetting(contract, "TF", EnumToString(_Period));
   AppendSetting(contract, "PIVOT", IntegerToString(InpPivotLength));
   AppendSetting(contract, "ATR_PERIOD", IntegerToString(InpATRPeriod));
   AppendSetting(contract, "MIN_ATR", DoubleToString(InpMinATRStrength, 8));
   AppendSetting(contract, "LEVEL_AGE", IntegerToString(InpMaxLevelAgeBars));
   AppendSetting(contract, "LEVELS", IntegerToString(InpMaxLevelsEachSide));
   AppendSetting(contract, "MERGE", DoubleToString(InpMergeThresholdATR, 8));
   AppendSetting(contract, "BREAK", DoubleToString(InpBreakSensitivityATR, 8));
   AppendSetting(contract, "ZONE", DoubleToString(InpZoneWidthATR, 8));
   AppendSetting(contract, "RETEST", IntegerToString(InpMinRetestDelayBars));
   AppendSetting(contract, "RECOVERY_START", IntegerToString(InpRecoveryStartLossStreak));
   AppendSetting(contract, "RECOVERY_DELAY", IntegerToString(InpRecoveryMinRetestDelayBars));
   AppendSetting(contract, "RECOVERY_SIDE", IntegerToString(InpRecoverySideMode));
   AppendSetting(contract, "LEVEL_TRADES", IntegerToString(InpMaxTradesPerLevel));
   AppendSetting(contract, "LEVEL_COOLDOWN", IntegerToString(InpSameLevelCooldownBars));
   AppendSetting(contract, "REARM", DoubleToString(InpRearmDistanceATR, 8));
   AppendSetting(contract, "REJECTION", BoolSetting(InpRequireRejection));
   AppendSetting(contract, "BODY", DoubleToString(InpMinBodyRangeRatio, 8));
   AppendSetting(contract, "WICK", DoubleToString(InpMinWickRangeRatio, 8));
   AppendSetting(contract, "CLOSE_LOCATION", DoubleToString(InpMinCloseLocation, 8));
   AppendSetting(contract, "MAX_CANDLE", DoubleToString(InpMaxCandleATRRatio, 8));
   AppendSetting(contract, "AUTO", BoolSetting(InpAutoDirection));
   AppendSetting(contract, "BUY", BoolSetting(InpEnableBuy));
   AppendSetting(contract, "SELL", BoolSetting(InpEnableSell));
   AppendSetting(contract, "EMA_FILTER", BoolSetting(InpUseEMAFilter));
   AppendSetting(contract, "EMA_PERIOD", IntegerToString(InpEMAPeriod));
   AppendSetting(contract, "EMA_SLOPE", IntegerToString(InpEMASlopeBars));
   AppendSetting(contract, "AUTO_EMA", IntegerToString(InpAutoBuyEMAPeriod));
   AppendSetting(contract, "AUTO_SLOPE_BARS", IntegerToString(InpAutoBuySlopeBars));
   AppendSetting(contract, "AUTO_SLOPE_ATR", DoubleToString(InpAutoBuyMinSlopeATR, 8));
   AppendSetting(contract, "AUTO_DISTANCE", DoubleToString(InpAutoBuyMinDistanceATR, 8));
   AppendSetting(contract, "AUTO_BUY_HOURS", StringFormat("%d-%d", InpAutoBuyStartHour, InpAutoBuyEndHour));
   AppendSetting(contract, "AUTO_PAUSE", StringFormat("%s-%d-%d", BoolSetting(InpAutoBuyUsePauseWindow), InpAutoBuyPauseStartHour, InpAutoBuyPauseEndHour));
   AppendSetting(contract, "BUY_BODY", DoubleToString(InpBuyMinBodyRangeRatio, 8));
   AppendSetting(contract, "BUY_WICK", DoubleToString(InpBuyMinWickRangeRatio, 8));
   AppendSetting(contract, "BUY_CLOSE", DoubleToString(InpBuyMinCloseLocation, 8));
   AppendSetting(contract, "SELL_REGIME", IntegerToString(InpAutoSellRegimeMode));
   AppendSetting(contract, "SESSION", StringFormat("%d-%d", InpSessionStartHour, InpSessionEndHour));
   AppendSetting(contract, "COOLDOWN", IntegerToString(InpCooldownBars));
   AppendSetting(contract, "DAILY_LOSSES", IntegerToString(InpMaxDailyLosses));
   AppendSetting(contract, "LOSS_PAUSE", IntegerToString(InpPauseAfterLossMinutes));
   AppendSetting(contract, "STREAK", IntegerToString(InpMaxConsecutiveLosses));
   AppendSetting(contract, "STREAK_BARS", IntegerToString(InpLossStreakPauseBars));
   AppendSetting(contract, "BE_THRESHOLD", DoubleToString(InpBreakEvenThresholdMoney, 8));
   AppendSetting(contract, "BROKER_SESSIONS", BoolSetting(InpUseBrokerSessions));
   AppendSetting(contract, "CLOSE_DAILY", IntegerToString(InpCloseBeforeDailyMinutes));
   AppendSetting(contract, "CLOSE_WEEKEND", IntegerToString(InpCloseBeforeWeekendMinutes));
   AppendSetting(contract, "BLOCK_CLOSE", IntegerToString(InpBlockEntriesBeforeCloseMinutes));
   AppendSetting(contract, "BLOCK_OPEN", IntegerToString(InpBlockAfterSessionOpenMinutes));
   AppendSetting(contract, "SCHEDULE_FAILSAFE", BoolSetting(InpBlockIfScheduleUnavailable));
   AppendSetting(contract, "SCHEDULE_TIMER", IntegerToString(InpScheduleTimerSeconds));
   AppendSetting(contract, "HARD_CUTOFF", StringFormat("%s-%d-%d-%d-%d", BoolSetting(InpUseHardDailyCutoff), InpHardDailyCloseHour, InpHardDailyCloseMinute, InpHardFridayCloseHour, InpHardFridayCloseMinute));
   AppendSetting(contract, "HOLIDAY", StringFormat("%s-%d-%d", BoolSetting(InpUseHolidayEarlyCutoff), InpHolidayEarlyCloseHour, InpHolidayEarlyCloseMinute));
   AppendSetting(contract, "LOT", DoubleToString(InpFixedLot, 8));
   AppendSetting(contract, "SL_POINTS", IntegerToString(InpStopLossPips));
   AppendSetting(contract, "TP_POINTS", IntegerToString(InpTakeProfitPips));
   AppendSetting(contract, "SL_MONEY", DoubleToString(InpStopLossMoney, 8));
   AppendSetting(contract, "TP_MONEY", DoubleToString(InpTakeProfitMoney, 8));
   AppendSetting(contract, "ATR_STOP", StringFormat("%s-%.8f", BoolSetting(InpUseATRAdjustedStop), InpMinimumStopATR));
   AppendSetting(contract, "EXIT_MODE", IntegerToString(InpExitMode));
   AppendSetting(contract, "BE_EXIT", StringFormat("%.8f-%.8f", InpBreakEvenActivationMoney, InpBreakEvenLockMoney));
   AppendSetting(contract, "TRAIL", StringFormat("%.8f-%.8f", InpTrailActivationMoney, InpTrailATRMultiplier));
   AppendSetting(contract, "STRUCTURE_EXIT", DoubleToString(InpStructureExitMinProfitMoney, 8));
   AppendSetting(contract, "MAX_POSITIONS", IntegerToString(InpMaxOpenPositions));
   AppendSetting(contract, "MAX_SPREAD", IntegerToString(InpMaxSpreadPoints));
   AppendSetting(contract, "DEVIATION", IntegerToString(InpDeviationPoints));
   AppendSetting(contract, "USD_REQUIRED", BoolSetting(InpRequireUSDAccount));
   AppendSetting(contract, "MAGIC", StringFormat("%I64u", InpMagicNumber));

   return StringFormat("FNV1A64-%016I64X", Fnv1a64(contract));
}

//+------------------------------------------------------------------+
string SignalTypeFromComment(const string comment, const long deal_type)
{
   if(StringFind(comment, "SUPPORT_BUY") >= 0)
      return "SUPPORT_BUY";
   if(StringFind(comment, "RESISTANCE_SELL") >= 0 ||
      StringFind(comment, "RESIST_SELL") >= 0)
      return "RESISTANCE_SELL";
   return (deal_type == DEAL_TYPE_BUY ? "SUPPORT_BUY" : "RESISTANCE_SELL");
}

//+------------------------------------------------------------------+
void RegisterOpenedTelemetryFromDeal(const ulong deal_ticket,
                             const int direction, const string signal_type,
                             const double level_price, const datetime pivot_time,
                             const double atr, const double spread_points,
                             const double initial_sl, const double initial_tp,
                             const double captured_volume)
{
   if(!AnalyticsEnabled())
      return;

   if(deal_ticket == 0 || !HistoryDealSelect(deal_ticket))
      return;
   const ulong position_id = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
   if(position_id == 0)
      return;

   int index = FindTelemetryIndex(position_id);
   if(index < 0)
      index = CreateTelemetry(position_id);
   if(index < 0)
      return;

   int wins, losses, break_evens, streak;
   datetime last_exit;
   const bool history_complete = GetClosedTradeStats(
      wins, losses, break_evens, streak, last_exit);
   MqlDateTime stamp;
   const datetime entry_time = (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
   TimeToStruct(entry_time, stamp);

   g_trade_telemetry[index].action = (direction > 0 ? "BUY" : "SELL");
   g_trade_telemetry[index].signal_type = signal_type;
   g_trade_telemetry[index].entry_time = entry_time;
   g_trade_telemetry[index].entry_price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
   g_trade_telemetry[index].volume = captured_volume;
   g_trade_telemetry[index].initial_sl = initial_sl;
   g_trade_telemetry[index].initial_tp = initial_tp;
   g_trade_telemetry[index].level_price = level_price;
   g_trade_telemetry[index].pivot_time = pivot_time;
   g_trade_telemetry[index].spread_points = spread_points;
   g_trade_telemetry[index].atr = atr;
   g_trade_telemetry[index].market_regime = MarketRegimeLabel(atr);
   g_trade_telemetry[index].session_name = EntrySessionName(entry_time);
   g_trade_telemetry[index].entry_hour = stamp.hour;
   g_trade_telemetry[index].loss_streak_before = streak;
   g_trade_telemetry[index].broker_utc_offset_seconds = CurrentBrokerUtcOffsetSeconds();
   g_trade_telemetry[index].data_quality =
      (history_complete ? "LIVE_CAPTURE" : "LIVE_CAPTURE_HISTORY_UNKNOWN");
   SaveTelemetryOutbox();
}

//+------------------------------------------------------------------+
bool PositionIdentifierIsOpen(const ulong position_id)
{
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket) &&
         (ulong)PositionGetInteger(POSITION_IDENTIFIER) == position_id)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
bool SelectPositionByIdentifier(const ulong position_id, ulong &ticket,
                                double &volume, double &open_price)
{
   ticket = 0;
   volume = 0.0;
   open_price = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate) ||
         (ulong)PositionGetInteger(POSITION_IDENTIFIER) != position_id)
         continue;
      ticket = candidate;
      volume = PositionGetDouble(POSITION_VOLUME);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      return (volume > 0.0 && open_price > 0.0);
   }
   return false;
}

//+------------------------------------------------------------------+
void SetTelemetryExitReasonByPositionId(const ulong position_id, const string reason)
{
   if(!AnalyticsEnabled() || position_id == 0)
      return;
   const int index = FindTelemetryIndex(position_id);
   if(index >= 0)
   {
      g_trade_telemetry[index].exit_reason = reason;
      SaveTelemetryOutbox();
   }
}

//+------------------------------------------------------------------+
void TrackOpenTradeTelemetry()
{
   if(!AnalyticsEnabled())
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      const ulong position_id = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      int index = FindTelemetryIndex(position_id);
      if(index < 0)
      {
         index = CreateTelemetry(position_id);
         if(index < 0)
            continue;
         const long position_type = PositionGetInteger(POSITION_TYPE);
         const string comment = PositionGetString(POSITION_COMMENT);
         double atr = 0.0;
         GetATR(1, atr);
         MqlDateTime stamp;
         g_trade_telemetry[index].action = (position_type == POSITION_TYPE_BUY ? "BUY" : "SELL");
         g_trade_telemetry[index].signal_type = SignalTypeFromComment(comment,
            position_type == POSITION_TYPE_BUY ? DEAL_TYPE_BUY : DEAL_TYPE_SELL);
         g_trade_telemetry[index].entry_time = (datetime)PositionGetInteger(POSITION_TIME);
         g_trade_telemetry[index].entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
         g_trade_telemetry[index].volume = PositionGetDouble(POSITION_VOLUME);
         g_trade_telemetry[index].initial_sl = PositionGetDouble(POSITION_SL);
         g_trade_telemetry[index].initial_tp = PositionGetDouble(POSITION_TP);
         g_trade_telemetry[index].pivot_time = g_trade_telemetry[index].entry_time;
         g_trade_telemetry[index].atr = atr;
         g_trade_telemetry[index].market_regime = MarketRegimeLabel(atr);
          g_trade_telemetry[index].session_name = EntrySessionName(g_trade_telemetry[index].entry_time);
          TimeToStruct(g_trade_telemetry[index].entry_time, stamp);
          g_trade_telemetry[index].entry_hour = stamp.hour;
           int wins, losses, break_evens, streak;
           datetime last_exit;
           const bool history_complete = GetClosedTradeStats(
              wins, losses, break_evens, streak, last_exit);
           g_trade_telemetry[index].loss_streak_before = streak;
           g_trade_telemetry[index].broker_utc_offset_seconds = CurrentBrokerUtcOffsetSeconds();
           g_trade_telemetry[index].data_quality = (history_complete ?
              "RECOVERED_OPEN_POSITION" : "RECOVERED_OPEN_POSITION_HISTORY_UNKNOWN");
          SaveTelemetryOutbox();
      }

      const double current_volume = PositionGetDouble(POSITION_VOLUME);
      if(current_volume > g_trade_telemetry[index].volume + 1e-8)
      {
         g_trade_telemetry[index].volume = current_volume;
         g_trade_telemetry[index].entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
      }
      const double floating_profit = PositionGetDouble(POSITION_PROFIT) +
                                     PositionGetDouble(POSITION_SWAP);
      g_trade_telemetry[index].mfe = MathMax(g_trade_telemetry[index].mfe, floating_profit);
      g_trade_telemetry[index].mae = MathMin(g_trade_telemetry[index].mae, floating_profit);
   }
}

//+------------------------------------------------------------------+
string DealExitReason(const long reason, const ulong position_id)
{
   if(g_exit_reason_override != "" && g_exit_reason_position_id == position_id)
      return g_exit_reason_override;
   if(reason == DEAL_REASON_TP)
      return "TAKE_PROFIT";
   if(reason == DEAL_REASON_SL)
   {
      const int index = FindTelemetryIndex(position_id);
      if(index >= 0 && g_trade_telemetry[index].protective_stop_reason != "")
         return g_trade_telemetry[index].protective_stop_reason;
      return "STOP_LOSS";
   }
   if(reason == DEAL_REASON_SO)
      return "STOP_OUT";
   if(reason == DEAL_REASON_CLIENT || reason == DEAL_REASON_MOBILE || reason == DEAL_REASON_WEB)
      return "MANUAL";
   return "EA_EXIT";
}

//+------------------------------------------------------------------+
bool MarkTelemetryClosed(const ulong exit_deal)
{
   if(!AnalyticsEnabled() ||
       exit_deal == 0 || !HistoryDealSelect(exit_deal))
      return false;
   if(HistoryDealGetString(exit_deal, DEAL_SYMBOL) != _Symbol)
      return false;

   const ulong position_id = (ulong)HistoryDealGetInteger(exit_deal, DEAL_POSITION_ID);
   if(position_id == 0 || PositionIdentifierIsOpen(position_id) ||
       !HistorySelectByPosition(position_id))
      return false;

   bool belongs_to_ea = false;
   for(int i = 0; i < HistoryDealsTotal(); ++i)
   {
      const ulong deal = HistoryDealGetTicket(i);
      const long entry_type = HistoryDealGetInteger(deal, DEAL_ENTRY);
      if((entry_type == DEAL_ENTRY_IN || entry_type == DEAL_ENTRY_INOUT) &&
         HistoryDealGetString(deal, DEAL_SYMBOL) == _Symbol &&
         (ulong)HistoryDealGetInteger(deal, DEAL_MAGIC) == InpMagicNumber)
      {
         belongs_to_ea = true;
         break;
      }
   }
   if(!belongs_to_ea)
      return false;

   int index = FindTelemetryIndex(position_id);
   const bool reconstructed = (index < 0);
   if(index < 0)
      index = CreateTelemetry(position_id);
   if(index < 0)
      return false;

   double profit = 0.0, commission = 0.0, swap = 0.0;
   double entry_volume = 0.0, entry_value = 0.0;
   double exit_volume = 0.0, exit_value = 0.0;
   datetime earliest_entry_time = 0;
   datetime latest_exit_time = 0;
   string inferred_exit_reason = "";
   for(int i = 0; i < HistoryDealsTotal(); ++i)
   {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      const long entry_type = HistoryDealGetInteger(deal, DEAL_ENTRY);
      commission += HistoryDealGetDouble(deal, DEAL_COMMISSION);
      swap += HistoryDealGetDouble(deal, DEAL_SWAP);
      if(entry_type == DEAL_ENTRY_IN || entry_type == DEAL_ENTRY_INOUT)
      {
         const double fill_volume = HistoryDealGetDouble(deal, DEAL_VOLUME);
         entry_volume += fill_volume;
         entry_value += fill_volume * HistoryDealGetDouble(deal, DEAL_PRICE);
         const datetime fill_time = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
         if(earliest_entry_time == 0 || fill_time < earliest_entry_time)
            earliest_entry_time = fill_time;
         if(g_trade_telemetry[index].entry_time == 0)
         {
            const long deal_type = HistoryDealGetInteger(deal, DEAL_TYPE);
            const string comment = HistoryDealGetString(deal, DEAL_COMMENT);
            g_trade_telemetry[index].action = (deal_type == DEAL_TYPE_BUY ? "BUY" : "SELL");
            g_trade_telemetry[index].signal_type = SignalTypeFromComment(comment, deal_type);
            g_trade_telemetry[index].entry_time = fill_time;
            g_trade_telemetry[index].entry_price = HistoryDealGetDouble(deal, DEAL_PRICE);
            g_trade_telemetry[index].volume = fill_volume;
            g_trade_telemetry[index].pivot_time = g_trade_telemetry[index].entry_time;
            g_trade_telemetry[index].session_name = EntrySessionName(g_trade_telemetry[index].entry_time);
         }
      }
      if(entry_type == DEAL_ENTRY_OUT || entry_type == DEAL_ENTRY_OUT_BY || entry_type == DEAL_ENTRY_INOUT)
      {
         profit += HistoryDealGetDouble(deal, DEAL_PROFIT);
         const double fill_volume = HistoryDealGetDouble(deal, DEAL_VOLUME);
         exit_volume += fill_volume;
         exit_value += fill_volume * HistoryDealGetDouble(deal, DEAL_PRICE);
         const datetime deal_time = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
         if(deal_time >= latest_exit_time)
         {
            latest_exit_time = deal_time;
            inferred_exit_reason = DealExitReason(
               HistoryDealGetInteger(deal, DEAL_REASON), position_id);
         }
      }
   }

   g_trade_telemetry[index].profit = profit;
   g_trade_telemetry[index].commission = commission;
   g_trade_telemetry[index].swap = swap;
   if(entry_volume > 0.0)
   {
      g_trade_telemetry[index].entry_time = earliest_entry_time;
      g_trade_telemetry[index].entry_price = entry_value / entry_volume;
      g_trade_telemetry[index].volume = entry_volume;
      if(reconstructed)
         g_trade_telemetry[index].data_quality = "RECOVERED_HISTORY";
      MqlDateTime entry_stamp;
      TimeToStruct(earliest_entry_time, entry_stamp);
      g_trade_telemetry[index].entry_hour = entry_stamp.hour;
      g_trade_telemetry[index].broker_utc_offset_seconds = CurrentBrokerUtcOffsetSeconds();
   }
   if(exit_volume > 0.0)
      g_trade_telemetry[index].exit_price = exit_value / exit_volume;
   g_trade_telemetry[index].exit_time = latest_exit_time;
   if(g_trade_telemetry[index].exit_reason == "")
      g_trade_telemetry[index].exit_reason = inferred_exit_reason;
   g_trade_telemetry[index].closed = (latest_exit_time > 0);
   g_trade_telemetry[index].mfe = MathMax(g_trade_telemetry[index].mfe, profit);
   g_trade_telemetry[index].mae = MathMin(g_trade_telemetry[index].mae, profit);
   SaveTelemetryOutbox();
   return g_trade_telemetry[index].closed;
}

//+------------------------------------------------------------------+
int ReconcileClosedTelemetryPosition(const ulong position_id)
{
   if(position_id == 0 || PositionIdentifierIsOpen(position_id))
      return 0;
   if(!HistorySelectByPosition(position_id))
      return 0;

   bool belongs_to_ea = false;
   bool has_entry = false;
   ulong latest_exit_deal = 0;
   datetime latest_exit_time = 0;
   for(int i = 0; i < HistoryDealsTotal(); ++i)
   {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      const long entry_type = HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry_type == DEAL_ENTRY_IN || entry_type == DEAL_ENTRY_INOUT)
      {
         has_entry = true;
         if(HistoryDealGetString(deal, DEAL_SYMBOL) == _Symbol &&
            (ulong)HistoryDealGetInteger(deal, DEAL_MAGIC) == InpMagicNumber)
            belongs_to_ea = true;
      }
      if(entry_type == DEAL_ENTRY_OUT || entry_type == DEAL_ENTRY_OUT_BY ||
         entry_type == DEAL_ENTRY_INOUT)
      {
         const datetime deal_time =
            (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
         if(deal_time >= latest_exit_time)
         {
            latest_exit_time = deal_time;
            latest_exit_deal = deal;
         }
      }
   }
   if(!has_entry)
      return 0;
   if(!belongs_to_ea)
      return -1;
   if(latest_exit_deal == 0)
      return 0;
   return (MarkTelemetryClosed(latest_exit_deal) ? 1 : 0);
}

//+------------------------------------------------------------------+
void FinalizeClosedTelemetry()
{
   if(!AnalyticsEnabled())
      return;

   for(int i = ArraySize(g_pending_exit_position_ids) - 1; i >= 0; --i)
   {
      const int result = ReconcileClosedTelemetryPosition(
         g_pending_exit_position_ids[i]);
      if(result != 0)
         RemoveUlongAt(g_pending_exit_position_ids, i);
   }

   for(int i = 0; i < ArraySize(g_trade_telemetry); ++i)
   {
      if(g_trade_telemetry[i].closed)
         continue;
      ReconcileClosedTelemetryPosition(g_trade_telemetry[i].position_id);
   }
}

//+------------------------------------------------------------------+
bool SendTradeAnalytics(const int index)
{
   if(index < 0 || index >= ArraySize(g_trade_telemetry) ||
      !g_trade_telemetry[index].closed || !HasDemoWebhookBaseURL() ||
      g_trade_telemetry[index].entry_time <= 0 ||
      g_trade_telemetry[index].exit_time < g_trade_telemetry[index].entry_time ||
      g_trade_telemetry[index].entry_price <= 0.0 ||
      g_trade_telemetry[index].exit_price <= 0.0 ||
      g_trade_telemetry[index].volume <= 0.0 ||
      (g_trade_telemetry[index].action != "BUY" &&
       g_trade_telemetry[index].action != "SELL"))
   {
      PrintFormat("S/R EA: analytics record is incomplete and was not sent. position=%I64u quality=%s",
                  (index >= 0 && index < ArraySize(g_trade_telemetry) ?
                   g_trade_telemetry[index].position_id : 0),
                  (index >= 0 && index < ArraySize(g_trade_telemetry) ?
                   g_trade_telemetry[index].data_quality : "INVALID_INDEX"));
      return false;
   }

   const double net_profit = g_trade_telemetry[index].profit +
                             g_trade_telemetry[index].commission +
                             g_trade_telemetry[index].swap;
   const string result = (net_profit > InpBreakEvenThresholdMoney ? "WIN" :
                         (net_profit < -InpBreakEvenThresholdMoney ? "LOSS" : "BREAK_EVEN"));
   const long duration = MathMax(0, (long)g_trade_telemetry[index].exit_time -
                                     (long)g_trade_telemetry[index].entry_time);
   const datetime pivot_time = (g_trade_telemetry[index].pivot_time > 0 ?
                                g_trade_telemetry[index].pivot_time :
                                g_trade_telemetry[index].entry_time);
   const string payload = StringFormat(
      "{\"token\":\"%s\",\"position_id\":\"%I64u\",\"account_ref\":\"%s\","
      "\"symbol\":\"%s\",\"action\":\"%s\",\"signal_type\":\"%s\","
      "\"timeframe\":\"%s\",\"entry_time\":%I64d,\"exit_time\":%I64d,"
      "\"duration_seconds\":%I64d,\"entry_price\":%.8f,\"exit_price\":%.8f,"
      "\"volume\":%.8f,\"initial_sl\":%.8f,\"initial_tp\":%.8f,"
      "\"profit\":%.2f,\"commission\":%.2f,\"swap\":%.2f,\"net_profit\":%.2f,"
      "\"mfe\":%.2f,\"mae\":%.2f,\"spread_points\":%.2f,\"atr\":%.8f,"
      "\"market_regime\":\"%s\",\"session_name\":\"%s\",\"entry_hour\":%d,"
       "\"loss_streak_before\":%d,\"exit_reason\":\"%s\",\"ea_version\":\"%s\","
      "\"settings_hash\":\"%s\",\"level_price\":%.8f,\"pivot_time\":%I64d,"
      "\"result\":\"%s\",\"broker_utc_offset_seconds\":%d,"
      "\"time_basis\":\"BROKER_SERVER\",\"data_quality\":\"%s\"}",
       JsonEscape(InpAnalyticsToken), g_trade_telemetry[index].position_id,
       JsonEscape(g_trade_telemetry[index].account_ref), JsonEscape(_Symbol),
      JsonEscape(g_trade_telemetry[index].action), JsonEscape(g_trade_telemetry[index].signal_type),
      JsonEscape(EnumToString(_Period)), (long)g_trade_telemetry[index].entry_time,
      (long)g_trade_telemetry[index].exit_time, duration,
      g_trade_telemetry[index].entry_price, g_trade_telemetry[index].exit_price,
      g_trade_telemetry[index].volume, g_trade_telemetry[index].initial_sl,
      g_trade_telemetry[index].initial_tp, g_trade_telemetry[index].profit,
      g_trade_telemetry[index].commission, g_trade_telemetry[index].swap, net_profit,
      g_trade_telemetry[index].mfe, g_trade_telemetry[index].mae,
      g_trade_telemetry[index].spread_points, g_trade_telemetry[index].atr,
      JsonEscape(g_trade_telemetry[index].market_regime),
      JsonEscape(g_trade_telemetry[index].session_name),
       g_trade_telemetry[index].entry_hour, g_trade_telemetry[index].loss_streak_before,
       JsonEscape(g_trade_telemetry[index].exit_reason),
       JsonEscape(g_trade_telemetry[index].ea_version),
       JsonEscape(g_trade_telemetry[index].settings_hash),
      g_trade_telemetry[index].level_price, (long)pivot_time, result,
      g_trade_telemetry[index].broker_utc_offset_seconds,
      JsonEscape(g_trade_telemetry[index].data_quality));

   char request_body[], response_body[];
   StringToCharArray(payload, request_body, 0, WHOLE_ARRAY, CP_UTF8);
   if(ArraySize(request_body) > 0)
      ArrayResize(request_body, ArraySize(request_body) - 1);
   const string headers = "Content-Type: application/json\r\n";
   string response_headers;
   ResetLastError();
   const int status = WebRequest("POST", AnalyticsWebhookURL(), headers,
                                 InpAnalyticsTimeoutMs, request_body,
                                 response_body, response_headers);
   string response = CharArrayToString(response_body, 0, WHOLE_ARRAY, CP_UTF8);
   StringReplace(response, " ", "");
   StringReplace(response, "\r", "");
   StringReplace(response, "\n", "");
   StringReplace(response, "\t", "");
   const string expected_position = StringFormat("\"positionId\":\"%I64u\"",
                                                  g_trade_telemetry[index].position_id);
   const string expected_account = StringFormat("\"accountRef\":\"%s\"",
                                                 JsonEscape(g_trade_telemetry[index].account_ref));
   const bool acknowledged = (StringFind(response, "\"ok\":true") >= 0 &&
                              StringFind(response, "\"instance\":\"demo\"") >= 0 &&
                              StringFind(response, expected_position) >= 0 &&
                              StringFind(response, expected_account) >= 0);
   if(status >= 200 && status < 300 && acknowledged)
      return true;
   PrintFormat("S/R EA: demo trade analytics failed or ACK was invalid. "
               "position=%I64u HTTP=%d ack=%s error=%d.",
               g_trade_telemetry[index].position_id, status,
               (acknowledged ? "true" : "false"), GetLastError());
   return false;
}

//+------------------------------------------------------------------+
int AnalyticsBackoffSeconds(const int retry_count)
{
   int delay = MathMax(5, InpAnalyticsRetrySeconds);
   const int exponent = MathMin(6, MathMax(0, retry_count - 1));
   for(int i = 0; i < exponent; ++i)
      delay *= 2;
   return MathMin(900, delay);
}

//+------------------------------------------------------------------+
void SendPendingTradeAnalytics()
{
   if(!AnalyticsEnabled())
      return;
   const datetime now = TimeLocal();
   int selected = -1;
   for(int i = 0; i < ArraySize(g_trade_telemetry); ++i)
   {
      if(!g_trade_telemetry[i].closed ||
          (g_trade_telemetry[i].last_send_attempt > 0 &&
           (long)now - (long)g_trade_telemetry[i].last_send_attempt <
              AnalyticsBackoffSeconds(g_trade_telemetry[i].retry_count)))
         continue;
      if(selected < 0 || g_trade_telemetry[i].exit_time <
                         g_trade_telemetry[selected].exit_time)
         selected = i;
   }
   if(selected < 0)
      return;

   // Persist the attempt first. If MT5 stops after the server commits but before
   // local removal, the idempotent position_id upsert safely accepts the retry.
   g_trade_telemetry[selected].last_send_attempt = now;
   SaveTelemetryOutbox();
   if(SendTradeAnalytics(selected))
      RemoveTelemetry(selected);
   else
      ++g_trade_telemetry[selected].retry_count;
   SaveTelemetryOutbox();
}

//+------------------------------------------------------------------+
bool GetLossStreakPauseState(bool &active)
{
   active = false;
   if(InpMaxConsecutiveLosses <= 0 || InpLossStreakPauseBars <= 0)
      return true;

   int wins, losses, break_evens, streak;
   datetime last_exit;
   if(!GetClosedTradeStats(wins, losses, break_evens, streak, last_exit))
      return false;
   if(streak < InpMaxConsecutiveLosses || last_exit <= 0)
      return true;

   const long pause_seconds = (long)InpLossStreakPauseBars * PeriodSeconds(_Period);
   active = ((long)TimeCurrent() - (long)last_exit < pause_seconds);
   return true;
}

//+------------------------------------------------------------------+
void UpdateStatsDashboard()
{
   if(!InpShowStatsDashboard)
   {
      Comment("");
      return;
   }

   int wins, losses, break_evens, streak;
   datetime last_exit;
   const bool stats_known = GetClosedTradeStats(
      wins, losses, break_evens, streak, last_exit);
   const int closed = wins + losses + break_evens;
   const double win_rate = (closed > 0 ? 100.0 * wins / closed : 0.0);
   int today_losses = 0;
   int loss_pause_seconds = 0;
   bool streak_pause_active = false;
   const bool daily_known = CountTodayLosingExits(today_losses);
   const bool loss_pause_known = LossPauseRemainingSeconds(loss_pause_seconds);
   const bool streak_known = GetLossStreakPauseState(streak_pause_active);
   const string pause_state = (InpMaxConsecutiveLosses <= 0 ? "DISABLED" :
      (!streak_known ? "UNKNOWN" : (streak_pause_active ? "ACTIVE" : "READY")));
   const string daily_state = (InpMaxDailyLosses <= 0 ? "DISABLED" :
      (!daily_known ? "UNKNOWN" :
       (today_losses >= InpMaxDailyLosses ? "ACTIVE" : "READY")));
   Comment(StringFormat("Adaptive S/R Dynamic v1.90\n"
                        "Closed: %d | Win: %d | Loss: %d | BE: %d\n"
                        "Win rate: %.2f%% | Current loss streak: %d\n"
                        "Today losses: %d/%d | Daily guard: %s\n"
                        "After-loss pause: %s (%d min left)\n"
                        "Cross-day loss guard: %s",
                        closed, wins, losses, break_evens,
                        win_rate, streak, today_losses, InpMaxDailyLosses,
                        daily_state,
                         (!stats_known || !loss_pause_known ? "UNKNOWN" :
                          (loss_pause_seconds > 0 ? "ACTIVE" : "READY")),
                        (loss_pause_seconds + 59) / 60, pause_state));
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
      if(sl >= entry || (tp > 0.0 && tp <= entry))
         return false;
      if((entry - sl) + 1e-12 < minimum_distance ||
         (tp > 0.0 && (tp - entry) + 1e-12 < minimum_distance))
         return false;
   }
   else
   {
      if(sl <= entry || (tp > 0.0 && tp >= entry))
         return false;
      if((sl - entry) + 1e-12 < minimum_distance ||
         (tp > 0.0 && (entry - tp) + 1e-12 < minimum_distance))
         return false;
   }
   return true;
}

//+------------------------------------------------------------------+
void ClearPendingEntryGuard()
{
   g_pending_entry_active = false;
   g_pending_entry_order = 0;
   g_pending_entry_since_ms = 0;
   g_pending_entry_direction = 0;
   g_pending_entry_level_price = 0.0;
   g_pending_entry_pivot_time = 0;
   g_pending_entry_atr = 0.0;
   g_pending_entry_initial_sl = 0.0;
   g_pending_entry_initial_tp = 0.0;
   g_pending_entry_requested_volume = 0.0;
   g_pending_entry_spread_points = 0.0;
}

//+------------------------------------------------------------------+
bool FindOurActiveEntryOrder(ulong &order_ticket)
{
   order_ticket = 0;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket) ||
         OrderGetString(ORDER_SYMBOL) != _Symbol ||
         (ulong)OrderGetInteger(ORDER_MAGIC) != InpMagicNumber)
         continue;
      const long order_type = OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY || order_type == ORDER_TYPE_SELL)
      {
         order_ticket = ticket;
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
bool PendingEntryActive()
{
   ulong active_order = 0;
   if(FindOurActiveEntryOrder(active_order))
   {
      g_pending_entry_active = true;
      g_pending_entry_order = active_order;
      if(g_pending_entry_since_ms == 0)
         g_pending_entry_since_ms = GetTickCount64();
      return true;
   }
   if(!g_pending_entry_active)
      return false;

   if(g_pending_entry_order > 0 && HistoryOrderSelect(g_pending_entry_order))
   {
      ClearPendingEntryGuard();
      return false;
   }

   // A server-accepted request without an order ticket is held briefly so its
   // queued trade transactions can reconcile before another entry is allowed.
   if(g_pending_entry_order == 0 && g_pending_entry_since_ms > 0 &&
      GetTickCount64() - g_pending_entry_since_ms > 30000)
   {
      Print("S/R EA: pending entry without an order ticket expired after 30 seconds.");
      ClearPendingEntryGuard();
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
void BeginPendingEntryGuard(const ulong order_ticket, const int direction,
                            const double level_price,
                            const datetime pivot_time, const double atr,
                            const double initial_sl, const double initial_tp,
                            const double requested_volume,
                            const double spread_points)
{
   g_pending_entry_active = true;
   g_pending_entry_order = order_ticket;
   g_pending_entry_since_ms = GetTickCount64();
   g_pending_entry_direction = direction;
   g_pending_entry_level_price = level_price;
   g_pending_entry_pivot_time = pivot_time;
   g_pending_entry_atr = atr;
   g_pending_entry_initial_sl = initial_sl;
   g_pending_entry_initial_tp = initial_tp;
   g_pending_entry_requested_volume = requested_volume;
   g_pending_entry_spread_points = spread_points;
}

//+------------------------------------------------------------------+
bool ConfirmEntryDeal(const ulong deal_ticket, ulong &position_id,
                      double &actual_volume, double &actual_price)
{
   position_id = 0;
   actual_volume = 0.0;
   actual_price = 0.0;
   if(deal_ticket == 0 || !HistoryDealSelect(deal_ticket) ||
      HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != _Symbol ||
      (ulong)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != InpMagicNumber)
      return false;
   const long entry_type = HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
   if(entry_type != DEAL_ENTRY_IN && entry_type != DEAL_ENTRY_INOUT)
      return false;
   position_id = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
   ulong position_ticket = 0;
   if(position_id == 0 ||
      !SelectPositionByIdentifier(position_id, position_ticket,
                                  actual_volume, actual_price))
      return false;
   return true;
}

//+------------------------------------------------------------------+
void CaptureEntryDealState(const ulong deal_ticket,
                           const bool use_pending_context)
{
   if(deal_ticket == 0 || !HistoryDealSelect(deal_ticket))
      return;
   const ulong position_id =
      (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
   const datetime entry_time =
      (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
   const string comment = HistoryDealGetString(deal_ticket, DEAL_COMMENT);
   ApplyPositionEntryToLevelState(position_id, comment, entry_time);

   if(use_pending_context && g_pending_entry_direction != 0)
   {
      ulong position_ticket = 0;
      double actual_volume = HistoryDealGetDouble(deal_ticket, DEAL_VOLUME);
      double actual_price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
      SelectPositionByIdentifier(position_id, position_ticket,
                                 actual_volume, actual_price);
      const string signal_type = (g_pending_entry_direction > 0 ?
                                  "SUPPORT_BUY" : "RESISTANCE_SELL");
      RegisterOpenedTelemetryFromDeal(
         deal_ticket, g_pending_entry_direction, signal_type,
         g_pending_entry_level_price, g_pending_entry_pivot_time,
         g_pending_entry_atr, g_pending_entry_spread_points,
         g_pending_entry_initial_sl, g_pending_entry_initial_tp,
         actual_volume);
   }
   else
      TrackOpenTradeTelemetry();
}

//+------------------------------------------------------------------+
bool OpenSignalTrade(const int direction, const double level_price,
                     const datetime pivot_time, const double atr)
{
   if(PendingEntryActive())
   {
      Print("S/R EA: signal skipped while a prior entry request is pending.");
      return false;
   }
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

   double volume = NormalizeVolume(InpFixedLot);
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
      sl = NormalizeDouble(sl, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
   }
   else if(!FindMoneyPrice(order_type, volume, entry, InpStopLossMoney, false, sl))
   {
      Print("S/R EA: cannot convert money SL target to broker price; signal skipped.");
      return false;
   }

   if(InpUseATRAdjustedStop && InpStopLossPips <= 0 && InpMinimumStopATR > 0.0)
   {
      const double tick = TickSize();
      const double fixed_distance = MathAbs(entry - sl);
      double stop_distance = MathMax(fixed_distance, InpMinimumStopATR * atr);
      stop_distance = MathCeil(stop_distance / tick - 1e-10) * tick;
      const double volatility_sl = NormalizeDouble(
         (direction > 0 ? entry - stop_distance : entry + stop_distance),
         (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
      double one_lot_loss = 0.0;
      if(!ProfitAtPrice(order_type, 1.0, entry, volatility_sl, one_lot_loss) ||
         one_lot_loss >= 0.0)
      {
         Print("S/R EA: cannot calculate ATR-adjusted risk; signal skipped.");
         return false;
      }

      const double risk_limited_volume = NormalizeVolumeDown(
         InpStopLossMoney / MathAbs(one_lot_loss));
      if(risk_limited_volume <= 0.0)
      {
         Print("S/R EA: minimum broker volume exceeds ATR-adjusted risk; signal skipped.");
         return false;
      }
      volume = MathMin(volume, risk_limited_volume);
      sl = volatility_sl;
   }

   if(InpExitMode == 0)
   {
      if(InpTakeProfitPips > 0)
      {
         const double tp_distance = InpTakeProfitPips * point;
         tp = (direction > 0) ? entry + tp_distance : entry - tp_distance;
         tp = NormalizeDouble(tp, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
      }
      else if(!FindMoneyPrice(order_type, volume, entry, InpTakeProfitMoney, true, tp))
      {
         Print("S/R EA: cannot convert money TP target to broker price; signal skipped.");
         return false;
      }
   }
   if(!StopsAreValid(order_type, entry, sl, tp))
   {
      Print("S/R EA: money-based SL/TP is inside the broker minimum stop distance; signal skipped.");
      return false;
   }

   const string side = (direction > 0) ? "SUPPORT_BUY" : "RESISTANCE_SELL";
   const string comment = StringFormat("%s%I64d",
      (direction > 0 ? "SRB_" : "SRS_"), (long)pivot_time);
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

   const double spread_points =
      (point > 0.0 ? (quote.ask - quote.bid) / point : 0.0);
   const ulong deal_ticket = g_trade.ResultDeal();
   const ulong order_ticket = g_trade.ResultOrder();
   BeginPendingEntryGuard(order_ticket, direction, level_price, pivot_time,
                          atr, sl, tp, volume, spread_points);

   ulong position_id = 0;
   double actual_volume = 0.0, actual_price = 0.0;
   const bool confirmed = ConfirmEntryDeal(
      deal_ticket, position_id, actual_volume, actual_price);
   if(confirmed)
   {
      CaptureEntryDealState(deal_ticket, true);
      if(retcode == TRADE_RETCODE_DONE)
         ClearPendingEntryGuard();
      else
         PendingEntryActive();
      PrintFormat("S/R EA: %s fill confirmed, level=%.*f, lot=%.2f, "
                  "price=%.*f, SL=%.*f (~%.2f), TP=%.*f, exit_mode=%d.",
                  side, _Digits, level_price, actual_volume,
                  _Digits, actual_price, _Digits, sl, InpStopLossMoney,
                  _Digits, tp, InpExitMode);
      return true;
   }

   PrintFormat("S/R EA: %s request accepted but fill is pending. "
               "retcode=%u order=%I64u deal=%I64u.",
               side, retcode, order_ticket, deal_ticket);
   return true;
}

//+------------------------------------------------------------------+
bool ReachedOppositeSR(const long position_type, const double entry,
                       const MqlTick &quote, const double atr)
{
   const double zone_half_width = 0.5 * InpZoneWidthATR * atr;
   for(int i = ArraySize(g_levels) - 1; i >= 0; --i)
   {
      if(position_type == POSITION_TYPE_BUY && g_levels[i].type == 1 &&
         g_levels[i].price > entry && quote.bid >= g_levels[i].price - zone_half_width)
         return true;
      if(position_type == POSITION_TYPE_SELL && g_levels[i].type == -1 &&
         g_levels[i].price < entry && quote.ask <= g_levels[i].price + zone_half_width)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
bool ModifyPositionSLConfirmed(const ulong ticket, const double desired_sl,
                               const string protective_reason)
{
   if(!PositionSelectByTicket(ticket))
      return false;
   const ulong position_id = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
   const double current_tp = PositionGetDouble(POSITION_TP);
   ResetLastError();
   const bool sent = g_trade.PositionModify(ticket, desired_sl, current_tp);
   const uint retcode = g_trade.ResultRetcode();
   const int terminal_error = GetLastError();
   const bool retcode_ok = (retcode == TRADE_RETCODE_DONE ||
                            retcode == TRADE_RETCODE_NO_CHANGES ||
                            retcode == TRADE_RETCODE_PLACED);

   bool state_confirmed = false;
   double actual_sl = 0.0;
   if(PositionSelectByTicket(ticket))
   {
      actual_sl = PositionGetDouble(POSITION_SL);
      state_confirmed = (MathAbs(actual_sl - desired_sl) <= TickSize() * 0.5);
   }
   if(sent && retcode_ok && state_confirmed)
   {
      const int index = FindTelemetryIndex(position_id);
      if(index >= 0)
      {
         g_trade_telemetry[index].protective_stop_reason = protective_reason;
         SaveTelemetryOutbox();
      }
      return true;
   }

   PrintFormat("S/R EA: dynamic SL was not confirmed and will retry if still needed. "
               "ticket=%I64u requested=%.*f actual=%.*f sent=%s retcode=%u (%s) error=%d",
               ticket, _Digits, desired_sl, _Digits, actual_sl,
               (sent ? "true" : "false"), retcode,
               g_trade.ResultRetcodeDescription(), terminal_error);
   return false;
}

//+------------------------------------------------------------------+
void ManageDynamicExits()
{
   if(InpExitMode <= 0 || CountOurPositions() <= 0)
      return;

   MqlTick quote;
   if(!SymbolInfoTick(_Symbol, quote))
      return;
   double atr = 0.0;
   if(!GetATR(0, atr) || atr <= 0.0)
      return;

   const double tick = TickSize();
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double minimum_distance = MathMax(
      (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL),
      (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL)) * point;
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      const long position_type = PositionGetInteger(POSITION_TYPE);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double gross_profit = PositionGetDouble(POSITION_PROFIT);
      const ENUM_ORDER_TYPE order_type = (position_type == POSITION_TYPE_BUY ?
                                          ORDER_TYPE_BUY : ORDER_TYPE_SELL);

      if(InpExitMode == 2 && gross_profit >= InpStructureExitMinProfitMoney &&
         ReachedOppositeSR(position_type, entry, quote, atr))
      {
         const bool closed = ClosePositionConfirmed(ticket, "OPPOSITE_SR",
                                                    "opposite S/R exit");
         if(closed)
            PrintFormat("S/R EA: dynamic exit at opposite S/R. ticket=%I64u profit=%.2f",
                        ticket, gross_profit);
         continue;
      }

      double desired_sl = current_sl;
      if(gross_profit >= InpBreakEvenActivationMoney)
      {
         double locked_price = 0.0;
         if(FindMoneyPrice(order_type, volume, entry,
                           InpBreakEvenLockMoney, true, locked_price))
         {
            if(position_type == POSITION_TYPE_BUY)
               desired_sl = MathMax(desired_sl, locked_price);
            else if(desired_sl <= 0.0)
               desired_sl = locked_price;
            else
               desired_sl = MathMin(desired_sl, locked_price);
         }
      }

      if(gross_profit >= InpTrailActivationMoney)
      {
         const double market_price = (position_type == POSITION_TYPE_BUY ? quote.bid : quote.ask);
         const double trail_price = (position_type == POSITION_TYPE_BUY ?
                                     market_price - InpTrailATRMultiplier * atr :
                                     market_price + InpTrailATRMultiplier * atr);
         if(position_type == POSITION_TYPE_BUY)
            desired_sl = MathMax(desired_sl, trail_price);
         else if(desired_sl <= 0.0)
            desired_sl = trail_price;
         else
            desired_sl = MathMin(desired_sl, trail_price);
      }

      if(desired_sl <= 0.0 || tick <= 0.0)
         continue;
      if(position_type == POSITION_TYPE_BUY)
         desired_sl = MathFloor(desired_sl / tick + 1e-10) * tick;
      else
         desired_sl = MathCeil(desired_sl / tick - 1e-10) * tick;
      desired_sl = NormalizeDouble(desired_sl, digits);

      const bool improves = (position_type == POSITION_TYPE_BUY ?
         desired_sl > current_sl + tick * 0.5 :
         (current_sl <= 0.0 || desired_sl < current_sl - tick * 0.5));
      const bool valid_from_market = (position_type == POSITION_TYPE_BUY ?
         desired_sl < quote.bid - minimum_distance :
         desired_sl > quote.ask + minimum_distance);
      if(!improves || !valid_from_market)
         continue;

      const string protective_reason = (gross_profit >= InpTrailActivationMoney ?
                                        "TRAILING_STOP" : "BREAK_EVEN_STOP");
      ModifyPositionSLConfirmed(ticket, desired_sl, protective_reason);
   }
}

//+------------------------------------------------------------------+
// Check if closed bar shift experienced a Bullish Rejection at Support Zone
bool IsBullishRejection(const int shift, const double support_price,
                        const double zone_half_width)
{
   const double open_p  = iOpen(_Symbol, _Period, shift);
   const double high_p  = iHigh(_Symbol, _Period, shift);
   const double low_p   = iLow(_Symbol, _Period, shift);
   const double close_p = iClose(_Symbol, _Period, shift);
   if(open_p <= 0.0 || high_p <= 0.0 || low_p <= 0.0 || close_p <= 0.0)
      return false;

   const double zone_top = support_price + zone_half_width;
   const double zone_bottom = support_price - zone_half_width;

   // Candle must intersect the zone and close back above its upper boundary.
   if(low_p > zone_top || high_p < zone_bottom)
      return false;
   if(close_p < zone_top)
      return false;

   if(!InpRequireRejection)
      return true;

   const double range = high_p - low_p;
   if(range <= 0.0)
      return false;

   const double body = close_p - open_p;
   const double lower_shadow = MathMin(open_p, close_p) - low_p;
   const double close_location = (close_p - low_p) / range;

   // InpBuyMin* parameters are always the BUY-side thresholds regardless of
   // InpAutoDirection mode. Conflating the two caused SELL-side parameters to
   // apply to BUY signals when InpAutoDirection was off.
   const double min_body  = (InpBuyMinBodyRangeRatio > 0.0 ? InpBuyMinBodyRangeRatio : InpMinBodyRangeRatio);
   const double min_wick  = (InpBuyMinWickRangeRatio > 0.0 ? InpBuyMinWickRangeRatio : InpMinWickRangeRatio);
   const double min_close = InpBuyMinCloseLocation;
   return (body > 0.0 &&
           body / range >= min_body &&
           lower_shadow / range >= min_wick &&
           close_location >= min_close);
}

//+------------------------------------------------------------------+
// Check if closed bar shift experienced a Bearish Rejection at Resistance Zone
bool IsBearishRejection(const int shift, const double resist_price,
                        const double zone_half_width)
{
   const double open_p  = iOpen(_Symbol, _Period, shift);
   const double high_p  = iHigh(_Symbol, _Period, shift);
   const double low_p   = iLow(_Symbol, _Period, shift);
   const double close_p = iClose(_Symbol, _Period, shift);
   if(open_p <= 0.0 || high_p <= 0.0 || low_p <= 0.0 || close_p <= 0.0)
      return false;

   const double zone_top = resist_price + zone_half_width;
   const double zone_bottom = resist_price - zone_half_width;

   // Candle must intersect the zone and close back below its lower boundary.
   if(high_p < zone_bottom || low_p > zone_top)
      return false;
   if(close_p > zone_bottom)
      return false;

   if(!InpRequireRejection)
      return true;

   const double range = high_p - low_p;
   if(range <= 0.0)
      return false;

   const double body = open_p - close_p;
   const double upper_shadow = high_p - MathMax(open_p, close_p);
   const double close_location = (high_p - close_p) / range;

   return (body > 0.0 &&
           body / range >= InpMinBodyRangeRatio &&
           upper_shadow / range >= InpMinWickRangeRatio &&
           close_location >= InpMinCloseLocation);
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

   // A traded level becomes eligible again only after price clearly leaves
   // the zone on the expected side. This keeps repeat entries as distinct
   // retests instead of firing repeatedly while price remains inside a zone.
   const double zone_half_width = InpZoneWidthATR * atr * 0.5;
   const double rearm_distance = InpRearmDistanceATR * atr;
   const double candle_high = iHigh(_Symbol, _Period, confirmation_shift);
   const double candle_low  = iLow(_Symbol, _Period, confirmation_shift);
   for(int i = ArraySize(g_levels) - 1; i >= 0; --i)
   {
      if(g_levels[i].trade_count <= 0 || g_levels[i].rearmed)
         continue;

      if((g_levels[i].type == -1 &&
          candle_low > g_levels[i].price + zone_half_width + rearm_distance) ||
         (g_levels[i].type == 1 &&
          candle_high < g_levels[i].price - zone_half_width - rearm_distance))
         g_levels[i].rearmed = true;
   }

   if(!allow_trade)
      return;
   if(!g_level_trade_state_ready)
   {
      Print("S/R EA: entry blocked until level trade history is restored.");
      return;
   }

   bool auto_buy_allowed = false;
   bool auto_sell_allowed = false;
   if(InpAutoDirection &&
      !GetAutoDirectionPermissions(confirmation_shift, atr,
                                   auto_buy_allowed, auto_sell_allowed))
      return;

   // 3. Trade Entry Logic: Check active levels for Retest & Rejection at confirmation_shift (bar 1)
   if(CountOurPositions() >= InpMaxOpenPositions)
      return;
   if(PendingEntryActive())
      return;

   if(!IsWithinTradingSession(confirmation_shift))
      return;

   if(!MarketScheduleAllowsEntry(TimeCurrent()))
      return;

   if((g_bar_serial - g_last_trade_serial) < InpCooldownBars)
      return;

   int today_losses = 0;
   if(!CountTodayLosingExits(today_losses))
   {
      Print("S/R EA: entry blocked because closed-trade history is incomplete.");
      return;
   }
   if(InpMaxDailyLosses > 0 && today_losses >= InpMaxDailyLosses)
   {
      PrintFormat("S/R EA: daily loss guard active after %d losses.", InpMaxDailyLosses);
      return;
   }

   int loss_pause_remaining = 0;
   if(!LossPauseRemainingSeconds(loss_pause_remaining))
   {
      Print("S/R EA: entry blocked because loss-pause history is incomplete.");
      return;
   }
   if(loss_pause_remaining > 0)
   {
      PrintFormat("S/R EA: after-loss pause active for %d more seconds.",
                  loss_pause_remaining);
      return;
   }

   bool streak_pause_active = false;
   if(!GetLossStreakPauseState(streak_pause_active))
   {
      Print("S/R EA: entry blocked because loss-streak history is incomplete.");
      return;
   }
   if(streak_pause_active)
   {
      PrintFormat("S/R EA: loss-streak pause active after %d consecutive losses.",
                  InpMaxConsecutiveLosses);
      return;
   }

   if(IsCandleTooLarge(confirmation_shift, atr))
   {
      PrintFormat("S/R EA: Signal skipped. Candle body at shift %d is too large (Momentum filter).", confirmation_shift);
      return;
   }

   int stats_wins, stats_losses, stats_break_evens, active_loss_streak;
   datetime stats_last_exit;
   if(!GetClosedTradeStats(stats_wins, stats_losses, stats_break_evens,
                           active_loss_streak, stats_last_exit))
   {
      Print("S/R EA: entry blocked because recovery history is incomplete.");
      return;
   }
   const bool recovery_active = (InpRecoveryStartLossStreak > 0 &&
                                 active_loss_streak >= InpRecoveryStartLossStreak);
   for(int i = ArraySize(g_levels) - 1; i >= 0; --i)
   {
      if(CountOurPositions() >= InpMaxOpenPositions)
         break;

      const bool recovery_applies_to_level =
         recovery_active &&
         (InpRecoverySideMode == 0 ||
          (InpRecoverySideMode == 1 && g_levels[i].type == -1) ||
          (InpRecoverySideMode == 2 && g_levels[i].type == 1));
      const int required_retest_delay = (recovery_applies_to_level ?
         MathMax(InpMinRetestDelayBars, InpRecoveryMinRetestDelayBars) :
         InpMinRetestDelayBars);

      if(g_levels[i].trade_count >= InpMaxTradesPerLevel ||
         !g_levels[i].rearmed ||
         (g_bar_serial - g_levels[i].last_trade_serial) < InpSameLevelCooldownBars ||
         (g_bar_serial - g_levels[i].created_bar_serial) < required_retest_delay)
         continue;

      const bool buy_permission = (InpEnableBuy &&
         (InpAutoDirection ? auto_buy_allowed : PassEMAFilter(1, confirmation_shift)));
      const bool sell_permission = (InpEnableSell &&
         (InpAutoDirection ? auto_sell_allowed : PassEMAFilter(-1, confirmation_shift)));

      if(g_levels[i].type == -1 && buy_permission)
      {
         if(IsBullishRejection(confirmation_shift, g_levels[i].price, zone_half_width))
         {
            if(OpenSignalTrade(1, g_levels[i].price, g_levels[i].pivot_time, atr))
            {
               break;
            }
         }
      }
      else if(g_levels[i].type == 1 && sell_permission)
      {
         if(IsBearishRejection(confirmation_shift, g_levels[i].price, zone_half_width))
         {
            if(OpenSignalTrade(-1, g_levels[i].price, g_levels[i].pivot_time, atr))
            {
               break;
            }
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
      InpMinRetestDelayBars < 0 || InpRecoveryStartLossStreak < 0 ||
      InpRecoveryMinRetestDelayBars < 0 ||
      InpRecoverySideMode < 0 || InpRecoverySideMode > 2 ||
      InpMaxTradesPerLevel < 1 ||
      InpSameLevelCooldownBars < 0 || InpRearmDistanceATR < 0.0 ||
      InpMinBodyRangeRatio < 0.0 ||
       InpMinBodyRangeRatio > 1.0 || InpMinWickRangeRatio < 0.0 ||
       InpMinWickRangeRatio > 1.0 || InpMinCloseLocation < 0.5 ||
       InpMinCloseLocation > 1.0 || InpMaxCandleATRRatio < 0.0 ||
       InpEMAPeriod < 2 || InpEMASlopeBars < 1 ||
      InpAutoBuyEMAPeriod < 2 || InpAutoBuySlopeBars < 1 ||
      InpAutoBuyMinSlopeATR < 0.0 || InpAutoBuyMinDistanceATR < 0.0 ||
      InpAutoBuyStartHour < 0 || InpAutoBuyStartHour > 23 ||
      InpAutoBuyEndHour < 0 || InpAutoBuyEndHour > 24 ||
      InpAutoBuyPauseStartHour < 0 || InpAutoBuyPauseStartHour > 23 ||
      InpAutoBuyPauseEndHour < 0 || InpAutoBuyPauseEndHour > 24 ||
      InpBuyMinBodyRangeRatio < 0.0 || InpBuyMinBodyRangeRatio > 1.0 ||
      InpBuyMinWickRangeRatio < 0.0 || InpBuyMinWickRangeRatio > 1.0 ||
      InpBuyMinCloseLocation < 0.5 || InpBuyMinCloseLocation > 1.0 ||
      InpAutoSellRegimeMode < 0 || InpAutoSellRegimeMode > 2 ||
      InpSessionStartHour < 0 || InpSessionStartHour > 23 ||
      InpSessionEndHour < 0 || InpSessionEndHour > 24 || InpCooldownBars < 0 ||
      InpMaxDailyLosses < 0 || InpPauseAfterLossMinutes < 0 ||
      InpMaxConsecutiveLosses < 0 ||
      InpLossStreakPauseBars < 0 || InpBreakEvenThresholdMoney < 0.0 ||
      InpCloseBeforeDailyMinutes < 0 || InpCloseBeforeWeekendMinutes < 0 ||
      InpBlockEntriesBeforeCloseMinutes < 0 ||
      InpBlockAfterSessionOpenMinutes < 0 || InpScheduleTimerSeconds < 1 ||
      InpHardDailyCloseHour < 0 || InpHardDailyCloseHour > 23 ||
      InpHardDailyCloseMinute < 0 || InpHardDailyCloseMinute > 59 ||
      InpHardFridayCloseHour < 0 || InpHardFridayCloseHour > 23 ||
      InpHardFridayCloseMinute < 0 || InpHardFridayCloseMinute > 59 ||
      InpHolidayEarlyCloseHour < 0 || InpHolidayEarlyCloseHour > 23 ||
      InpHolidayEarlyCloseMinute < 0 || InpHolidayEarlyCloseMinute > 59 ||
      InpMinimumStopATR < 0.0 ||
      InpExitMode < 0 || InpExitMode > 2 ||
      InpBreakEvenActivationMoney <= 0.0 || InpBreakEvenLockMoney < 0.0 ||
      InpBreakEvenLockMoney >= InpBreakEvenActivationMoney ||
      InpTrailActivationMoney < InpBreakEvenActivationMoney ||
       InpTrailATRMultiplier <= 0.0 || InpStructureExitMinProfitMoney < 0.0 ||
       InpFixedLot <= 0.0 || InpMaxOpenPositions < 1 ||
       InpMaxSpreadPoints < 0 || InpDeviationPoints < 0 ||
      (InpStopLossPips <= 0 && InpStopLossMoney <= 0.0) ||
      (InpExitMode == 0 && InpTakeProfitPips <= 0 && InpTakeProfitMoney <= 0.0))
   {
      Print("S/R EA: invalid inputs.");
      return INIT_PARAMETERS_INCORRECT;
   }

   g_demo_analytics_active = false;
   if(InpEnableDemoAnalytics)
   {
      if(MQLInfoInteger(MQL_TESTER))
      {
         Print("S/R EA: demo trade analytics are skipped in Strategy Tester.");
      }
      else
      {
         if(AccountInfoInteger(ACCOUNT_TRADE_MODE) != ACCOUNT_TRADE_MODE_DEMO)
         {
            Print("S/R EA: demo analytics were requested on a non-demo account and have been disabled; trading protection remains active.");
         }
         else if(!HasDemoWebhookBaseURL() || StringLen(InpAnalyticsToken) == 0 ||
                 !IsSafeDatasetPrefix(InpAnalyticsAccountRef) ||
                 InpAnalyticsRetrySeconds < 5 ||
                 InpAnalyticsTimeoutMs < 100 || InpAnalyticsTimeoutMs > 2000)
         {
            Print("S/R EA: invalid demo analytics settings; analytics have been disabled without stopping the EA. The URL must be exactly https://ats.thaipesleague.com/demo, token is required, dataset prefix must be 1-40 safe characters, and timeout must be 100-2000 ms.");
         }
         else
         {
            g_demo_analytics_active = true;
            PrintFormat("S/R EA: demo trade analytics enabled: %s. Add https://ats.thaipesleague.com to the MT5 WebRequest allow-list.",
                        AnalyticsWebhookURL());
         }
      }
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

   if(InpUseEMAFilter)
   {
      g_ema_handle = iMA(_Symbol, _Period, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(g_ema_handle == INVALID_HANDLE)
      {
         PrintFormat("S/R EA: cannot create EMA handle. error=%d", GetLastError());
         return INIT_FAILED;
      }
   }

   if(InpAutoDirection)
   {
      g_auto_buy_ema_handle = iMA(_Symbol, _Period, InpAutoBuyEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(g_auto_buy_ema_handle == INVALID_HANDLE)
      {
         PrintFormat("S/R EA: cannot create automatic direction EMA handle. error=%d", GetLastError());
         return INIT_FAILED;
      }
   }

   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints((ulong)InpDeviationPoints);
   g_trade.SetTypeFillingBySymbol(_Symbol);
   g_trade.SetAsyncMode(false);

   g_last_open_time = iTime(_Symbol, _Period, 0);
   g_state_ready = RebuildLevelState();
   g_level_trade_state_ready = (g_state_ready &&
      RestoreLevelTradeStateFromHistory());
   const bool outbox_loaded = LoadTelemetryOutbox();
   TrackOpenTradeTelemetry();
   FinalizeClosedTelemetry();
   if(outbox_loaded)
      SaveTelemetryOutbox();
   if(!g_state_ready)
      Print("S/R EA: waiting for enough price history to rebuild S/R state.");
   else if(!g_level_trade_state_ready)
      Print("S/R EA: trading is blocked until entry history can restore level cooldowns.");

   PrintFormat("S/R EA (Rejection Strategy) ready on %s %s. Lot=%.2f, SL=%.2f, TP=%.2f, exit_mode=%d.",
               _Symbol, EnumToString(_Period), InpFixedLot,
               InpStopLossMoney, InpTakeProfitMoney, InpExitMode);
   EventSetTimer(InpScheduleTimerSeconds);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   SaveTelemetryOutbox();
   EventKillTimer();
   if(g_atr_handle != INVALID_HANDLE)
      IndicatorRelease(g_atr_handle);
   if(g_ema_handle != INVALID_HANDLE)
      IndicatorRelease(g_ema_handle);
   if(g_auto_buy_ema_handle != INVALID_HANDLE)
      IndicatorRelease(g_auto_buy_ema_handle);
   Comment("");
}

void SendHeartbeat()
{
   if(!InpEnableDemoAnalytics)
      return;

   static datetime last_heartbeat = 0;
   const datetime now = TimeLocal();
   if(now - last_heartbeat < 5)
      return;
   last_heartbeat = now;

   string base_url = InpAnalyticsBaseURL;
   while(StringLen(base_url) > 0 && StringSubstr(base_url, StringLen(base_url) - 1, 1) == "/")
      base_url = StringSubstr(base_url, 0, StringLen(base_url) - 1);
   if(StringLen(base_url) == 0)
      return;

   const string url = base_url + "/api/signals/pending";
   const double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   const double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   const double fm = AccountInfoDouble(ACCOUNT_FREEMARGIN);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   string positions_json = "[";
   int pos_count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      if(pos_count > 0)
         positions_json += ",";

      const long ptype = PositionGetInteger(POSITION_TYPE);
      const string stype = (ptype == POSITION_TYPE_BUY ? "BUY" : "SELL");
      positions_json += StringFormat("{\"ticket\":\"%I64u\",\"symbol\":\"%s\",\"type\":\"%s\",\"volume\":%.2f,\"open_price\":%.5f,\"current_price\":%.5f,\"sl\":%.5f,\"tp\":%.5f,\"profit\":%.2f}",
         ticket, PositionGetString(POSITION_SYMBOL), stype,
         PositionGetDouble(POSITION_VOLUME), PositionGetDouble(POSITION_PRICE_OPEN),
         PositionGetDouble(POSITION_PRICE_CURRENT), PositionGetDouble(POSITION_SL),
         PositionGetDouble(POSITION_TP), PositionGetDouble(POSITION_PROFIT));
      pos_count++;
   }
   positions_json += "]";

   const string payload = StringFormat("{\"token\":\"%s\",\"balance\":%.2f,\"equity\":%.2f,\"free_margin\":%.2f,\"bid\":%.5f,\"ask\":%.5f,\"positions\":%s}",
      InpAnalyticsToken, bal, eq, fm, bid, ask, positions_json);

   char pd[], rd[];
   string rh;
   StringToCharArray(payload, pd, 0, StringLen(payload), CP_UTF8);
   if(ArraySize(pd) > 0)
      ArrayResize(pd, ArraySize(pd) - 1);

   const string headers = "Content-Type: application/json\r\n";
   ResetLastError();
   WebRequest("POST", url, headers, InpAnalyticsTimeoutMs, pd, rd, rh);
}

//+------------------------------------------------------------------+
void OnTimer()
{
   ManageMarketSchedule();
   if(g_state_ready && !g_level_trade_state_ready)
      g_level_trade_state_ready = RestoreLevelTradeStateFromHistory();
   PendingEntryActive();
   UpdateStatsDashboard();
   TrackOpenTradeTelemetry();
   FinalizeClosedTelemetry();
   SaveTelemetryOutbox();
   SendPendingTradeAnalytics();
   SendHeartbeat();
}

//+------------------------------------------------------------------+
void OnTick()
{
   TrackOpenTradeTelemetry();
   const bool forced_close_active = ManageMarketSchedule();
   if(!forced_close_active)
      ManageDynamicExits();
   const datetime current_open_time = iTime(_Symbol, _Period, 0);
   if(current_open_time <= 0)
      return;

   if(!g_state_ready)
   {
      g_state_ready = RebuildLevelState();
      if(!g_state_ready)
         return;
      g_level_trade_state_ready = RestoreLevelTradeStateFromHistory();
      if(!g_level_trade_state_ready)
      {
         Print("S/R EA: S/R state rebuilt, but entry history restoration is pending.");
         return;
      }
      // State reconstruction never opens historical trades.
      g_last_open_time = current_open_time;
      Print("S/R EA: S/R history reconstruction completed.");
      return;
   }

   if(!g_level_trade_state_ready)
   {
      g_level_trade_state_ready = RestoreLevelTradeStateFromHistory();
      if(!g_level_trade_state_ready)
         return;
   }

   if(current_open_time == g_last_open_time)
      return;

   // Use exact=false so a missing bar time (e.g. after reconnect or holiday gap)
   // returns the nearest known shift instead of -1, preventing missed bar processing.
   int closed_bars = iBarShift(_Symbol, _Period, g_last_open_time, false);
   if(closed_bars < 1)
      closed_bars = 1;
   closed_bars = MathMin(closed_bars, InpMaxLevelAgeBars);

   // Rebuild missed closed bars in order, but only the latest signal may trade.
   for(int shift = closed_bars; shift >= 1; --shift)
      ProcessClosedBar(shift, shift == 1 && !forced_close_active);

   g_last_open_time = current_open_time;
   UpdateStatsDashboard();
}

//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &transaction,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(transaction.type == TRADE_TRANSACTION_DEAL_ADD && transaction.deal > 0 &&
      HistoryDealSelect(transaction.deal))
   {
      const string deal_symbol = HistoryDealGetString(transaction.deal, DEAL_SYMBOL);
      const long entry_type = HistoryDealGetInteger(transaction.deal, DEAL_ENTRY);
      const bool our_entry = (deal_symbol == _Symbol &&
         (ulong)HistoryDealGetInteger(transaction.deal, DEAL_MAGIC) == InpMagicNumber);
      if(our_entry && (entry_type == DEAL_ENTRY_IN || entry_type == DEAL_ENTRY_INOUT))
      {
         const bool use_pending_context = (g_pending_entry_active &&
            (g_pending_entry_order == 0 ||
             transaction.order == g_pending_entry_order));
         CaptureEntryDealState(transaction.deal, use_pending_context);
         SaveTelemetryOutbox();
      }

      if(AnalyticsEnabled() && deal_symbol == _Symbol &&
         (entry_type == DEAL_ENTRY_OUT || entry_type == DEAL_ENTRY_OUT_BY ||
          entry_type == DEAL_ENTRY_INOUT))
      {
         const ulong position_id =
            (ulong)HistoryDealGetInteger(transaction.deal, DEAL_POSITION_ID);
         AddUniqueUlong(g_pending_exit_position_ids, position_id);
         if(MarkTelemetryClosed(transaction.deal))
         {
            const int queued_index = FindUlongValue(
               g_pending_exit_position_ids, position_id);
            RemoveUlongAt(g_pending_exit_position_ids, queued_index);
         }
      }
   }

   if(g_pending_entry_active)
      PendingEntryActive();
}
//+------------------------------------------------------------------+
