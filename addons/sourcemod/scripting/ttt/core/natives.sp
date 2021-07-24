void InitForwards()
{
    g_fwOnRoundStart_Pre = new GlobalForward("TTT_OnRoundStart_Pre", ET_Event);
    g_fwOnRoundStart = new GlobalForward("TTT_OnRoundStart", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
    g_fwOnRoundStartFailed = new GlobalForward("TTT_OnRoundStartFailed", ET_Ignore, Param_Cell, Param_Cell);
    g_fwOnRoundEnd = new GlobalForward("TTT_OnRoundEnd", ET_Ignore, Param_Cell, Param_Cell);
    g_fwOnClientGetRole = new GlobalForward("TTT_OnClientGetRole", ET_Ignore, Param_Cell, Param_Cell);
    g_fwOnTakeDamage = new GlobalForward("TTT_OnTakeDamage", ET_Ignore, Param_Cell, Param_Cell, Param_Float, Param_Cell, Param_Cell);
    g_fwOnClientDeath = new GlobalForward("TTT_OnClientDeath", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
    g_fwOnClientDeathPre = new GlobalForward("TTT_OnClientDeathPre", ET_Event, Param_Cell, Param_Cell);
    g_fwOnButtonPress = new GlobalForward("TTT_OnButtonPress", ET_Ignore, Param_Cell, Param_Cell);
    g_fwOnButtonRelease = new GlobalForward("TTT_OnButtonRelease", ET_Ignore, Param_Cell, Param_Cell);
    g_fwOnModelUpdate = new GlobalForward("TTT_OnModelUpdate", ET_Ignore, Param_Cell, Param_String);
    g_fwOnPlayerDeathPre = new GlobalForward("TTT_OnPlayerDeath", ET_Event, Param_Cell, Param_Cell);
    g_fwOnPreKarmaUpdate = new GlobalForward("TTT_OnPreKarmaUpdate", ET_Event, Param_Cell, Param_Cell, Param_Cell);
    g_fwOnKarmaUpdate = new GlobalForward("TTT_OnKarmaUpdate", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
    g_fwOnRulesMenu = new GlobalForward("TTT_OnRulesMenu", ET_Event, Param_Cell, Param_CellByRef);
    g_fwOnDetectiveMenu = new GlobalForward("TTT_OnDetectiveMenu", ET_Event, Param_Cell, Param_CellByRef);
    g_fwOnCheckCommandAccess = new GlobalForward("TTT_OnCheckCommandAccess", ET_Event, Param_Cell, Param_String, Param_String, Param_CellByRef);
    g_fwOnPlayerRespawn = new GlobalForward("TTT_OnPlayerRespawn", ET_Ignore, Param_Cell);
    g_fwOnRoundSlay = new GlobalForward("TTT_OnRoundSlay", ET_Ignore, Param_Cell, Param_Cell);
    g_fwOnRoleSelection = new GlobalForward("TTT_OnRoleSelection", ET_Event, Param_CellByRef, Param_CellByRef, Param_CellByRef);
    g_fOnRoundTimerStart_Pre = new GlobalForward("TTT_OnRoundTimerStart_Pre", ET_Event, Param_CellByRef, Param_CellByRef);
}

void InitNatives()
{
    CreateNative("TTT_GetClientTeam", Native_GetClientTeam);
    CreateNative("TTT_GetClientRole", Native_GetClientRole);
    CreateNative("TTT_SetClientRole", Native_SetClientRole);
    CreateNative("TTT_GetClientKarma", Native_GetClientKarma);
    CreateNative("TTT_SetClientKarma", Native_SetClientKarma);
    CreateNative("TTT_AddClientKarma", Native_AddClientKarma);
    CreateNative("TTT_RemoveClientKarma", Native_RemoveClientKarma);
    CreateNative("TTT_ForceTraitor", Native_ForceTraitor);
    CreateNative("TTT_ForceDetective", Native_ForceDetective);
    CreateNative("TTT_IsRoundActive", Native_IsRoundActive);
    CreateNative("TTT_LogString", Native_LogString);
    CreateNative("TTT_AddRoundSlays", Native_AddRoundSlays);
    CreateNative("TTT_AddRoundSlaysByID", Native_AddRoundSlaysByID);
    CreateNative("TTT_SetRoundSlays", Native_SetRoundSlays);
    CreateNative("TTT_IsPlayerAlive", Native_IsPlayerAlive);
    CreateNative("TTT_ClientOpenRules", Native_ClientOpenRules);
    CreateNative("TTT_GetRoundTime", Native_GetRoundTime);
    CreateNative("TTT_GetRoundTimestamp", Native_GetRoundTimestamp);
    CreateNative("TTT_CheckCommandAccess", Native_CheckCommandAccess);
    CreateNative("TTT_RespawnPlayer", Native_RespawnPlayer);
    CreateNative("TTT_RespawnPlayerRandom", Native_RespawnPlayerRandom);
    CreateNative("TTT_DisableRounds", Native_DisableRounds);
    CreateNative("TTT_GetRoundStatus", Native_GetRoundStatus);
    CreateNative("TTT_GetRoundID", Native_GetRoundID);
    CreateNative("TTT_IsClientReady", Native_IsClientReady);
    CreateNative("TTT_GetPlayerID", Native_GetPlayerID);
    CreateNative("TTT_GetClientOfPlayerID", Native_GetClientOfPlayerID);
    CreateNative("TTT_SetRoundStatus", Native_SetRoundStatus);
    CreateNative("TTT_StopRoundTimer", Native_StopRoundTimer);
    CreateNative("TTT_TerminateRound", Native_StopRound);
    CreateNative("TTT_GetClientName", Native_GetClientName);
}

public int Native_IsRoundActive(Handle plugin, int numParams)
{
    if (g_iStatus == Round_Active)
    {
        return true;
    }

    return false;
}

public int Native_GetClientTeam(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if (TTT_IsClientValid(client))
    {
        return g_iPlayer[client].Team;
    }

    return -1;
}

public int Native_GetClientRole(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if (TTT_IsClientValid(client))
    {
        return g_iPlayer[client].Role;
    }

    return -1;
}

public int Native_GetClientKarma(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if (TTT_IsClientValid(client))
    {
        bool publicKarma = view_as<bool>(GetNativeCell(2));

        if (g_iPlayer[client].KarmaReady)
        {
            if (g_cpublicKarma.BoolValue || publicKarma)
            {
                return g_iPlayer[client].Karma;
            }
            else
            {
                return g_iPlayer[client].KarmaStart;
            }
        }
    }

    return -1;
}

public int Native_SetClientRole(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if (TTT_IsClientValid(client))
    {
        int role = GetNativeCell(2);

        if (TTT_IsClientValid(client) && (role >= TTT_TEAM_UNASSIGNED && role <= TTT_TEAM_DETECTIVE))
        {
            g_iPlayer[client].Role = role;
            TeamInitialize(client);
            return g_iPlayer[client].Role;
        }
    }

    return -1;
}

public int Native_SetClientKarma(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if (TTT_IsClientValid(client))
    {
        int karma = GetNativeCell(2);
        bool force = view_as<bool>(GetNativeCell(3));

        if (TTT_IsClientValid(client) && g_iPlayer[client].KarmaReady)
        {
            return setKarma(client, karma, force);
        }
    }

    return -1;
}

public int Native_AddClientKarma(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if (TTT_IsClientValid(client))
    {
        int karma = GetNativeCell(2);
        bool force = view_as<bool>(GetNativeCell(3));

        if (TTT_IsClientValid(client) && g_iPlayer[client].KarmaReady)
        {
            return setKarma(client, g_iPlayer[client].Karma + karma, force);
        }
    }

    return -1;
}

public int Native_RemoveClientKarma(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if (TTT_IsClientValid(client))
    {
        int karma = GetNativeCell(2);
        bool force = view_as<bool>(GetNativeCell(3));

        if (TTT_IsClientValid(client) && g_iPlayer[client].KarmaReady)
        {
            return setKarma(client, g_iPlayer[client].Karma - karma, force);
        }
    }

    return -1;
}

public int Native_LogString(Handle plugin, int numParams)
{
    char message[512];
    int bytes;

    FormatNativeString(0, 1, 2, sizeof(message), bytes, message);
    PushStringToLogs(message);

    return 0;
}

public int Native_ForceTraitor(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if (TTT_IsClientValid(client))
    {
        int userid = GetClientUserId(client);
        
        if(g_aForceTraitor.FindValue(userid) == -1 && g_aForceDetective.FindValue(userid) == -1)
        {
            g_aForceTraitor.Push(userid);
        }
        else
        {
            return false;
        }
    }

    return true;
}

public int Native_ForceDetective(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if (TTT_IsClientValid(client))
    {
        int userid = GetClientUserId(client);
    
        if(g_aForceTraitor.FindValue(userid) == -1 && g_aForceDetective.FindValue(userid) == -1)
        {
            g_aForceDetective.Push(userid);
        }
        else
        {
            return false;
        }
    }

    return true;
}

public int Native_AddRoundSlays(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    if (TTT_IsClientValid(client))
    {
        int rounds = GetNativeCell(2);

        if (rounds < 1)
        {
            CReplyToCommand(client, "Rounds must be positive and higher as zero.");
            return -1;
        }

        bool force = view_as<bool>(GetNativeCell(3));
        
        AddRoundSlays(client, rounds, force);
        UpdatePlayerRSlays(client);
        
        return g_iPlayer[client].RoundSlays;
    }

    return -1;
}

public int Native_AddRoundSlaysByID(Handle plugin, int numParams)
{
    int id = GetNativeCell(1);

    if (id < 0)
    {
        PrintToServer("TTT_AddRoundSlaysByID: Invalid Player ID passed.");
        return -1;
    }

    int rounds = GetNativeCell(2);

    if (rounds < 1)
    {
        PrintToServer("TTT_AddRoundSlaysByID: Rounds must be positive integer >0.");
        return -1;
    }

    int client = GetClientOfPlayerID(id);
    if (client > 0 && view_as<bool>(GetNativeCell(3)))
    {
        AddRoundSlays(client, rounds);
    }

    UpdatePlayerRSlaysByID(id, rounds);

    return 0;
}

stock void AddRoundSlays(int client, int rounds, bool force = false)
{
    g_iPlayer[client].RoundSlays += rounds;

    if (g_iStatus == Round_Active && force && IsPlayerAlive(client) && g_iPlayer[client].RoundSlays > 0)
    {
        ForcePlayerSuicide(client);
        g_iPlayer[client].RoundSlays--;

        if (g_iPlayer[client].RoundSlays > 0)
        {
            CPrintToChat(client, "%s %T", g_sTag, "RS - Slayed", client, g_iPlayer[client].RoundSlays);
            LogAction(0, client, "\"%L\" was slayed! Remaining Rounds: %d", client, g_iPlayer[client].RoundSlays);
        }
    }
}

public int Native_SetRoundSlays(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if (TTT_IsClientValid(client))
    {
        int rounds = GetNativeCell(2);

        if (rounds < 0)
        {
            CReplyToCommand(client, "Rounds must be zero (reset) or higher.");
            return -1;
        }
        
        bool force = view_as<bool>(GetNativeCell(3));
        
        g_iPlayer[client].RoundSlays = rounds;
        
        if (g_iStatus == Round_Active || force)
        {
            if (IsPlayerAlive(client) && g_iPlayer[client].RoundSlays > 0)
            {
                ForcePlayerSuicide(client);
                g_iPlayer[client].RoundSlays--;
                
                if (g_iPlayer[client].RoundSlays > 0)
                {
                    CPrintToChat(client, "%s %T", g_sTag, "RS - Slayed", client, g_iPlayer[client].RoundSlays);
                    LogAction(0, client, "\"%L\" was slayed! Remaining Rounds: %d", client, g_iPlayer[client].RoundSlays);
                }
            }
        }
        
        UpdatePlayerRSlays(client);
        
        return rounds;
    }

    return -1;
}

public int Native_IsPlayerAlive(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if (TTT_IsClientValid(client) && TTT_ClientValidTeam(client))
    {
        return g_iPlayer[client].Alive;
    }

    return false;
}

public int Native_ClientOpenRules(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if (TTT_IsClientValid(client))
    {
        g_iPlayer[client].Rules = false;

        char sBuffer[12];
        IntToString(g_iPlayer[client].Rules, sBuffer, sizeof(sBuffer));
        g_coRules.Set(client, sBuffer);

        ShowRules(client, g_iPlayer[client].Site);
    }

    return -1;
}

public int Native_GetRoundTime(Handle plugin, int numParams)
{
    if (g_iTeamSelectTime > 0)
    {
        int type = GetNativeCell(1);
        int iTime = GetTime() - g_iTeamSelectTime;

        if (type == 0)
        {
            // Time
            return iTime;
        }
        else if (type == 1)
        {
            // Minutes
            return ((iTime / 60) % 60);
        }
        else if (type == 2)
        {
            // Seconds
            return (iTime % 60);
        }
    }

    return -1;
}

public int Native_GetRoundTimestamp(Handle plugin, int numParams)
{
    return g_iRoundTime;
}

public int Native_CheckCommandAccess(Handle plugin, int numParams)
{
    /*
        We don't check the root flag check, it's already included in the CheckAdminCommandAccess function that will be used for CheckClientCommandAccess/CheckCommandAccess
        CheckCommandAccess: https://github.com/alliedmodders/sourcemod/blob/237db0504c7a59e394828446af3e8ca3d53ef647/core/logic/smn_console.cpp#L65
        CheckClientCommandAccess: https://github.com/alliedmodders/sourcemod/blob/5611ec54a21c3045cc1680b954631c6ca049c768/core/logic/AdminCache.cpp#L2005
        CheckAdminCommandAccess: https://github.com/alliedmodders/sourcemod/blob/5611ec54a21c3045cc1680b954631c6ca049c768/core/logic/AdminCache.cpp#L2036
    */

    int client = GetNativeCell(1);

    char sCommand[32];
    GetNativeString(2, sCommand, sizeof(sCommand));

    ConVar cvar = view_as<ConVar>(GetNativeCell(3));

    bool override_only = view_as<bool>(GetNativeCell(4));

    char sFlags[24];
    cvar.GetString(sFlags, sizeof(sFlags));

    if (strlen(sFlags) < 1)
    {
        return false;
    }
    
    int iFlags = ReadFlagString(sFlags);
    if (CheckCommandAccess(client, sCommand, iFlags, override_only))
    {
        return true;
    }

    bool access = false;

    Action result = Forward_OnCheckCommandAccess(client, sCommand, sFlags, access);
    if (result == Plugin_Changed)
    {
        return access;
    }

    return false;
}

public int Native_RespawnPlayerRandom(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    g_iPlayer[client].Respawn = true;
    CS_RespawnPlayer(client);
    TeamInitialize(client, true, false);
    g_iPlayer[client].Alive = true;
    TTT_SetFoundStatus(client, false);

    if (g_bBodies)
    {
        TTT_RemoveClientRagdoll(client);
    }

    Forward_OnPlayerRespawn(client);
}

public int Native_RespawnPlayer(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    g_iPlayer[client].Respawn = true;
    CS_RespawnPlayer(client);
    TeamInitialize(client, true, false);
    g_iPlayer[client].Alive = true;
    TTT_SetFoundStatus(client, false);

    float fOrigin[3];
    bool bFound = false;

    if (g_bBodies)
    {
        int ragdoll = TTT_GetClientRagdollEntIndex(client);
        if (ragdoll > 0)
        {
            GetEntPropVector(ragdoll, Prop_Send, "m_vecOrigin", fOrigin);
            TTT_RemoveClientRagdoll(client);
            bFound = true;
        }
    }

    if (bFound)
    {
        TeleportEntity(client, fOrigin, NULL_VECTOR, NULL_VECTOR);

        if (TTT_IsClientStuck(client))
        {
            while (TTT_IsClientStuck(client))
            {
                fOrigin[2] += 0.5;

                if(g_cDebug.BoolValue)
                {
                    PrintToChat(client, "Origin[2] = %.1f", fOrigin[2]);
                }
                
                TeleportEntity(client, fOrigin, NULL_VECTOR, NULL_VECTOR);
            }
        }

        Forward_OnPlayerRespawn(client);
    }
    else
    {
        TTT_RespawnPlayerRandom(client);
    }
}

public int Native_TerminateRound(Handle plugin, int numParams)
{
    float fDelay = view_as<float>(GetNativeCell(1));
    CSRoundEndReason rReason = view_as<CSRoundEndReason>(GetNativeCell(2));

    CS_TerminateRound(fDelay, rReason, true);
}

public int Native_DisableRounds(Handle plugin, int numParams)
{
    g_bDisabled = view_as<bool>(GetNativeCell(1));
    return g_bDisabled;
}

public int Native_GetRoundStatus(Handle plugin, int numParams)
{
    return view_as<int>(g_iStatus);
}

public int Native_GetRoundID(Handle plugin, int numParams)
{
    return g_iRoundID;
}

public int Native_IsClientReady(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if (TTT_IsClientValid(client))
    {
        return g_iPlayer[client].Ready;
    }

    return false;
}

public int Native_GetPlayerID(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    return g_iPlayer[client].ID;
}

public int Native_GetClientOfPlayerID(Handle plugin, int numParams)
{
    int id = GetNativeCell(1);

    return GetClientOfPlayerID(id);
}

public int Native_SetRoundStatus(Handle plugin, int numParams)
{
    g_iStatus = view_as<RoundStatus>(GetNativeCell(1));

    return view_as<int>(g_iStatus);
}

public int Native_StopRoundTimer(Handle plugin, int numParams)
{
    delete g_hRoundTimer;
}

public int Native_StopRound(Handle plugin, int numParams)
{
    float fTimer = view_as<float>(GetNativeCell(1));
    CSRoundEndReason reason = view_as<CSRoundEndReason>(GetNativeCell(2));

    g_iStatus = Round_Ending;
    CS_TerminateRound(fTimer, reason);
}

public int Native_GetClientName(Handle plugin, int numParams)
{
    int iReturn = SetNativeString(2, g_iPlayer[GetNativeCell(1)].Name, GetNativeCell(3));

    if (iReturn == SP_ERROR_NONE)
    {
        return true;
    }

    return false;
}
