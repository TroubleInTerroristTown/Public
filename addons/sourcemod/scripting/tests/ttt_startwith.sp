#pragma semicolon 1

#include <sourcemod>
#include <ttt>
#include <ttt_shop>
#include <ttt_weapons>

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Start With Items"

public Plugin myinfo =
{
    name = PLUGIN_NAME,
    author = TTT_PLUGIN_AUTHOR,
    description = TTT_PLUGIN_DESCRIPTION,
    version = TTT_PLUGIN_VERSION,
    url = TTT_PLUGIN_URL
};

public void TTT_OnClientGetRole(int client, int role)
{
    if (role == TTT_TEAM_DETECTIVE)
    {
        TTT_GiveClientItem(client, KEVHELM_D_ITEM_SHORT);
    }
}
