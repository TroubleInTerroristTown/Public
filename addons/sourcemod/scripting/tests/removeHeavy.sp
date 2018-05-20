#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <ttt>

int g_iHeavyID[MAXPLAYERS+1] = { -1, ...};

public void OnPluginStart()
{
    RegAdminCmd("sm_heavy", Command_Heavy, ADMFLAG_ROOT);
    RegAdminCmd("sm_rheavy", Command_RHeavy, ADMFLAG_ROOT);
    RegAdminCmd("sm_end", Command_End, ADMFLAG_ROOT);
    RegAdminCmd("sm_count", Command_Count, ADMFLAG_ROOT);
}
public Action Command_Heavy(int client, int args)
{
    g_iHeavyID[client] = GivePlayerItem(client, "item_heavyassaultsuit");
    PrintToChat(client, "Player: %N, Heavy: %d", client, g_iHeavyID[client]);
}

public Action Command_RHeavy(int client, int args)
{
    PrintToChat(client, "m_bHasHelmet == %b", GetEntProp(client, Prop_Send, "m_bHasHelmet"));
    PrintToChat(client, "m_bHasHeavyArmor == %b", GetEntProp(client, Prop_Send, "m_bHasHeavyArmor"));
    PrintToChat(client, "m_bWearingSuit == %b", GetEntProp(client, Prop_Send, "m_bWearingSuit"));
    PrintToChat(client, "m_ArmorValue == %d", GetEntProp(client, Prop_Data, "m_ArmorValue"));

    SetEntProp(client, Prop_Send, "m_bHasHelmet", false);
    SetEntProp(client, Prop_Send, "m_bHasHeavyArmor", false);
    SetEntProp(client, Prop_Send, "m_bWearingSuit", false);
    SetEntProp(client, Prop_Data, "m_ArmorValue", 0);

    RequestFrame(Frame_CheckArmor, GetClientUserId(client));
}

public void Frame_CheckArmor(int userid)
{
    int client = GetClientOfUserId(userid);

    if (TTT_IsClientValid(client))
    {
        PrintToChat(client, "m_bHasHelmet == %b", GetEntProp(client, Prop_Send, "m_bHasHelmet"));
        PrintToChat(client, "m_bHasHeavyArmor == %b", GetEntProp(client, Prop_Send, "m_bHasHeavyArmor"));
        PrintToChat(client, "m_bWearingSuit == %b", GetEntProp(client, Prop_Send, "m_bWearingSuit"));
        PrintToChat(client, "m_ArmorValue == %b", GetEntProp(client, Prop_Data, "m_ArmorValue"));
    }
}

public Action Command_End(int client, int args)
{
    CS_TerminateRound(1.0, CSRoundEnd_CTSurrender, true);
}

public Action Command_Count(int client, int args)
{
    PrintToChat(client, "GetClientCount: %d, Ingame: %d", GetClientCount(false), GetClientCount(true));
}
