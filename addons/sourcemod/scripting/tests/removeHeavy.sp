#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <cstrike>

char g_sModel[MAXPLAYERS + 1][PLATFORM_MAX_PATH+1];

public void OnPluginStart()
{
    RegAdminCmd("sm_gheavy", Command_GHeavy, ADMFLAG_ROOT);
    RegAdminCmd("sm_rheavy", Command_RHeavy, ADMFLAG_ROOT);
}
public Action Command_GHeavy(int client, int args)
{
    GetClientModel(client, g_sModel[client], sizeof(g_sModel[]));

    GivePlayerItem(client, "item_heavyassaultsuit");
}

public Action Command_RHeavy(int client, int args)
{
    if (GetEntProp(client, Prop_Send, "m_bHasHeavyArmor"))
    {
        PrintToChat(client, "m_bHasHelmet == %b", GetEntProp(client, Prop_Send, "m_bHasHelmet"));
        PrintToChat(client, "m_bHasHeavyArmor == %b", GetEntProp(client, Prop_Send, "m_bHasHeavyArmor"));
        PrintToChat(client, "m_bWearingSuit == %b", GetEntProp(client, Prop_Send, "m_bWearingSuit"));
        PrintToChat(client, "m_ArmorValue == %d", GetEntProp(client, Prop_Data, "m_ArmorValue"));

        SetEntProp(client, Prop_Send, "m_bHasHelmet", false);
        SetEntProp(client, Prop_Send, "m_bHasHeavyArmor", false);
        SetEntProp(client, Prop_Send, "m_bWearingSuit", false);
        SetEntProp(client, Prop_Data, "m_ArmorValue", 0);

        SetEntityModel(client, g_sModel[client]);
    }
}
