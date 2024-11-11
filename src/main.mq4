// Main MQL4 file for the trading bot.
// 13/50 EMA Crossover with Risk Management EA
// This EA trades based on a 13/50 EMA crossover, with risk management implemented

//--- Input parameters for crossover strategy
input int FastMAPeriod = 13;       // Fast EMA (13 period)
input int SlowMAPeriod = 50;       // Slow EMA (50 period)

//--- Risk management parameters
input double RiskPercent = 1.0;       // Risk 1% of account balance
input int RewardToRiskRatio = 2;      // TP is 2 times SL
input int MaxTradeDurationHours = 2;  // Maximum duration in hours before closing the trade if negative
input double Lots = 0.1;              // Fixed lot size (used if risk-based lot calculation fails)
input int Slippage = 3;               // Slippage in points
input int StopLossPipsBuffer = 5;     // 5 pips buffer for SL above/below entry candle

//--- Global variables
double StopLossLevel, TakeProfitLevel;
datetime TradeOpenTime;
int TradeTicket;
bool StopMovedToBreakEven = false;
double FastMA, SlowMA;

//--- Function to calculate EMA values
double GetEMA(int period, int shift) {
    return iMA(NULL, 0, period, 0, MODE_EMA, PRICE_CLOSE, shift);
}

//--- Initialization function
int OnInit() {
    Print("13/50 EMA Crossover with Risk Management EA initialized.");
    return(INIT_SUCCEEDED);
}

//--- Main function
void OnTick() {
    // Calculate the current and previous values of the 13 EMA and 50 EMA
    FastMA = GetEMA(FastMAPeriod, 0);       // Current 13 EMA
    double PreviousFastMA = GetEMA(FastMAPeriod, 1); // Previous 13 EMA
    SlowMA = GetEMA(SlowMAPeriod, 0);       // Current 50 EMA
    double PreviousSlowMA = GetEMA(SlowMAPeriod, 1); // Previous 50 EMA

    // Check for EMA crossover
    bool BullishCross = (PreviousFastMA < PreviousSlowMA && FastMA > SlowMA);
    bool BearishCross = (PreviousFastMA > PreviousSlowMA && FastMA < SlowMA);

    // Check for pullback criteria (price within 25-50 pips of 50 EMA)
    double priceDistance = MathAbs(Close[0] - SlowMA) / Point;
    bool ValidPullback = (priceDistance >= 25 && priceDistance <= 50);

    // Check if there's an open position
    if (OrdersTotal() > 0) {
        ManageOpenTrade();
    } else {
        // Open a new trade if conditions are met
        if (BullishCross && ValidPullback && Close[1] < FastMA && Close[0] > FastMA) {
            PlaceTrade(OP_BUY);
        } 
        else if (BearishCross && ValidPullback && Close[1] > FastMA && Close[0] < FastMA) {
            PlaceTrade(OP_SELL);
        }
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
        TakeProfitLevel = price + RewardToRiskRatio * (price - StopLossLevel); // TP at reward-to-risk ratio
    } else if (orderType == OP_SELL) {
        price = Bid;
        StopLossLevel = entryCandleHigh + (StopLossPipsBuffer * Point); // 5 pips above the high of the entry candle
        TakeProfitLevel = price - RewardToRiskRatio * (StopLossLevel - price); // TP at reward-to-risk ratio
    }

    // Calculate position size based on risk
    double lotSize = Lots; // Default lot size
    if (StopLossLevel > 0 && riskAmount > 0) {
        double pipRisk = MathAbs(price - StopLossLevel) / Point;
        lotSize = riskAmount / (pipRisk * MarketInfo(Symbol(), MODE_TICKVALUE));
        lotSize = MathMax(lotSize, MarketInfo(Symbol(), MODE_MINLOT)); // Ensure minimum lot size
    }

    // Place the order
    TradeTicket = OrderSend(Symbol(), orderType, lotSize, price, Slippage, StopLossLevel, TakeProfitLevel, "Risk Managed Trade", 0, 0, clrGreen);

    if (TradeTicket > 0) {
        TradeOpenTime = TimeCurrent(); // Record the trade open time
        StopMovedToBreakEven = false;  // Reset break-even flag
        Print("Trade placed successfully. Ticket #: ", TradeTicket);
    } else {
        Print("Error placing trade. Error: ", GetLastError());
    }
}

//--- Function to manage the open trade
void ManageOpenTrade() {
    for (int i = 0; i < OrdersTotal(); i++) {
        if (OrderSelect(i, SELECT_BY_POS) && OrderMagicNumber() == 0 && OrderSymbol() == Symbol()) {
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
        double closePrice = (OrderType() == OP_BUY) ? Bid : Ask;
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
