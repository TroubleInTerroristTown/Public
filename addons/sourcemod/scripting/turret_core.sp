#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <autoexecconfig>
#pragma newdecls required
#define LoopIngamePlayers(%1) for(int %1=1;%1<=MaxClients;++%1) if(IsClientInGame(%1) && !IsFakeClient(%1))

int g_Turrets[MAXPLAYERS+1]= {-1,...};
float damageTakenByTurrets[MAXPLAYERS+1]= {0.0,...};
bool g_TurretCanShoot[MAXPLAYERS+1]= {true,...};
float g_fTurretAim[MAXPLAYERS+1]={0.0,...};
bool g_bTurretAim[MAXPLAYERS+1]= {true,...};
int g_iTurrets_Team[MAXPLAYERS+1]= {-1,...};
bool g_CanAttackClient[MAXPLAYERS+1] = {false,...};

int g_BeamSprite = -1;
int g_HaloSprite = -1;

Handle Turret_OnTurretDead = null;
public Plugin myinfo = 
{
	name = "CS:GO Turret Core",
	author = "Tast - SDC Edited by Kento & e54385991",
	description = "",
	version = "1.0",
	url = "<- URL ->"
}

ConVar Cvar_Enable = null;
ConVar Cvar_Health = null;
ConVar Cvar_Damage = null;
ConVar Cvar_Rate = null;
ConVar Cvar_CheckTeam = null;


public void OnPluginStart()
{
	//ConVar
	AutoExecConfig_SetFile("csgo_turret");
	Cvar_Enable = AutoExecConfig_CreateConVar("sd_turret_enable"      , "1", "", FCVAR_NONE, true, 0.0, true, 1.0);
	Cvar_Health = AutoExecConfig_CreateConVar("sd_turret_health"	, 	"300.0"		, "Turrent HP",FCVAR_NONE, true, 1.0, true, 30000.0);
	Cvar_Damage = AutoExecConfig_CreateConVar("sd_turret_damage"	, 	"10"		, "Turrent Damage",FCVAR_NONE);
	Cvar_Rate =   AutoExecConfig_CreateConVar("sd_turret_rate"      , "0.3", "Time Between Turrent Fires", FCVAR_NONE, true, 0.0001, true, 200.0);
	Cvar_CheckTeam =   AutoExecConfig_CreateConVar("sd_turret_checkteam"      ,  "2", "1 = Check Team T / CT   2 = Any Client not contain yourself  3 = API Mode g_CanAttackClient Target", FCVAR_NONE, true, 1.0, true, 3.0);
	
	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();
	//
	
	HookEvent("round_start", Event_RoundStart);
	RegAdminCmd("testturret", CreateTurrettest,ADMFLAG_ROOT);
	
	Turret_OnTurretDead = CreateGlobalForward("Turret_OnTurretDead", ET_Event, Param_Cell, Param_Cell);
}



public void OnClientDisconnect(int client){
	DestroyTurrets(client);
	ResetPlayerVars(client);
}

public Action CreateTurrettest(int client, int args){
	CreateTurret(client);
}

public void Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	InitVars();
}
public void InitVars()
{
	for (int i = 1; i < MaxClients; i++)
	{
		g_Turrets[i] = -1;
		damageTakenByTurrets[i] = 0.0;
		g_TurretCanShoot[i] = true;
		g_fTurretAim[i] = 0.0;
		g_bTurretAim[i] = true;
		g_CanAttackClient[i] = false;
		g_iTurrets_Team[i] = -1;
	}
}

public void ResetPlayerVars(int i)
{
	g_Turrets[i] = -1;
	damageTakenByTurrets[i] = 0.0;
	g_TurretCanShoot[i] = true;
	g_fTurretAim[i] = 0.0;
	g_bTurretAim[i] = true;
	g_CanAttackClient[i] = false;
	g_iTurrets_Team[i] = -1;
}


public void OnMapStart(){
	PrecacheSound("weapons/sg556/sg556-1.wav");
	PrecacheSound("player/damage1.wav");
	PrecacheSound("player/damage2.wav");
	PrecacheSound("player/damage3.wav");
	g_BeamSprite = PrecacheModel("materials/sprites/laserbeam.vmt");
	g_HaloSprite = PrecacheModel("materials/sprites/halo.vmt");
	
	PrecacheSound("training/light_on.wav");
	PrecacheSound("training/gallery_stop.wav");
	
	//PrecacheSound("buttons/blip2.wav");
	//-----------------------------------------------------------------------
	
	PrecacheModel("models/Combine_turrets/floor_turret.mdl");
	
	AddFileToDownloadsTable("models/Combine_turrets/floor_turret.mdl");
	AddFileToDownloadsTable("models/Combine_turrets/Floor_turret.dx90.vtx");
	AddFileToDownloadsTable("models/Combine_turrets/floor_turret.mdl");
	AddFileToDownloadsTable("models/Combine_turrets/Floor_turret.phy");
	AddFileToDownloadsTable("models/Combine_turrets/Floor_turret.sw.vtx");
	AddFileToDownloadsTable("models/Combine_turrets/floor_turret.vvd");
	
	AddFileToDownloadsTable("materials/models/Combine_turrets/floor_turret/combine_gun002.vmt");
	AddFileToDownloadsTable("materials/models/Combine_turrets/floor_turret/floor_turret_citizen.vmt");
	AddFileToDownloadsTable("materials/models/Combine_turrets/floor_turret/floor_turret_citizen2.vmt");
	AddFileToDownloadsTable("materials/models/Combine_turrets/floor_turret/floor_turret_citizen4.vmt");
	AddFileToDownloadsTable("materials/models/Combine_turrets/floor_turret/combine_gun002.vtf");
	AddFileToDownloadsTable("materials/models/Combine_turrets/floor_turret/combine_gun002_mask.vtf");
	AddFileToDownloadsTable("materials/models/Combine_turrets/floor_turret/combine_gun002_normal.vtf");
	AddFileToDownloadsTable("materials/models/Combine_turrets/floor_turret/floor_turret_citizen.vtf");
	AddFileToDownloadsTable("materials/models/Combine_turrets/floor_turret/floor_turret_citizen_glow.vtf");
	AddFileToDownloadsTable("materials/models/Combine_turrets/floor_turret/floor_turret_citizen_noalpha.vtf");
	AddFileToDownloadsTable("materials/models/Combine_turrets/floor_turret/floor_turret_citizen2.vtf");
	AddFileToDownloadsTable("materials/models/Combine_turrets/floor_turret/floor_turret_citizen2_noalpha.vtf");
	AddFileToDownloadsTable("materials/models/Combine_turrets/floor_turret/floor_turret_citizen4.vtf");
	AddFileToDownloadsTable("materials/models/Combine_turrets/floor_turret/floor_turret_citizen4_noalpha.vtf");
	AddFileToDownloadsTable("materials/models/Combine_turrets/floor_turret/floor_turret_citizen4Normal.vtf");
	AddFileToDownloadsTable("materials/models/Combine_turrets/floor_turret/floor_turret_citizenNormal.vtf");
}

#define EF_BONEMERGE                (1 << 0)
#define EF_NOSHADOW                 (1 << 4)
#define EF_NORECEIVESHADOW          (1 << 6)
#define EF_PARENT_ANIMATES          (1 << 9)

void CreateTurret(int client){
	
	if(!Cvar_Enable.BoolValue)
		return;
	
	if(!IsPlayerAlive(client)){
		return;
	}
	
	if(g_Turrets[client] != -1)
		return;
	
	int ent = CreateEntityByName("prop_dynamic_override");
	
	if(ent == -1){
		return;
	}
	
	SetEntityModel(ent, "models/Combine_turrets/floor_turret.mdl");
	DispatchKeyValue(ent, "disablereceiveshadows", "1");
	DispatchKeyValue(ent, "disableshadows", "1");
	DispatchKeyValue(ent, "solid", "6");
	SetEntProp(ent, Prop_Data, "m_CollisionGroup", 1); // stop collisions with players or world
	SetEntProp(ent, Prop_Send, "m_fEffects", EF_BONEMERGE|EF_NOSHADOW|EF_NORECEIVESHADOW|EF_PARENT_ANIMATES);
	
	
	DispatchSpawn(ent);
	ActivateEntity(ent);
	
	SetVariantString("deploy");			//m_nSequence = 1
	AcceptEntityInput(ent, "SetAnimation", -1, -1, 0);
	
	
	//--------------------------------------
	float pos[3], angle[3], vecDir[3];
	
	GetClientEyeAngles(client, angle);
	GetAngleVectors(angle, vecDir, NULL_VECTOR, NULL_VECTOR);
	GetClientEyePosition(client, pos); 
	
	pos[0]+=vecDir[0]*100.0;
	pos[1]+=vecDir[1]*100.0;
	pos[2]-=60.0;
	angle[0]=0.0;
	TeleportEntity(ent, pos, angle, NULL_VECTOR);
	
	//VARS
	g_Turrets[client] = ent;
	damageTakenByTurrets[client] = 0.0;
	g_iTurrets_Team[client] = GetClientTeam(client);
	//VARS
	
	if(GetRandomInt(1,0))
		EmitSoundToAll("training/gallery_stop.wav",ent,SNDCHAN_AUTO,SNDLEVEL_NORMAL,SND_NOFLAGS,SNDVOL_NORMAL,SNDPITCH_NORMAL,-1,pos,NULL_VECTOR,true,0.0);
	else EmitSoundToAll("training/light_on.wav",ent,SNDCHAN_AUTO,SNDLEVEL_NORMAL,SND_NOFLAGS,SNDVOL_NORMAL,SNDPITCH_NORMAL,-1,pos,NULL_VECTOR,true,0.0);
	
	
	SDKHook(ent, SDKHook_OnTakeDamage, TurretTakeDamage);
	
	HookSingleEntityOutput(ent, "OnAnimationDone", OnAnimationDone, false);
}

public Action TurretTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (attacker < 1 || attacker > MAXPLAYERS)
		return Plugin_Continue;
	
	int client_index = -1;
	
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		if (g_Turrets[i] == victim)
		{
			client_index = i;
			break;
		}
	}
	
	if (client_index == -1)
		return Plugin_Continue;
	
	
	if(Cvar_CheckTeam.IntValue == 1 && client_index == GetClientTeam(attacker)){
		return Plugin_Continue;
	}
	if(Cvar_CheckTeam.IntValue == 2){
		if(client_index == attacker) return Plugin_Continue;
	}
	if(Cvar_CheckTeam.IntValue == 3 && !g_CanAttackClient[attacker]){
		return Plugin_Continue;
	}
	
	
	damageTakenByTurrets[client_index] += damage;
	
	if (damageTakenByTurrets[client_index] > Cvar_Health.FloatValue)
	{
		DestroyTurrets(client_index);
		Call_StartForward(Turret_OnTurretDead);
		Call_PushCell(client_index);
		Call_PushCell(attacker);
		Call_Finish();
	}
	
	return Plugin_Continue;
}

stock int GetTurretTeam(int ent){
	
	int iTeam = -1;
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		if (g_Turrets[i] == ent)
		{
			iTeam = g_iTurrets_Team[i];
			break;
		}
	}
	
	return iTeam;
}


stock int GetTurretOwner(int ent){
	
	int Owner = -1;
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		if (g_Turrets[i] == ent)
		{
			Owner = i;
			break;
		}
	}
	
	if(!IsValidClient(Owner))
		return -1;
	
	return Owner;
}







public void DestroyTurrets(int client_index)
{
	if (g_Turrets[client_index] != -1 && g_Turrets[client_index] > MaxClients && IsValidEdict(g_Turrets[client_index]))
	{
		AcceptEntityInput(g_Turrets[client_index], "Kill");
	}
	g_Turrets[client_index] = -1;
}


public void OnAnimationDone(const char[] output, int caller, int activator, float delay)
{
	if(IsValidEntity(caller)){
		//int owner = GetEntPropEnt(caller, Prop_Data, "m_hOwnerEntity")
		
		SetVariantString("idlealert");
		AcceptEntityInput(caller, "SetAnimation", -1, -1, 0);
	}
}


//Cvar_CheckTeam
//g_CanAttackClient[i]

void TickTurret(int client){
	
	if(!IsValidEntity(g_Turrets[client])){
		return;
	}
	float TurretPos[3];
	GetEntPropVector(g_Turrets[client], Prop_Send, "m_vecOrigin", TurretPos);
	int iTeam = GetTurretTeam(g_Turrets[client]); 
	
	//if(iTeam != GetClientTeam(client)) ..
	for(int i=1;i<MaxClients;++i){
		if(IsClientInGame(i) && IsPlayerAlive(i))
		{
			if(Cvar_CheckTeam.IntValue == 1 && iTeam == GetClientTeam(i)){
				continue;
			}
			if(Cvar_CheckTeam.IntValue == 2){
				int owner = GetTurretOwner(g_Turrets[client]);
				if(owner != -1 && owner == i) continue;
			}
			
			if(Cvar_CheckTeam.IntValue == 3 && !g_CanAttackClient[i]){
				continue;
			}
			
			float EnemyPos[3];
			GetClientEyePosition(i, EnemyPos);
			float m_vecMins[3];
			float m_vecMaxs[3];
			GetEntPropVector(g_Turrets[client], Prop_Send, "m_vecMins", m_vecMins);
			GetEntPropVector(g_Turrets[client], Prop_Send, "m_vecMaxs", m_vecMaxs);
			
			TR_TraceHullFilter(TurretPos, EnemyPos, m_vecMins, m_vecMaxs, MASK_SOLID, DontHitOwnerOrNade, client);
			if(TR_GetEntityIndex() == i){
				TurretTickFollow(client, i);
				return;
			}
			
		}
	}
	TurretTickIdle(client);
}

void TurretTickFollow(int owner, int player){
	float TurretPos[3], EnemyPos[3],EnemyAngle[3], TuretAngle[3], vecDir[3];
	
	GetEntPropVector(g_Turrets[owner], Prop_Send, "m_angRotation", TuretAngle);
	GetEntPropVector(g_Turrets[owner], Prop_Send, "m_vecOrigin", TurretPos);
	GetClientAbsOrigin(player, EnemyPos);
	
	MakeVectorFromPoints(EnemyPos, TurretPos, vecDir);
	GetVectorAngles(EnemyPos, EnemyAngle);
	GetVectorAngles(vecDir, vecDir);
	vecDir[2]=0.0;
	
	TuretAngle[1]+=180.0;
	
	float m_iDegreesY = (((vecDir[2]-TuretAngle[2])+30.0)/60.0);
	float m_iDegreesX = (((vecDir[1]-TuretAngle[1])+30.0)/60.0);
	
	if(m_iDegreesX < 0.0 || m_iDegreesX > 2.2){
		TurretTickIdle(owner);
		return;
	}
	
	g_fTurretAim[owner] = m_iDegreesX;
	SetEntPropFloat(g_Turrets[owner], Prop_Send, "m_flPoseParameter", m_iDegreesX, 0);
	SetEntPropFloat(g_Turrets[owner], Prop_Send, "m_flPoseParameter", m_iDegreesY, 1);
	
	if(g_TurretCanShoot[owner]){
		SetVariantString("retract");
		AcceptEntityInput(g_Turrets[owner], "SetAnimationNoReset", -1, -1, 0);
		
		TurretPos[2]+=50.0;
		EnemyPos[2]=FloatAdd(EnemyPos[2], GetRandomFloat(10.0, 70.0));
		EnemyPos[0]=FloatAdd(EnemyPos[0], GetRandomFloat(-5.0, 5.0));
		EnemyPos[1]=FloatAdd(EnemyPos[1], GetRandomFloat(-5.0, 5.0));
		
		if(GetTurretTeam(g_Turrets[owner]) == CS_TEAM_CT)
			TE_SetupBeamPoints(TurretPos, EnemyPos, g_BeamSprite, g_HaloSprite, 0, 30, GetRandomFloat(0.1, 0.3), 1.0, 1.0, 0, 1.0, {128,128,64, 100}, 0);
		else if(GetTurretTeam(g_Turrets[owner]) == CS_TEAM_T)
			TE_SetupBeamPoints(TurretPos, EnemyPos, g_BeamSprite, g_HaloSprite, 0, 30, GetRandomFloat(0.1, 0.3), 1.0, 1.0, 0, 1.0, {102,153,255, 100}, 0);
		else 	TE_SetupBeamPoints(TurretPos, EnemyPos, g_BeamSprite, g_HaloSprite, 0, 30, GetRandomFloat(0.1, 0.3), 1.0, 1.0, 0, 1.0, {204,0,51, 100}, 0);
		TE_SendToAll();
		
		int hp = Cvar_Damage.IntValue;
		
		SDKHooks_TakeDamage(player, 0, owner, float(hp * 2), DMG_BULLET, -1 , TurretPos, EnemyPos); //http://docs.sourcemod.net/api/index.php?fastload=show&id=1028&
		
		
		char szFile[128];
		Format(szFile, sizeof(szFile), "player/damage%d.wav", GetRandomInt(1, 3));
		EmitSoundToClient(player, szFile);
		EmitAmbientSound("weapons/sg556/sg556-1.wav", TurretPos);
		
		g_TurretCanShoot[owner] = false;
		
		int ref = EntIndexToEntRef(owner);
		
		CreateTimer(Cvar_Rate.FloatValue, TurretSetState, ref);
	}
}

public Action TurretSetState(Handle Timer, any ref){
	
	int entity = EntRefToEntIndex(ref);
	
	if (entity != INVALID_ENT_REFERENCE)
	{
		g_TurretCanShoot[entity] = true;
	}
}
public void OnGameFrame(){
	LoopIngamePlayers(i){
		if(g_Turrets[i] != -1 && IsValidEdict(g_Turrets[i])) TickTurret(i);
	}
}


public bool DontHitOwnerOrNade(int entity, int contentsMask, any data){
	if(entity > 0 && entity < MaxClients && IsClientInGame(entity)) 
		return true;
	return false;
}


void TurretTickIdle(int client){
	if(g_fTurretAim[client] <= 0.1) g_bTurretAim[client] = true;
	if(g_fTurretAim[client] >= 0.9) g_bTurretAim[client] = false;	
	
	if(g_bTurretAim[client])
		g_fTurretAim[client] = FloatAdd(g_fTurretAim[client], 0.01);
	else 	g_fTurretAim[client] = FloatSub(g_fTurretAim[client], 0.01);
	
	SetEntPropFloat(g_Turrets[client], Prop_Send, "m_flPoseParameter", g_fTurretAim[client], 0);
	SetEntPropFloat(g_Turrets[client], Prop_Send, "m_flPoseParameter", 0.5, 1);
}

//





//NATIVES


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("CreateTurret", Native_CreateTurret);
	CreateNative("RemoveTurret", Native_RemovePlayerTurret);
	CreateNative("SetTurretCanAttackClient", Native_SetTurretCanAttackClient);
	
	RegPluginLibrary("TurretCore");
	return APLRes_Success;
}

public int Native_CreateTurret(Handle plugin, int numParams)
{
	int client_index = GetNativeCell(1);
	if (!IsValidClient(client_index))
	{
		PrintToServer("Invalid client (%d)", client_index)
		return;
	}
	CreateTurret(client_index);
}

public int Native_RemovePlayerTurret(Handle plugin, int numParams)
{
	int client_index = GetNativeCell(1);
	if (!IsValidClient(client_index))
	{
		PrintToServer("Invalid client (%d)", client_index)
		return;
	}
	DestroyTurrets(client_index);
	ResetPlayerVars(client_index);
}

public int Native_SetTurretCanAttackClient(Handle plugin, int numParams)
{
	int client_index = GetNativeCell(1);
	bool bCanAttack = view_as<bool>(GetNativeCell(2));
	if (!IsValidClient(client_index))
	{
		PrintToServer("Invalid client (%d)", client_index)
		return;
	}
	g_CanAttackClient[client_index] = bCanAttack;
	
}
//NATIVES

stock bool IsValidClient(int client)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client))
	{
		return false;
	}
	return IsClientInGame(client);
}
