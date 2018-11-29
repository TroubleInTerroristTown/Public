void InitForwards()
{
    g_hOnRoundStart_Pre = CreateGlobalForward("TTT_OnRoundStart_Pre", ET_Event);
    g_hOnRoundStart = CreateGlobalForward("TTT_OnRoundStart", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
    g_hOnRoundStartFailed = CreateGlobalForward("TTT_OnRoundStartFailed", ET_Ignore, Param_Cell, Param_Cell);
    g_hOnRoundEnd = CreateGlobalForward("TTT_OnRoundEnd", ET_Ignore, Param_Cell, Param_Cell);
    g_hOnClientGetRole = CreateGlobalForward("TTT_OnClientGetRole", ET_Ignore, Param_Cell, Param_Cell);
    g_hOnTakeDamage = CreateGlobalForward("TTT_OnTakeDamage", ET_Ignore, Param_Cell, Param_Cell, Param_Float, Param_Cell, Param_Cell);
    g_hOnClientDeath = CreateGlobalForward("TTT_OnClientDeath", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
    g_hOnClientDeathPre = CreateGlobalForward("TTT_OnClientDeathPre", ET_Event, Param_Cell, Param_Cell);
    g_hOnBodyFound = CreateGlobalForward("TTT_OnBodyFound", ET_Ignore, Param_Cell, Param_Cell, Param_Array, Param_Cell);
    g_hOnBodyCheck = CreateGlobalForward("TTT_OnBodyCheck", ET_Event, Param_Cell, Param_Array);
    g_hOnButtonPress = CreateGlobalForward("TTT_OnButtonPress", ET_Ignore, Param_Cell, Param_Cell);
    g_hOnButtonRelease = CreateGlobalForward("TTT_OnButtonRelease", ET_Ignore, Param_Cell, Param_Cell);
    g_hOnModelUpdate = CreateGlobalForward("TTT_OnModelUpdate", ET_Ignore, Param_Cell, Param_String);
    g_hOnPlayerDeathPre = CreateGlobalForward("TTT_OnPlayerDeath", ET_Event, Param_Cell, Param_Cell);
    g_hOnKarmaUpdate = CreateGlobalForward("TTT_OnKarmaUpdate", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
    g_hOnRulesMenu = CreateGlobalForward("TTT_OnRulesMenu", ET_Event, Param_Cell, Param_CellByRef);
    g_hOnDetectiveMenu = CreateGlobalForward("TTT_OnDetectiveMenu", ET_Event, Param_Cell, Param_CellByRef);
    g_hOnCheckCommandAccess = CreateGlobalForward("TTT_OnCheckCommandAccess", ET_Event, Param_Cell, Param_String, Param_String, Param_CellByRef);
    g_hOnPlayerRespawn = CreateGlobalForward("TTT_OnPlayerRespawn", ET_Ignore, Param_Cell);
    g_hOnVersionCheck = CreateGlobalForward("TTT_OnLatestVersion", ET_Ignore, Param_String);
    g_hOnRoundSlay = CreateGlobalForward("TTT_OnRoundSlay", ET_Ignore, Param_Cell, Param_Cell);
}

void InitNatives()
{
    CreateNative("TTT_WasBodyFound", Native_WasBodyFound);
    CreateNative("TTT_WasBodyScanned", Native_WasBodyScanned);
    CreateNative("TTT_GetFoundStatus", Native_GetFoundStatus);
    CreateNative("TTT_SetFoundStatus", Native_SetFoundStatus);
    CreateNative("TTT_GetClientRagdoll", Native_GetClientRagdoll);
    CreateNative("TTT_GetClientByRagdollID", Native_GetClientByRagdollID);
    CreateNative("TTT_SetRagdoll", Native_SetRagdoll);
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
    CreateNative("TTT_SetRoundSlays", Native_SetRoundSlays);
    CreateNative("TTT_IsPlayerAlive", Native_IsPlayerAlive);
    CreateNative("TTT_ClientOpenRules", Native_ClientOpenRules);
    CreateNative("TTT_GetRoundTime", Native_GetRoundTime);
    CreateNative("TTT_GetRoundTimestamp", Native_GetRoundTimestamp);
    CreateNative("TTT_CheckCommandAccess", Native_CheckCommandAccess);
    CreateNative("TTT_RespawnPlayer", Native_RespawnPlayer);
    CreateNative("TTT_TerminateRound", Native_TerminateRound);
    CreateNative("TTT_GetLatestVersion", Native_GetLatestVersion);
    CreateNative("TTT_GetCommitsCount", Native_GetCommitsCount);
    CreateNative("TTT_DisableRounds", Native_DisableRounds);
    CreateNative("TTT_GetRoundStatus", Native_GetRoundStatus);
}

public int Native_IsRoundActive(Handle plugin, int numParams)
{
    return g_bRoundStarted;
}

public int Native_GetClientRole(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if (TTT_IsClientValid(client))
    {
        return g_iRole[client];
    }

    return -1;
}

public int Native_GetClientKarma(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if (TTT_IsClientValid(client))
    {
        bool publicKarma = view_as<bool>(GetNativeCell(2));

        if (g_bKarma[client])
        {
            if (g_cpublicKarma.BoolValue || publicKarma)
            {
                return g_iKarma[client];
            }
            else
            {
                return g_iKarmaStart[client];
            }
        }
    }

    return -1;
}

public int Native_GetClientRagdoll(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if (TTT_IsClientValid(client))
    {
        int iBody[Ragdolls];

        for (int i = 0; i < g_aRagdoll.Length; i++)
        {
            g_aRagdoll.GetArray(i, iBody[0], sizeof(iBody));
            if (iBody[Victim] == GetClientUserId(client))
            {
                SetNativeArray(2, iBody[0], sizeof(iBody));
                return true;
            }
        }
    }

    return false;
}

public int Native_GetClientByRagdollID(Handle plugin, int numParams)
{
    int ragdoll = GetNativeCell(1);

    if (IsValidEntity(ragdoll))
    {
        int iBody[Ragdolls];

        for (int i = 0; i < g_aRagdoll.Length; i++)
        {
            g_aRagdoll.GetArray(i, iBody[0], sizeof(iBody));
            if (iBody[Ent] == EntIndexToEntRef(ragdoll))
            {
                return GetClientOfUserId(iBody[Victim]);
            }
        }
    }

    return -1;
}

public int Native_SetRagdoll(Handle plugin, int numParams)
{
    int iBody[Ragdolls];

    GetNativeArray(1, iBody[0], sizeof(iBody));

    g_aRagdoll.PushArray(iBody[0]);

    return 0;
}

public int Native_SetClientRole(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if (TTT_IsClientValid(client))
    {
        int role = GetNativeCell(2);

        if (TTT_IsClientValid(client) && (role >= TTT_TEAM_UNASSIGNED && role <= TTT_TEAM_DETECTIVE))
        {
            g_iRole[client] = role;
            TeamInitialize(client);
            return g_iRole[client];
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

        if (TTT_IsClientValid(client) && g_bKarma[client])
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

        if (TTT_IsClientValid(client) && g_bKarma[client])
        {
            return setKarma(client, g_iKarma[client] + karma, force);
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

        if (TTT_IsClientValid(client) && g_bKarma[client])
        {
            return setKarma(client, g_iKarma[client] - karma, force);
        }
    }

    return -1;
}

public int Native_WasBodyFound(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if (TTT_IsClientValid(client))
    {
        int iSize = g_aRagdoll.Length;

        if (iSize == 0)
        {
            return false;
        }

        int iRagdoll[Ragdolls];

        for (int i = 0; i < iSize; i++)
        {
            g_aRagdoll.GetArray(i, iRagdoll[0]);

            if (iRagdoll[Victim] == GetClientUserId(client))
            {
                return iRagdoll[Found];
            }
        }
    }

    return -1;
}

public int Native_WasBodyScanned(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if (TTT_IsClientValid(client))
    {
        int iSize = g_aRagdoll.Length;

        if (iSize == 0)
        {
            return false;
        }

        int iRagdoll[Ragdolls];

        for (int i = 0; i < iSize; i++)
        {
            g_aRagdoll.GetArray(i, iRagdoll[0]);

            if (iRagdoll[Victim] == GetClientUserId(client))
            {
                return iRagdoll[Scanned];
            }
        }
    }

    return -1;
}

public int Native_LogString(Handle plugin, int numParams)
{
    char message[512];
    int bytes;

    FormatNativeString(0, 1, 2, sizeof(message), bytes, message);
    addArrayTime(message);

    return 0;
}

public int Native_GetFoundStatus(Handle plugin, int numParams)
{
    return g_bFound[GetNativeCell(1)];
}

public int Native_SetFoundStatus(Handle plugin, int numParams)
{
    g_bFound[GetNativeCell(1)] = view_as<bool>(GetNativeCell(2));

    return;
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
        
        g_iRoundSlays[client] += rounds;
        
        if (g_bRoundStarted && force && IsPlayerAlive(client) && g_iRoundSlays[client] > 0)
        {
            ForcePlayerSuicide(client);
            g_iRoundSlays[client]--;
            
            if (g_iRoundSlays[client] > 0)
            {
                CPrintToChat(client, "%s %T", g_sTag, "RS - Slayed", client, g_iRoundSlays[client]);
                LogAction(0, client, "\"%L\" was slayed! Remaining Rounds: %d", client, g_iRoundSlays[client]);
            }
        }
        
        UpdateRoundSlaysCookie(client);
        
        return g_iRoundSlays[client];
    }

    return -1;
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
        
        g_iRoundSlays[client] = rounds;
        
        if (g_bRoundStarted || force)
        {
            if (IsPlayerAlive(client) && g_iRoundSlays[client] > 0)
            {
                ForcePlayerSuicide(client);
                g_iRoundSlays[client]--;
                
                if (g_iRoundSlays[client] > 0)
                {
                    CPrintToChat(client, "%s %T", g_sTag, "RS - Slayed", client, g_iRoundSlays[client]);
                    LogAction(0, client, "\"%L\" was slayed! Remaining Rounds: %d", client, g_iRoundSlays[client]);
                }
            }
        }
        
        UpdateRoundSlaysCookie(client);
        
        return rounds;
    }

    return -1;
}

public int Native_IsPlayerAlive(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if (TTT_IsClientValid(client))
    {
        return g_bAlive[client];
    }

    return false;
}

public int Native_ClientOpenRules(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if (TTT_IsClientValid(client))
    {
        g_bRules[client] = false;

        char sBuffer[12];
        IntToString(g_bRules[client], sBuffer, sizeof(sBuffer));
        SetClientCookie(client, g_hRules, sBuffer);

        ShowRules(client, g_iSite[client]);
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
    
    int iFlags = ReadFlagString(sFlags);
    if (CheckCommandAccess(client, sCommand, iFlags, override_only))
    {
        return true;
    }

    bool access = false;

    Action result = Plugin_Continue;
    Call_StartForward(g_hOnCheckCommandAccess);
    Call_PushCell(client);
    Call_PushString(sCommand);
    Call_PushString(sFlags);
    Call_PushCellRef(access);
    Call_Finish(result);

    if (result == Plugin_Changed)
    {
        return access;
    }

    return false;
}

public int Native_RespawnPlayer(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    g_bRespawn[client] = true;
    CS_RespawnPlayer(client);
    TeamInitialize(client, true);
    g_bAlive[client] = true;
    g_bFound[client] = false;

    float fOrigin[3];
    bool bFound = false;

    int iBody[Ragdolls];
    for (int i = 0; i < g_aRagdoll.Length; i++)
    {
        g_aRagdoll.GetArray(i, iBody[0], sizeof(iBody));
        if (iBody[Victim] == GetClientUserId(client))
        {
            g_aRagdoll.Erase(i);

            int iRagdoll = EntRefToEntIndex(iBody[Ent]);

            if (iRagdoll > 0)
            {
                GetEntPropVector(iRagdoll, Prop_Send, "m_vecOrigin", fOrigin);
                AcceptEntityInput(iRagdoll, "Kill");
                bFound = true;
            }
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
                PrintToChat(client, "Origin[2] = %.1f", fOrigin[2]);
                TeleportEntity(client, fOrigin, NULL_VECTOR, NULL_VECTOR);
            }
        }

        Call_StartForward(g_hOnPlayerRespawn);
        Call_PushCell(client);
        Call_Finish();
    }
}

public int Native_TerminateRound(Handle plugin, int numParams)
{
    float fDelay = view_as<float>(GetNativeCell(1));
    CSRoundEndReason rReason = view_as<CSRoundEndReason>(GetNativeCell(2));

    CS_TerminateRound(fDelay, rReason, true);
}

public int Native_GetLatestVersion(Handle plugin, int numParams)
{
    if (strlen(g_sLatestVersion) < 1)
    {
        return false;
    }

    SetNativeString(1, g_sLatestVersion, GetNativeCell(2));

    return true;
}

public int Native_GetCommitsCount(Handle plugin, int numParams)
{
    char sSplit[2][12];
    ExplodeString(TTT_PLUGIN_VERSION, ".", sSplit, sizeof(sSplit), sizeof(sSplit[]));

    if (IsStringNumeric(sSplit[1]))
    {
        return StringToInt(sSplit[1]);
    }

    return -1;
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
