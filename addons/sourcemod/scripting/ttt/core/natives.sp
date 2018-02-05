void InitForwards()
{
	g_hOnRoundStart_Pre = CreateGlobalForward("TTT_OnRoundStart_Pre", ET_Event);
	g_hOnRoundStart = CreateGlobalForward("TTT_OnRoundStart", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	g_hOnRoundStartFailed = CreateGlobalForward("TTT_OnRoundStartFailed", ET_Ignore, Param_Cell, Param_Cell);
	g_hOnRoundEnd = CreateGlobalForward("TTT_OnRoundEnd", ET_Ignore, Param_Cell);
	g_hOnClientGetRole = CreateGlobalForward("TTT_OnClientGetRole", ET_Ignore, Param_Cell, Param_Cell);
	g_hOnClientDeath = CreateGlobalForward("TTT_OnClientDeath", ET_Ignore, Param_Cell, Param_Cell);
	g_hOnBodyFound = CreateGlobalForward("TTT_OnBodyFound", ET_Ignore, Param_Cell, Param_Cell, Param_String);
	g_hOnBodyChecked = CreateGlobalForward("TTT_OnBodyChecked", ET_Event, Param_Cell, Param_Array);
	g_hOnButtonPress = CreateGlobalForward("TTT_OnButtonPress", ET_Ignore, Param_Cell, Param_Cell);
	g_hOnButtonRelease = CreateGlobalForward("TTT_OnButtonRelease", ET_Ignore, Param_Cell, Param_Cell);
	g_hOnModelUpdate = CreateGlobalForward("TTT_OnModelUpdate", ET_Ignore, Param_Cell, Param_String);
}

void InitNatives()
{
	CreateNative("TTT_WasBodyFound", Native_WasBodyFound);
	CreateNative("TTT_WasBodyScanned", Native_WasBodyScanned);
	CreateNative("TTT_GetFoundStatus", Native_GetFoundStatus);
	CreateNative("TTT_SetFoundStatus", Native_SetFoundStatus);
	CreateNative("TTT_GetClientRagdoll", Native_GetClientRagdoll);
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

	return 0;
}

public int Native_GetClientKarma(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	bool publicKarma = view_as<bool>(GetNativeCell(2));

	if (TTT_IsClientValid(client) && g_bKarma[client])
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

	return 0;
}

public int Native_GetClientRagdoll(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	int iBody[Ragdolls];

	if (TTT_IsClientValid(client))
	{
		for (int i = 0; i < g_aRagdoll.Length; i++)
		{
			g_aRagdoll.GetArray(i, iBody[0], sizeof(iBody));
			if (iBody[Victim] == GetClientUserId(client))
			{
				SetNativeArray(2, iBody[0], sizeof(iBody));
			}
			return 1;
		}
	}

	return 0;
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
	int role = GetNativeCell(2);

	if (TTT_IsClientValid(client))
	{
		g_iRole[client] = role;
		TeamInitialize(client);
		return g_iRole[client];
	}
	else if (role < TTT_TEAM_UNASSIGNED || role > TTT_TEAM_DETECTIVE)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid role %d", role);
	}

	return 0;
}

public int Native_SetClientKarma(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int karma = GetNativeCell(2);
	bool force = view_as<bool>(GetNativeCell(3));

	if (TTT_IsClientValid(client) && g_bKarma[client])
	{
		return setKarma(client, karma, force);
	}

	return 0;
}

public int Native_AddClientKarma(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int karma = GetNativeCell(2);
	bool force = view_as<bool>(GetNativeCell(3));

	if (TTT_IsClientValid(client) && g_bKarma[client])
	{
		return setKarma(client, g_iKarma[client] + karma, force);
	}

	return 0;
}

public int Native_RemoveClientKarma(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int karma = GetNativeCell(2);
	bool force = view_as<bool>(GetNativeCell(3));

	if (TTT_IsClientValid(client) && g_bKarma[client])
	{
		return setKarma(client, g_iKarma[client] - karma, force);
	}

	return 0;
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

	return 0;
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

	return 0;
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
	int userid = GetClientUserId(GetNativeCell(1));
	
	if(g_aForceTraitor.FindValue(userid) == -1 && g_aForceDetective.FindValue(userid) == -1)
	{
		g_aForceTraitor.Push(userid);
	}
	else
	{
		return false;
	}

	return true;
}

public int Native_ForceDetective(Handle plugin, int numParams)
{
	int userid = GetClientUserId(GetNativeCell(1));
	
	if(g_aForceTraitor.FindValue(userid) == -1 && g_aForceDetective.FindValue(userid) == -1)
	{
		g_aForceDetective.Push(userid);
	}
	else
	{
		return false;
	}

	return true;
}

public int Native_AddRoundSlays(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if (TTT_IsClientValid(client))
	{
		int rounds = GetNativeCell(2);
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
		bool force = view_as<bool>(GetNativeCell(3));
		
		g_iRoundSlays[client] = rounds;
		
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
		
		return rounds;
	}
	
	return -1;
}

