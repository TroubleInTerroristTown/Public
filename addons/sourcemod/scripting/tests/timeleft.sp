#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <ttt>

int g_iRoundStart = -1;

public void OnPluginStart()
{
    HookEvent("round_prestart", Event_RoundStartPre, EventHookMode_Pre);

    RegConsoleCmd("sm_timeleft", Command_Timeleft);
}

public Action Event_RoundStartPre(Event event, const char[] name, bool dontBroadcast)
{
    g_iRoundStart = GetTime();
}

public Action Command_Timeleft(int client, int args)
{
    ConVar g_cRoundTime = FindConVar("mp_roundtime");
    int iElapsed = (GetTime() - g_iRoundStart) - 1;
    int iLeft = ((g_cRoundTime.IntValue * 60) - iElapsed);

    ReplyToCommand(client, "Time Elapsed: %d, Time Left: %d (TTT stock: %d)", iElapsed, iLeft, TTT_GetRoundTimeLeft());
}
