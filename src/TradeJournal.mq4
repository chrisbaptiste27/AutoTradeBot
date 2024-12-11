//--- File names
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
    // Initialize log file
    WriteToFile(logFileName, "Timestamp;Event");
    // Initialize trade journal file
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

//--- Example usage: Logging bot events
void LogBotEventsExample() {
    LogEvent("Bot initialized");
    LogEvent("EMA crossover detected");
    LogEvent("Trade executed successfully");
}

//--- Example usage: Logging trade details
void LogTradeExample() {
    string symbol = Symbol();
    int orderType = OP_BUY;
    double lots = 0.1;
    double entryPrice = 1.23456;
    double exitPrice = 1.23556;
    double profit = 10.0;
    double duration = 2.5; // Duration in hours
    LogTrade(symbol, orderType, lots, entryPrice, exitPrice, profit, duration);
}

//--- Call this function in OnInit to initialize logging
int OnInit() {
    Print("Initializing trading bot...");
    InitializeLogging();
    LogEvent("Bot initialized successfully");
    return(INIT_SUCCEEDED);
}

//--- Example trade execution with logging
void PlaceTradeWithLogging(int orderType) {
    // Example trade execution logic (simplified for demo purposes)
    double entryPrice = (orderType == OP_BUY) ? Ask : Bid;
    double exitPrice = entryPrice + (orderType == OP_BUY ? 0.001 : -0.001); // Simulated exit price
    double profit = 50; // Simulated profit
    double duration = 1.2; // Simulated trade duration in hours

    // Log trade details
    LogTrade(Symbol(), orderType, Lots, entryPrice, exitPrice, profit, duration);
    LogEvent("Trade executed: " + (orderType == OP_BUY ? "BUY" : "SELL"));
}
