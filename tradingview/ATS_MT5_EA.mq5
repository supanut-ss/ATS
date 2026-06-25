//+------------------------------------------------------------------+
//|                                                   ATS_MT5_EA.mq5 |
//|                                  Copyright 2026, Antigravity AI  |
//|                                             https://ats.info.com |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, Antigravity AI"
#property link        "https://ats.info.com"
#property version     "1.00"
#property description "ATS MetaTrader 5 Webhook Execution Connector"
#property strict

#include <Trade\Trade.mqh>

//--- Input Parameters
input group "🔗 Connection Settings"
input string   InpBackendURL = "https://ats.thaipesleague.com";               // Backend API URL
input string   InpAuthToken  = "ats_sec_9f5c4b8e2a1d7f0e3c6b8a9f";    // Auth Token
input int      InpPollInterval = 1000;                               // Polling Interval (ms)

input group "🛡 Trade Settings"
input double   InpDefaultLot = 0.01;                                 // Default Lot (fallback)
input int      InpSlippage   = 30;                                   // Max Slippage (points)
input int      InpMagic      = 88188;                                // Magic Number

//--- Global Variables
CTrade   trade;
int      timer_counter = 0;
string   backend_url = "";
string   auth_token = "";

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
   
   // Start polling timer
   EventSetMillisecondTimer(InpPollInterval);
   
   Print("ATS EA: Initialized successfully. Polling URL: ", backend_url);
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
//| Get current MT5 state as JSON                                    |
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
      // Select position by index for MT5
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
         double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP); // include swap
         
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
   
   // Call API
   int http_code = WebRequest("POST", url, headers, 3000, post_data, result_data, result_headers);
   
   if(http_code == -1)
   {
      int err = GetLastError();
      // Error 4014 means URL is not allowed in Tools -> Options -> Expert Advisors
      if(err == 4014)
      {
         Print("ATS EA ERROR: WebRequest URL not allowed! Add '", backend_url, "' to Allowed URLs list.");
      }
      else
      {
         Print("ATS EA ERROR: WebRequest failed. Error code: ", err);
      }
      return;
   }
   
   if(http_code != 200)
   {
      Print("ATS EA: Backend returned HTTP Code ", http_code);
      return;
   }
   
   string json_response = CharArrayToString(result_data, 0, WHOLE_ARRAY, CP_UTF8);
   if(json_response == "" || json_response == "[]")
      return;
      
   // Parse JSON Response
   ProcessSignals(json_response);
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
      // Try without quotes for numeric values
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
   
   // Loop through all JSON objects in array
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
      
      // Clean symbol mapping (e.g. handle broker suffixes XAUUSDm, GOLD)
      string execute_symbol = symbol;
      if(symbol == "XAUUSD" && Symbol() != "XAUUSD")
      {
         // If chart is XAUUSD.m, trade XAUUSD.m
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
      if(ticket == 0) ticket = trade.ResultDeal(); // fallback
      
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
      // Fallback: If no ticket ID is stored, close the most recent position on this symbol
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
            // Fallback: search history by position ID
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
      // Force change status so it doesn't loop forever
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
   
   // Format parameters
   string payload = StringFormat(
      "{\"token\":\"%s\",\"id\":\"%s\",\"status\":\"%s\",\"ticket\":\"%s\",\"entry_price\":%s,\"exit_price\":%s,\"profit\":%s}",
      auth_token, id, status, IntegerToString(ticket), 
      DoubleToString(entry_price, 2), 
      DoubleToString(exit_price, 2), 
      DoubleToString(profit, 2)
   );
   
   Print("ATS EA Debug: Sending POST to ", url);
   Print("ATS EA Debug: Payload: ", payload);
   
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
