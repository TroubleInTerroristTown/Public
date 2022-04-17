#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <colorlib>
#include <ttt>
#include <ttt_roles>

ConVar g_cPluginTag = null;
char g_sPluginTag[PLATFORM_MAX_PATH] = "";

public Plugin myinfo =
{
    name = TTT_PLUGIN_NAME ... " - Role: Default",
    author = TTT_PLUGIN_AUTHOR,
    description = TTT_PLUGIN_DESCRIPTION,
    version = TTT_PLUGIN_VERSION,
    url = TTT_PLUGIN_URL
};

public void OnPluginStart()
{
    // We must define OnPluginStart for ColorLib
    // https://github.com/TroubleInTerroristTown/Private/runs/1646390527?check_suite_focus=true#step:11:20
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

public void TTT_OnClientGetRole(int client, int team, int role)
{
    if (role != TTT_ROLE_DEFAULT)
    {
        return;
    }

    if (team == TTT_TEAM_INNOCENT)
    {
        CPrintToChat(client, "%s You are the average {role i}Innocent!", g_sPluginTag);
        CPrintToChat(client, "%s - You enjoy C4 and Watermelons, with a side of lead.", g_sPluginTag);
    }
    else if (team == TTT_TEAM_TRAITOR)
    {
        CPrintToChat(client, "%s You are not the average {role t}Terrorist!", g_sPluginTag);
        CPrintToChat(client, "%s - Unlike the rest of your kin, you always though you were destined for more.", g_sPluginTag);
        CPrintToChat(client, "%s - Now is your time.", g_sPluginTag);
    }
    else if (team == TTT_TEAM_DETECTIVE)
    {
        CPrintToChat(client, "%s You are not the average {role d}Detective!", g_sPluginTag);
        CPrintToChat(client, "%s - Having recently read \"And Then There Were None\" by Agatha Christie.", g_sPluginTag);
        CPrintToChat(client, "%s - Now would be as good as good a time as any, to solve a mystery.", g_sPluginTag);
    }
}
