#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <colorlib>
#include <ttt>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Round End Sounds"

int g_iSoundEnts[2048];
int g_iNumSounds;

ConVar g_cEnable = null;
ConVar g_cDetPath = null;
ConVar g_cTraPath = null;
ConVar g_cInnPath = null;
ConVar g_cPlayType = null;
ConVar g_cStop = null;
ConVar g_cSettings = null;

Cookie g_coCookie = null;

bool SoundsDetSucess = false;
bool SoundsTraSucess = false;
bool SoundsInnSucess = false;

ArrayList detSound;
ArrayList traSound;
ArrayList innSound;

public Plugin myinfo =
{
    name = PLUGIN_NAME,
    author = "Bara (& AbNeR_CSS)",
    description = TTT_PLUGIN_DESCRIPTION,
    version = TTT_PLUGIN_VERSION,
    url = TTT_PLUGIN_URL
}

public void OnPluginStart()
{  
    TTT_StartConfig("res");
    CreateConVar("ttt2_res_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cEnable = AutoExecConfig_CreateConVar("res_enable", "0", "Enable round end sounds plugin? (Default: false/0)", _, true, 0.0, true, 1.0);
    g_cTraPath = AutoExecConfig_CreateConVar("res_traitor_path", "ttt/res/traitor", "Path off traitor sounds in /cstrike/sound");
    g_cDetPath = AutoExecConfig_CreateConVar("res_detective_path", "ttt/res/detective", "Path off detective sounds in /cstrike/sound");
    g_cInnPath = AutoExecConfig_CreateConVar("res_innocent_path", "ttt/res/innocent", "Path off innocent sounds in /cstrike/sound");
    g_cPlayType = AutoExecConfig_CreateConVar("res_play_type", "0", "0 - Random, 1 - Play in queue", _, true, 0.0, true, 1.0);
    g_cStop = AutoExecConfig_CreateConVar("res_stop_map_music", "1", "Stop map musics", _, true, 0.0, true, 1.0);    
    g_cSettings = AutoExecConfig_CreateConVar("res_client_preferences", "1", "Enable/Disable client preferences", _, true, 0.0, true, 1.0);
    TTT_EndConfig();
    
    g_coCookie = new Cookie("Round End Sounds", "", CookieAccess_Private);
    SetCookieMenuItem(Cookie_RoundEndSound, 0, "Round End Sounds");
    
    LoadTranslations("common.phrases");

    RegConsoleCmd("sm_res", Commamnd_RES);
    
    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
    
    detSound = new ArrayList(512);
    traSound = new ArrayList(512);
    innSound = new ArrayList(512);
}

public void OnMapStart()
{
    RefreshSounds(0);
}

public void TTT_OnRoundEnd(int winner, int role, Handle array)
{
    if (!g_cEnable.BoolValue)
    {
        return;
    }
    
    if(g_cStop.BoolValue)
    {
        StopMapMusic();
    }
    
    if(winner == TTT_TEAM_TRAITOR)
    {
        if(SoundsTraSucess)
        {
            PlaySoundTra();
        }
        else
        {
            PrintToServer("[TTT] Can't find sounds for traitors.");
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
            PrintToServer("[TTT] Can't find sounds for detectives.");
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
            PrintToServer("[TTT] Can't find sounds for innocents.");
            return;
        }
    }
}

public void StopMapMusic()
{
    char sSound[PLATFORM_MAX_PATH];
    int entity = INVALID_ENT_REFERENCE;
    LoopValidClients(i)
    {
        for (int u = 0; u < g_iNumSounds; u++)
        {
            entity = EntRefToEntIndex(g_iSoundEnts[u]);
            if (entity != INVALID_ENT_REFERENCE)
            {
                GetEntPropString(entity, Prop_Data, "m_iszSound", sSound, sizeof(sSound));
                StopClientSound(i, entity, SNDCHAN_STATIC, sSound);
            }
        }
    }
}

void StopClientSound(int client, int entity, int channel, const char[] name)
{
    EmitSoundToClient(client, name, entity, channel, SNDLEVEL_NONE, SND_STOP, 0.0, SNDPITCH_NORMAL, _, _, _, true);
}

public void Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
    if(g_cEnable.BoolValue && g_cStop.BoolValue)
    {
        g_iNumSounds = 0;
        
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

public void Cookie_RoundEndSound(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
    Commamnd_RES(client, 0);
} 

public Action Commamnd_RES(int client, int args)
{
    if(g_cSettings.BoolValue)
    {
        return Plugin_Handled;
    }
    
    char sValue[12];
    g_coCookie.Get(client, sValue, sizeof(sValue));
    int cookievalue = StringToInt(sValue);

    Menu menu = new Menu(MenuHandle);
    menu.SetTitle("Round End Sounds...");
    char Item[128];
    if(cookievalue == 0)
    {
        Format(Item, sizeof(Item), "Sounds on [X]");
        menu.AddItem("ON", Item);
        Format(Item, sizeof(Item), "Sounds off"); 
        menu.AddItem("OFF", Item);
    }
    else
    {
        Format(Item, sizeof(Item), "Sounds on");
        menu.AddItem("ON", Item);
        Format(Item, sizeof(Item), "Sounds off [X]");
        menu.AddItem("OFF", Item);
    }
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, 30);
    return Plugin_Continue;
}

public int MenuHandle(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_DrawItem)
    {
        return ITEMDRAW_DEFAULT;
    }
    else if(param == MenuCancel_ExitBack)
    {
        ShowCookieMenu(client);
    }
    else if (action == MenuAction_Select)
    {
        switch (param)
        {
            case 0:
            {
                g_coCookie.Set(client, "0");
                Commamnd_RES(client, 0);
            }
            case 1:
            {
                g_coCookie.Set(client, "1");
                Commamnd_RES(client, 0);
            }
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void RefreshSounds(int client)
{
    int size = LoadSoundsDet();
    SoundsDetSucess = (size > 0);
    if(SoundsDetSucess)
    {
        if (client == 0)
        {
            LogMessage("[TTT] %d detective sounds loaded.", size);
        }
        else
        {
            ReplyToCommand(client, "[TTT] %d detective sounds loaded.", size);
        }        
    }
    else
    {
        if (client == 0)
        {
            LogMessage("[TTT] Invalid detective sound path.");
        }
        else
        {
            ReplyToCommand(client, "[TTT] Invalid detective sound path.");
        }
    }
    
    size = LoadSoundsTra();
    SoundsTraSucess = (size > 0);
    if(SoundsTraSucess)
    {
        if (client == 0)
        {
            LogMessage("[TTT] %d traitor sounds loaded.", size);
        }
        else
        {
            ReplyToCommand(client, "[TTT] %d traitor sounds loaded.", size);
        }    
    }
    else
    {
        if (client == 0)
        {
            LogMessage("[TTT] Invalid traitor sound path.");
        }
        else
        {
            ReplyToCommand(client, "[TTT] Invalid traitor sound path.");
        }
    }
    
    size = LoadSoundsInn();
    SoundsInnSucess = (size > 0);
    if(SoundsInnSucess)
    {
        if (client == 0)
        {
            LogMessage("[TTT] %d innocent sounds loaded.", size);
        }
        else
        {
            ReplyToCommand(client, "[TTT] %d innocent sounds loaded.", size);
        }    
    }
    else
    {
        if (client == 0)
        {
            LogMessage("[TTT] Invalid innocent sound path.");
        }
        else
        {
            ReplyToCommand(client, "[TTT] Invalid innocent sound path.");
        }
    }
}
 
int LoadSoundsDet()
{
    if (detSound != null)
    {
        detSound.Clear();
    }
    
    char name[128];
    char soundname[512];
    char soundpath[PLATFORM_MAX_PATH];
    char soundpath2[PLATFORM_MAX_PATH];
    g_cDetPath.GetString(soundpath, sizeof(soundpath));
    
    Format(soundpath2, sizeof(soundpath2), "sound/%s/", soundpath);
    DirectoryListing hDir = OpenDirectory(soundpath2);
    if(hDir != null)
    {
        while (hDir.GetNext(name, sizeof(name)))
        {
            int namelen = strlen(name) - 4;
            if (StrContains(name, ".mp3", false) == namelen)
            {
                Format(soundname, sizeof(soundname), "sound/%s/%s", soundpath, name);
                AddFileToDownloadsTable(soundname);
                Format(soundname, sizeof(soundname), "%s/%s", soundpath, name);
                PrecacheSound(soundname);
                detSound.PushString(soundname);
            }
        }
        
        delete hDir;
    }
    
    return detSound.Length;
}

int LoadSoundsTra()
{
    if (traSound != null)
    {
        traSound.Clear();
    }
    
    char name[128];
    char soundname[512];
    char soundpath[PLATFORM_MAX_PATH];
    char soundpath2[PLATFORM_MAX_PATH];
    g_cTraPath.GetString(soundpath, sizeof(soundpath));
    
    Format(soundpath2, sizeof(soundpath2), "sound/%s/", soundpath);
    DirectoryListing hDir = OpenDirectory(soundpath2);
    if(hDir != null)
    {
        while (hDir.GetNext(name, sizeof(name)))
        {
            int namelen = strlen(name) - 4;
            if (StrContains(name, ".mp3", false) == namelen)
            {
                Format(soundname, sizeof(soundname), "sound/%s/%s", soundpath, name);
                AddFileToDownloadsTable(soundname);
                Format(soundname, sizeof(soundname), "%s/%s", soundpath, name);
                PrecacheSound(soundname);
                traSound.PushString(soundname);
            }
        }
        
        delete hDir;
    }
    return traSound.Length;
}

int LoadSoundsInn()
{
    if (innSound != null)
    {
        innSound.Clear();
    }
    
    char name[128];
    char soundname[512];
    char soundpath[PLATFORM_MAX_PATH];
    char soundpath2[PLATFORM_MAX_PATH];
    g_cInnPath.GetString(soundpath, sizeof(soundpath));
    Format(soundpath2, sizeof(soundpath2), "sound/%s/", soundpath);
    DirectoryListing hDir = OpenDirectory(soundpath2);
    if(hDir != null)
    {
        while (hDir.GetNext(name, sizeof(name)))
        {
            int namelen = strlen(name) - 4;
            if(StrContains(name,".mp3",false) == namelen)
            {
                Format(soundname, sizeof(soundname), "sound/%s/%s", soundpath, name);
                AddFileToDownloadsTable(soundname);
                Format(soundname, sizeof(soundname), "%s/%s", soundpath, name);
                PrecacheSound(soundname);
                innSound.PushString(soundname);
            }
        }
        
        delete hDir;
    }
    
    return innSound.Length;
}

void PlaySoundDet()
{
    int soundToPlay = 0;
    if(g_cPlayType.BoolValue)
    {
        soundToPlay = GetRandomInt(0, detSound.Length-1);
    }
    
    char sSound[128];
    detSound.GetString(soundToPlay, sSound, sizeof(sSound));
    detSound.Erase(soundToPlay);
    PlayMusicAll(sSound);
    if(detSound.Length == 0)
        LoadSoundsDet();
}

void PlaySoundTra()
{
    int soundToPlay = 0;
    if(g_cPlayType.BoolValue)
    {
        soundToPlay = GetRandomInt(0, traSound.Length-1);
    }
    
    char sSound[128];
    traSound.GetString(soundToPlay, sSound, sizeof(sSound));
    traSound.Erase(soundToPlay);
    PlayMusicAll(sSound);
    if(traSound.Length == 0)
        LoadSoundsTra();
}

void PlaySoundInn()
{
    int soundToPlay = 0;
    if(g_cPlayType.BoolValue)
    {
        soundToPlay = GetRandomInt(0, innSound.Length-1);
    }
    
    char sSound[128];
    innSound.GetString(soundToPlay, sSound, sizeof(sSound));
    innSound.Erase(soundToPlay);
    PlayMusicAll(sSound);
    if(innSound.Length == 0)
        LoadSoundsInn();
}

void PlayMusicAll(char[] sSound)
{
    char sValue[12];
    LoopValidClients(i)
    {
        g_coCookie.Get(i, sValue, sizeof(sValue));
        int iValue = StringToInt(sValue);
        if((!g_cSettings.BoolValue || iValue == 0))
        {
            ClientCommand(i, "playgamesound Music.StopAllMusic");
            ClientCommand(i, "play \"*%s\"", sSound);
        }
    }
}
