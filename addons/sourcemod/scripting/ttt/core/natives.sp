public int Native_IsRoundActive(Handle plugin, int numParams)
{
	return g_bRoundStarted;
}

public int Native_GetClientRole(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if (TTT_IsClientValid(client))
		return g_iRole[client];
	return 0;
}

public int Native_GetClientKarma(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if (TTT_IsClientValid(client) && g_bKarma[client])
		return g_iKarma[client];
	return 0;
}

public int Native_GetClientCredits(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if (TTT_IsClientValid(client))
		return g_iCredits[client];
	return 0;
}

public int Native_GetClientRagdoll(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	int Body[Ragdolls];
	if (TTT_IsClientValid(client))
	{
		for (int i = 0; i < GetArraySize(g_hRagdollArray); i++)
		{
			GetArrayArray(g_hRagdollArray, i, Body[0], sizeof(Body));
			if(Body[victim] == client)
			{
				SetNativeArray(2, Body[0], sizeof(Body));
			}
			return 1;
		}
	}
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
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid role %d", role);
	return 0;
}

public int Native_SetClientKarma(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int karma = GetNativeCell(2);
	
	if (TTT_IsClientValid(client) && g_bKarma[client])
	{
		setKarma(client, karma);
		return g_iKarma[client];
	}
	return 0;
}

public int Native_SetClientCredits(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int credits = GetNativeCell(2);
	
	if (TTT_IsClientValid(client))
	{
		setCredits(client, credits);
		return g_iCredits[client];
	}
	return 0;
}

public int Native_WasBodyFound(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if (TTT_IsClientValid(client))
	{
		int iSize = GetArraySize(g_hRagdollArray);
		
		if (iSize == 0)
			return false;
		
		int Items[Ragdolls];
		
		for (int i = 0; i < iSize; i++)
		{
			GetArrayArray(g_hRagdollArray, i, Items[0]);
			
			if (Items[victim] == client)
			{
				return Items[found];
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
		int iSize = GetArraySize(g_hRagdollArray);
		
		if (iSize == 0)
			return false;
		
		int Items[Ragdolls];
		
		for (int i = 0; i < iSize; i++)
		{
			GetArrayArray(g_hRagdollArray, i, Items[0]);
			
			if (Items[victim] == client)
			{
				return Items[scanned];
			}
		}
	}
	return 0;
}

public int Native_LogString(Handle plugin, int numParams)
{
	char message[512];
	GetNativeString(1, message, sizeof(message));
	
	PushArrayString(g_hLogsArray, message);
	
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

public int Native_OverrideConfigInt(Handle plugin, int numParams)
{
	g_iConfig[GetNativeCell(1)] = GetNativeCell(2);
	
	return;
}

public int Native_OverrideConfigBool(Handle plugin, int numParams)
{
	g_iConfig[GetNativeCell(1)] = GetNativeCell(2);
	
	return;
}

public int Native_OverrideConfigFloat(Handle plugin, int numParams)
{
	g_iConfig[GetNativeCell(1)] = GetNativeCell(2);
	
	return;
}

public int Native_OverrideConfigString(Handle plugin, int numParams)
{
	int size = GetNativeCell(3);
	char[] buffer = new char[size];
	GetNativeString(2, buffer, size);
	strcopy(view_as<char>(g_iConfig[GetNativeCell(1)]), size, buffer);
	
	return;
}

public int Native_ReloadConfig(Handle plugin, int numParams)
{
	SetupConfig();
	
	return;
} 