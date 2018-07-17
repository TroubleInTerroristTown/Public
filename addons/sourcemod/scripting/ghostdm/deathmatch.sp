GhostDM_OnPluginStart()
{
    RegConsoleCmd("sm_dm", Command_DM);
    RegConsoleCmd("sm_stopdm", Command_StopDM);
}

public Action Command_GhostDM(int client, int args)
{
    if (!IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if (IsPlayerAlive(client))
    {
        // TODO: Add Message
        return Plugin_Handled;
    }

    if (!g_bRedie[client])
    {
        // TODO: Add Message
        return Plugin_Handled;
    }

    g_bDM[client] = true;
    // TODO: Add Message (in Deathmatch)

    return Plugin_Continue;
}

public Action Command_GhostDM(int client, int args)
{
    ResetDM(client);
}

void ResetDM(int client)
{
    g_bDM[client] = false;
}
