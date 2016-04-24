#pragma semicolon 1

/*
			I N C L U D E S
	------------------------------------------------
*/
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <lasermines>
#include <multicolors>
#include <ttt>
/*
	------------------------------------------------
*/

/*
			D E F I N E S
	------------------------------------------------
*/
#define PLUGIN_VERSION "1.5.1"

#define MDL_LASER "materials/sprites/purplelaser1.vmt"
#define MDL_MINE "models/lasermine/lasermine.mdl"

#define SND_MINEPUT "npc/roller/blade_cut.wav"
#define SND_MINEACT "npc/roller/mine/rmine_blades_in2.wav"
#define SND_BUYMINE "items/itempickup.wav"
#define SND_CANTBUY "buttons/weapon_cant_buy.wav"
/*
	------------------------------------------------
*/

/*
		|G|  |L| |O| |B| |A| |L| |S|
	------------------------------------------------
*/

new Handle:h_enable, bool:b_enable,
	Handle:h_message, bool:b_message,
	Handle:h_amount, i_amount,
	Handle:h_maxamount, i_maxamount,
	Handle:h_damage, i_damage,
	Handle:h_explode_damage, i_explode_damage,
	Handle:h_explode_radius, i_explode_radius,
	Handle:h_health, i_health,
	Handle:h_color_t, String:s_color_t[16],
	Handle:h_color_ct, String:s_color_ct[16],
	Handle:h_activate_time, Float:f_activate_time,
	Handle:h_allow_pickup, bool:b_allow_pickup,
	Handle:h_allow_friendly_pickup, bool:b_allow_friendly_pickup,
	Handle:h_allow_enemy_pickup, bool:b_allow_enemy_pickup,
	Handle:h_wpn_dmg, String:s_wpn_dmg[16],
	Handle:h_lm_hs, bool:b_lm_hs;

new Handle:h_friendlyfire, bool:b_friendlyfire;

/*
		F O R W A R D S
	------------------------------------------------
*/
new Handle:h_fwdOnPlantLasermine,
	Handle:h_fwdOnLaserminePlanted,
	Handle:h_fwdOnPreHitByLasermine,
	Handle:h_fwdOnPostHitByLasermine,
	Handle:h_fwdOnPrePickupLasermine,
	Handle:h_fwdOnPostPickupLasermine;

/*
	------------------------------------------------
*/

new i_clients_amount[MAXPLAYERS+1],
	i_clients_myamount[MAXPLAYERS+1],
	i_clients_maxlimit[MAXPLAYERS+1],
	b_used_by_native[MAXPLAYERS+1];

/*
		P L U G I N    I N F O
	------------------------------------------------
*/

public Plugin:myinfo = 
{
	name = "[CS:GO] Lasermines",
	author = "FrozDark (adapting by Grey83)",
	description = "Plants a laser mine in CS:GO",
	version = PLUGIN_VERSION,
	url = "http://www.hlmod.ru/"
};

new bool:b_late;
/*
	Fires when the plugin is asked to be loaded
	-------------------------------------------------------
*/
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("AddClientLasermines", Native_AddMines);
	CreateNative("SetClientLasermines", Native_SetMines);
	CreateNative("SubClientLasermines", Native_SubstractMines);
	CreateNative("GetClientLasermines", Native_GetMines);
	CreateNative("PlantClientLasermine", Native_PlantMine);
	CreateNative("ClearMapClientLasermines", Native_ClearMapMines);
	CreateNative("IsEntityLasermine", Native_IsLasermine);
	CreateNative("GetClientByLasermine", Native_GetClientByLasermine);
	CreateNative("SetClientMaxLasermines", Native_SetClientMaxLasermines);
	CreateNative("ResetClientMaxLasermines", Native_ResetClientMaxLasermines);
	CreateNative("GetBeamByLasermine", Native_GetBeamByLasermine);
	CreateNative("GetLasermineByBeam", Native_GetLasermineByBeam);
	
	h_fwdOnPlantLasermine = CreateGlobalForward("OnPlantLasermine", ET_Hook, Param_Cell, Param_FloatByRef, Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_Array);
	h_fwdOnLaserminePlanted = CreateGlobalForward("OnLaserminePlanted", ET_Ignore, Param_Cell, Param_Cell, Param_Float, Param_Cell, Param_Cell, Param_Cell, Param_Array);
	
	h_fwdOnPreHitByLasermine = CreateGlobalForward("OnPreHitByLasermine", ET_Hook, Param_Cell, Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_CellByRef);
	h_fwdOnPostHitByLasermine = CreateGlobalForward("OnPostHitByLasermine", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	
	h_fwdOnPrePickupLasermine = CreateGlobalForward("OnPrePickupLasermine", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	h_fwdOnPostPickupLasermine = CreateGlobalForward("OnPostPickupLasermine", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	
	RegPluginLibrary("lasermines");
	
	b_late = late;
	
	return APLRes_Success;
}

/*
		Fires when the plugin starts
	------------------------------------------------
*/
public OnPluginStart()
{
	// Creates console variable version
	CreateConVar("csgo_lasermines_version", PLUGIN_VERSION, "The version of the plugin", FCVAR_PLUGIN|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	// Creates console variables
	h_enable = CreateConVar("sm_lasermines_enable", "1", "Enables/Disables the plugin", FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 1.0);
	h_message = CreateConVar("sm_lasermines_welcome_message", "1", "Show Plugin Message at the beginning of each round.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	h_amount = CreateConVar("sm_lasermines_amount", "3", "The amount to give laser mines to a player each spawn (if buy mode is disabled, -1 = Infinity)", FCVAR_PLUGIN, true, -1.0);
	h_maxamount = CreateConVar("sm_lasermines_maxamount", "3", "The maximum amount of laser mines a player can carry. (0-Unlimited)", FCVAR_PLUGIN, true, 0.0);
	h_damage = CreateConVar("sm_lasermines_damage", "500", "The damage to deal to a player by the laser", FCVAR_PLUGIN, true, 1.0, true, 100000.0);
	h_explode_damage = CreateConVar("sm_lasermines_explode_damage", "300", "The damage to deal to a player when a laser mine breaks", FCVAR_PLUGIN, true, 0.0, true, 100000.0);
	h_explode_radius = CreateConVar("sm_lasermines_explode_radius", "300", "The radius of the explosion", FCVAR_PLUGIN, true, 1.0, true, 100000.0);
	h_health = CreateConVar("sm_lasermines_health", "300", "The laser mines health. 0 = never breaked", FCVAR_PLUGIN, true, 0.0, true, 100000.0);
	h_activate_time = CreateConVar("sm_lasermines_activatetime", "2", "The delay of laser mines' activation", FCVAR_PLUGIN, true, 0.0, true, 10.0);
	h_color_t = CreateConVar("sm_lasermines_color_t", "255 127 0", "Terrorist's color. Set by RGB", FCVAR_PLUGIN);
	h_color_ct = CreateConVar("sm_lasermines_color_ct", "0 127 255", "Counter-Terrorist's color. Set by RGB", FCVAR_PLUGIN);
	h_allow_pickup = CreateConVar("sm_lasermines_allow_pickup", "1", "Allow players to pickup their planted lasermines", FCVAR_PLUGIN);
	h_allow_friendly_pickup = CreateConVar("sm_lasermines_allow_friendly_pickup", "0", "Allow players to pickup allies planted lasermines", FCVAR_PLUGIN);
	h_allow_enemy_pickup = CreateConVar("sm_lasermines_allow_enemy_pickup", "0", "Allow players to pickup enemys planted lasermines", FCVAR_PLUGIN);
	h_wpn_dmg = CreateConVar("sm_lasermines_wpn", "taser", "Enemy has died from this weapon", FCVAR_PLUGIN);
	h_lm_hs = CreateConVar("sm_lasermines_hs", "1", "Headshot On/Off", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	
	h_friendlyfire = FindConVar("mp_friendlyfire");
	
	// Gets them to the global
	b_enable = GetConVarBool(h_enable);
	b_message = GetConVarBool(h_message);
	i_amount = GetConVarInt(h_amount);
	i_maxamount = GetConVarInt(h_maxamount);
	i_damage = GetConVarInt(h_damage);
	i_explode_damage = GetConVarInt(h_explode_damage);
	i_explode_radius = GetConVarInt(h_explode_radius);
	i_health = GetConVarInt(h_health);
	f_activate_time = GetConVarFloat(h_activate_time);
	b_allow_pickup = GetConVarBool(h_allow_pickup);
	b_allow_friendly_pickup = GetConVarBool(h_allow_friendly_pickup);
	b_allow_enemy_pickup = GetConVarBool(h_allow_enemy_pickup);
	
	GetConVarString(h_color_t, s_color_t, sizeof(s_color_t));
	GetConVarString(h_color_ct, s_color_ct, sizeof(s_color_ct));
	GetConVarString(h_wpn_dmg, s_wpn_dmg, sizeof(s_wpn_dmg));
	b_lm_hs = GetConVarBool(h_lm_hs);
	
	b_friendlyfire = GetConVarBool(h_friendlyfire);
	
	// Hooks their change
	HookConVarChange(h_enable, OnConVarChanged);
	HookConVarChange(h_message, OnConVarChanged);
	HookConVarChange(h_amount, OnConVarChanged);
	HookConVarChange(h_maxamount, OnConVarChanged);
	HookConVarChange(h_damage, OnConVarChanged);
	HookConVarChange(h_explode_damage, OnConVarChanged);
	HookConVarChange(h_explode_radius, OnConVarChanged);
	HookConVarChange(h_health, OnConVarChanged);
	HookConVarChange(h_activate_time, OnConVarChanged);
	HookConVarChange(h_color_t, OnConVarChanged);
	HookConVarChange(h_color_ct, OnConVarChanged);
	HookConVarChange(h_allow_pickup, OnConVarChanged);
	HookConVarChange(h_allow_friendly_pickup, OnConVarChanged);
	HookConVarChange(h_allow_enemy_pickup, OnConVarChanged);
	HookConVarChange(h_wpn_dmg, OnConVarChanged);
	HookConVarChange(h_lm_hs, OnConVarChanged);
	
	HookConVarChange(h_friendlyfire, OnConVarChanged);
	
	// Hooks event changes
	HookEvent("player_death", OnPlayerDeath_Pre, EventHookMode_Pre);
	HookEvent("round_start", RoundStart);
	
	// Registers new console commands
	RegConsoleCmd("sm_plantlm", Command_PlantMine, "Plant a laser mine");
	RegConsoleCmd("sm_blm", Command_PlantMine, "Plant a laser mine");
	RegConsoleCmd("sm_lm", Command_PlantMine, "Plant a laser mine");
	
	// Hooks entity env_beam ouput events
	HookEntityOutput("env_beam", "OnTouchedByEntity", OnTouchedByEntity);
	
	// Loads the translation
	LoadTranslations("csgo_lasermines.phrases");
	
	AutoExecConfig(true, "plugin.csgo_lasermines");
	
	if (b_late)
	{
		b_late = false;
		OnMapStart();
	}
}
/*
	------------------------------------------------
*/

/*
			Cvars changes
	------------------------------------------------
*/
public OnConVarChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (convar == h_enable)
	{
		b_enable = bool:StringToInt(newValue);
	}
	else if (convar == h_message)
	{
		b_message = bool:StringToInt(newValue);
	}
	else if (convar == h_amount)
	{
		i_amount = StringToInt(newValue);
		LookupClients();
	}
	else if (convar == h_maxamount)
	{
		i_maxamount = StringToInt(newValue);
		LookupClients();
	}
	else if (convar == h_damage)
	{
		i_damage = StringToInt(newValue);
	}
	else if (convar == h_explode_damage)
	{
		i_explode_damage = StringToInt(newValue);
	}
	else if (convar == h_explode_radius)
	{
		i_explode_radius = StringToInt(newValue);
	}
	else if (convar == h_health)
	{
		i_health = StringToInt(newValue);
	}
	else if (convar == h_activate_time)
	{
		f_activate_time = StringToFloat(newValue);
	}
	else if (convar == h_color_t)
	{
		strcopy(s_color_t, sizeof(s_color_t), newValue);
	}
	else if (convar == h_color_ct)
	{
		strcopy(s_color_ct, sizeof(s_color_ct), newValue);
	}
	else if (convar == h_friendlyfire)
	{
		b_friendlyfire = bool:StringToInt(newValue);
	}
	else if (convar == h_allow_pickup)
	{
		b_allow_pickup = bool:StringToInt(newValue);
	}
	else if (convar == h_allow_friendly_pickup)
	{
		b_allow_friendly_pickup = bool:StringToInt(newValue);
	}
	else if (convar == h_allow_enemy_pickup)
	{
		b_allow_enemy_pickup = bool:StringToInt(newValue);
	}
	else if (convar == h_wpn_dmg)
	{
		strcopy(s_wpn_dmg, sizeof(s_wpn_dmg), newValue);
	}
	else if (convar == h_lm_hs)
	{
		b_lm_hs = bool:StringToInt(newValue);
	}
}

LookupClients()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		OnClientConnected(i);
	}
}


/*
		Fires when the map starts
	------------------------------------------------
*/
public OnMapStart()
{
	PrecacheModel(MDL_MINE, true);
	PrecacheModel(MDL_LASER, true);

	PrecacheSound(SND_MINEPUT, true);
	PrecacheSound(SND_MINEACT, true);
	PrecacheSound(SND_BUYMINE, true);
	PrecacheSound(SND_CANTBUY, true);

	AddFileToDownloadsTable( "models/lasermine/lasermine.dx80.vtx" );
	AddFileToDownloadsTable( "models/lasermine/lasermine.dx90.vtx" );
	AddFileToDownloadsTable( "models/lasermine/lasermine.mdl" );
	AddFileToDownloadsTable( "models/lasermine/lasermine.phy" );
	AddFileToDownloadsTable( "models/lasermine/lasermine.vvd" );

	AddFileToDownloadsTable( "materials/models/lasermine/lasermine.vmt" );
	AddFileToDownloadsTable( "materials/models/lasermine/lasermine.vtf" );
}
/*
	------------------------------------------------
*/

public RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(b_enable && b_message)
	{
  		CPrintToChatAll("%t", "Welcome Message 1");
	}
}
/*
	------------------------------------------------
*/

public OnClientConnected(client)
{
	if (!b_used_by_native[client])
	{
		i_clients_maxlimit[client] = i_maxamount;
		i_clients_myamount[client] = i_amount;
	}
}

/*
	Fires when a client disconnects
	------------------------------------------------
*/
public OnClientDisconnect(client)
{
	for (new index = MaxClients+1; index <= 2048; index++)
	{
		if (GetClientByLasermine(index) == client)
		{
			SDKUnhook(index, SDKHook_OnTakeDamage, OnTakeDamage);
			AcceptEntityInput(index, "KillHierarchy");
		}
	}
}

/*
	Fires when a client fully disconnected
	------------------------------------------------
*/
public OnClientDisconnect_Post(client)
{
	i_clients_amount[client] = 0;
	b_used_by_native[client] = false;
}

/*
			Touch event
	------------------------------------------------
*/
public OnTouchedByEntity(const String:output[], caller, activator, Float:delay)
{
	if (!(1 <= activator <= MaxClients))
	{
		return;
	}
	new owner = GetEntPropEnt(caller, Prop_Data, "m_hOwnerEntity");
	new lasermine = GetLasermineByBeam(caller);
	
	if (owner == -1 || lasermine == -1 || activator == owner || (!b_friendlyfire && GetClientTeam(activator) == GetClientTeam(owner)))
	{
		return;
	}
	
	decl dummy_caller, dummy_owner, damage, dummy_lasermine;
	dummy_caller = caller;
	dummy_owner = owner;
	damage = i_damage;
	dummy_lasermine = lasermine;
	
	new Action:result = Forward_OnPreHit(activator, dummy_owner, dummy_caller, dummy_lasermine, damage);
	
	switch (result)
	{
		case Plugin_Handled, Plugin_Stop :
		{
			return;
		}
		case Plugin_Continue :
		{
			dummy_caller = caller;
			dummy_owner = owner;
			damage = i_damage;
			dummy_lasermine = lasermine;
		}
	}
	
	if(TTT_GetClientRole(dummy_caller) == TTT_TEAM_TRAITOR)
	{
		return;
	}
	
	// Make custom damage to the client
	SDKHooks_TakeDamage(activator, dummy_caller, dummy_owner, float(damage), DMG_ENERGYBEAM);
	
	Forward_OnPostHit(activator, dummy_owner, dummy_caller, dummy_lasermine, damage);
}

public Action:OnPlayerDeath_Pre(Handle:event, const String:name[], bool:dontBroadcast)
{
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if (1 <= attacker <= MaxClients)
	{
		decl String:g_szWeapon[32];
		GetEventString(event, "weapon", g_szWeapon, sizeof(g_szWeapon));
		if (StrEqual(g_szWeapon, "env_beam"))
		{
			SetEventString(event, "weapon", s_wpn_dmg);
			if (b_lm_hs)
			{
				SetEventBool(event, "headshot", true);
			}
		}
	}
	return Plugin_Continue;
}

/*
	------------------------------------------------
*/
public Action:Command_PlantMine(client, argc)
{
	if (!client || !b_enable || !IsClientInGame(client) || TTT_GetClientRole(client) != TTT_TEAM_TRAITOR)
	{
		return Plugin_Continue;
	}
	if (!i_clients_amount[client])
	{
		PrintHintText(client, "%t", "Mines", i_clients_amount[client]);
		return Plugin_Handled;
	}
	if (!IsPlayerAlive(client))
	{
		PrintHintText(client, "%t", "Can't plant, while dead");
		return Plugin_Handled;
	}
	
	decl color[3];
	switch (GetClientTeam(client))
	{
		case 2 :
		{
			StringToColor(s_color_t, color, 255);
		}
		case 3 :
		{
			StringToColor(s_color_ct, color, 255);
		}
		default :
		{
			PrintHintText(client, "%t", "Can't use, while spec");
			return Plugin_Handled;
		}
	}
	
	decl Float:delay_time, dummy_damage, dummy_radius, health, dummy_color[3];
	delay_time = f_activate_time;
	dummy_damage = i_explode_damage;
	dummy_radius = i_explode_radius;
	health = i_health;
	dummy_color = color;
	
	new Action:result = Forward_OnPlantMine(client, delay_time, dummy_damage, dummy_radius, health, dummy_color);
	
	switch (result)
	{
		case Plugin_Handled, Plugin_Stop :
		{
			return result;
		}
		case Plugin_Continue :
		{
			delay_time = f_activate_time;
			dummy_damage = i_explode_damage;
			dummy_radius = i_explode_radius;
			health = i_health;
			dummy_color = color;
		}
	}
	
	new mine;
	if ((mine = PlantMine(client, delay_time, dummy_damage, dummy_radius, health, dummy_color)) == -1)
		return Plugin_Handled;
	
	Forward_OnMinePlanted(client, mine, delay_time, dummy_damage, dummy_radius, health, dummy_color);
	
	switch (i_clients_amount[client])
	{
		case -1 :
		{
			PrintHintText(client, "%t", "Infinity mines");
		}
		default :
		{
			i_clients_amount[client]--;
			PrintHintText(client, "%t", "Mines", i_clients_amount[client]);
		}
	}
	
	return Plugin_Handled;
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	static iPrevButtons[MAXPLAYERS+1];

	if (!b_allow_pickup || IsFakeClient(client) || !IsPlayerAlive(client))
		return Plugin_Continue;
	
	if ((buttons & IN_USE) && !(iPrevButtons[client] & IN_USE))
	{
		OnButtonPressed(client);
	}
	
	iPrevButtons[client] = buttons;
	
	return Plugin_Continue;
}

OnButtonPressed(client)
{
	new Handle:trace = TraceRay(client);
	
	new ent = -1;
	if (TR_DidHit(trace) && (ent = TR_GetEntityIndex(trace)) > MaxClients)
	{	
		CloseHandle(trace);
		new owner = GetClientByLasermine(ent);
		if (owner == -1)
		{
			return;
		}
		if (owner == client)
		{
			PickupLasermine(client, ent, owner);
			return;
		}
		if (GetClientTeam(owner) == GetClientTeam(client))
		{
			if (b_allow_friendly_pickup)
			{
				PickupLasermine(client, ent, owner);
			}
		}
		else if (b_allow_enemy_pickup)
		{
			PickupLasermine(client, ent, owner);
		}
	}
	else
		CloseHandle(trace);
}

PickupLasermine(client, lasermine, owner)
{
	if (i_clients_amount[client] >= 0 && i_clients_amount[client] == AddClientLasermines(client))
	{
		return;
	}
	
	new Action:result = Forward_OnPrePickup(client, lasermine, owner);
	
	switch (result)
	{
		case Plugin_Handled, Plugin_Stop :
		{
			return;
		}
	}
	
	AcceptEntityInput(lasermine, "KillHierarchy");
	if (i_clients_amount[client] >= 0)
		PrintHintText(client, "%t", "Mines", i_clients_amount[client]);
	else
		PrintHintText(client, "%t", "Infinity mines");
	EmitSoundToClient(client, SND_BUYMINE);
	
	Forward_OnPostPickup(client, lasermine, owner);
}

Handle:TraceRay(client)
{
	new Float:startent[3], Float:angle[3], Float:end[3];
	GetClientEyePosition(client, startent);
	GetClientEyeAngles(client, angle);
	GetAngleVectors(angle, end, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(end, end);

	startent[0] = startent[0] + end[0] * 10.0;
	startent[1] = startent[1] + end[1] * 10.0;
	startent[2] = startent[2] + end[2] * 10.0;

	end[0] = startent[0] + end[0] * 80.0;
	end[1] = startent[1] + end[1] * 80.0;
	end[2] = startent[2] + end[2] * 80.0;
	
	return TR_TraceRayFilterEx(startent, end, CONTENTS_SOLID, RayType_EndPoint, FilterPlayers);
}


/*
	------------------------------------------------
*/

PlantMine(client, Float:activation_delay = 0.0, explode_damage, explode_radius, const health = 0, const color[3] = {255, 255, 255})
{
	if (activation_delay > 10.0)
	{
		activation_delay = 10.0;
	}
	else if (activation_delay < 0.0)
	{
		activation_delay = 0.0;
	}
	
	new Handle:trace = TraceRay(client);
	
	decl Float:end[3], Float:normal[3], Float:beamend[3];
	if (TR_DidHit(trace) && TR_GetEntityIndex(trace) < 1)
	{
		TR_GetEndPosition(end, trace);
		TR_GetPlaneNormal(trace, normal);
		CloseHandle(trace);
		
		GetVectorAngles(normal, normal);
		
		TR_TraceRayFilter(end, normal, CONTENTS_SOLID, RayType_Infinite, FilterAll);
		TR_GetEndPosition(beamend, INVALID_HANDLE);
		
		new ent = CreateEntityByName("prop_physics_override");
		if (ent == -1 || !IsValidEdict(ent))
		{
			LogError("Could not create entity \"prop_physics_override\"");
			return -1;
		}
		
		new beament = CreateEntityByName("env_beam");
		if (beament == -1 || !IsValidEdict(beament))
		{
			LogError("Could not create entity \"env_beam\"");
			return -1;
		}
		
		decl String:start[30], String:tmp[200];
		Format(start, sizeof(start), "Beam%i", beament);
		
		SetEntityModel(ent, MDL_MINE);
		
		decl String:buffer[16];
		IntToString(explode_damage, buffer, sizeof(buffer));
		DispatchKeyValue(ent, "ExplodeDamage", buffer);
		IntToString(explode_radius, buffer, sizeof(buffer));
		DispatchKeyValue(ent, "ExplodeRadius", buffer);
		
		DispatchKeyValue(ent, "spawnflags", "3");
		DispatchSpawn(ent);
		
		AcceptEntityInput(ent, "DisableMotion");
		SetEntityMoveType(ent, MOVETYPE_NONE);
		TeleportEntity(ent, end, normal, NULL_VECTOR);
		
		SetEntProp(ent, Prop_Data, "m_nSolidType", 6);
		SetEntProp(ent, Prop_Data, "m_CollisionGroup", 5);
		
		if (health)
		{
			SetEntProp(ent, Prop_Data, "m_takedamage", 2);
			SetEntProp(ent, Prop_Data, "m_iHealth", health);
		}
		
		Format(tmp, sizeof(tmp), "%s,Kill,,0,-1", start);
		DispatchKeyValue(ent, "OnBreak", tmp);
		
		EmitSoundToAll(SND_MINEPUT, ent);
		
		
		
		// Set keyvalues on the beam.
		DispatchKeyValue(beament, "targetname", start);
		DispatchKeyValue(beament, "damage", "0");
		DispatchKeyValue(beament, "framestart", "0");
		DispatchKeyValue(beament, "BoltWidth", "4.0");
		DispatchKeyValue(beament, "renderfx", "0");
		DispatchKeyValue(beament, "TouchType", "3"); // 0 = none, 1 = player only, 2 = NPC only, 3 = player or NPC, 4 = player, NPC or physprop
		DispatchKeyValue(beament, "framerate", "0");
		DispatchKeyValue(beament, "decalname", "Bigshot");
		DispatchKeyValue(beament, "TextureScroll", "35");
		DispatchKeyValue(beament, "HDRColorScale", "1.0");
		DispatchKeyValue(beament, "texture", MDL_LASER);
		DispatchKeyValue(beament, "life", "0"); // 0 = infinite, beam life time in seconds
		DispatchKeyValue(beament, "StrikeTime", "1"); // If beam life time not infinite, this repeat it back
		DispatchKeyValue(beament, "LightningStart", start);
		DispatchKeyValue(beament, "spawnflags", "0"); // 0 disable, 1 = start on, etc etc. look from hammer editor
		DispatchKeyValue(beament, "NoiseAmplitude", "0"); // straight beam = 0, other make noise beam
		DispatchKeyValue(beament, "Radius", "256");
		DispatchKeyValue(beament, "renderamt", "100");
		DispatchKeyValue(beament, "rendercolor", "0 0 0");
		
		AcceptEntityInput(beament, "TurnOff");
		
		SetEntityModel(beament, MDL_LASER);
		
		TeleportEntity(beament, beamend, NULL_VECTOR, NULL_VECTOR); // Teleport the beam
		
		SetEntPropVector(beament, Prop_Data, "m_vecEndPos", end);
		SetEntPropFloat(beament, Prop_Data, "m_fWidth", 3.0);
		SetEntPropFloat(beament, Prop_Data, "m_fEndWidth", 3.0);
		
		SetEntPropEnt(beament, Prop_Data, "m_hOwnerEntity", client); // Sets the owner of the beam
		SetEntPropEnt(ent, Prop_Data, "m_hMoveChild", beament);
		SetEntPropEnt(beament, Prop_Data, "m_hEffectEntity", ent);
		
		new Handle:datapack = CreateDataPack();
		WritePackCell(datapack, beament);
		WritePackCell(datapack, ent);
		WritePackCell(datapack, color[0]);
		WritePackCell(datapack, color[1]);
		WritePackCell(datapack, color[2]);
		WritePackString(datapack, start);
		CreateTimer(activation_delay, OnActivateLaser, datapack, TIMER_FLAG_NO_MAPCHANGE|TIMER_HNDL_CLOSE);
		
		SDKHook(ent, SDKHook_OnTakeDamage, OnTakeDamage);
		
		return ent;
	}
	else
		CloseHandle(trace);
	return -1;
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if (IsEntityLasermine(victim))
	{
		if (1 <= attacker <= MaxClients)
		{
			new client = GetClientByLasermine(victim);
			if ((client != -1) && (client != attacker) && (GetClientTeam(client) == GetClientTeam(attacker)))
			{
				return Plugin_Handled;
			}
			return Plugin_Continue;
		}
		else if (!IsEntityLasermine(inflictor))
		{
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

/*
	------------------------------------------------
*/

public bool:FilterAll(entity, contentsMask)
{
	return false;
}

public bool:FilterPlayers(entity, contentsMask)
{
	return !(1 <= entity <= MaxClients);
}

public Action:OnActivateLaser(Handle:timer, any:hDataPack)
{
	ResetPack(hDataPack);
	decl String:start[30], String:tmp[200], color[3];
	new beament = ReadPackCell(hDataPack);
	new ent = ReadPackCell(hDataPack);
	color[0] = ReadPackCell(hDataPack);
	color[1] = ReadPackCell(hDataPack);
	color[2] = ReadPackCell(hDataPack);
	ReadPackString(hDataPack, start, sizeof(start));
	
	if (!IsValidEdict(beament) || !IsValidEdict(ent))
	{
		return Plugin_Stop;
	}
	
	AcceptEntityInput(beament, "TurnOn");
	
	SetEntityRenderColor(beament, color[0], color[1], color[2]);

	Format(tmp, sizeof(tmp), "%s,TurnOff,,0.001,-1", start);
	DispatchKeyValue(beament, "OnTouchedByEntity", tmp);
	Format(tmp, sizeof(tmp), "%s,TurnOn,,0.002,-1", start);
	DispatchKeyValue(beament, "OnTouchedByEntity", tmp);

	EmitSoundToAll(SND_MINEACT, ent);
	
	return Plugin_Stop;
}

/*
			N A T I V E S
	------------------------------------------------
*/

public Native_AddMines(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	if (client < 1 || client > MaxClients)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
		return 0;
	}
	else if (!IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NOT_FOUND, "Client %i is not in game", client);
		return 0;
	}
	
	new amount = GetNativeCell(2);
	new bool:limit = bool:GetNativeCell(3);
	
	if (amount <= 0)
	{
		return i_clients_amount[client];
	}
	if (i_clients_amount[client] < 0)
	{
		return -1;
	}
	
	i_clients_amount[client] += amount;
	
	if (limit)
	{
		if (i_clients_amount[client] > i_clients_maxlimit[client])
		{
			i_clients_amount[client] = i_clients_maxlimit[client];
		}
	}
	
	return i_clients_amount[client];
}

public Native_SetMines(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	if (client < 1 || client > MaxClients)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
		return false;
	}
	else if (!IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NOT_FOUND, "Client %i is not in game", client);
		return false;
	}
	
	new amount = GetNativeCell(2);
	new bool:limit = bool:GetNativeCell(3);
	
	if (amount < -1)
	{
		amount = -1;
	}
	
	i_clients_amount[client] = amount;
	
	if (limit)
	{
		if (i_clients_amount[client] > i_clients_maxlimit[client])
		{
			i_clients_amount[client] = i_clients_maxlimit[client];
		}
	}
	
	return true;
}

public Native_SubstractMines(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	if (client < 1 || client > MaxClients)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
		return 0;
	}
	else if (!IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NOT_FOUND, "Client %i is not in game", client);
		return 0;
	}
	
	new amount = GetNativeCell(2);
	
	if (i_clients_amount[client] == -1)
	{
		return i_clients_amount[client];
	}
	
	if (amount <= 0)
	{
		return i_clients_amount[client];
	}
	
	i_clients_amount[client] -= amount;
	if (i_clients_amount[client] < 0)
	{
		i_clients_amount[client] = 0;
	}
	
	return i_clients_amount[client];
}

public Native_GetMines(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	if (client < 1 || client > MaxClients)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
		return 0;
	}
	else if (!IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NOT_FOUND, "Client %i is not in game", client);
		return 0;
	}
	
	return i_clients_amount[client];
}

public Native_ClearMapMines(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	if (client < 1 || client > MaxClients)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
		return;
	}
	else if (!IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NOT_FOUND, "Client %i is not in game", client);
		return;
	}
	
	OnClientDisconnect(client);
}

public Native_PlantMine(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	
	if (client < 1 || client > MaxClients)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
		return false;
	}
	else if (!IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NOT_FOUND, "Client %i is not in game", client);
		return false;
	}
	
	new Float:f_delay = GetNativeCell(2);
	new i_exp_damage = GetNativeCell(3);
	new i_exp_radius = GetNativeCell(4);
	new health = GetNativeCell(5);
	decl color[3]; GetNativeArray(6, color, sizeof(color));
	
	new mine;
	if ((mine = PlantMine(client, f_delay, i_exp_damage, i_exp_radius, health, color)) != -1)
	{
		Forward_OnMinePlanted(client, mine, f_delay, i_exp_damage, i_exp_radius, health, color);
	}
	return (mine != -1);
}

public Native_IsLasermine(Handle:plugin, numParams)
{
	new entity = GetNativeCell(1);
	if (entity <= MaxClients || !IsValidEdict(entity))
	{
		return false;
	}
	decl String:g_szModel[PLATFORM_MAX_PATH];
	GetEntPropString(entity, Prop_Data, "m_ModelName", g_szModel, sizeof(g_szModel));
	return (StrEqual(g_szModel, MDL_MINE, false) && GetEntPropEnt(entity, Prop_Data, "m_hMoveChild") != -1);
}

public Native_GetClientByLasermine(Handle:plugin, numParams)
{
	new entity = GetNativeCell(1);
	new beam;
	if ((beam = GetBeamByLasermine(entity)) == -1)
	{
		return -1;
	}
	return GetEntPropEnt(beam, Prop_Data, "m_hOwnerEntity");
}

public Native_SetClientMaxLasermines(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	if (client < 1 || client > MaxClients)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
	}
	else if (!IsClientAuthorized(client))
	{
		ThrowNativeError(SP_ERROR_NOT_FOUND, "Client %i is not authorized", client);
	}
	new amount = GetNativeCell(2);
	if (amount < -1)
	{
		amount = -1;
	}
	i_clients_maxlimit[client] = amount;
	i_clients_myamount[client] = amount;
	b_used_by_native[client] = true;
}

public Native_ResetClientMaxLasermines(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	if (client < 1 || client > MaxClients)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
	}
	else if (!IsClientConnected(client))
	{
		ThrowNativeError(SP_ERROR_NOT_FOUND, "Client %i is not connected", client);
	}
	OnClientConnected(client);
}

public Native_GetBeamByLasermine(Handle:plugin, numParams)
{
	new entity = GetNativeCell(1);
	if (IsEntityLasermine(entity))
	{
		return GetEntPropEnt(entity, Prop_Data, "m_hMoveChild");
	}
	return -1;
}

public Native_GetLasermineByBeam(Handle:plugin, numParams)
{
	new mine = GetEntPropEnt(GetNativeCell(1), Prop_Data, "m_hEffectEntity");
	if (mine != -1 && IsEntityLasermine(mine))
	{
		return mine;
	}
	return -1;
}

/*
		F O R W A R D S
	------------------------------------------------
*/

Action:Forward_OnPlantMine(client, &Float:activate_time, &exp_damage, &exp_radius, &health, color[3])
{
	decl Action:result;
	result = Plugin_Continue;
	
	Call_StartForward(h_fwdOnPlantLasermine);
	Call_PushCell(client);
	Call_PushFloatRef(activate_time);
	Call_PushCellRef(exp_damage);
	Call_PushCellRef(exp_radius);
	Call_PushCellRef(health);
	Call_PushArrayEx(color, sizeof(color), SM_PARAM_COPYBACK);
	Call_Finish(result);
	
	return result;
}

Forward_OnMinePlanted(client, mine, Float:activate_time, exp_damage, exp_radius, health, color[3])
{
	Call_StartForward(h_fwdOnLaserminePlanted);
	Call_PushCell(client);
	Call_PushCell(mine);
	Call_PushFloat(activate_time);
	Call_PushCell(exp_damage);
	Call_PushCell(exp_radius);
	Call_PushCell(health);
	Call_PushArray(color, sizeof(color));
	Call_Finish();
}

Action:Forward_OnPreHit(victim, &attacker, &beam, &lasermine, &damage)
{
	decl Action:result;
	result = Plugin_Continue;
	
	Call_StartForward(h_fwdOnPreHitByLasermine);
	Call_PushCell(victim);
	Call_PushCellRef(attacker);
	Call_PushCellRef(beam);
	Call_PushCellRef(lasermine);
	Call_PushCellRef(damage);
	Call_Finish(result);
	
	return result;
}

Forward_OnPostHit(victim, attacker, beam, lasermine, damage)
{
	Call_StartForward(h_fwdOnPostHitByLasermine);
	Call_PushCell(victim);
	Call_PushCell(attacker);
	Call_PushCell(beam);
	Call_PushCell(lasermine);
	Call_PushCell(damage);
	Call_Finish();
}

Action:Forward_OnPrePickup(client, lasermine, owner)
{
	decl Action:result;
	result = Plugin_Continue;
	
	Call_StartForward(h_fwdOnPrePickupLasermine);
	Call_PushCell(client);
	Call_PushCell(lasermine);
	Call_PushCell(owner);
	Call_Finish(result);
	
	return result;
}

Forward_OnPostPickup(client, lasermine, owner)
{
	Call_StartForward(h_fwdOnPostPickupLasermine);
	Call_PushCell(client);
	Call_PushCell(lasermine);
	Call_PushCell(owner);
	Call_Finish();
}

/*
			S T O C K S
	------------------------------------------------
*/


stock bool:StringToColor(const String:str[], color[3], const defvalue = -1)
{
	new bool:result = false;
	decl String:Splitter[3][64];
	if (ExplodeString(str, " ", Splitter, sizeof(Splitter), sizeof(Splitter[])) == 3 && String_IsNumeric(Splitter[0]) && String_IsNumeric(Splitter[1]) && String_IsNumeric(Splitter[2]))
	{
		color[0] = StringToInt(Splitter[0]);
		color[1] = StringToInt(Splitter[1]);
		color[2] = StringToInt(Splitter[2]);
		result = true;
	}
	else
	{
		color[0] = defvalue;
		color[1] = defvalue;
		color[2] = defvalue;
	}
	return result;
}

stock bool:String_IsNumeric(const String:str[])
{	
	new x=0;
	new numbersFound=0;

	if (str[x] == '+' || str[x] == '-')
		x++;

	while (str[x] != '\0')
	{
		if (IsCharNumeric(str[x]))
			numbersFound++;
		else
			return false;
		x++;
	}
	
	if (!numbersFound)
		return false;
	
	return true;
}