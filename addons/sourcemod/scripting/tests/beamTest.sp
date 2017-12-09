#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <ttt>

#define MODEL_SPRITE "materials/sprites/laserbeam.vmt"

int g_iRed[4] = { 255, 0, 0, 60 };
int g_iGreen[4] = { 0, 255, 0, 60 };
int g_iLaser[4] =  { 255, 0, 255, 40 };
char g_sLaser[16] =  { "255 0 255" };

int g_iStart[MAXPLAYERS + 1] =  { -1, ... };
int g_iEnd[MAXPLAYERS + 1] =  { -1, ... };
int g_iEnt[MAXPLAYERS + 1] =  { -1, ... };

float g_fStart[MAXPLAYERS + 1][3];

int g_iSprite = -1;

public void OnPluginStart()
{
	g_iSprite = PrecacheModel(MODEL_SPRITE);
}

public void OnMapStart()
{
	g_iSprite = PrecacheModel(MODEL_SPRITE);
}

public int TTT_OnButtonPress(int client, int button)
{
	if (button & IN_USE)
	{
		GetCollisionPoint(client, g_fStart[client]);
		
		float fOrigin[3];
		GetClientAbsOrigin(client, fOrigin);
		
		float fDistance = GetVectorDistance(g_fStart[client], fOrigin);
		
		if (fDistance > 90)
		{
			PrintToChat(client, "Point is too far away... (Current Distance: %.0f - Max. Distance: %.0f)", fDistance, 90.0);
			
			g_fStart[client][0] = 0.0;
			g_fStart[client][1] = 0.0;
			g_fStart[client][2] = 0.0;
		}
	}
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if (TTT_IsClientValid(client))
	{
		if (g_fStart[client][0] != 0.0 && g_fStart[client][1] != 0.0 && g_fStart[client][2] != 0.0)
		{
			float fOrigin[3], fPOrigin[3];
			GetCollisionPoint(client, fOrigin);
			GetClientAbsOrigin(client, fPOrigin);
			float fDistance = GetVectorDistance(g_fStart[client], fOrigin);
			
			if (fDistance >= 60.0 && fDistance <= 350.0)
			{
				fDistance = GetVectorDistance(fPOrigin, fOrigin);
				
				if (fDistance > 90)
				{
					TE_SetupBeamPoints(g_fStart[client], fOrigin, g_iSprite, 0, 0, 0, 0.1, 1.0, 1.0, 10, 0.0, g_iRed, 0);
					TE_SendToClient(client);
				}
				else
				{
					Handle hTrace = TR_TraceRayFilterEx(g_fStart[client], fOrigin, MASK_SOLID_BRUSHONLY, RayType_EndPoint, TR_CheckFilter);
					
					if (!TR_DidHit(hTrace))
					{
						TE_SetupBeamPoints(g_fStart[client], fOrigin, g_iSprite, 0, 0, 0, 0.1, 1.0, 1.0, 10, 0.0, g_iGreen, 0);
						TE_SendToClient(client);
					}
					else
					{
						TE_SetupBeamPoints(g_fStart[client], fOrigin, g_iSprite, 0, 0, 0, 0.1, 1.0, 1.0, 10, 0.0, g_iRed, 0);
						TE_SendToClient(client);
					}
					
					delete hTrace;
				}
			}
			else
			{
				TE_SetupBeamPoints(g_fStart[client], fOrigin, g_iSprite, 0, 0, 0, 0.1, 1.0, 1.0, 10, 0.0, g_iRed, 0);
				TE_SendToClient(client);
			}
		}
	}
}

public bool TR_CheckFilter(int entity, int contestsMask, int data)
{
	return entity == data;
}

public int TTT_OnButtonRelease(int client, int button)
{
	if (button & IN_USE)
	{
		float fOrigin[3], fPOrigin[3];
		GetCollisionPoint(client, fOrigin);
		GetClientAbsOrigin(client, fPOrigin);
		
		float fDistance = GetVectorDistance(fOrigin, fPOrigin);
		
		if (g_fStart[client][0] != 0.0 && g_fStart[client][1] != 0.0 && g_fStart[client][2] != 0.0)
		{
			fDistance = GetVectorDistance(g_fStart[client], fOrigin);
			if (fDistance < 60.0 || fDistance > 350.0)
			{
				if (fDistance > 350.0)
				{
					PrintToChat(client, "Points are too far away... (Current Distance: %.0f - Max. Distance: %.0f)", fDistance, 350.0);
				}
				else if (fDistance < 60.0)
				{
					PrintToChat(client, "Points are too short... (Current Distance: %.0f - Max. Distance: %.0f)", fDistance, 90.0);
				}
				
				g_fStart[client][0] = 0.0;
				g_fStart[client][1] = 0.0;
				g_fStart[client][2] = 0.0;
				
				return;
			}
			
			GetCollisionPoint(client, fOrigin);
			
			char sStart[32], sEnd[32], sBeam[32];
			
			// Create start point
			Format(sStart, sizeof(sStart), "startBeam%d", g_iStart[client]);
			g_iStart[client] = CreateEntityByName("env_beam");
			DispatchKeyValue(g_iStart[client], "targetname", sStart);
			if (DispatchSpawn(g_iStart[client]))
			{
				TeleportEntity(g_iStart[client], g_fStart[client], NULL_VECTOR, NULL_VECTOR);
				
				CreateTimer(3.0, Timer_KillStart, GetClientUserId(client));
			}
			
			// Create end point
			Format(sEnd, sizeof(sEnd), "stopBeam%d", g_iEnd[client]);
			g_iEnd[client] = CreateEntityByName("env_beam");
			DispatchKeyValue(g_iEnd[client], "targetname", sEnd);
			if (DispatchSpawn(g_iEnd[client]))
			{
				TeleportEntity(g_iEnd[client], fOrigin, NULL_VECTOR, NULL_VECTOR);
				
				CreateTimer(3.0, Timer_KillEnd, GetClientUserId(client));
			}
			
			// Create env_beam entity
			g_iEnt[client] = CreateEntityByName("env_beam");
			IntToString(GetClientUserId(client), sBeam, sizeof(sBeam));
			DispatchKeyValue(g_iEnt[client], "targetname", sBeam);
			DispatchKeyValue(g_iEnt[client], "texture", MODEL_SPRITE);
			DispatchKeyValue(g_iEnt[client], "TouchType", "1");
			DispatchKeyValue(g_iEnt[client], "BoltWidth", "10.0");
			DispatchKeyValue(g_iEnt[client], "life", "0");
			DispatchKeyValue(g_iEnt[client], "rendercolor", g_sLaser);
			DispatchKeyValue(g_iEnt[client], "StrikeTime", "0.1");
			DispatchKeyValue(g_iEnt[client], "renderamt", "255");
			DispatchKeyValue(g_iEnt[client], "HDRColorScale", "1.0");
			DispatchKeyValue(g_iEnt[client], "decalname", "redglowfade");
			DispatchKeyValue(g_iEnt[client], "TextureScroll", "35");
			DispatchKeyValue(g_iEnt[client], "LightningStart", sStart);
			DispatchKeyValue(g_iEnt[client], "LightningEnd", sEnd);
			
			if (g_iEnt[client])
			{
				ActivateEntity(g_iEnt[client]);
				AcceptEntityInput(g_iEnt[client], "TurnOn");
				AcceptEntityInput(g_iEnt[client], "Alpha 40");
				HookSingleEntityOutput(g_iEnt[client], "OnTouchedByEntity", OnBeamTouch, true);
			}
			
			// Create "debug" beam
			TE_SetupBeamPoints(g_fStart[client], fOrigin, g_iSprite, 0, 0, 0, 3.0, 1.0, 1.0, 10, 0.0, g_iLaser, 0);
			TE_SendToAll();
			
			g_fStart[client][0] = 0.0;
			g_fStart[client][1] = 0.0;
			g_fStart[client][2] = 0.0;
		}
	}
}

public void OnBeamTouch(const char[] output, int caller, int activator, float delay)
{
	char sUserID[128];
	GetEntPropString(caller, Prop_Data, "m_iName", sUserID, sizeof(sUserID)); 
	int client = GetClientOfUserId(StringToInt(sUserID));
	
	if (TTT_IsClientValid(client))
	{
		// PrintToChat(client, "Activator: %N", activator);
		// if(activator != client)
		// {
			// if(TTT_GetClientRole(activator) != TTT_GetClientRole(client))
			// {
				// SDKHooks_TakeDamage(victim, entity, attacker, g_cDamage.FloatValue, DMG_POISON, entity);
			SDKHooks_TakeDamage(activator, g_iEnt[client], client, 4.0, DMG_ENERGYBEAM, -1);
			// }
			AcceptEntityInput(caller, "TurnOff");
			AcceptEntityInput(caller, "TurnOn");
			
			g_iEnt[client] = -1;
		// }
	}
}

public Action Timer_KillStart(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	
	if (TTT_IsClientValid(client) && IsValidEntity(g_iStart[client]))
	{
		RemoveEdict(g_iStart[client]);
		g_iStart[client] = -1;
	}
}

public Action Timer_KillEnd(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	
	if (TTT_IsClientValid(client) && IsValidEntity(g_iEnd[client]))
	{
		RemoveEdict(g_iEnd[client]);
		g_iEnd[client] = -1;
	}
}

void GetCollisionPoint(int client, float pos[3])
{
	float vOrigin[3];
	float vAngles[3];
	
	GetClientEyePosition(client, vOrigin);
	GetClientEyeAngles(client, vAngles);
	
	Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_PLAYERSOLID, RayType_Infinite, TR_Filter);
	
	if(TR_DidHit(trace))
	{
		TR_GetEndPosition(pos, trace);
		delete trace;
		return;
	}
	delete trace;
}

bool TR_Filter(int entity, int contentsMask)
{
	return entity > MaxClients;
}  
