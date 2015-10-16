#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>
#include <csgocolors>
#include <emitsoundany>

#define PLUGIN_VERSION "1.4"

#define PF " {NORMAL}[{GREEN}T{RED}T{BLUE}T{NORMAL}]{YELLOW} %t"


#define TRAITORS_AMOUNT 0.25
#define DETECTIVES_AMOUNT 0.125

#define GRAB_DISTANCE 150.0

new virtualmoney[MAXPLAYERS+1];

new bool:realmoney[MAXPLAYERS+1];

public Plugin:myinfo =
{
	name = "SM Trouble in Terrorist Town",
	author = "Franc1sco Steam: franug",
	description = "",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/id/franug"
};

new ACCOUNT_OFFSET;


new bool:cuchi[MAXPLAYERS+1];
new bool:scan[MAXPLAYERS+1];
new bool:g_jbomb[MAXPLAYERS+1];
new ID[MAXPLAYERS+1];
new Handle:h_jbomb[MAXPLAYERS+1];
new equipo[MAXPLAYERS+1];

#define U 0
#define I 1
#define T 2
#define D 3

#define MONEYHIDE 16000

new Handle:tiempoinicial;

new Handle:starttimer;
new Handle:array_jugadores;

new icon[MAXPLAYERS+1];

new bool:rondaempezada8;

new Handle:roundtimer;

new bool:inactivo;

new g_offsCollisionGroup;

new karma[MAXPLAYERS+1];

new Handle:array_ragdolls;

new g_BeamSprite        = -1;
new g_HaloSprite        = -1;

new bool:g_found[MAXPLAYERS+1];
new bool:g_detonate[MAXPLAYERS+1];

new g_iIsAliveOffset = -1;

enum Ragdolls
{
	ref,
	victima,
	atacante,
	String:victimaname[32],
	String:atacantename[32],
	bool:scanned,
	Float:tiempo,
	String:weaponused[32],
	bool:found
}

enum Playerinfo
{
	money2,
	karma2,
}

new bool:recibiendo[MAXPLAYERS+1];
new Handle:trie_info;

new Handle:array_logs;

public OnPluginStart()
{
	
	
	LoadTranslations("ttt.phrases");
	trie_info = CreateTrie();
	array_ragdolls = CreateArray(102);
	g_offsCollisionGroup = FindSendPropOffs("CBaseEntity", "m_CollisionGroup");
	ACCOUNT_OFFSET = FindSendPropOffs("CCSPlayer", "m_iAccount");
	HookEvent("player_death", event_Death, EventHookMode_Pre);
	CreateTimer(0.1, Adjust, _, TIMER_REPEAT);
	
	CreateTimer(5.0, Refresh, _, TIMER_REPEAT);
	
	RegConsoleCmd("sm_karma", ShowKarma);
	RegConsoleCmd("sm_money", ShowMoney);
	RegConsoleCmd("sm_credits", ShowMoney);
	
	RegConsoleCmd("sm_boom",     Command_Detonate,     "Detonate your bomb, if any."); 
	RegConsoleCmd("sm_jihad_detonate",     Command_Detonate,     "Detonate your bomb, if any."); 
	
	RegConsoleCmd("sm_logs", Logs);
	RegConsoleCmd("sm_log", Logs);
	
	RegConsoleCmd("say_team", SayTeam);
	
	HookEvent("player_spawn", PlayerSpawn);
	
	HookEvent("round_start", Event_Start, EventHookMode_Pre);
	HookEvent("round_end", Event_End, EventHookMode_Pre);
	HookEvent("player_changename", OnNameChange);
	
	HookEvent("player_death",PlayerDeath2);
	
	HookEvent("player_hurt", Event_PlayerHurt);
	
	tiempoinicial = FindConVar("mp_join_grace_time");
	
	array_jugadores = CreateArray();
	array_logs = CreateArray(512);
	
	RegConsoleCmd("sm_menu", ShowMenu);
	RegConsoleCmd("sm_id", ShowID);
	
	AddCommandListener(Command_LAW, "+lookatweapon");
	
/* 	AddCommandListener(Command_InterceptSuicide, "kill");
	AddCommandListener(Command_InterceptSuicide, "explode");
	AddCommandListener(Command_InterceptSuicide, "spectate");
	AddCommandListener(Command_InterceptSuicide, "jointeam");
	AddCommandListener(Command_InterceptSuicide, "joinclass"); */
	
	for(new i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i)) OnClientPutInServer(i);
}
public Action:Logs(client, args)
{
	if(!IsPlayerAlive(client) || !rondaempezada8) ShowLogs(client);
	else CPrintToChat(client, PF, "you cant see logs");
	return Plugin_Handled;
}

ShowLogs(client)
{
	new sizearray = GetArraySize(array_logs);
	if(sizearray == 0)
	{
		CPrintToChat(client, PF, "Aun no items");
		return;
	}
	if(recibiendo[client]) return;
	recibiendo[client] = true;
	CPrintToChat(client, PF, "Receiving logs");
	PrintToConsole(client, "--------------------------------------");
	PrintToConsole(client, "-------------TTT LOGS---------------");
	decl String:item[512];
	new numero = 5;
	new bool:end = false;
	if(numero >= sizearray)
	{
		end = true;
		numero = (sizearray -1);
	}
		
	for(new i = 0; i <= numero; i++)
	{
		GetArrayString(array_logs, i, item, sizeof(item));
		PrintToConsole(client, item);
	}
	
	if(end)
	{
		CPrintToChat(client, PF, "See your console");
		recibiendo[client] = false;
		PrintToConsole(client, "--------------------------------------");
		PrintToConsole(client, "--------------------------------------");
		return;
	}
	new Handle:pack;
	CreateDataTimer(0.1, Creating, pack);
	WritePackCell(pack, client);
	WritePackCell(pack, numero);
}

public Action:Creating(Handle:timer, Handle:pack)
{
	//unpack into
	new client;
	new numero;
	
	
	ResetPack(pack);
	client = ReadPackCell(pack);
	numero = ReadPackCell(pack);
	
	if (IsClientInGame(client))
	{
		new sizearray = GetArraySize(array_logs);
		new old = (numero + 1);
		numero += 5;
		new bool:end = false;
		if(numero >= sizearray)
		{
			end = true;
			numero = (sizearray -1);
		}
		decl String:item[512];
		
		for(new i = old; i <= numero; i++)
		{
			GetArrayString(array_logs, i, item, sizeof(item));
			PrintToConsole(client, item);
		}
		if(end)
		{
			CPrintToChat(client, PF, "See your console");
			recibiendo[client] = false;
			PrintToConsole(client, "--------------------------------------");
			PrintToConsole(client, "--------------------------------------");
			return;
		}
		new Handle:pack2;
		CreateDataTimer(0.1, Creating, pack2);
		WritePackCell(pack2, client);
		WritePackCell(pack2, numero);
	}
}

/* public Action:Command_InterceptSuicide(client, const String:command[], args)
{
	if(IsPlayerAlive(client))
	{
		CPrintToChat(client, " {NORMAL}[{GREEN}T{RED}T{BLUE}T{NORMAL}]{PURPLE} Suicide blocked");
		return Plugin_Handled;
	}
	return Plugin_Continue;
} */

public OnMapStart()
{
	g_BeamSprite = PrecacheModel("materials/sprites/bomb_planted_ring.vmt");
	g_HaloSprite = PrecacheModel("materials/sprites/halo.vtf");
	
	PrecacheSoundAny("slayersgaming/jihad/explosion.mp3", true); 
	PrecacheSound("buttons/blip2.wav", true); 
	PrecacheSound("buttons/button11.wav", true); 
	PrecacheSoundAny("slayersgaming/jihad/jihad.mp3", true); 

	AddFileToDownloadsTable("sound/slayersgaming/jihad/explosion.mp3"); 
	AddFileToDownloadsTable("sound/slayersgaming/jihad/jihad.mp3");
	
	ClearTrie(trie_info);
	ClearArray(array_logs);
	PrecacheSound("buttons/button18.wav");
	
	AddFileToDownloadsTable("materials/sprites/sg_detective_icon.vmt");
	AddFileToDownloadsTable("materials/sprites/sg_detective_icon.vtf");
	PrecacheModel("materials/sprites/sg_detective_icon.vmt");
	
	AddFileToDownloadsTable("materials/sprites/sg_traitor_icon.vmt");
	AddFileToDownloadsTable("materials/sprites/sg_traitor_icon.vtf");
	PrecacheModel("materials/sprites/sg_traitor_icon.vmt");
	
	AddFileToDownloadsTable("materials/overlays/ttt/innocents_win.vmt");
	AddFileToDownloadsTable("materials/overlays/ttt/innocents_win.vtf");
	PrecacheDecal("overlays/ttt/innocents_win", true);
	
	AddFileToDownloadsTable("materials/overlays/ttt/traitors_win.vmt");
	AddFileToDownloadsTable("materials/overlays/ttt/traitors_win.vtf");
	PrecacheDecal("overlays/ttt/traitors_win", true);
	
/* 	AddFileToDownloadsTable("materials/overlays/ttt/detectives_win.vmt");
	AddFileToDownloadsTable("materials/overlays/ttt/detectives_win.vtf");
	PrecacheDecal("overlays/ttt/detectives_win", true); */
	
	g_iIsAliveOffset = FindSendPropOffs("CCSPlayerResource", "m_bAlive");
	if (g_iIsAliveOffset == -1)
		SetFailState("CCSPlayerResource.m_bAlive offset is invalid");
    
	new CSPlayerManagerIndex = FindEntityByClassname(0, "cs_player_manager"); 
	SDKHook(CSPlayerManagerIndex, SDKHook_ThinkPost, OnThinkPost);
}

public OnThinkPost(entity) 
{
    decl isAlive[65];
    
    GetEntDataArray(entity, g_iIsAliveOffset, isAlive, 65);
    for (new i = 1; i <= MaxClients; ++i)
    {
        if (IsClientInGame(i))
		{
			if(IsPlayerAlive(i) || !g_found[i]) isAlive[i] = true;
			else isAlive[i] = false;
		}
    }
    SetEntDataArray(entity, g_iIsAliveOffset, isAlive, 65);
}

public Action:ShowKarma(client, args)
{
	CPrintToChat(client, PF, "Your karma is", karma[client]);
	
	return Plugin_Handled;
}

public Action:Event_Start(Handle:event, const String:name[], bool:dontBroadcast)
{
	ClearArray(array_ragdolls);
	
	inactivo = false;
	
	for(new i = 1; i <= MaxClients; i++)
	{
		equipo[i] = U;
		g_found[i] = true;
		
		if(IsClientInGame(i)) 
		{
			CS_SetClientClanTag(i, "");
		}
	}
		
		
	if(starttimer != INVALID_HANDLE) KillTimer(starttimer);
	starttimer = CreateTimer(GetConVarFloat(tiempoinicial) + 2.0, Seleccion);
	
	rondaempezada8 = false;
	
	if (roundtimer != INVALID_HANDLE) 
		CloseHandle(roundtimer);
		
	roundtimer = CreateTimer(GetConVarFloat(FindConVar("mp_roundtime")) * 60.0, on_round_time_end);
	
	ShowOverlayToAll("");
}

public Action:Event_End(Handle:event, const String:name[], bool:dontBroadcast)
{
	for(new i = 1; i <=MaxClients; ++i)
	{
		g_found[i] = true;
		if(IsClientInGame(i))
		{
			ShowLogs(i);
			
			TeamTag(i);
		}
	}
		
		
	if (roundtimer != INVALID_HANDLE) {
		CloseHandle(roundtimer);
		roundtimer = INVALID_HANDLE;
	}
}

public Action:Seleccion(Handle:timer)
{
	starttimer = INVALID_HANDLE;
	
	CPrintToChatAll(PF, "TEAMS HAS BEEN SELECTED");
	
	ClearArray(array_jugadores);
	
	new cuenta = 0;
	for(new i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i) && IsPlayerAlive(i))
		{
			cuenta++;
			PushArrayCell(array_jugadores, i);
		}
		
	if(cuenta < 2) 
	{
		inactivo = true;
		CPrintToChatAll(PF, "MIN PLAYERS REQUIRED FOR PLAY: 3");
		return;
	}
	new detectives = RoundToNearest(cuenta * DETECTIVES_AMOUNT);
	new traidores = RoundToNearest(cuenta * TRAITORS_AMOUNT);
	if(detectives == 0) detectives = 1;
	if(traidores == 0) traidores = 1;
	
	if(cuenta < 4) detectives = 0;
	
	new numero;
	new player;
	while((numero = RandomArray()) != -1)
	{
		player = GetArrayCell(array_jugadores, numero);
		
		if(detectives > 0)
		{
			equipo[player] = D;
			detectives--;
		}
		else if(traidores > 0)
		{
			equipo[player] = T;
			traidores--;
		}
		else equipo[player] = I;
		
		
/* 		new knife = GetPlayerWeaponSlot(player, 2);
		if (knife != -1)
		{
			RemovePlayerItem(player, knife);
			AcceptEntityInput(player, "Kill");
		} */
		GivePlayerItem(player, "weapon_knife");
		
		TeamElegido(player);
		
		g_found[player] = false;
		
		RemoveFromArray(array_jugadores, numero);
	}
	
	ClearArray(array_logs);
	rondaempezada8 = true;
	PonerIconos();
}

RandomArray()
{
	new tamanio = GetArraySize(array_jugadores);
	if(tamanio == 0) return -1;
	
	return GetRandomInt(0, tamanio-1);
}

TeamElegido(client)
{
	if(equipo[client] == D)
	{
		//icon[client] = CreateIcon(client);
		CS_SetClientClanTag(client, "DETECTIVE");
		new primario = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);
		if (primario == -1) GivePlayerItem(client, "weapon_m4a1");
		GivePlayerItem(client, "weapon_taser");
			
		CPrintToChat(client, PF, "Your Team is DETECTIVES");
	}
	else if(equipo[client] == T)
	{
		//icon[client] = CreateIcon(client);
		CPrintToChat(client, PF, "Your Team is TRAITORS");
	}
	else if(equipo[client] == I) CPrintToChat(client, PF, "Your Team is INNOCENTS");
}

TeamTag(client)
{
	if(equipo[client] == D)
	{
		CS_SetClientClanTag(client, "DETECTIVE");
	}
	else if(equipo[client] == T)
	{
		CS_SetClientClanTag(client, "TRAITOR");
	}
	else if(equipo[client] == I) CS_SetClientClanTag(client, "INNOCENT");
}

public Action:Refresh(Handle:timer)
{
	for(new i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i) && IsPlayerAlive(i))
		{
			icon[i] = CreateIcon(i);
		}
}
PonerIconos()
{
	for(new i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i) && IsPlayerAlive(i))
		{
			icon[i] = CreateIcon(i);
		}
}

public Action:PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	CPrintToChat(client, PF, "Your REAL money is", virtualmoney[client]);
	CPrintToChat(client, PF, "Your karma is", karma[client]);
	
	StripAllWeapons(client);
	
	ClearTimer(h_jbomb[client]);
	g_detonate[client] = false;
	
	if(inactivo)
	{
		new cuenta = 0;
		for(new i = 1; i <= MaxClients; i++)
			if(IsClientInGame(i) && IsPlayerAlive(i))
			{
				cuenta++;
			}
		
		if(cuenta >= 3) ServerCommand("mp_restartgame 2");
	}
	
	cuchi[client] = false;
	scan[client] = false;
	ID[client] = false;
	g_jbomb[client] = false;
	
}

public OnClientPutInServer(client)
{
	decl String:steamid[64];
	GetClientAuthString(client, steamid, 64);


	//g_found[client] = true;
	
	//equipo[client] = U;
	
	realmoney[client] = false;
	
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	
	SetEntData(client, ACCOUNT_OFFSET, MONEYHIDE);
	
	new Items[Playerinfo];
	if(GetTrieArray(trie_info, steamid, Items[0], sizeof(Items)))
	{
		virtualmoney[client] = Items[money2];
		karma[client] = Items[karma2];
	}
	else
	{
		virtualmoney[client] = 800;
		karma[client] = 100;
	}
}

public IsValidClient( client ) 
{ 
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) ) 
        return false; 
     
    return true; 
}

public Action:OnTakeDamage(client, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if(!rondaempezada8) return Plugin_Handled;
	if(!attacker || !IsValidClient(attacker)) return Plugin_Continue;
	
	decl String:classname[64];
	GetEdictClassname(inflictor, classname, sizeof(classname));
	if(StrContains(classname, "_projectile") == -1)
	{
		GetClientWeapon(attacker, classname, sizeof(classname));
		if(StrEqual(classname, "weapon_taser"))
		{
			if(equipo[client] == T)
			{
				CPrintToChat(attacker, PF, "You hurt to a Traitor", client);
				GanarCreditos(attacker, 1000);
			}
			else if(equipo[client] == D) CPrintToChat(attacker, PF, "You hurt to a Detective", client);
			else if(equipo[client] == I) CPrintToChat(attacker, PF, "You hurt to a Innocent", client);
			return Plugin_Handled;
		}
		else if(cuchi[attacker] && StrEqual(classname, "weapon_knife"))
		{
			QuitarMegaCuchi(attacker);
			damage = 1000.0;
			return Plugin_Changed;
		}
	}
	
	if(karma[attacker] == 100) return Plugin_Continue;
	
	damage = (damage * (karma[attacker] * 0.01));
	
	if(damage < 1.0) damage = 1.0;
	
	return Plugin_Changed;
}

public Action:event_Death(Handle:event, const String:nameu[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	ClearIcon(client);
	
	ClearTimer(h_jbomb[client]);
	if(equipo[client] > U)
	{
		decl String:playermodel[128];
		GetClientModel(client, playermodel, 128);
	
		decl Float:origin[3], Float:angles[3], Float:velocity[3];
	
		GetClientAbsOrigin(client, origin);
		GetClientAbsAngles(client, angles);
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", velocity);
	
		new iEntity = CreateEntityByName("prop_ragdoll");
		//new iEntity = CreateEntityByName("prop_dynamic");
		DispatchKeyValue(iEntity, "model", playermodel);
		DispatchSpawn(iEntity);
		//AcceptEntityInput(iEntity, "BecomeRagdoll");
	
		new Float:speed = GetVectorLength(velocity);
		if(speed >= 500) TeleportEntity(iEntity, origin, angles, NULL_VECTOR); 
		else TeleportEntity(iEntity, origin, angles, velocity); 
	
		SetEntData(iEntity, g_offsCollisionGroup, 2, 4, true);
	

		new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
		decl String:name[32];
		GetClientName(client, name, sizeof(name));
		new Items[Ragdolls];
		Items[ref] = EntIndexToEntRef(iEntity);
		Items[victima] = client;
		Format(Items[victimaname], 32, name);
		Items[scanned] = false;
		GetClientName(attacker, name, sizeof(name));
		Items[atacante] = attacker;
		Format(Items[atacantename], 32, name);
		Items[tiempo] = GetGameTime();
		GetEventString(event, "weapon", Items[weaponused], sizeof(Items[weaponused]));
	
		PushArrayArray(array_ragdolls, Items[0]);
	}
	if(!dontBroadcast)
	{	
		dontBroadcast = true;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public OnClientDisconnect(client)
{
	if(IsClientInGame(client))
	{
		decl String:steamid[64];
		GetClientAuthString(client, steamid, 64);
	
		new Items2[Playerinfo];
		Items2[money2] = virtualmoney[client];
		Items2[karma2] = karma[client];
	
		SetTrieArray(trie_info, steamid, Items2[0], sizeof(Items2));
	}
	
	ClearIcon(client);
	
	ClearTimer(h_jbomb[client]);
	
	recibiendo[client] = false;
/* 	new thesize = GetArraySize(array_ragdolls);
	
	if(thesize == 0) return;
	
	new Items[Ragdolls];
			
	for(new i = 0;i < GetArraySize(array_ragdolls);i++)
	{
		GetArrayArray(array_ragdolls, i, Items[0]);
				
		if(client == Items[atacante] || client == Items[victima])
		{
			new entity = EntRefToEntIndex(Items[ref]);
			if(entity != INVALID_ENT_REFERENCE) AcceptEntityInput(entity, "kill");
					
			RemoveFromArray(array_ragdolls, i);
			break;
		}
	}  */
}

public Action:OnNameChange(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (!IsClientInGame(client)) return;
		
	decl String:userName[32];
	GetEventString(event, "newname", userName, sizeof(userName));
	
 	new thesize = GetArraySize(array_ragdolls);
	
	if(thesize == 0) return;
	
	new Items[Ragdolls];
			
	for(new i = 0;i < GetArraySize(array_ragdolls);i++)
	{
		GetArrayArray(array_ragdolls, i, Items[0]);
				
		if(client == Items[atacante])
		{
			Format(Items[atacantename], 32, userName);
			SetArrayArray(array_ragdolls, i, Items[0]);
		}
		else if(client == Items[victima])
		{
			Format(Items[victimaname], 32, userName);
			SetArrayArray(array_ragdolls, i, Items[0]);
		}
	} 
}

public Action:Adjust(Handle:timer)
{	
	
	
	new I_lives = 0;
	new T_lives = 0;
	new Float:vec[3];
	for(new i = 1; i <=MaxClients; ++i)
		if(IsClientInGame(i) && IsPlayerAlive(i))
		{
			if(CS_GetClientAssists(i) != 0) CS_SetClientAssists(i, 0);
			if(CS_GetClientContributionScore(i) != 0) CS_SetClientContributionScore(i, 0);
			if(equipo[i] == T)
			{
				GetClientAbsOrigin(i, vec);
		
				vec[2] += 10;
				T_lives++;
				//TE_SetupBeamRingPoint(vec, 10.0, 190.0, g_BeamSprite, g_HaloSprite, 0, 15, 1.0, 5.0, 0.0, {0, 0, 255, 255}, 10, 0);
				new clients[MaxClients];
				new index = 0;
				for(new i2 = 1; i2 <=MaxClients; ++i2)
					if(IsClientInGame(i2) && IsPlayerAlive(i2) && i2 != i && (equipo[i2] == T))
					{
						clients[index] = i2;
						index++;
					}
				
				TE_SetupBeamRingPoint(vec, 50.0, 60.0, g_BeamSprite, g_HaloSprite, 0, 15, 0.1, 10.0, 0.0, {0, 0, 255, 255}, 10, 0);
				TE_Send(clients, index);
			}
			else if(equipo[i] == I)
			{
				I_lives++;
			}
			
			if(realmoney[i]) continue;
			new money = GetEntData(i, ACCOUNT_OFFSET);
			if(money != MONEYHIDE)
			{
				SetEntData(i, ACCOUNT_OFFSET, MONEYHIDE);
				//virtualmoney[i] += RoundToNearest((money-MONEYHIDE) * (karma[i] * 0.01));
			}
		}
		
	if(rondaempezada8)
	{
		if(I_lives == 0)
		{
			rondaempezada8 = false;
			CS_TerminateRound(7.0, CSRoundEnd_TerroristWin);
		}
		else if(T_lives == 0)
		{		
			rondaempezada8 = false;
			CS_TerminateRound(7.0, CSRoundEnd_CTWin);
		}
	}
	
/* 	new thesize = GetArraySize(array_ragdolls);
	
	if(thesize == 0) return;
	
	new Items[Ragdolls];
			
	for(new i = 0;i < GetArraySize(array_ragdolls);i++)
	{
		GetArrayArray(array_ragdolls, i, Items[0]);
				
		new entity = EntRefToEntIndex(Items[ref]);
		if(entity != INVALID_ENT_REFERENCE)
		{
			decl Float:fVelocity[3];
			GetEntPropVector(entity, Prop_Data, "m_vecVelocity", fVelocity);
			new Float:speed = GetVectorLength(fVelocity);
			if(speed >= 4000)
			{
				AcceptEntityInput(entity, "kill");
				RemoveFromArray(array_ragdolls, i);
			}
			else if(speed >= 500)
			{
				if(!(GetEntityFlags(entity) & FL_FROZEN))
				{
					new flags = GetEntityFlags(entity);
					SetEntityFlags(entity, flags|FL_FROZEN);
					CreateTimer(3.0, Des, EntIndexToEntRef(entity));
				}
			}
		}
					
	}  */
}

/* public Action:Des(Handle:timer, any:ref2)
{
	new entity = EntRefToEntIndex(ref2);
	if(entity != INVALID_ENT_REFERENCE)
	{
		if(GetEntityFlags(entity) & FL_FROZEN)
		{
			new flags = GetEntityFlags(entity);
			SetEntityFlags(entity, flags&~FL_FROZEN);
		}
	}
} */

public Action:ShowMoney(client, args)
{
	//ReplyToCommand(client, "Your REAL money is: %i", virtualmoney[client]);
	CPrintToChat(client, PF, "Your REAL money is", virtualmoney[client]);
	
	return Plugin_Handled;
}

/* public Action:CS_OnBuyCommand(client, const String:weapon[])
{
	SetEntData(client, ACCOUNT_OFFSET, virtualmoney[client]);
	realmoney[client] = true;
	
	CreateTimer(0.1, Pasado, client);
}

public Action:Pasado(Handle:timer, any:client)
{
	if(!IsClientInGame(client)) return;
	
	virtualmoney[client] = GetEntData(client, ACCOUNT_OFFSET);
	SetEntData(client, ACCOUNT_OFFSET, MONEYHIDE);
	realmoney[client] = false;
} */

public Action:PlayerDeath2(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	
	if (!IsValidEntity(client))
		return;
    
	new ragdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
	if (ragdoll<0)
	{
		return;
	}
	AcceptEntityInput(ragdoll, "Kill");
	
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if(!attacker || attacker == client) return;
	
 	//if(CS_GetClientAssists(i) != 0) CS_SetClientAssists(i, 0);
	//if(CS_GetClientContributionScore(i) != 0) CS_SetClientContributionScore(i, 0);
	if(GetEntProp(client, Prop_Data, "m_iDeaths") != 0) SetEntProp(client, Prop_Data, "m_iDeaths", 0);
	if(GetEntProp(attacker, Prop_Data, "m_iFrags") != 0) SetEntProp(attacker, Prop_Data, "m_iFrags", 0);
	
	if(equipo[attacker] == T) CPrintToChat(client, PF, "Your killer is Traitor");
	else if(equipo[attacker] == D) CPrintToChat(client, PF, "Your killer is Detective");
	else if(equipo[attacker] == I) CPrintToChat(client, PF, "Your killer is Innocent");
	
	if(equipo[client] == T) CPrintToChat(attacker, PF, "You killed to a Traitor");
	else if(equipo[client] == D) CPrintToChat(attacker, PF, "You killed to a Detective");
	else if(equipo[client] == I) CPrintToChat(attacker, PF, "You killed to a Innocent");
	decl String:item[512];
	
	if(equipo[attacker] == I && equipo[client] == T)
	{
		Format(item, sizeof(item), "%N (Innocent) killed to %N (Traitor) - GOOD ACTION", attacker, client);
		PushArrayString(array_logs, item);
		karma[attacker] += 5;
		GanarCreditos(attacker, 1500);
	}
	else if(equipo[attacker] == I && equipo[client] == D)
	{
		Format(item, sizeof(item), "%N (Innocent) killed to %N (Detective) - BAD ACTION", attacker, client);
		PushArrayString(array_logs, item);
		karma[attacker] -= 7;
		QuitarCreditos(attacker, 2100);
		//RDM(attacker);
	}
	else if(equipo[attacker] == T && equipo[client] == D)
	{
		Format(item, sizeof(item), "%N (Traitor) killed to %N (Detective) - GOOD ACTION", attacker, client);
		PushArrayString(array_logs, item);
		
		karma[attacker] += 3;
		GanarCreditos(attacker, 1200);
	}
	else if(equipo[attacker] == T && equipo[client] == I)
	{
		Format(item, sizeof(item), "%N (Traitor) killed to %N (Innocent) - GOOD ACTION", attacker, client);
		PushArrayString(array_logs, item);
		
		karma[attacker] += 2;
		GanarCreditos(attacker, 600);
	}
	else if(equipo[attacker] == D && equipo[client] == T)
	{
		Format(item, sizeof(item), "%N (Detective) killed to %N (Traitor) - GOOD ACTION", attacker, client);
		PushArrayString(array_logs, item);
		karma[attacker] += 7;
		GanarCreditos(attacker, 2100);
	}
	else if(equipo[attacker] == D && equipo[client] != T)
	{
		Format(item, sizeof(item), "%N (Detective) killed to %N (Inocente) - BAD ACTION", attacker, client);
		PushArrayString(array_logs, item);
		
		karma[attacker] -= 7;
		//RDM(attacker);
		QuitarCreditos(attacker, 2100);
	}
	else if(equipo[attacker] == I && equipo[client] != T)
	{
		Format(item, sizeof(item), "%N (Innocent) killed to %N (Innocent) - BAD ACTION", attacker, client);
		PushArrayString(array_logs, item);
		
		karma[attacker] -= 5;
		//RDM(attacker);
		QuitarCreditos(attacker, 1500);
	}
	else if(equipo[attacker] == T && equipo[client] == T)
	{
		Format(item, sizeof(item), "%N (Traidor) killed to %N (Traidor) - BAD ACTION", attacker, client);
		PushArrayString(array_logs, item);
		karma[attacker] -= 5;
		//RDM(attacker);
		QuitarCreditos(attacker, 1500);
	}
	
	if(karma[attacker] > 100) karma[attacker] = 100;
	else if(karma[attacker] < 1) karma[attacker] = 1;
	
}

CreateIcon(client) {
  
	ClearIcon(client);
	if(equipo[client] < T || !rondaempezada8) return 0;
	
	decl String:iTarget[16];
	Format(iTarget, 16, "client%d", client);
	DispatchKeyValue(client, "targetname", iTarget);

	decl Float:origin[3];
  
	GetClientAbsOrigin(client, origin);				
	origin[2] = origin[2] + 80.0;

	new Ent = CreateEntityByName("env_sprite");
	if(!Ent) return -1;

	if(equipo[client] == D) DispatchKeyValue(Ent, "model", "sprites/sg_detective_icon.vmt");
	else if(equipo[client] == T) DispatchKeyValue(Ent, "model", "sprites/sg_traitor_icon.vmt");
	DispatchKeyValue(Ent, "classname", "env_sprite");
	DispatchKeyValue(Ent, "spawnflags", "1");
	DispatchKeyValue(Ent, "scale", "0.08");
	DispatchKeyValue(Ent, "rendermode", "1");
	DispatchKeyValue(Ent, "rendercolor", "255 255 255");
	DispatchSpawn(Ent);
	TeleportEntity(Ent, origin, NULL_VECTOR, NULL_VECTOR);
	SetVariantString(iTarget);
	AcceptEntityInput(Ent, "SetParent", Ent, Ent, 0);
 
	if(equipo[client] == T) SDKHook(Ent, SDKHook_SetTransmit, Hook_SetTransmitT); 
	return Ent;
}

public Action:Hook_SetTransmitT(entity, client) 
{ 
    if (entity != client && equipo[client] != T && IsPlayerAlive(client)) 
        return Plugin_Handled;
     
    return Plugin_Continue; 
}  

public OnMapEnd() {
	if (roundtimer != INVALID_HANDLE) {
		CloseHandle(roundtimer);
		roundtimer = INVALID_HANDLE;
	}
}

public Action:on_round_time_end(Handle:timer) 
{
	roundtimer = INVALID_HANDLE;
	
	//CS_TerminateRound(7.0, CSRoundEnd_Draw);
	
	rondaempezada8 = false;
	CS_TerminateRound(7.0, CSRoundEnd_CTWin);
}

public Action:CS_OnTerminateRound(&Float:delay, &CSRoundEndReason:reason)
{
	if(rondaempezada8) return Plugin_Handled;
	for(new client = 1; client <=MaxClients; ++client)
		if(IsClientInGame(client) && IsPlayerAlive(client)) ClearIcon(client);
	
	if(reason == CSRoundEnd_CTWin)
	{
		for(new client = 1; client <=MaxClients; ++client)
			if(IsClientInGame(client))
			{
				if(equipo[client] != T && equipo[client] != U)
				{
					if(IsPlayerAlive(client)) GanarCreditos(client, 2400);
					else GanarCreditos(client, 300);
				}
			}
			
		ShowOverlayToAll("overlays/ttt/innocents_win");
	}
	else if(reason == CSRoundEnd_TerroristWin)
	{
		for(new client = 1; client <=MaxClients; ++client)
			if(IsClientInGame(client))
			{
				if(equipo[client] == T)
				{
					if(IsPlayerAlive(client)) GanarCreditos(client, 2400);
					else GanarCreditos(client, 300);
				}
			}
			
			
		ShowOverlayToAll("overlays/ttt/traitors_win");
	}
	//if(reason == CSRoundEnd_CTWin) ShowOverlayToAll("overlays/ttt/detectives_win");
	
	//ShowLog();
	
	return Plugin_Continue;
}

ShowOverlayToClient(client, const String:overlaypath[])
{
	ClientCommand(client, "r_screenoverlay \"%s\"", overlaypath);
}

ShowOverlayToAll(const String:overlaypath[])
{
	// x = client index.
	for (new x = 1; x <= MaxClients; x++)
	{
		// If client isn't in-game, then stop.
		if (IsClientInGame(x) && !IsFakeClient(x))
		{
			ShowOverlayToClient(x, overlaypath);
		}
	}
}

stock StripAllWeapons(iClient)
{
    new iEnt;
    for (new i = 0; i <= 4; i++)
    {
		while ((iEnt = GetPlayerWeaponSlot(iClient, i)) != -1)
		{
            RemovePlayerItem(iClient, iEnt);
            AcceptEntityInput(iEnt, "Kill");
		}
    }
}  

public Action:Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{	
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if(!attacker)
		return;

	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	
	new damage = GetEventInt(event, "dmg_health");
	decl String:item[512];
	if(equipo[attacker] == I && equipo[client] == T)
	{
		Format(item, sizeof(item), "%N (Innocent) hurt to %N (Traitor) with %i damage - GOOD ACTION", attacker, client, damage);
		PushArrayString(array_logs, item);
	}
	else if(equipo[attacker] == I && equipo[client] == D)
	{
		Format(item, sizeof(item), "%N (Innocent) hurt to %N (Detective) with %i damage - BAD ACTION", attacker, client, damage);
		PushArrayString(array_logs, item);
	}
	else if(equipo[attacker] == T && equipo[client] == D)
	{
		Format(item, sizeof(item), "%N (Traitor) hurt to %N (Detective) with %i damage - GOOD ACTION", attacker, client, damage);
		PushArrayString(array_logs, item);
		
	}
	else if(equipo[attacker] == T && equipo[client] == I)
	{
		Format(item, sizeof(item), "%N (Traitor) hurt to %N (Innocent) with %i damage - GOOD ACTION", attacker, client, damage);
		PushArrayString(array_logs, item);
		
	}
	else if(equipo[attacker] == D && equipo[client] == T)
	{
		Format(item, sizeof(item), "%N (Detective) hurt to %N (Traitor) with %i damage - GOOD ACTION", attacker, client, damage);
		PushArrayString(array_logs, item);
	}
	else if(equipo[attacker] == D && equipo[client] != T)
	{
		Format(item, sizeof(item), "%N (Detective) hurt to %N (Inocente) with %i damage - BAD ACTION", attacker, client, damage);
		PushArrayString(array_logs, item);
		
	}
	else if(equipo[attacker] == I && equipo[client] != T)
	{
		Format(item, sizeof(item), "%N (Innocent) hurt to %N (Innocent) with %i damage - BAD ACTION", attacker, client, damage);
		PushArrayString(array_logs, item);
		
	}
	else if(equipo[attacker] == T && equipo[client] == T)
	{
		Format(item, sizeof(item), "%N (Traidor) hurt to %N (Traidor) with %i damage - BAD ACTION", attacker, client, damage);
		PushArrayString(array_logs, item);
	}
}

/* RDM(client)
{
	for(new i = 1; i <=MaxClients; ++i)
		if(IsClientInGame(i) && (GetUserFlagBits(i) & ADMFLAG_BAN)) CPrintToChat(i, PF, "is possibly RDMing", client);
} */

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3])
{
	if(!IsClientInGame(client)) return;
	
	if(buttons & IN_USE)
	{
		
		new entidad = GetClientAimTarget(client, false);
		if(entidad > 0)
		{
			decl Float:OriginG[3],Float:TargetOriginG[3];
			GetClientEyePosition(client, TargetOriginG);
			GetEntPropVector(entidad, Prop_Data, "m_vecOrigin", OriginG);
			if(GetVectorDistance(TargetOriginG,OriginG, false) > 90.0) return;
			
			
		 	new thesize = GetArraySize(array_ragdolls);
	
			if(thesize == 0) return;
	
			new Items[Ragdolls];
			new entity;
			
			for(new i = 0;i < thesize;i++)
			{
				GetArrayArray(array_ragdolls, i, Items[0]);
				entity = EntRefToEntIndex(Items[ref]);
				
				if(entity == entidad)
				{
					//if(!IsValidClient(Items[victima])) return;
					
					MostrarMenu(client, Items[victima], Items[atacante], RoundToNearest(GetGameTime()-Items[tiempo]), Items[weaponused], Items[victimaname], Items[atacantename]);
					
					if(!Items[found] && IsPlayerAlive(client))
					{
						Items[found] = true;
						if(IsClientInGame(Items[victima])) g_found[Items[victima]] = true;
						
						if(equipo[Items[victima]] == I) 
						{
							CPrintToChatAll(PF, "Found Innocent", client, Items[victimaname]);
							SetEntityRenderColor(entidad, 0, 255, 0, 255);
						}
						else if(equipo[Items[victima]] == D)
						{
							CPrintToChatAll(PF, "Found Detective", client, Items[victimaname]);
							SetEntityRenderColor(entidad, 0, 0, 255, 255);
						}
						else if(equipo[Items[victima]] == T) 
						{
							CPrintToChatAll(PF, "Found Traitor", client,Items[victimaname]);
							SetEntityRenderColor(entidad, 255, 0, 0, 255);
						}
						
						TeamTag(Items[victima]);
						
						
						
						GanarCreditos(client, 300);
					}
					
					if(scan[client] && !Items[scanned] && IsPlayerAlive(client))
					{
						Items[scanned] = true;
						if(Items[atacante] > 0 && Items[atacante] != Items[victima]) CPrintToChatAll(PF, "Detective scan found body", client, Items[atacantename], Items[weaponused]);
						else CPrintToChatAll(PF, "Detective scan found body suicide", client);
						
						
					}
					SetArrayArray(array_ragdolls, i, Items[0]);
					
					break;
				}
			} 
		}
	}
}

public Action:ShowID(client, args)
{
	if(ID[client] && IsPlayerAlive(client))
	{
		CPrintToChatAll(PF, "Player Is an Innocent", client);
	}
	else CPrintToChat(client, PF, "You dont have it!");
	
	return Plugin_Handled;

}

public Action:SayTeam(client, args)
{
	if(!client || !IsPlayerAlive(client)) return Plugin_Continue;
	
	decl String:SayText[512];
	GetCmdArgString(SayText,sizeof(SayText));
	
	StripQuotes(SayText);
	
	if(strlen(SayText) < 2) return Plugin_Continue;
		
	if (SayText[0] == '@') return Plugin_Continue;
	
	if(equipo[client] == T)
	{
		for(new i = 1; i <=MaxClients; ++i)
			if(IsClientInGame(i) && (equipo[i] == T || !IsPlayerAlive(i))) 
			{
				EmitSoundToClient(i, "buttons/button18.wav");
				CPrintToChat(i, " %t", "T channel", client, SayText);
			}
			
		return Plugin_Handled;
	}
	else if(equipo[client] == D)
	{
		for(new i = 1; i <=MaxClients; ++i)
			if(IsClientInGame(i) && (equipo[i] == D || !IsPlayerAlive(i))) 
			{
				EmitSoundToClient(i, "buttons/button18.wav");
				CPrintToChat(i, " %t", "D channel", client, SayText);
			}
			
		return Plugin_Handled;
	}
	return Plugin_Handled;
}

public Action:ShowMenu(client, args)
{
	new team = equipo[client];
	if(team != U)
	{
		decl String:MenuItem[128];
		new Handle:menu = CreateMenu(DIDMenuHandler);
		SetMenuTitle(menu, "%T by Franc1sco franug", "TTT Shop", client);
	
		if(team == T)
		{
			Format(MenuItem, sizeof(MenuItem),"%T", "Buy jihadbomb", client);
			AddMenuItem(menu, "jbomb", MenuItem);
			
			
			Format(MenuItem, sizeof(MenuItem),"%T", "1 hit kill knife (only good for 1 shot)", client);
			AddMenuItem(menu, "1knife", MenuItem);

			Format(MenuItem, sizeof(MenuItem),"%T", "FAKE ID card (type !id for show your innocence)", client);
			AddMenuItem(menu, "fakeID", MenuItem);
			
			Format(MenuItem, sizeof(MenuItem),"%T", "M4S", client);
			AddMenuItem(menu, "m4s", MenuItem);
			
			Format(MenuItem, sizeof(MenuItem),"%T", "USPS", client);
			AddMenuItem(menu, "usps", MenuItem);
			
		}
		if(team == D)
		{
			Format(MenuItem, sizeof(MenuItem),"%T", "DNA scanner (scan a dead body and show who the killer is)", client);
			AddMenuItem(menu, "scan13", MenuItem);
		}
		if(team != I)
		{
			Format(MenuItem, sizeof(MenuItem),"%T", "Kevlar", client);
			AddMenuItem(menu, "kevlar", MenuItem);
		}
		if(team == I)
		{
/*    			Format(MenuItem, sizeof(MenuItem),"%T", "Buy rol Traitor", client);
			AddMenuItem(menu, "buyT", MenuItem);
			
			Format(MenuItem, sizeof(MenuItem),"%T", "Buy rol Detective", client);
			AddMenuItem(menu, "buyD", MenuItem); */
			
			Format(MenuItem, sizeof(MenuItem),"%T", "ID card (type !id for show your innocence)", client);
			AddMenuItem(menu, "ID", MenuItem);
		}
		Format(MenuItem, sizeof(MenuItem),"%T", "Taser", client);
		AddMenuItem(menu, "taser", MenuItem);
		
		SetMenuExitButton(menu, true);
		DisplayMenu(menu, client, 15);
	
	}
	else CPrintToChat(client, PF, "Please wait till your team is assigned");
	
	return Plugin_Handled;

}

public DIDMenuHandler(Handle:menu, MenuAction:action, client, itemNum) 
{
	if ( action == MenuAction_Select ) 
	{
		if(!IsPlayerAlive(client)) return;
		decl String:info[32];
		
		GetMenuItem(menu, itemNum, info, sizeof(info));
		if ( strcmp(info,"kevlar") == 0 ) 
		{
			if(virtualmoney[client] >= 2500)
			{
				GivePlayerItem( client, "item_assaultsuit");
				virtualmoney[client] -= 2500;
				CPrintToChat(client, PF, "Item bought! Your REAL money is", virtualmoney[client]);
			}
			else CPrintToChat(client, PF, "You don't have enough money");
		}
		else if ( strcmp(info,"1knife") == 0 )
		{
			if(virtualmoney[client] >= 5000)
			{
				DarMegaCuchi(client);
				virtualmoney[client] -= 5000;
				CPrintToChat(client, PF, "Item bought! Your REAL money is", virtualmoney[client]);
			}
			else CPrintToChat(client, PF, "You don't have enough money");
		}
		else if ( strcmp(info,"scan13") == 0 )
		{
			if(virtualmoney[client] >= 5000)
			{
				scan[client] = true;
				virtualmoney[client] -= 5000;
				CPrintToChat(client, PF, "Item bought! Your REAL money is", virtualmoney[client]);
			}
			else CPrintToChat(client, PF, "You don't have enough money");
		}
		else if ( strcmp(info,"ID") == 0 )
		{
			if(virtualmoney[client] >= 500)
			{
				ID[client] = true;
				virtualmoney[client] -= 500;
				CPrintToChat(client, PF, "Item bought! Your REAL money is", virtualmoney[client]);
			}
			else CPrintToChat(client, PF, "You don't have enough money");
		}
		else if ( strcmp(info,"fakeID") == 0 )
		{
			if(virtualmoney[client] >= 5000)
			{
				ID[client] = true;
				virtualmoney[client] -= 5000;
				CPrintToChat(client, PF, "Item bought! Your REAL money is", virtualmoney[client]);
			}
			else CPrintToChat(client, PF, "You don't have enough money");
		}
		else if ( strcmp(info,"buyT") == 0 )
		{
			if(virtualmoney[client] >= 10000)
			{
				equipo[client] = T;
				TeamElegido(client);
				virtualmoney[client] -= 10000;
				CPrintToChat(client, PF, "Item bought! Your REAL money is", virtualmoney[client]);
			}
			else CPrintToChat(client, PF, "You don't have enough money");
		}
		else if ( strcmp(info,"buyD") == 0 )
		{
			if(virtualmoney[client] >= 5000)
			{
				equipo[client] = D;
				TeamElegido(client);
				virtualmoney[client] -= 5000;
				CPrintToChat(client, PF, "Item bought! Your REAL money is", virtualmoney[client]);
			}
			else CPrintToChat(client, PF, "You don't have enough money");
		}
		else if ( strcmp(info,"taser") == 0 )
		{
			if(virtualmoney[client] >= 3000)
			{
				GivePlayerItem(client, "weapon_taser");
				virtualmoney[client] -= 3000;
				CPrintToChat(client, PF, "Item bought! Your REAL money is", virtualmoney[client]);
			}
			else CPrintToChat(client, PF, "You don't have enough money");
		}
		else if ( strcmp(info,"usps") == 0 )
		{
			if(virtualmoney[client] >= 3000)
			{
				GivePlayerItem(client, "weapon_usp_silencer");
				virtualmoney[client] -= 3000;
				CPrintToChat(client, PF, "Item bought! Your REAL money is", virtualmoney[client]);
			}
			else CPrintToChat(client, PF, "You don't have enough money");
		}
		else if ( strcmp(info,"m4s") == 0 )
		{
			if(virtualmoney[client] >= 6000)
			{
				GivePlayerItem(client, "weapon_m4a1_silencer");
				virtualmoney[client] -= 6000;
				CPrintToChat(client, PF, "Item bought! Your REAL money is", virtualmoney[client]);
			}
			else CPrintToChat(client, PF, "You don't have enough money");
		}
		else if ( strcmp(info,"jbomb") == 0 )
		{
			if(virtualmoney[client] >= 6000)
			{
				g_jbomb[client] = true;
				ClearTimer(h_jbomb[client]);
				h_jbomb[client] = CreateTimer(60.0, BombaArmada, client);
				virtualmoney[client] -= 6000;
				CPrintToChat(client, PF, "Item bought! Your REAL money is", virtualmoney[client]);
				CPrintToChat(client, PF, "bomb will arm in 60 seconds, double tab F to explode");
			}
			else CPrintToChat(client, PF, "You don't have enough money");
		}
	}
		
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Action:BombaArmada(Handle:Timer, any:client) 
{ 
	CPrintToChat(client, PF, "Your bomb is now armed.");
	EmitAmbientSound("buttons/blip2.wav", NULL_VECTOR, client);
	h_jbomb[client] = INVALID_HANDLE;	
} 

MostrarMenu(client, victima2, atacante2, tiempo2, const String:weapon[], const String:victimaname2[], const String:atacantename2[])
{
	//if(!IsValidClient(victima2)) return;
	
	decl String:team[32];
	if(equipo[victima2] == T)
	{
		Format(team, sizeof(team), "%T", "Traitors", client);
	}
	else if(equipo[victima2] == D)
	{
		Format(team, sizeof(team), "%T", "Detectives", client);
	}
	else if(equipo[victima2] == I) 
	{
		Format(team, sizeof(team), "%T", "Innocents", client);
	}

	new Handle:menu = CreateMenu(BodyMenuHandler);
	decl String:Item[128];
	
	SetMenuTitle(menu, "%T", "Inspected body. The extracted data are the following", client);
	
	Format(Item, sizeof(Item), "%T", "Victim name", client, victimaname2);
	AddMenuItem(menu, "", Item);
	
	Format(Item, sizeof(Item), "%T", "Team victim", client, team);
	AddMenuItem(menu, "", Item);
	
	if(equipo[client] == D)
	{
		Format(Item, sizeof(Item), "%T", "Elapsed since his death", client, tiempo2);
		AddMenuItem(menu, "", Item);
		
		if(atacante2 > 0 && atacante2 != victima2)
		{
			Format(Item, sizeof(Item), "%T", "The weapon used has been", client, weapon);
			AddMenuItem(menu, "", Item);
		}
		else
		{
			Format(Item, sizeof(Item), "%T", "The weapon used has been: himself (suicide)", client);
			AddMenuItem(menu, "", Item);
		}
	}
	
	if(scan[client])
	{
		if(atacante2 > 0 && atacante2 != victima2) Format(Item, sizeof(Item), "%T", "Killer is Player",client, atacantename2);
		else Format(Item, sizeof(Item), "%T", "Player committed suicide", client);
		
		AddMenuItem(menu, "", Item);
	}
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 15);
	
}

public BodyMenuHandler(Handle:menu, MenuAction:action, client, itemNum) 
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

DarMegaCuchi(client)
{
	cuchi[client] = true;
	new iWeapon = GetPlayerWeaponSlot(client, 2);
	if (iWeapon != INVALID_ENT_REFERENCE) 
	{
		RemovePlayerItem(client, iWeapon);
		AcceptEntityInput(iWeapon, "Kill");
	} 
	new item = GivePlayerItem(client, "weapon_knife");
	SetEntProp(item, Prop_Send, "m_iItemDefinitionIndex", 515);
}

QuitarMegaCuchi(client)
{
	cuchi[client] = false;
	new iWeapon = GetPlayerWeaponSlot(client, 2);
	if (iWeapon != INVALID_ENT_REFERENCE) 
	{
		RemovePlayerItem(client, iWeapon);
		AcceptEntityInput(iWeapon, "Kill");
	} 
	GivePlayerItem(client, "weapon_knife");
}
ClearIcon(client)
{
	if(icon[client] > 0 && IsValidEdict(icon[client]))
	{
		if(equipo[client] == T) SDKUnhook(icon[client], SDKHook_SetTransmit, Hook_SetTransmitT);
		AcceptEntityInput(icon[client], "Kill");
	}
	icon[client] = 0;
	
}

GanarCreditos(client, cantidad)
{
	cantidad = RoundToNearest((cantidad) * (karma[client] * 0.01));
	virtualmoney[client] += cantidad;
	
	PrintHintText(client, "%t", "credits earned", cantidad, virtualmoney[client]);
}

QuitarCreditos(client, cantidad)
{
	virtualmoney[client] -= cantidad;
	if(virtualmoney[client] < 0) virtualmoney[client] = 0;
	PrintHintText(client, "%t", "lost credits", cantidad, virtualmoney[client]);
}

stock ClearTimer(&Handle:timer)
{
    if (timer != INVALID_HANDLE)
    {
        KillTimer(timer);
        timer = INVALID_HANDLE;
    }     
} 

Detonate(client) 
{ 
    // Explosion! 
    new ExplosionIndex = CreateEntityByName("env_explosion"); 
    if (ExplosionIndex != -1) 
    { 
        SetEntProp(ExplosionIndex, Prop_Data, "m_spawnflags", 16384); 
        SetEntProp(ExplosionIndex, Prop_Data, "m_iMagnitude", 1000); 
        SetEntProp(ExplosionIndex, Prop_Data, "m_iRadiusOverride", 600); 

        DispatchSpawn(ExplosionIndex); 
        ActivateEntity(ExplosionIndex); 
         
        new Float:playerEyes[3]; 
        GetClientEyePosition(client, playerEyes); 
        //new clientTeam = GetEntProp(client, Prop_Send, "m_iTeamNum"); 

        TeleportEntity(ExplosionIndex, playerEyes, NULL_VECTOR, NULL_VECTOR); 
        SetEntPropEnt(ExplosionIndex, Prop_Send, "m_hOwnerEntity", client); 
        //SetEntProp(ExplosionIndex, Prop_Send, "m_iTeamNum", clientTeam); 
         
        EmitAmbientSoundAny("slayersgaming/jihad/explosion.mp3", NULL_VECTOR, client, SNDLEVEL_RAIDSIREN); 
         
         
        AcceptEntityInput(ExplosionIndex, "Explode"); 
         
        AcceptEntityInput(ExplosionIndex, "Kill"); 
    } 
    g_jbomb[client] = false;
} 

public Action:Command_Detonate(client, args) 
{ 
    if (!g_jbomb[client]) 
    { 
	
		CPrintToChat(client, PF, "You dont have it!");
		return Plugin_Handled; 
    } 
	
    if (h_jbomb[client] != INVALID_HANDLE) 
    { 
		CPrintToChat(client, PF, "Your bomb is not armed.");
		return Plugin_Handled; 
    } 
     
    EmitAmbientSoundAny("slayersgaming/jihad/jihad.mp3", NULL_VECTOR, client); 
         
    CreateTimer(2.0, TimerCallback_Detonate, client); 
    g_jbomb[client] = false;
    //SetEntityRenderColor(client, 255, 0, 0, 255);

    return Plugin_Handled; 
} 

public Action:TimerCallback_Detonate(Handle:Timer, any:client) 
{ 
    if(!client || !IsClientInGame(client) || !IsPlayerAlive(client)) 
        return Plugin_Handled; 
    Detonate(client); 
    return Plugin_Handled; 
} 

public Action:Command_LAW(client, const String:command[], argc)
{

	if(!IsClientInGame(client)) //If player is not in-game then ignore!
		return;

	if(!IsPlayerAlive(client) || !g_jbomb[client] || h_jbomb[client] != INVALID_HANDLE) //If player is not alive then continue the command.
		return;	

	if(g_detonate[client])
	{
		EmitAmbientSoundAny("slayersgaming/jihad/jihad.mp3", NULL_VECTOR, client); 
         
		CreateTimer(2.0, TimerCallback_Detonate, client); 
		g_jbomb[client] = false;
	}
	else
	{
		g_detonate[client] = true;
		CreateTimer(2.0, PasarJ, client);
	}

}

public Action:PasarJ(Handle:Timer, any:client) 
{ 
    if(!client || !IsClientInGame(client)) 
        return Plugin_Handled; 
    g_detonate[client] = false;
    return Plugin_Handled; 
} 