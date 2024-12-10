//--- File names for logging and journaling
string logFileName = "TradingBot_Log.csv";
string journalFileName = "TradingJournal.csv";

//--- Helper function to write to a file
void WriteToFile(string fileName, string content) {
    int fileHandle = FileOpen(fileName, FILE_CSV | FILE_WRITE | FILE_READ, ";");
    if (fileHandle < 0) {
        Print("Error opening file: ", fileName);
        return;
    }
    FileSeek(fileHandle, 0, SEEK_END);
    FileWrite(fileHandle, content);
    FileClose(fileHandle);
}

//--- Initialize log and journal files
void InitializeLogging() {
    WriteToFile(logFileName, "Timestamp;Event");
    WriteToFile(journalFileName, "Timestamp;Symbol;OrderType;Lots;EntryPrice;ExitPrice;Profit;TradeDuration");
}

//--- Function to log bot activity
void LogEvent(string eventMessage) {
    string logEntry = TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES) + ";" + eventMessage;
    WriteToFile(logFileName, logEntry);
}

//--- Function to log trade details
void LogTrade(string symbol, int orderType, double lots, double entryPrice, double exitPrice, double profit, double duration) {
    string tradeEntry = TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES) + ";" +
                        symbol + ";" +
                        (orderType == OP_BUY ? "BUY" : "SELL") + ";" +
                        DoubleToString(lots, 2) + ";" +
                        DoubleToString(entryPrice, 5) + ";" +
                        DoubleToString(exitPrice, 5) + ";" +
                        DoubleToString(profit, 2) + ";" +
                        DoubleToString(duration, 2);
    WriteToFile(journalFileName, tradeEntry);
}

//--- Input parameters for crossover strategy
input int FastMAPeriod = 13;       // Fast EMA (13 period)
input int SlowMAPeriod = 50;       // Slow EMA (50 period)
input double RiskPercent = 1.0;   // Risk 1% of account balance
input int RewardToRiskRatio = 2;  // TP is 2 times SL
input int MaxTradeDurationHours = 2; // Max duration in hours before closing the trade if negative
input double Lots = 0.1;          // Fixed lot size
input int Slippage = 3;           // Slippage in points
input int StopLossPipsBuffer = 5; // 5 pips buffer for SL above/below entry candle

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
    Print("Initializing trading bot...");
    InitializeLogging();
    LogEvent("Bot initialized successfully");
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
            LogEvent("Bullish EMA crossover detected");
            PlaceTrade(OP_BUY);
        } else if (BearishCross && ValidPullback && Close[1] > FastMA && Close[0] < FastMA) {
            LogEvent("Bearish EMA crossover detected");
            PlaceTrade(OP_SELL);
        }
    }
}

//--- Function to place a trade
void PlaceTrade(int orderType) {
    double entryPrice = (orderType == OP_BUY) ? Ask : Bid;
    double stopLoss = (orderType == OP_BUY) ? entryPrice - (StopLossPipsBuffer * Point) : entryPrice + (StopLossPipsBuffer * Point);
    double takeProfit = (orderType == OP_BUY) ? entryPrice + RewardToRiskRatio * (entryPrice - stopLoss) : entryPrice - RewardToRiskRatio * (stopLoss - entryPrice);
    double lots = Lots;

    // Execute trade
    TradeTicket = OrderSend(Symbol(), orderType, lots, entryPrice, Slippage, stopLoss, takeProfit, "Trade with Risk Management", 0, 0, clrGreen);
    if (TradeTicket > 0) {
        LogEvent("Trade placed successfully. Ticket #: " + IntegerToString(TradeTicket));
        TradeOpenTime = TimeCurrent();
        StopMovedToBreakEven = false;
    } else {
        LogEvent("Error placing trade. Error code: " + IntegerToString(GetLastError()));
    }
}

//--- Function to manage open trades
void ManageOpenTrade() {
    for (int i = 0; i < OrdersTotal(); i++) {
        if (OrderSelect(i, SELECT_BY_POS) && OrderSymbol() == Symbol()) {
            double profit = OrderProfit();
            double duration = (TimeCurrent() - OrderOpenTime) / 3600.0;

            if (profit > 0 && !StopMovedToBreakEven) {
                LogEvent("Moving stop loss to break even");
                MoveStopToBreakEven(OrderTicket(), OrderType());
                StopMovedToBreakEven = true;
            }

            if (duration >= MaxTradeDurationHours) {
                LogEvent("Trade duration exceeded maximum allowed time");
                CloseTrade(OrderTicket());
            }
        }
    }
}

//--- Function to close a trade
void CloseTrade(int ticket) {
    if (OrderSelect(ticket, SELECT_BY_TICKET)) {
        double closePrice = (OrderType() == OP_BUY) ? Bid : Ask;
        double profit = OrderProfit();
        double duration = (TimeCurrent() - OrderOpenTime) / 3600.0;
        bool result = OrderClose(ticket, OrderLots(), closePrice, Slippage, clrRed);

        if (result) {
            LogEvent("Trade closed successfully. Ticket #: " + IntegerToString(ticket));
            LogTrade(Symbol(), OrderType(), OrderLots(), OrderOpenPrice(), closePrice, profit, duration);
        } else {
            LogEvent("Error closing trade. Error code: " + IntegerToString(GetLastError()));
        }
    }
}

//--- Function to move stop loss to break even
void MoveStopToBreakEven(int ticket, int orderType) {
    if (OrderSelect(ticket, SELECT_BY_TICKET)) {
        double newStopLoss = OrderOpenPrice();
        bool result = OrderModify(ticket, OrderOpenPrice(), newStopLoss, OrderTakeProfit(), 0, clrBlue);

        if (result) {
            LogEvent("Stop loss moved to break even successfully");
        } else {
            LogEvent("Error moving stop loss. Error code: " + IntegerToString(GetLastError()));
        }
    }
}

