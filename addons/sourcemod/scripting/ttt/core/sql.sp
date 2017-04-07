public void Callback_Karma(Handle owner, Handle hndl, const char[] error, any userid)
{
	if (hndl == null || strlen(error) > 0)
	{
		LogToFileEx(g_iConfig[s_errFile], "(Callback_Karma) Query failed: %s", error);
		return;
	}
}

public void Callback_InsertPlayer(Handle owner, Handle hndl, const char[] error, any userid)
{
	if (hndl == null || strlen(error) > 0)
	{
		LogToFileEx(g_iConfig[s_errFile], "(Callback_InsertPlayer) Query failed: %s", error);
		return;
	}
	else
	{
		int client = GetClientOfUserId(userid);

		if (TTT_IsClientValid(client))
		{
			g_bKarma[client] = true;
		}
	}
}
