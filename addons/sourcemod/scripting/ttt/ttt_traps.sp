#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>
#include <ttt>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Traitor Traps"

public Plugin myinfo = 
{
	name = PLUGIN_NAME, 
	author = TTT_PLUGIN_AUTHOR ... ", R3TROATTACK",
	description = TTT_PLUGIN_DESCRIPTION, 
	version = TTT_PLUGIN_VERSION, 
	url = TTT_PLUGIN_URL
};

public void OnPluginStart()
{
	TTT_IsGameCSGO();
}

public void TTT_OnRoundStart(int innocents, int traitors, int detective)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if(!TTT_IsClientValid(i))
            continue;
            
        switch(TTT_GetClientRole(i))
        {
            case TTT_TEAM_TRAITOR:
                DispatchKeyValue(i, "targetname", "TRAITOR");
            case TTT_TEAM_DETECTIVE:
                DispatchKeyValue(i, "targetname", "DETECTIVE");
            case TTT_TEAM_INNOCENT:
                DispatchKeyValue(i, "targetname", "INNOCENT");
        }
    }
}