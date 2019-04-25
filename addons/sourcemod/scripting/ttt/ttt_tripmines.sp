#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <ttt>
#include <ttt_shop>
#include <multicolors>
#undef REQUIRE_PLUGIN
#include <tripmines>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Tripmines"

#define SHORTNAME_T "tripmines"

ConVar g_cLongName = null;
ConVar g_cPrice = null;
ConVar g_cPrio = null;
ConVar g_cAmount = null;

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

    TTT_StartConfig("tripmines");
    CreateConVar("ttt2_tripmines_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cLongName = AutoExecConfig_CreateConVar("tripmines_name", "Tripmines", "The name of this in Shop");
    g_cPrice = AutoExecConfig_CreateConVar("tripmines_price", "0", "The amount of credits a tripmines costs as detective. 0 to disable.");
    g_cPrio = AutoExecConfig_CreateConVar("tripmines_sort_prio", "0", "The sorting priority of the tripmines in the shop menu.");
    g_cAmount = AutoExecConfig_CreateConVar("tripmines_mines", "0", "How mines get the player?", _, true, 1.0);
    TTT_EndConfig();
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

public void OnAllPluginsLoaded()
{
    char sFile[] = "tripmines.smx";
    Handle hPlugin = FindPluginByFile(sFile);
    
    if (hPlugin == null || GetPluginStatus(hPlugin) != Plugin_Running)
    {
        TTT_RemoveCustomItem(SHORTNAME_T);
        SetFailState("Can't find tripmines.smx! This file will be provided with TTT.");
        return;
    }
}

public void TTT_OnShopReady()
{
    RegisterItem();
}

void RegisterItem()
{
    char sBuffer[MAX_ITEM_LENGTH];
    
    g_cLongName.GetString(sBuffer, sizeof(sBuffer));
    TTT_RegisterCustomItem(SHORTNAME_T, sBuffer, g_cPrice.IntValue, TTT_TEAM_TRAITOR, g_cPrio.IntValue);
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count, int price)
{
    if (TTT_IsClientValid(client) && IsPlayerAlive(client))
    {
        if (StrEqual(itemshort, SHORTNAME_T, false))
        {
            int role = TTT_GetClientRole(client);

            if (role == TTT_TEAM_TRAITOR)
            {
                Tripmine_AddClientMines(client, g_cAmount.IntValue);
            }
        }
    }
    return Plugin_Continue;
}
