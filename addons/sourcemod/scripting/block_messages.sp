#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

public Plugin myinfo = 
{
	name = "Block messages",
	author = "Bara",
	description = "",
	version = "1.0.0",
	url = "csgottt.com"
};

public void OnPluginStart()
{
	CreateConVar("block_messages_version", "1.0.0", "Plugin to block some usermessage messages", FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	
	HookUserMessage(GetUserMessageId("TextMsg"), UserMsg_TextMsg, true);
}

public Action UserMsg_TextMsg(UserMsg msg_id, Protobuf msg, const int[] players, int playersNum, bool reliable, bool init)
{
	if(reliable)
	{
		char sText[64], sFileText[64];
		msg.ReadString("params", sText, sizeof(sText), 0);
		
		char sPath[PLATFORM_MAX_PATH + 1];
		BuildPath(Path_SM, sPath, sizeof(sPath), "configs/ttt/block_messages.ini");

		Handle hFile = OpenFile(sPath, "rt");

		if (!FileExists(sPath))
		{
			SetFailState("Can't find the following file: \"configs/ttt/block_messages.ini\"");
			return Plugin_Continue;
		}

		while(!IsEndOfFile(hFile) && ReadFileLine(hFile, sFileText, sizeof(sFileText)))
		{
			if (StrContains(sText, sFileText, false) != -1)
			{
				return Plugin_Handled;
			}
		}
		
		delete hFile;
	}
	return Plugin_Continue;
}