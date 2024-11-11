// 13/50 EMA Crossover with Pullback EA
// This EA trades based on a 13/50 EMA crossover, a 25-50 pip pullback to the 50 EMA, 
// and a confirmation candle close above/below the 13 EMA.

// Input parameters
input int FastMAPeriod = 13;       // Fast EMA (13 period)
input int SlowMAPeriod = 50;       // Slow EMA (50 period)
input double LotSize = 0.1;        // Lot size for each trade
input double StopLoss = 50;        // Stop loss in points
input double TakeProfit = 100;     // Take profit in points
input double PullbackMin = 25;     // Minimum pullback in pips
input double PullbackMax = 50;     // Maximum pullback in pips

// Global variables
double FastMA, SlowMA;
bool BuySignal = false;
bool SellSignal = false;

// Function to calculate EMA values
double GetEMA(int period, int shift) {
    return iMA(NULL, 0, period, 0, MODE_EMA, PRICE_CLOSE, shift);
}

// Initialization
int OnInit() {
    return(INIT_SUCCEEDED);
}

// Deinitialization
void OnDeinit(const int reason) {
    // No specific deinitialization needed
}

// Main function
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
    bool ValidPullback = (priceDistance >= PullbackMin && priceDistance <= PullbackMax);

    // Check for signal conditions after a crossover and a valid pullback
    if (BullishCross && ValidPullback && Close[1] < FastMA && Close[0] > FastMA) {
        // Bullish trade condition met
        if (OrderSelect(0, SELECT_BY_POS) == false || OrderType() != OP_BUY) {
            // Close any existing sell order before opening a new buy order
            CloseAll(OP_SELL);
            OpenTrade(OP_BUY);
        }
    } 
    else if (BearishCross && ValidPullback && Close[1] > FastMA && Close[0] < FastMA) {
        // Bearish trade condition met
        if (OrderSelect(0, SELECT_BY_POS) == false || OrderType() != OP_SELL) {
            // Close any existing buy order before opening a new sell order
            CloseAll(OP_BUY);
            OpenTrade(OP_SELL);
        }
    }
}

// Function to open a trade with specified parameters
void OpenTrade(int tradeType) {
    double price = (tradeType == OP_BUY) ? Ask : Bid;
    double sl = (tradeType == OP_BUY) ? price - StopLoss * Point : price + StopLoss * Point;
    double tp = (tradeType == OP_BUY) ? price + TakeProfit * Point : price - TakeProfit * Point;
    int ticket = OrderSend(Symbol(), tradeType, LotSize, price, 3, sl, tp, "", 0, 0, Blue);

    if (ticket < 0) {
        Print("Error opening order: ", ErrorDescription(GetLastError()));
    } else {
        Print("Order opened successfully with ticket #", ticket);
    }
}

// Function to close all trades of a specific type
void CloseAll(int orderType) {
    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        if (OrderSelect(i, SELECT_BY_POS) && OrderType() == orderType && OrderSymbol() == Symbol()) {
            OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), 3, Violet);
        }
    }
}
