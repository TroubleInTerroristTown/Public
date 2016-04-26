public int Native_IsRoundActive(Handle plugin, int numParams)
{
    return g_bRoundStarted;
}

public int Native_GetClientRole(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if(TTT_IsClientValid(client))
		return g_iRole[client];
	return 0;
}

public int Native_GetClientKarma(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if(TTT_IsClientValid(client) && g_bKarma[client])
		return g_iKarma[client];
	return 0;
}

public int Native_GetClientCredits(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if(TTT_IsClientValid(client))
		return g_iCredits[client];
	return 0;
}

public int Native_SetClientRole(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int role = GetNativeCell(2);

	if(TTT_IsClientValid(client))
	{
		g_iRole[client] = role;
		TeamInitialize(client);
		return g_iRole[client];
	}
	else if(role < TTT_TEAM_UNASSIGNED || role > TTT_TEAM_DETECTIVE)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid role %d", role);
	return 0;
}

public int Native_SetClientKarma(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int karma = GetNativeCell(2);

	if(TTT_IsClientValid(client) && g_bKarma[client])
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

	if(TTT_IsClientValid(client))
	{
		setCredits(client, credits);
		return g_iCredits[client];
	}
	return 0;
}

public int Native_WasBodyFound(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if(TTT_IsClientValid(client))
	{
		int iSize = GetArraySize(g_hRagdollArray);

		if(iSize == 0)
			return false;

		int Items[Ragdolls];

		for(int i = 0; i < iSize; i++)
		{
			GetArrayArray(g_hRagdollArray, i, Items[0]);

			if(Items[victim] == client)
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

	if(TTT_IsClientValid(client))
	{
		int iSize = GetArraySize(g_hRagdollArray);

		if(iSize == 0)
			return false;

		int Items[Ragdolls];

		for(int i = 0; i < iSize; i++)
		{
			GetArrayArray(g_hRagdollArray, i, Items[0]);

			if(Items[victim] == client)
			{
				return Items[scanned];
			}
		}
	}
	return 0;
}

public int Native_RegisterCustomItem(Handle plugin, int numParams)
{
	if(numParams < 3)
		return false;

	char temp_short[16];
	char temp_long[64];
	GetNativeString(1, temp_short, sizeof(temp_short));
	GetNativeString(2, temp_long, sizeof(temp_long));

	int temp_price = GetNativeCell(3);
	int temp_role = GetNativeCell(4);
	
	int temp_item[Item];
	
	if((strlen(temp_short) < 1) || (strlen(temp_long) < 1) || (temp_price <= 0))
		return false;
	
	for (int i = 0; i < g_aCustomItems.Length; i++)
	{
		g_aCustomItems.GetArray(i, temp_item[0]);
		if(StrEqual(temp_item[Short], temp_short, false))
		{
			return false;
		}
	}

	Format(temp_item[Short], sizeof(temp_short), "%s", temp_short);
	Format(temp_item[Long], sizeof(temp_long), "%s", temp_long);
	temp_item[Price] = temp_price;
	temp_item[Role] = temp_role;
	g_aCustomItems.PushArray(temp_item[0]);
	
	if(g_iConfig[b_sortItems])
		Sort(g_iConfig[b_sortItemsOrder]);
	
	return true;
}

//TODO Improve sort algorithm (currently it's a bubble sort)
public void Sort(bool sort)
{
	int temp_item[Item];
	int temp_item2[Item];
	if (!sort)
	{
		for (int i = 1; i < g_aCustomItems.Length; i++)
		{
			for (int j = 0; j < (g_aCustomItems.Length - i); j++)
			{
				g_aCustomItems.GetArray(j, temp_item[0]);
				g_aCustomItems.GetArray(j + 1, temp_item2[0]);
				if (temp_item[Price] > temp_item2[Price])
				{
					g_aCustomItems.SwapAt(j, j + 1);
				}
			}
		}
	} else {
		for (int i = 1; i < g_aCustomItems.Length; i++)
		{
			for (int j = 0; j < (g_aCustomItems.Length - i); j++)
			{
				g_aCustomItems.GetArray(j, temp_item[0]);
				g_aCustomItems.GetArray(j + 1, temp_item2[0]);
				if (temp_item[Price] < temp_item2[Price])
				{
					g_aCustomItems.SwapAt(j, j + 1);
				}
			}
		}
	}
}

public int Native_GetCustomItemPrice(Handle plugin, int numParams)
{
	char temp_short[32];
	GetNativeString(1, temp_short, sizeof(temp_short));
	
	int temp_item[Item];
	
	for(int i = 0; i < g_aCustomItems.Length; i++)
	{
		g_aCustomItems.GetArray(i, temp_item[0]);
		if(strcmp(temp_short, temp_item[Short], false) == 0)
			return temp_item[Price];
	}

	return 0;
}

public int Native_GetCustomItemRole(Handle plugin, int numParams)
{
	char temp_short[32];
	GetNativeString(1, temp_short, sizeof(temp_short));
	
	int temp_item[Item];
	
	for(int i = 0; i < g_aCustomItems.Length; i++)
	{
		g_aCustomItems.GetArray(i, temp_item[0]);
		if(strcmp(temp_short, temp_item[Short], false) == 0)
			return temp_item[Role];
	}
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