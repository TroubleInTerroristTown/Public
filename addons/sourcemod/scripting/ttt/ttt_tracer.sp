#pragma semicolon 1
#include <sourcemod>
#include <ttt>
#include <ttt_shop>
#include <ttt_inventory>
#pragma newdecls required

/* Spec Modes */

#define SPECMODE_NONE                     0
#define SPECMODE_FIRSTPERSON             4
#define SPECMODE_3RDPERSON                 5
#define SPECMODE_FREELOOK                 6


#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Tracer"

#define SHORT_NAME_TRACER "Tracer_t"
#define SHORT_NAME_JAMMER "Jammer_d"

ConVar g_cTracerPrice = null;
ConVar g_cTracerLimit = null;
ConVar g_cTracerPrio = null;
ConVar g_cTracerLongName = null;
ConVar g_cTracerCount = null;
ConVar g_cCompassShowNameDistance = null;
ConVar g_cCompassDisorientationDistance = null;

ConVar g_cJammerPrice = null;
ConVar g_cJammerLimit = null;
ConVar g_cJammerPrio = null;
ConVar g_cJammerLongName = null;
ConVar g_cJammerCount = null;

Handle g_hHUD = null;

public Plugin myinfo =
{
    name = PLUGIN_NAME,
    author = "bbs.93x.net & zipcore",
    description = TTT_PLUGIN_DESCRIPTION,
    version = TTT_PLUGIN_VERSION,
    url = TTT_PLUGIN_URL
};

public void OnPluginStart()
{
    TTT_LoadTranslations();
    
    TTT_StartConfig("tracer");
    CreateConVar("ttt2_tracer_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cCompassShowNameDistance = AutoExecConfig_CreateConVar("tracer_compass_show_name_distance", "1024.0", "Max distance to show name / Distance in compass HUD.");
    g_cCompassDisorientationDistance = AutoExecConfig_CreateConVar("tracer_compass_disorientation_distance", "1024.0", "If nearest player is closer than this use 4 instead of 8 directions in compass HUD.");
    g_cJammerLongName = AutoExecConfig_CreateConVar("jammer_name", "Jammer", "The name of this in Shop");
    g_cJammerPrice = AutoExecConfig_CreateConVar("jammer_price", "9000", "The amount of credits jammer costs as detective. 0 to disable.");
    g_cJammerLimit = AutoExecConfig_CreateConVar("jammer_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cJammerPrio = AutoExecConfig_CreateConVar("jammer_sort_prio", "0", "The sorting priority of the jammer in the shop menu.");
    g_cJammerCount = AutoExecConfig_CreateConVar("jammer_count", "1", "Amount of purchases for Jammer as detective");
    g_cTracerLongName = AutoExecConfig_CreateConVar("tracer_name", "Tracer", "The name of this in Shop");
    g_cTracerPrice = AutoExecConfig_CreateConVar("tracer_price", "9000", "The amount of credits tracer costs as traitor. 0 to disable.");
    g_cTracerLimit = AutoExecConfig_CreateConVar("tracer_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cTracerPrio = AutoExecConfig_CreateConVar("tracer_sort_prio", "0", "The sorting priority of the tracer in the shop menu.");
    g_cTracerCount = AutoExecConfig_CreateConVar("tracer_count", "1", "Amount of purchases for Tracer as traitor");
    TTT_EndConfig();

    g_hHUD = CreateHudSynchronizer();
    
    CreateTimer(1.0, Tracer_Display, _, TIMER_REPEAT);
}

public void OnPluginEnd()
{
    if (TTT_IsShopRunning())
    {
        TTT_RemoveShopItem(SHORT_NAME_TRACER);
        TTT_RemoveShopItem(SHORT_NAME_JAMMER);
    }
}

public void OnConfigsExecuted()
{
    RegisterItem();
}

public void TTT_OnShopReady()
{
    RegisterItem();
}

void RegisterItem()
{
    char sName[MAX_ITEM_LENGTH];

    g_cTracerLongName.GetString(sName, sizeof(sName));
    TTT_RegisterShopItem(SHORT_NAME_TRACER, sName, g_cTracerPrice.IntValue, TTT_TEAM_TRAITOR, g_cTracerPrio.IntValue, g_cTracerCount.IntValue, g_cTracerLimit.IntValue, OnItemPurchased);

    g_cJammerLongName.GetString(sName, sizeof(sName));
    TTT_RegisterShopItem(SHORT_NAME_JAMMER, sName, g_cJammerPrice.IntValue, TTT_TEAM_DETECTIVE, g_cJammerPrio.IntValue, g_cJammerCount.IntValue, g_cJammerLimit.IntValue, OnItemPurchased);
}

public Action OnItemPurchased(int client, const char[] itemshort, int count, int price)
{
    int iTeam = TTT_GetClientTeam(client);

    if (StrEqual(itemshort, SHORT_NAME_TRACER, false))
    {
        if (iTeam != TTT_TEAM_TRAITOR)
        {
            return Plugin_Stop;
        }
        
        TTT_AddInventoryItem(client, SHORT_NAME_TRACER);
    }
    else if (StrEqual(itemshort, SHORT_NAME_JAMMER, false))
    {
        if (iTeam != TTT_TEAM_DETECTIVE)
        {
            return Plugin_Stop;
        }
        
        TTT_AddInventoryItem(client, SHORT_NAME_JAMMER);
    }

    return Plugin_Continue;
}

public Action Tracer_Display(Handle timer)
{
    LoopValidClients(client)
    {
        int iClientToShow = client;
        
        // Check if players is spectating another player
        if(!IsPlayerAlive(client) || IsClientObserver(client))
        {
            int iObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
            if(iObserverMode == SPECMODE_FIRSTPERSON || iObserverMode == SPECMODE_3RDPERSON)
            {
                iClientToShow = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
                
                if(iClientToShow <= 0 || iClientToShow > MaxClients)
                {
                    continue;
                }
            }
            else
            {
                continue;
            }
        }
        
        if(!TTT_IsItemInInventory(iClientToShow, SHORT_NAME_TRACER) || TTT_GetClientTeam(iClientToShow) != TTT_TEAM_TRAITOR)
        {
            continue;
        }

        if (TTT_IsItemInInventory(client, SHORT_NAME_JAMMER))
        {
            continue;
        }
        
        ShowHUD(client, iClientToShow);
    }
    
    return Plugin_Continue;
}

void ShowHUD(int client, int iClientToShow)
{
    char sInfo[32], sName[64], centerText[64];
    
    if(GetCompassInfo(client, sInfo, sName) > 0)
    {
        Format(centerText, sizeof(centerText), "%s%s%s", sInfo, StrEqual(sName, "") ? "" : ": ", sName);
        SetHudTextParams(0.2, 0.2, 2.0, 135 , 206, 255, 255, 0, 30.0, 0.0, 0.0);
        ShowSyncHudText(iClientToShow, g_hHUD, centerText);
    }
}

int GetCompassInfo(int client, char sInfo[32], char sName[64])
{
    float clientOrigin[3];
    GetClientAbsOrigin(client, clientOrigin);
    
    int nearest = GetCompassTarget(client, clientOrigin);
    
    if(nearest <= 0)
    {
        return false;
    }
    
    float targetOrigin[3];
    GetClientAbsOrigin(nearest, targetOrigin);
    
    float clientAngles[3];
    GetClientAbsAngles(client, clientAngles);
    
    float vecPoints[3];
    MakeVectorFromPoints(clientOrigin, targetOrigin, vecPoints);
    
    float vecAngles[3];
    GetVectorAngles(vecPoints, vecAngles);
    
    float distance;
    distance = GetVectorDistance(clientOrigin, targetOrigin);
    
    // Get direction
    float diff = clientAngles[1] - vecAngles[1];
    
    while(diff < -180.0)
    {
        diff += 360.0;
    }
    
    while(diff > 180.0)
    {
        diff -= 360.0;
    }
    
    // up
    if (diff >= -22.5 && diff < 22.5)
    {
        Format(sInfo, sizeof(sInfo), "\xe2\x86\x91");
    }
    // right up
    else if (diff >= 22.5 && diff < 67.5)
    {
        if(distance > g_cCompassDisorientationDistance.FloatValue)
        {
            Format(sInfo, sizeof(sInfo), "\xe2\x86\x97");
        }
        // left
        else
        {
            Format(sInfo, sizeof(sInfo), "\xe2\x86\x91");
        }
    }
    // right
    else if (diff >= 67.5 && diff < 112.5)
    {
        Format(sInfo, sizeof(sInfo), "\xe2\x86\x92");
    }
    // right down
    else if (diff >= 112.5 && diff < 157.5)
    {
        if(distance > g_cCompassDisorientationDistance.FloatValue)
        {
            Format(sInfo, sizeof(sInfo), "\xe2\x86\x98");
        }
        // left
        else
        {
            Format(sInfo, sizeof(sInfo), "\xe2\x86\x92");
        }
    }
    // down
    else if (diff >= 157.5 || diff < -157.5)
    {
        Format(sInfo, sizeof(sInfo), "\xe2\x86\x93");
    }
    // down left
    else if (diff >= -157.5 && diff < -112.5)
    {
        if(distance > g_cCompassDisorientationDistance.FloatValue)
        {
            Format(sInfo, sizeof(sInfo), "\xe2\x86\x99");
        }
        // left
        else
        {
            Format(sInfo, sizeof(sInfo), "\xe2\x86\x93");
        }
    }
    // left
    else if (diff >= -112.5 && diff < -67.5)
    {
        Format(sInfo, sizeof(sInfo), "\xe2\x86\x90");
    }
    // left up
    else 
    {
        if(distance > g_cCompassDisorientationDistance.FloatValue)
        {
            Format(sInfo, sizeof(sInfo), "\xe2\x86\x96");
        }
        // left
        else
        {
            Format(sInfo, sizeof(sInfo), "\xe2\x86\x90");
        }
    }
    
    char sTarget[12];
    TTT_GetClientName(nearest, sTarget, sizeof(sTarget));
    int iMeters = RoundToFloor(distance * 0.02);
    
    if(distance < g_cCompassShowNameDistance.FloatValue)
    {
        Format(sName, sizeof(sName), "%s ( ~%dm )", sTarget, iMeters);
    }
    
    return true;
}

int GetCompassTarget(int client, float pos[3])
{
    float fDistance;
    float fClosestDistance = -1.0;
    int player = 0;
    
    LoopValidClients(i)
    {
        if(i == client)
        {
            continue;
        }
        
        if(!IsPlayerAlive(i))
        {
            continue;
        }
        
        if(TTT_GetClientTeam(i) == TTT_TEAM_TRAITOR || TTT_GetClientTeam(i) == TTT_TEAM_UNASSIGNED)
        {
            continue;
        }
        
        
        float fTargetPos[3];
        GetClientAbsOrigin(i, fTargetPos);
        
        if(fTargetPos[0] == 0.0 && fTargetPos[1] == 0.0 && fTargetPos[2] == 0.0)
        {
            continue;
        }
        
        fDistance = GetVectorDistance(pos, fTargetPos);
        
        if (fDistance < fClosestDistance || fClosestDistance == -1.0)
        {
            fClosestDistance = fDistance;
            player = i;
        }
    }
    
    return player;
}
