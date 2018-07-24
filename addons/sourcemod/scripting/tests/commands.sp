#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>

public void OnPluginStart()
{
	RegConsoleCmd("sm_checkGOTV", Command_CheckGOTV);
	RegConsoleCmd("sm_reloadmap", Command_Reloadmap);
	RegConsoleCmd("sm_hud", Command_HUD);
	RegConsoleCmd("sm_endround", Command_EndRound);
	RegConsoleCmd("sm_give", Command_Give);
}

public Action Command_CheckGOTV(int client, int args)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		ReplyToCommand(client, "i: %d, Name: %N, IsFakeClient: %d, IsClientSourceTV: %d, IsClientConnected: %d, IsClientInGame: %d, IsPlayerAlive: %d", i, i, IsFakeClient(i), IsClientSourceTV(i), IsClientConnected(i), IsClientInGame(i), IsPlayerAlive(i));
	}
}


public Action Command_Reloadmap(int client, int args)
{
	char sMap[32];
	GetCurrentMap(sMap, sizeof(sMap));
	ForceChangeLevel(sMap, "Reloading map...");
}

public Action Command_HUD(int client, int args)
{
	if (args < 5)
	{
		ReplyToCommand(client, "sm_hud <Red> <Green> <Blue> <Alpha> <#UserID|Name> <message>");
		return Plugin_Handled;
	}
	
	int targets[129];
	bool ml = false;
	char sRed[6];
	char sGreen[6];
	char sBlue[6];
	char sAlpha[6];
	char buffer[MAX_NAME_LENGTH], sTarget[MAX_NAME_LENGTH];
	
	GetCmdArg(1, sRed, sizeof(sRed));
	GetCmdArg(2, sGreen, sizeof(sGreen));
	GetCmdArg(3, sBlue, sizeof(sBlue));
	GetCmdArg(4, sAlpha, sizeof(sAlpha));
	GetCmdArg(5, sTarget, sizeof(sTarget));

	int iRed = StringToInt(sRed);
	int iGreen = StringToInt(sGreen);
	int iBlue = StringToInt(sBlue);
	int iAlpha = StringToInt(sAlpha);
	
	int count = ProcessTargetString(sTarget, client, targets, sizeof(targets), COMMAND_FILTER_CONNECTED, buffer, sizeof(buffer), ml);
	if (count <= 0)
	{
		ReplyToCommand(client, "Invalid Target");
	}
	else for (int i = 0; i < count; i++)
	{
		int target = targets[i];
		
		if(target < 1 || !IsClientInGame(target))
			continue;

		char sText[256];

		if (args >= 6)
		{
			for (int j = 6; j <= args; j++)
			{
				char sBuffer[64];
				GetCmdArg(j, sBuffer, sizeof(sBuffer));
				Format(sText, sizeof(sText), "%s %s", sText, sBuffer);
			}
		}

		SetHudTextParams(0.34, -0.57, 7.0, iRed, iGreen, iBlue, iAlpha, 1, 2.0, 1.0, 1.0);
		ShowHudText(target, -1, sText);
	}
	
	return Plugin_Continue;
}

public Action Command_EndRound(int client, int args)
{
	if (args != 1)
	{
		ReplyToCommand(client, "sm_endround <delay in seconds>");
		return Plugin_Handled;
	}

	char sArg[12];
	GetCmdArg(1, sArg, sizeof(sArg));

	CS_TerminateRound(StringToFloat(sArg), CSRoundEnd_Draw, true);

	return Plugin_Handled;
}


public Action Command_Give(int client, int args)
{
	if (args != 1)
	{
		ReplyToCommand(client, "sm_give <weapon>");
		return Plugin_Handled;
	}

	char sArg[32];
	GetCmdArg(1, sArg, sizeof(sArg));
	Format(sArg, sizeof(sArg), "weapon_%s", sArg);
	int iWeapon = GivePlayerItem(client, sArg);
	EquipPlayerWeapon(client, iWeapon);

	return Plugin_Handled;
}
