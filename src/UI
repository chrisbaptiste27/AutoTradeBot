//+------------------------------------------------------------------+
//| Initialize UI elements                                           |
//+------------------------------------------------------------------+
void InitializeUI()
{
   // Create Start/Stop Button
   ObjectCreate("StartStopButton", OBJ_BUTTON, 0, 0, 0);
   ObjectSet("StartStopButton", OBJPROP_CORNER, 0);
   ObjectSet("StartStopButton", OBJPROP_XDISTANCE, 10);
   ObjectSet("StartStopButton", OBJPROP_YDISTANCE, 10);
   ObjectSetText("StartStopButton", "Start Bot", 10, "Arial", clrBlack);

   // Create Status Label
   ObjectCreate("StatusLabel", OBJ_LABEL, 0, 0, 0);
   ObjectSet("StatusLabel", OBJPROP_CORNER, 0);
   ObjectSet("StatusLabel", OBJPROP_XDISTANCE, 10);
   ObjectSet("StatusLabel", OBJPROP_YDISTANCE, 40);
   ObjectSetText("StatusLabel", "Bot Status: Stopped", 10, "Arial", clrWhite);
}

//+------------------------------------------------------------------+
//| Chart event function                                             |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if (id == CHARTEVENT_OBJECT_CLICK && sparam == "StartStopButton")
   {
      isBotRunning = !isBotRunning;
      ObjectSetText("StartStopButton", isBotRunning ? "Stop Bot" : "Start Bot", 10, "Arial", clrBlack);
      ObjectSetText("StatusLabel", "Bot Status: " + (isBotRunning ? "Running" : "Stopped"), 10, "Arial", clrWhite);

      Print("Bot " + (isBotRunning ? "started" : "stopped") + ".");
   }
}

