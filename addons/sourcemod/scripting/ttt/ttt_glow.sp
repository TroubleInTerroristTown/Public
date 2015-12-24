#include <sourcemod>
#include <sdkhooks>
#include <ttt>
#include <CustomPlayerSkins>

int g_iColorTraitor[3] =  {255, 0, 0};
int g_iColorDetective[3] =  {0, 0, 255};

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Glow"

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = "Bara & zipcore",
	description = TTT_PLUGIN_DESCRIPTION,
	version = TTT_PLUGIN_VERSION,
	url = TTT_PLUGIN_URL
};

public void OnPluginStart()
{
	StartGlowTimer();
}

void StartGlowTimer()
{
	CreateTimer(1.5, Timer_SetupGlow, _, TIMER_REPEAT);
}

public Action Timer_SetupGlow(Handle timer, any data)
{

	LoopValidClients(client)
		if (IsPlayerAlive(client))
			SetupGlowSkin(client)
	
	return Plugin_Continue;
}

void SetupGlowSkin(int client)
{
	CPS_RemoveSkin(client);
	
	if(!TTT_IsRoundActive())
		return;
	
	char sModel[PLATFORM_MAX_PATH];
	GetClientModel(client, sModel, sizeof(sModel));
	CPS_SetSkin(client, sModel, CPS_RENDER);
		
	int iSkin = CPS_GetSkin(client);
	
	if(iSkin == -1)
		return;
		
	if (SDKHookEx(iSkin, SDKHook_SetTransmit, OnSetTransmit_GlowSkin))
		SetupGlow(client, iSkin);
}

void SetupGlow(int client, int iSkin)
{
	int iOffset;
	
	if (!iOffset && (iOffset = GetEntSendPropOffs(iSkin, "m_clrGlow")) == -1)
		return;
	
	SetEntProp(iSkin, Prop_Send, "m_bShouldGlow", true, true);
	
	int iRed = 255;
	int iGreen = 255;
	int iBlue = 255;
	
	if(TTT_GetClientRole(client) == TTT_TEAM_DETECTIVE)
	{
		iRed = g_iColorDetective[0];
		iGreen = g_iColorDetective[1];
		iBlue = g_iColorDetective[2];
	}
	else if(TTT_GetClientRole(client) == TTT_TEAM_TRAITOR)
	{
		iRed = g_iColorTraitor[0];
		iGreen = g_iColorTraitor[1];
		iBlue = g_iColorTraitor[2];
	}
	
	SetEntData(iSkin, iOffset, iRed, _, true);
	SetEntData(iSkin, iOffset + 1, iGreen, _, true);
	SetEntData(iSkin, iOffset + 2, iBlue, _, true);
	SetEntData(iSkin, iOffset + 3, 255, _, true);
}

public Action OnSetTransmit_GlowSkin(int iSkin, int client)
{
	if(IsFakeClient(client))
		return Plugin_Handled;
		
	if(!IsPlayerAlive(client))
		return Plugin_Handled;
	
	if(!TTT_IsRoundActive())
		return Plugin_Handled;
		
	int target = -1;
	LoopValidClients(i)
	{
		if(!IsPlayerAlive(i))
			continue;
		
		if(!CPS_HasSkin(i))
			continue;
			
		if(EntRefToEntIndex(CPS_GetSkin(i)) != iSkin)
			continue;
			
		target = i;
	}
	
	if(target == -1)
		return Plugin_Handled;
	
	if(TTT_GetClientRole(client) == TTT_TEAM_DETECTIVE && TTT_GetClientRole(client) == TTT_GetClientRole(target))
		return Plugin_Continue;
	
	if(TTT_GetClientRole(client) == TTT_TEAM_TRAITOR && TTT_GetClientRole(client) == TTT_GetClientRole(target))
		return Plugin_Continue;
	
	return Plugin_Handled;
}