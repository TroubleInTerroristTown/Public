void GhostDM_OnPluginStart()
{
    RegConsoleCmd("sm_dm", Command_GhostDM);
    RegConsoleCmd("sm_stopdm", Command_StopGhostDM);
}

public Action Command_GhostDM(int client, int args)
{
    if (!IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if (IsPlayerAlive(client))
    {
        PrintToChat(client, "You must be dead!");
        return Plugin_Handled;
    }

    if (!g_bRedie[client])
    {
        PrintToChat(client, "You must in redie!");
        return Plugin_Handled;
    }

    g_bDM[client] = true;
    PrintToChat(client, "You are now in deathmatch mode!");

    return Plugin_Continue;
}

public Action Command_StopGhostDM(int client, int args)
{
    ResetDM(client);
}

void ResetDM(int client)
{
    g_bDM[client] = false;
}
