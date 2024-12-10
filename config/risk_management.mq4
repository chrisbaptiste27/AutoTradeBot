//--- Input parameters
input double RiskPercent = 1.0;      // Risk 1% of account balance
input int RewardToRiskRatio = 2;     // TP is 2 times SL
input int MaxTradeDurationHours = 2; // Maximum duration in hours before closing the trade if negative
input double Lots = 0.1;             // Fixed lot size
input int Slippage = 3;              // Slippage in points
input int StopLossPipsBuffer = 5;    // 5 pips buffer for SL above/below entry candle

//--- Global variables
double StopLossLevel, TakeProfitLevel;
datetime TradeOpenTime;
int TradeTicket;
bool StopMovedToBreakEven = false;

//--- Initialization function (runs once when the EA is launched)
int OnInit() {
   Print("Stop Loss Risk Management System with 5 pips buffer initialized.");
   return(INIT_SUCCEEDED);
}

//--- Main function (called on every new tick)
void OnTick() {
   // Check if there's an open position
   if (PositionsTotal() > 0) {
      // Monitor the trade and adjust SL/TP as per the logic
      ManageOpenTrade();
   } else {
      // Example: Logic to open a new trade (this could be based on a different condition)
      // Let's assume a buy order for demonstration
      PlaceTrade(OP_BUY);
   }
}

//--- Function to place a trade with 1% risk management and 5 pips buffer on SL
void PlaceTrade(int orderType) {
   double accountBalance = AccountBalance();
   double riskAmount = (RiskPercent / 100.0) * accountBalance;
   
   double price, slPrice, tpPrice;
   double entryCandleHigh = High[1];  // High of the entry candle (previous candle)
   double entryCandleLow = Low[1];    // Low of the entry candle (previous candle)
   
   // Calculate SL and TP based on the high/low of the entry candle and a 5-pip buffer
   if (orderType == OP_BUY) {
      price = Ask;
      StopLossLevel = entryCandleLow - (StopLossPipsBuffer * Point); // 5 pips below the low of the entry candle
      TakeProfitLevel = price + 2 * (price - StopLossLevel); // TP at 2:1 ratio
   } else if (orderType == OP_SELL) {
      price = Bid;
      StopLossLevel = entryCandleHigh + (StopLossPipsBuffer * Point); // 5 pips above the high of the entry candle
      TakeProfitLevel = price - 2 * (StopLossLevel - price); // TP at 2:1 ratio
   }
   
   // Place the order
   TradeTicket = OrderSend(Symbol(), orderType, Lots, price, Slippage, StopLossLevel, TakeProfitLevel, "Risk Managed Trade", 0, 0, clrGreen);
   
   if (TradeTicket > 0) {
      TradeOpenTime = TimeCurrent(); // Record the trade open time
      Print("Trade placed successfully. Ticket #: ", TradeTicket);
   } else {
      Print("Error placing trade. Error: ", GetLastError());
   }
}

//--- Function to manage the open trade
void ManageOpenTrade() {
   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS) && OrderType() <= OP_SELL && OrderMagicNumber() == 0) {
         double currentPrice = (OrderType() == OP_BUY) ? Bid : Ask;
         double profit = OrderProfit();
         
         // Check if the trade has been open for more than the defined maximum duration
         if ((TimeCurrent() - OrderOpenTime) >= (MaxTradeDurationHours * 3600)) {
            if (profit < 0) {
               // Close the trade if it's negative after 2 hours
               CloseTrade(OrderTicket());
            } else if (profit > 0 && !StopMovedToBreakEven) {
               // Move stop loss to break even if trade is positive after 2 hours
               MoveStopToBreakEven(OrderTicket(), OrderType());
               StopMovedToBreakEven = true;
            }
         }
      }
   }
}

//--- Function to close a trade
void CloseTrade(int ticket) {
   if (OrderSelect(ticket, SELECT_BY_TICKET)) {
      int closeType = OrderType();
      double closePrice = (closeType == OP_BUY) ? Bid : Ask;
      bool result = OrderClose(ticket, OrderLots(), closePrice, Slippage, clrRed);
      
      if (result) {
         Print("Trade closed successfully. Ticket #: ", ticket);
      } else {
         Print("Error closing trade. Error: ", GetLastError());
      }
   }
}

//--- Function to move SL to break even
void MoveStopToBreakEven(int ticket, int orderType) {
   if (OrderSelect(ticket, SELECT_BY_TICKET)) {
      double newSL = OrderOpenPrice();
      bool result = OrderModify(ticket, OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrBlue);
      
      if (result) {
         Print("Stop loss moved to break even.");
      } else {
         Print("Error modifying stop loss. Error: ", GetLastError());
      }
   }
}
