#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <ttt>
#include <ttt_shop>

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Teleporter"
#define SHORT_NAME "teleporter"

ConVar g_cPrice = null;
ConVar g_cPrio = null;
ConVar g_cCount = null;
ConVar g_cLongName = null;
ConVar g_cAmount = null;

int g_iPCount[MAXPLAYERS + 1] =  { 0, ... };
int g_iPAmount[MAXPLAYERS + 1] =  { 0, ... };

bool g_bTeleport[MAXPLAYERS + 1] =  { false, ... };
bool g_bDuck[MAXPLAYERS + 1] =  { false, ... };
bool g_bInTeleport[MAXPLAYERS + 1] =  { false, ... };

float g_fLocation[MAXPLAYERS + 1][3];

ConVar g_cPluginTag = null;
char g_sPluginTag[64];

public Plugin myinfo =
{
    name = PLUGIN_NAME,
    author = TTT_PLUGIN_AUTHOR,
    description = TTT_PLUGIN_DESCRIPTION,
    version = TTT_PLUGIN_VERSION,
    url = TTT_PLUGIN_URL
};

public void OnPluginStart()
{
    TTT_IsGameCSGO();

    TTT_LoadTranslations();
    
    TTT_StartConfig("teleporter");
    CreateConVar("ttt2_teleporter_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cLongName = AutoExecConfig_CreateConVar("teleporter_name", "Teleporter", "The name of this in Shop");
    g_cPrice = AutoExecConfig_CreateConVar("teleporter_price", "9000", "The amount of credits Teleporter costs as traitor. 0 to disable.");
    g_cPrio = AutoExecConfig_CreateConVar("teleporter_sort_prio", "0", "The sorting priority of the Teleporter in the shop menu.");
    g_cCount = AutoExecConfig_CreateConVar("teleporter_count", "2", "How often a players can port him back to the location");
    g_cAmount = AutoExecConfig_CreateConVar("teleporter_amount", "1", "How many teleporters can a traitor buy?");
    TTT_EndConfig();

    RegConsoleCmd("sm_tele", Command_Tele);

    HookEvent("player_spawn", Event_PlayerSpawn);
}

public void TTT_OnLatestVersion(const char[] version)
{
    TTT_CheckVersion(TTT_PLUGIN_VERSION, TTT_GetCommitsCount());
}

public void OnConfigsExecuted()
{
    g_cPluginTag = FindConVar("ttt_plugin_tag");
    g_cPluginTag.AddChangeHook(OnConVarChanged);
    g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_cPluginTag)
    {
        g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
    }
}

public void TTT_OnShopReady()
{
    RegisterItem();
}

void RegisterItem()
{
    char sName[MAX_ITEM_LENGTH];
    g_cLongName.GetString(sName, sizeof(sName));
    
    TTT_RegisterCustomItem(SHORT_NAME, sName, g_cPrice.IntValue, TTT_TEAM_TRAITOR, g_cPrio.IntValue);
}

public void OnClientDisconnect(int client)
{
    ResetTeleporter(client);
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count, int price)
{
    if (TTT_IsClientValid(client) && IsPlayerAlive(client))
    {
        if (StrEqual(itemshort, SHORT_NAME, false))
        {
            int role = TTT_GetClientRole(client);

            if (g_iPAmount[client] >= g_cAmount.IntValue)
            {
                char sName[MAX_ITEM_LENGTH], sTag[64];
                g_cLongName.GetString(sName, sizeof(sName));

                ConVar hTag = FindConVar("ttt_plugin_tag");
                hTag.GetString(sTag, sizeof(sTag));

                CPrintToChat(client, "%s %T", sTag, "Bought All", client, sName, g_cAmount.IntValue);
                return Plugin_Stop;
            }

            g_bDuck[client] = view_as<bool>(GetEntProp(client, Prop_Send, "m_bDucked"));
            GetClientAbsOrigin(client, g_fLocation[client]);
            
            g_bTeleport[client] = true;
            g_iPCount[client] = 0;
            g_iPAmount[client]++;

            CPrintToChat(client, "%s %T", g_sPluginTag, "Location Saved", client);
        }
    }
    return Plugin_Continue;
} 

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (TTT_IsClientValid(client))
    {
        ResetTeleporter(client);
    }
}

public Action Command_Tele(int client, int args)
{
    if (!TTT_IsClientValid(client) || !g_bTeleport[client])
    {
        return Plugin_Handled;
    }
    
    if (g_iPCount[client] >= g_cCount.IntValue)
    {
        CPrintToChat(client, "%s %T", g_sPluginTag, "Teleport Max", client, g_cCount.IntValue);
        return Plugin_Handled;
    }

    if (g_bDuck[client])
    {
        g_bInTeleport[client] = true;
    }
    else
    {
        TeleportEntity(client, g_fLocation[client], NULL_VECTOR, NULL_VECTOR);
    }
    
    g_iPCount[client]++;

    return Plugin_Continue;
}

void ResetTeleporter(int client)
{
    g_bTeleport[client] = false;
    g_bDuck[client] = false;
    g_bInTeleport[client] = false;
    g_iPCount[client] = 0;
    g_iPAmount[client] = 0;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
    if (TTT_IsClientValid(client))
    {
        if (g_bDuck[client] && g_bInTeleport[client])
        {
            if (!(buttons & IN_DUCK))
			{
				buttons ^= IN_DUCK;
			}
            
            RequestFrame(Frame_Teleport, GetClientUserId(client));
            return Plugin_Changed;
        }
    }

    return Plugin_Continue;
}

public void Frame_Teleport(int userid)
{
    int client = GetClientOfUserId(userid);

    if (TTT_IsClientValid(client) && TTT_IsPlayerAlive(client))
    {
        TeleportEntity(client, g_fLocation[client], NULL_VECTOR, NULL_VECTOR);
        RequestFrame(Frame_Reset, userid);
    }
}


public void Frame_Reset(int userid)
{
    int client = GetClientOfUserId(userid);

    if (TTT_IsClientValid(client))
    {
        g_bDuck[client] = false;
        g_bInTeleport[client] = false;
    }
}
