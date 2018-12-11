#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>

bool g_bRun[MAXPLAYERS + 1] = { false, ... };
float g_fAngle[MAXPLAYERS + 1][3];

public void OnPluginStart()
{
    RegConsoleCmd("sm_checkGOTV", Command_CheckGOTV);
    RegConsoleCmd("sm_reloadmap", Command_Reloadmap);
    RegConsoleCmd("sm_hud", Command_HUD);
    RegConsoleCmd("sm_endround", Command_EndRound);
    RegConsoleCmd("sm_give", Command_Give);
    RegConsoleCmd("sm_givee", Command_GiveE);
    RegConsoleCmd("sm_roundtime", Command_RoundTime);
    RegConsoleCmd("sm_stone", Command_Stone);
    RegConsoleCmd("sm_ghost", Command_Ghost);
    RegConsoleCmd("sm_classname", Command_Classname);
}

public Action Command_CheckGOTV(int client, int args)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        ReplyToCommand(client, "i: %d, Name: %N, IsFakeClient: %d, IsClientSourceTV: %d, IsClientInGame: %d, IsPlayerAlive: %d", i, i, IsFakeClient(i), IsClientSourceTV(i), IsClientInGame(i), IsPlayerAlive(i));
    }
}


public Action Command_Reloadmap(int client, int args)
{
    char sMap[32];
    GetCurrentMap(sMap, sizeof(sMap));
    ForceChangeLevel(sMap, "Reloading map...");
}

public Action Command_HUD(int client, int args)
{
    if (args < 8)
    {
        ReplyToCommand(client, "sm_hud <X> <Y> <Red> <Green> <Blue> <Alpha> <#UserID|Name> <message>");
        return Plugin_Handled;
    }
    
    int targets[129];
    bool ml = false;
    char sY[12];
    char sX[12];
    char sRed[6];
    char sGreen[6];
    char sBlue[6];
    char sAlpha[6];
    char buffer[MAX_NAME_LENGTH], sTarget[MAX_NAME_LENGTH];

    GetCmdArg(1, sX, sizeof(sX));
    GetCmdArg(2, sY, sizeof(sY));
    GetCmdArg(3, sRed, sizeof(sRed));
    GetCmdArg(4, sGreen, sizeof(sGreen));
    GetCmdArg(5, sBlue, sizeof(sBlue));
    GetCmdArg(6, sAlpha, sizeof(sAlpha));
    GetCmdArg(7, sTarget, sizeof(sTarget));

    int iRed = StringToInt(sRed);
    int iGreen = StringToInt(sGreen);
    int iBlue = StringToInt(sBlue);
    int iAlpha = StringToInt(sAlpha);
    
    int count = ProcessTargetString(sTarget, client, targets, sizeof(targets), COMMAND_FILTER_CONNECTED, buffer, sizeof(buffer), ml);
    if (count <= 0)
    {
        ReplyToCommand(client, "Invalid Target");
    }
    else for (int i = 0; i < count; i++)
    {
        int target = targets[i];
        
        if(target < 1 || !IsClientInGame(target))
            continue;

        char sText[256];

        if (args >= 8)
        {
            for (int j = 8; j <= args; j++)
            {
                char sBuffer[64];
                GetCmdArg(j, sBuffer, sizeof(sBuffer));
                Format(sText, sizeof(sText), "%s %s", sText, sBuffer);
            }
        }

        SetHudTextParams(StringToFloat(sX), StringToFloat(sY), 7.0, iRed, iGreen, iBlue, iAlpha, 1, 2.0, 1.0, 1.0);
        ShowHudText(target, -1, sText);
    }
    
    return Plugin_Continue;
}

public Action Command_EndRound(int client, int args)
{
    if (args != 2)
    {
        ReplyToCommand(client, "sm_endround <delay in seconds>, <hook 0 - yes, 1 - no>");
        return Plugin_Handled;
    }

    char sArg[12], sArg2[12];
    GetCmdArg(1, sArg, sizeof(sArg));
    GetCmdArg(2, sArg2, sizeof(sArg2));

    CS_TerminateRound(StringToFloat(sArg), CSRoundEnd_Draw, view_as<bool>(StringToInt(sArg2)));

    return Plugin_Handled;
}

public Action Command_Give(int client, int args)
{
    if (args != 1)
    {
        ReplyToCommand(client, "sm_give <weapon>");
        return Plugin_Handled;
    }

    char sArg[32];
    GetCmdArg(1, sArg, sizeof(sArg));
    Format(sArg, sizeof(sArg), "weapon_%s", sArg);
    int iWeapon = GivePlayerItem(client, sArg);
    EquipPlayerWeapon(client, iWeapon);

    return Plugin_Handled;
}

public Action Command_GiveE(int client, int args)
{
    if (args != 1)
    {
        ReplyToCommand(client, "sm_givee <weapon>");
        return Plugin_Handled;
    }

    char sArg[32];
    GetCmdArg(1, sArg, sizeof(sArg));
    Format(sArg, sizeof(sArg), "weapon_%s", sArg);
    GivePlayerItem(client, sArg);

    return Plugin_Handled;
}

public Action Command_RoundTime(int client, int args)
{
    int time = GameRules_GetProp("m_iRoundTime");
    ReplyToCommand(client, "Round Time: %d", time);
}


public Action Command_Stone(int client, int args)
{
    if (args != 1)
    {
        ReplyToCommand(client, "sm_stone <status 0/1>");
        return Plugin_Handled;
    }

    char sBuffer[3];
    GetCmdArg(1, sBuffer, sizeof(sBuffer));
    bool status = view_as<bool>(StringToInt(sBuffer));

    GetClientEyeAngles(client, g_fAngle[client]);

    g_bRun[client] = status;

    if (g_bRun[client])
    {
        RequestFrame(Frame_SetAngle, GetClientUserId(client));
    }

    return Plugin_Handled;
}

public void Frame_SetAngle(int userid)
{
    int client = GetClientOfUserId(userid);

    if (IsClientInGame(client))
    {
        TeleportEntity(client, NULL_VECTOR, g_fAngle[client], NULL_VECTOR);

        if (g_bRun[client])
        {
            RequestFrame(Frame_SetAngle, GetClientUserId(client));
        }
    }
}

public Action Command_Ghost(int client, int args)
{
    PrintToChat(client, "Ghost: %d", GetEntProp(client, Prop_Send, "m_bIsPlayerGhost"));
    SetEntProp(client, Prop_Send, "m_bIsPlayerGhost", !GetEntProp(client, Prop_Send, "m_bIsPlayerGhost"));
    PrintToChat(client, "Ghost: %d", GetEntProp(client, Prop_Send, "m_bIsPlayerGhost"));
}

public Action Command_Classname(int client, int args)
{
    int iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

    if (IsValidEntity(iWeapon))
    {
        char sClass[32];
        GetEntityClassname(iWeapon, sClass, sizeof(sClass));
        PrintToChat(client, "Index: %d, Class: %s", iWeapon, sClass);
    }
}
