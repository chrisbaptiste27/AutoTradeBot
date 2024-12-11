//+------------------------------------------------------------------+
//|                                                 AUTOTRADEBOT.mq4 |
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+


//--- Input parameters
input int      FastMAPeriod      = 13;      // Fast EMA period
input int      SlowMAPeriod      = 50;      // Slow EMA period
input double   RiskPercent       = 1.0;     // Risk % of account balance
input int      RewardToRiskRatio = 2;       // TP/SL ratio
input int      MaxTradeDuration  = 2;       // Max duration in hours
input int      StopLossPipsBuffer = 5;      // Stop loss buffer in pips
input int      Slippage          = 3;       // Slippage in pips
input int      MagicNumber       = 12345;   // Magic number for trades
input bool     LogEnabled        = true;    // Enable/disable logging

//--- Global variables
bool isBotRunning = false;                  // Start/Stop status
double fastMA, slowMA, prevFastMA, prevSlowMA;  // EMA values
double StopLossLevel, TakeProfitLevel;
datetime TradeOpenTime;
int TradeTicket;
bool StopMovedToBreakEven = false;

//--- UI element names
string StartStopButton = "StartStopButton";
string StatusLabel     = "StatusLabel";
string LogLabel        = "LogLabel";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   InitializeUI();
   Log("AUTOTRADEBOT with Risk Management initialized.");
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectDelete(StartStopButton);
   ObjectDelete(StatusLabel);
   ObjectDelete(LogLabel);
   Log("AUTOTRADEBOT deinitialized.");
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if (!isBotRunning) return;

   // Calculate EMAs
   fastMA     = iMA(NULL, 0, FastMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
   slowMA     = iMA(NULL, 0, SlowMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
   prevFastMA = iMA(NULL, 0, FastMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
   prevSlowMA = iMA(NULL, 0, SlowMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);

   // Check for crossover signals
   if (prevFastMA < prevSlowMA && fastMA > slowMA) // Bullish crossover
   {
      Log("Bullish crossover detected. Placing BUY order.");
      PlaceTrade(OP_BUY);
   }
   else if (prevFastMA > prevSlowMA && fastMA < slowMA) // Bearish crossover
   {
      Log("Bearish crossover detected. Placing SELL order.");
      PlaceTrade(OP_SELL);
   }

   // Manage any open trades
   ManageOpenTrade();
}
//+------------------------------------------------------------------+
//| Trade placement function                                         |
//+------------------------------------------------------------------+
void PlaceTrade(int orderType)
{
   double accountBalance = AccountBalance();
   double riskAmount = (RiskPercent / 100.0) * accountBalance;

   double price, slPrice, tpPrice;
   double entryCandleHigh = High[1];  // High of the previous candle
   double entryCandleLow = Low[1];   // Low of the previous candle
   double lotSize;

   // Calculate SL and TP based on the high/low of the entry candle and a buffer
   if (orderType == OP_BUY)
   {
      price = Ask;
      StopLossLevel = entryCandleLow - (StopLossPipsBuffer * Point);
      TakeProfitLevel = price + RewardToRiskRatio * (price - StopLossLevel);
   }
   else if (orderType == OP_SELL)
   {
      price = Bid;
      StopLossLevel = entryCandleHigh + (StopLossPipsBuffer * Point);
      TakeProfitLevel = price - RewardToRiskRatio * (StopLossLevel - price);
   }

   // Calculate lot size based on risk amount
   lotSize = riskAmount / MathAbs(price - StopLossLevel);

   // Normalize values
   StopLossLevel = NormalizeDouble(StopLossLevel, Digits);
   TakeProfitLevel = NormalizeDouble(TakeProfitLevel, Digits);
   lotSize = NormalizeDouble(lotSize, 2);

   // Place the order
   TradeTicket = OrderSend(Symbol(), orderType, lotSize, price, Slippage, StopLossLevel, TakeProfitLevel, "EMA Crossover Trade", MagicNumber, 0, clrBlue);

   if (TradeTicket > 0)
   {
      TradeOpenTime = TimeCurrent(); // Record the trade open time
      StopMovedToBreakEven = false;
      Log("Trade placed successfully. Ticket: " + IntegerToString(TradeTicket));
   }
   else
   {
      Log("Error placing trade. Error: " + IntegerToString(GetLastError()));
   }
}
//+------------------------------------------------------------------+
//| Manage open trade                                                |
//+------------------------------------------------------------------+
void ManageOpenTrade()
{
   for (int i = 0; i < OrdersTotal(); i++)
   {
      if (OrderSelect(i, SELECT_BY_POS) && OrderMagicNumber() == MagicNumber)
      {
         double profit = OrderProfit();
         datetime openTime = OrderOpenTime();
         // Check if the trade has exceeded the maximum duration
         if ((TimeCurrent() - openTime) >= (MaxTradeDuration * 3600))
         {
            if (profit < 0)
            {
               Log("Trade negative beyond max duration. Closing trade.");
               CloseTrade(OrderTicket());
            }
            else if (!StopMovedToBreakEven)
            {
               Log("Moving SL to break even.");
               MoveStopToBreakEven(OrderTicket());
               StopMovedToBreakEven = true;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Close trade                                                      |
//+------------------------------------------------------------------+
void CloseTrade(int ticket)
{
   if (OrderSelect(ticket, SELECT_BY_TICKET))
   {
      double closePrice = (OrderType() == OP_BUY) ? Bid : Ask;
      if (OrderClose(ticket, OrderLots(), closePrice, Slippage, clrRed))
         Log("Trade closed successfully. Ticket: " + IntegerToString(ticket));
      else
         Log("Error closing trade. Error: " + IntegerToString(GetLastError()));
   }
}
//+------------------------------------------------------------------+
//| Move stop loss to break even                                     |
//+------------------------------------------------------------------+
void MoveStopToBreakEven(int ticket)
{
   if (OrderSelect(ticket, SELECT_BY_TICKET))
   {
      double newSL = OrderOpenPrice();
      if (OrderModify(ticket, OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrBlue))
         Log("Stop loss moved to break even.");
      else
         Log("Error modifying stop loss. Error: " + IntegerToString(GetLastError()));
   }
}
//+------------------------------------------------------------------+
//| UI Initialization                                                |
//+------------------------------------------------------------------+
void InitializeUI()
{
   ObjectCreate(StartStopButton, OBJ_BUTTON, 0, 0, 0);
   ObjectSet(StartStopButton, OBJPROP_CORNER, 0);
   ObjectSet(StartStopButton, OBJPROP_XDISTANCE, 10);
   ObjectSet(StartStopButton, OBJPROP_YDISTANCE, 10);
   ObjectSetText(StartStopButton, "Start Bot", 10, "Arial", clrBlack);

   ObjectCreate(StatusLabel, OBJ_LABEL, 0, 0, 0);
   ObjectSet(StatusLabel, OBJPROP_CORNER, 0);
   ObjectSet(StatusLabel, OBJPROP_XDISTANCE, 10);
   ObjectSet(StatusLabel, OBJPROP_YDISTANCE, 40);
   ObjectSetText(StatusLabel, "Bot Status: Stopped", 10, "Arial", clrWhite);

   ObjectCreate(LogLabel, OBJ_LABEL, 0, 0, 0);
   ObjectSet(LogLabel, OBJPROP_CORNER, 0);
   ObjectSet(LogLabel, OBJPROP_XDISTANCE, 10);
   ObjectSet(LogLabel, OBJPROP_YDISTANCE, 70);
   ObjectSetText(LogLabel, "Logs:\n", 10, "Arial", clrWhite);
}
//+------------------------------------------------------------------+
//| Logging                                                          |
//+------------------------------------------------------------------+
void Log(string message)
{
   if (LogEnabled)
   {
      Print(message);
      string currentLog = ObjectDescription(LogLabel);
      ObjectSetText(LogLabel, currentLog + "\n" + message, 10, "Arial", clrWhite);
   }
}
//+------------------------------------------------------------------+
