#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <clientprefs>
#include <cstrike>
#include <emitsoundany>
#include <ttt>

#pragma newdecls required // 2015 rules 
#pragma semicolon 1

//MapSounds Stuff
int g_iSoundEnts[2048];
int g_iNumSounds;

//Cvars
Handle g_hDetPath;
Handle g_hTraPath;
Handle g_hInnPath;

Handle g_hPlayType;
Handle g_hCookie;
Handle g_hStop;
Handle g_PlayPrint;
Handle g_ClientSettings;

bool SoundsDetSucess = false;
bool SoundsTraSucess = false;
bool SoundsInnSucess = false;

//Sounds Arrays
ArrayList detSound;
ArrayList traSound;
ArrayList innSound;

public Plugin myinfo =
{
	name = "[Outbreak] Round End Sounds",
	author = "Bara (& AbNeR_CSS)",
	description = "",
	version = "1.0.0",
	url = "outbreak-community.de"
}

public void OnPluginStart()
{  
	//Cvars
	g_hDetPath   	           = CreateConVar("res_det_path", "path/to/detective/res", "Path off detective sounds in /cstrike/sound");
	g_hTraPath	               = CreateConVar("res_tra_path", "path/to/traitor/res", "Path off traitor sounds in /cstrike/sound");
	g_hInnPath	               = CreateConVar("res_inn_path", "path/to/innocent/res", "Path off innocent sounds in /cstrike/sound");
	
	g_hPlayType                = CreateConVar("res_play_type", "1", "1 - Random, 2- Play in queue");
	g_hStop                    = CreateConVar("res_stop_map_music", "1", "Stop map musics");	
	g_PlayPrint                = CreateConVar("res_print_to_chat_mp3_name", "1", "Print mp3 name in chat (Suggested by m22b)");
	g_ClientSettings	       = CreateConVar("res_client_preferences", "1", "Enable/Disable client preferences");
	
	//ClientPrefs
	g_hCookie = RegClientCookie("Round End Sounds", "", CookieAccess_Private);
	SetCookieMenuItem(SoundCookieHandler, 0, "Round End Sounds");
	
	LoadTranslations("common.phrases");
	LoadTranslations("res.phrases");
	AutoExecConfig(true, "res2");

	RegAdminCmd("res_refresh", CommandLoad, ADMFLAG_SLAY);
	RegConsoleCmd("res", Commamnd_RES);
	
	HookConVarChange(g_hDetPath, PathChange);
	HookConVarChange(g_hTraPath, PathChange);
	HookConVarChange(g_hInnPath, PathChange);
	HookConVarChange(g_hPlayType, PathChange);
	
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	
	detSound = new ArrayList(512);
	traSound = new ArrayList(512);
	innSound = new ArrayList(512);
}

stock bool IsValidClient(int client)
{
	if(client <= 0 ) return false;
	if(client > MaxClients) return false;
	if(!IsClientConnected(client)) return false;
	return IsClientInGame(client);
}

public void StopMapMusic()
{
	char sSound[PLATFORM_MAX_PATH];
	int entity = INVALID_ENT_REFERENCE;
	for(int i=1;i<=MaxClients;i++){
		if(!IsClientInGame(i)){ continue; }
		for (int u=0; u<g_iNumSounds; u++){
			entity = EntRefToEntIndex(g_iSoundEnts[u]);
			if (entity != INVALID_ENT_REFERENCE){
				GetEntPropString(entity, Prop_Data, "m_iszSound", sSound, sizeof(sSound));
				Client_StopSound(i, entity, SNDCHAN_STATIC, sSound);
			}
		}
	}
}

stock void Client_StopSound(int client, int entity, int channel, const char[] name)
{
	EmitSoundToClient(client, name, entity, channel, SNDLEVEL_NONE, SND_STOP, 0.0, SNDPITCH_NORMAL, _, _, _, true);
}

public void TTT_OnRoundEnd(int winner)
{
	if(winner == TTT_TEAM_TRAITOR)
	{
		if(SoundsTraSucess)
		{
			PlaySoundTra();
		}
		else
		{
			PrintToServer("[Outbreak] TRA_SOUNDS ERROR: Sounds not loaded.");
			CPrintToChatAll("{green}[Outbreak] {default}TRA_SOUNDS ERROR: Sounds not loaded.");
			return;
		}
	}
	else if(winner == TTT_TEAM_DETECTIVE)
	{
		if(SoundsDetSucess)
		{
			PlaySoundDet();
		}
		else
		{
			PrintToServer("[Outbreak] DET_SOUNDS ERROR: Sounds not loaded.");
			CPrintToChatAll("{green}[Outbreak] {default}DET_SOUNDS ERROR: Sounds not loaded.");
			return;
		}
	}
	else if(winner == TTT_TEAM_INNOCENT)
	{
		if(SoundsInnSucess)
		{
			PlaySoundInn();
		}
		else
		{
			PrintToServer("[Outbreak] INN_SOUNDS ERROR: Sounds not loaded.");
			CPrintToChatAll("{green}[Outbreak] {default}INN_SOUNDS ERROR: Sounds not loaded.");
			return;
		}
	}
	
	if(GetConVarInt(g_hStop) == 1)
		StopMapMusic();
}

public void Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	if(GetConVarInt(g_hStop) == 1)
	{
		// Ents are recreated every round.
		g_iNumSounds = 0;
		
		// Find all ambient sounds played by the map.
		char sSound[PLATFORM_MAX_PATH];
		int entity = INVALID_ENT_REFERENCE;
		
		while ((entity = FindEntityByClassname(entity, "ambient_generic")) != INVALID_ENT_REFERENCE)
		{
			GetEntPropString(entity, Prop_Data, "m_iszSound", sSound, sizeof(sSound));
			
			int len = strlen(sSound);
			if (len > 4 && (StrEqual(sSound[len-3], "mp3") || StrEqual(sSound[len-3], "wav")))
			{
				g_iSoundEnts[g_iNumSounds++] = EntIndexToEntRef(entity);
			}
		}
	}
}

public void SoundCookieHandler(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
	Commamnd_RES(client, 0);
} 

public Action Commamnd_RES(int client, int args)
{
	if(GetConVarInt(g_ClientSettings) != 1)
	{
		return Plugin_Handled;
	}
	
	int cookievalue = GetIntCookie(client, g_hCookie);
	Handle g_AbNeRMenu = CreateMenu(AbNeRMenuHandler);
	SetMenuTitle(g_AbNeRMenu, "Round End Sounds...");
	char Item[128];
	if(cookievalue == 0)
	{
		Format(Item, sizeof(Item), "%t %t", "RES_ON", "Selected"); 
		AddMenuItem(g_AbNeRMenu, "ON", Item);
		Format(Item, sizeof(Item), "%t", "RES_OFF"); 
		AddMenuItem(g_AbNeRMenu, "OFF", Item);
	}
	else
	{
		Format(Item, sizeof(Item), "%t", "RES_ON");
		AddMenuItem(g_AbNeRMenu, "ON", Item);
		Format(Item, sizeof(Item), "%t %t", "RES_OFF", "Selected"); 
		AddMenuItem(g_AbNeRMenu, "OFF", Item);
	}
	SetMenuExitBackButton(g_AbNeRMenu, true);
	SetMenuExitButton(g_AbNeRMenu, true);
	DisplayMenu(g_AbNeRMenu, client, 30);
	return Plugin_Continue;
}

public int AbNeRMenuHandler(Handle menu, MenuAction action, int param1, int param2)
{
	Handle g_AbNeRMenu = CreateMenu(AbNeRMenuHandler);
	if (action == MenuAction_DrawItem)
	{
		return ITEMDRAW_DEFAULT;
	}
	else if(param2 == MenuCancel_ExitBack)
	{
		ShowCookieMenu(param1);
	}
	else if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 0:
			{
				SetClientCookie(param1, g_hCookie, "0");
				Commamnd_RES(param1, 0);
			}
			case 1:
			{
				SetClientCookie(param1, g_hCookie, "1");
				Commamnd_RES(param1, 0);
			}
		}
		CloseHandle(g_AbNeRMenu);
	}
	return 0;
}

public void PathChange(Handle cvar, const char[] oldVal, const char[] newVal)
{       
	RefreshSounds(0);
}

public void OnConfigsExecuted()
{
	RefreshSounds(0);
}

void RefreshSounds(int client)
{
	char soundpath[PLATFORM_MAX_PATH];
	char soundpath2[PLATFORM_MAX_PATH];
	char soundpath3[PLATFORM_MAX_PATH];
	GetConVarString(g_hTraPath, soundpath, sizeof(soundpath));
	GetConVarString(g_hDetPath, soundpath2, sizeof(soundpath2));
	GetConVarString(g_hInnPath, soundpath3, sizeof(soundpath3));
	
	int size = LoadSoundsDet();
	SoundsDetSucess = (size > 0);
	if(SoundsDetSucess)
	{
		ReplyToCommand(client, "[Outbreak] DET_SOUNDS: %d sounds loaded.", size);
	}
	else
	{
		ReplyToCommand(client, "[Outbreak] INVALID DET SOUND PATH.");
	}
	
	size = LoadSoundsTra();
	SoundsTraSucess = (size > 0);
	if(SoundsTraSucess)
	{
		ReplyToCommand(client, "[Outbreak] TRA_SOUNDS: %d sounds loaded.", size);
	}
	else
	{
		ReplyToCommand(client, "[Outbreak] INVALID TRA SOUND PATH.");
	}
	
	size = LoadSoundsInn();
	SoundsInnSucess = (size > 0);
	if(SoundsInnSucess)
	{
		ReplyToCommand(client, "[Outbreak] INN_SOUNDS: %d sounds loaded.", size);
	}
	else
	{
		ReplyToCommand(client, "[Outbreak] INVALID INN SOUND PATH.");
	}
}
 
int LoadSoundsDet()
{
	detSound.Clear();
	char name[128];
	char soundname[512];
	char soundpath[PLATFORM_MAX_PATH];
	char soundpath2[PLATFORM_MAX_PATH];
	GetConVarString(g_hDetPath, soundpath, sizeof(soundpath));
	Format(soundpath2, sizeof(soundpath2), "sound/%s/", soundpath);
	Handle pluginsdir = OpenDirectory(soundpath2);
	if(pluginsdir != INVALID_HANDLE)
	{
		while(ReadDirEntry(pluginsdir,name,sizeof(name)))
		{
			int namelen = strlen(name) - 4;
			if(StrContains(name,".mp3",false) == namelen)
			{
				Format(soundname, sizeof(soundname), "sound/%s/%s", soundpath, name);
				AddFileToDownloadsTable(soundname);
				Format(soundname, sizeof(soundname), "%s/%s", soundpath, name);
				PrecacheSoundAny(soundname);
				detSound.PushString(soundname);
			}
		}
	}
	return detSound.Length;
}

int LoadSoundsTra()
{
	traSound.Clear();
	char name[128];
	char soundname[512];
	char soundpath[PLATFORM_MAX_PATH];
	char soundpath2[PLATFORM_MAX_PATH];
	GetConVarString(g_hTraPath, soundpath, sizeof(soundpath));
	Format(soundpath2, sizeof(soundpath2), "sound/%s/", soundpath);
	Handle pluginsdir = OpenDirectory(soundpath2);
	if(pluginsdir != INVALID_HANDLE)
	{
		while(ReadDirEntry(pluginsdir,name,sizeof(name)))
		{
			int namelen = strlen(name) - 4;
			if(StrContains(name,".mp3",false) == namelen)
			{
				Format(soundname, sizeof(soundname), "sound/%s/%s", soundpath, name);
				AddFileToDownloadsTable(soundname);
				Format(soundname, sizeof(soundname), "%s/%s", soundpath, name);
				PrecacheSoundAny(soundname);
				traSound.PushString(soundname);
			}
		}
	}
	return traSound.Length;
}

int LoadSoundsInn()
{
	innSound.Clear();
	char name[128];
	char soundname[512];
	char soundpath[PLATFORM_MAX_PATH];
	char soundpath2[PLATFORM_MAX_PATH];
	GetConVarString(g_hInnPath, soundpath, sizeof(soundpath));
	Format(soundpath2, sizeof(soundpath2), "sound/%s/", soundpath);
	Handle pluginsdir = OpenDirectory(soundpath2);
	if(pluginsdir != INVALID_HANDLE)
	{
		while(ReadDirEntry(pluginsdir,name,sizeof(name)))
		{
			int namelen = strlen(name) - 4;
			if(StrContains(name,".mp3",false) == namelen)
			{
				Format(soundname, sizeof(soundname), "sound/%s/%s", soundpath, name);
				AddFileToDownloadsTable(soundname);
				Format(soundname, sizeof(soundname), "%s/%s", soundpath, name);
				PrecacheSoundAny(soundname);
				innSound.PushString(soundname);
			}
		}
	}
	return innSound.Length;
}

void PlaySoundDet()
{
	int soundToPlay = 0;
	if(GetConVarInt(g_hPlayType) == 1)
	{
		soundToPlay = GetRandomInt(0, detSound.Length-1);
	}
	
	char szSound[128];
	detSound.GetString(soundToPlay, szSound, sizeof(szSound));
	detSound.Erase(soundToPlay);
	PlayMusicAll(szSound);
	if(detSound.Length == 0)
		LoadSoundsDet();
}

void PlaySoundTra()
{
	int soundToPlay = 0;
	if(GetConVarInt(g_hPlayType) == 1)
	{
		soundToPlay = GetRandomInt(0, traSound.Length-1);
	}
	
	char szSound[128];
	traSound.GetString(soundToPlay, szSound, sizeof(szSound));
	traSound.Erase(soundToPlay);
	PlayMusicAll(szSound);
	if(traSound.Length == 0)
		LoadSoundsTra();
}

void PlaySoundInn()
{
	int soundToPlay = 0;
	if(GetConVarInt(g_hPlayType) == 1)
	{
		soundToPlay = GetRandomInt(0, innSound.Length-1);
	}
	
	char szSound[128];
	innSound.GetString(soundToPlay, szSound, sizeof(szSound));
	innSound.Erase(soundToPlay);
	PlayMusicAll(szSound);
	if(innSound.Length == 0)
		LoadSoundsInn();
}

void PlayMusicAll(char[] szSound)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i) && (GetConVarInt(g_ClientSettings) == 0 || GetIntCookie(i, g_hCookie) == 0)) //Adicionado versão v3.4
		{
			EmitSoundToClientAny(i, szSound, _, _, _, _, 0.5);
		}
	}
	
	if(GetConVarInt(g_PlayPrint) == 1)
	{
		CPrintToChatAll("{green}[Outbreak] {default}%t", "mp3 print", szSound);
	}
}

public Action CommandLoad(int client, int args)
{   
	RefreshSounds(client);
	return Plugin_Handled;
}

int GetIntCookie(int client, Handle handle)
{
	char sCookieValue[11];
	GetClientCookie(client, handle, sCookieValue, sizeof(sCookieValue));
	return StringToInt(sCookieValue);
}
