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
	
	if (TTT_IsClientValid(client) && g_bKarma[client])
	{
		return g_iKarma[client];
	}

	return 0;
}

public int Native_GetClientRagdoll(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	int Body[Ragdolls];

	if (TTT_IsClientValid(client))
	{
		for (int i = 0; i < g_aRagdoll.Length; i++)
		{
			g_aRagdoll.GetArray(i, Body[0], sizeof(Body));
			if (Body[Victim] == client)
			{
				SetNativeArray(2, Body[0], sizeof(Body));
			}
			return 1;
		}
	}

	return 0;
}

public int Native_SetRagdoll(Handle plugin, int numParams)
{
	int Body[Ragdolls];

	GetNativeArray(1, Body[0], sizeof(Body));

	g_aRagdoll.PushArray(Body[0]);

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
	
	if (TTT_IsClientValid(client) && g_bKarma[client])
	{
		setKarma(client, karma);
		return g_iKarma[client];
	}

	return 0;
}

public int Native_AddClientKarma(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int karma = GetNativeCell(2);
	
	if (TTT_IsClientValid(client) && g_bKarma[client])
	{
		setKarma(client, g_iKarma[client]+karma);
		return g_iKarma[client];
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
		
		int Items[Ragdolls];
		
		for (int i = 0; i < iSize; i++)
		{
			g_aRagdoll.GetArray(i, Items[0]);
			
			if (Items[Victim] == client)
			{
				return Items[Found];
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
		
		int Items[Ragdolls];
		
		for (int i = 0; i < iSize; i++)
		{
			g_aRagdoll.GetArray(i, Items[0]);
			
			if (Items[Victim] == client)
			{
				return Items[Scanned];
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
	g_aLogs.PushString(message);
	
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

public int Native_ForceTraitor(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(TTT_IsClientValid(client))
	{
		if(g_aForceTraitor.FindValue(client) == -1 && g_aForceDetective.FindValue(client) == -1)
			g_aForceTraitor.Push(client);
		else 
			return false;
	}
		
	return true;
}

public int Native_ForceDetective(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(TTT_IsClientValid(client))
	{
		if(g_aForceTraitor.FindValue(client) == -1 && g_aForceDetective.FindValue(client) == -1)
			g_aForceDetective.Push(client);
		else 
			return false;
	}
		
	return true;
}