#pragma semicolon 1

#include <ttt>

public void TTT_OnRoundEnd(int winner, Handle array)
{
    PrintToChatAll("[Log Test] Winner: %d", winner);

    ArrayList aLogs = view_as<ArrayList>(array);

    for (int i = 0; i < aLogs.Length; i++)
    {
        char sBuffer[512];
        aLogs.GetString(i, sBuffer, sizeof(sBuffer));
        Format(sBuffer, sizeof(sBuffer), "[Log Test] %s", sBuffer);
        PrintToChatAll(sBuffer);
    }
}
