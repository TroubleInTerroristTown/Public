#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <autoexecconfig>

ArrayList g_aMessages = null;

ConVar g_cDisableTextFilter = null;

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
    g_aMessages = new ArrayList(64);
    
    CreateConVar("block_messages_version", "1.0.0", "Plugin to block some usermessage messages", FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    AutoExecConfig_SetCreateDirectory(true);
    AutoExecConfig_SetCreateFile(true);
    AutoExecConfig_SetFile("block_messages");
    g_cDisableTextFilter = AutoExecConfig_CreateConVar("block_message_disable_textfilter", "1", "Disable Valve's Text Filter?",_ , true, 0.0, true, 1.0);
    AutoExecConfig_ExecuteFile();
    AutoExecConfig_CleanFile();
    
    HookUserMessage(GetUserMessageId("TextMsg"), UserMsg_TextMsg, true);
}

public void OnConfigsExecuted()
{
    g_aMessages.Clear();
    
    char sPath[PLATFORM_MAX_PATH + 1], sFileText[64];
    BuildPath(Path_SM, sPath, sizeof(sPath), "configs/ttt/block_messages.ini");
    
    if (!FileExists(sPath))
    {
        SetFailState("Can't find the following file: \"configs/ttt/block_messages.ini\"");
    }
    
    File hFile = OpenFile(sPath, "rt");
    
    if(hFile != null)
    {
        while(!hFile.EndOfFile() && hFile.ReadLine(sFileText, sizeof(sFileText)))
        {
            g_aMessages.PushString(sFileText);
        }
    }
    
    delete hFile;
}


public Action UserMsg_TextMsg(UserMsg msg_id, Protobuf msg, const int[] players, int playersNum, bool reliable, bool init)
{
    if(reliable)
    {
        char sText[512];
        msg.ReadString("params", sText, sizeof(sText), 0);
        
        
        char sBuffer[512];
        for (int i = 0; i < g_aMessages.Length; i++)
        {
            g_aMessages.GetString(i, sBuffer, sizeof(sBuffer));
            if (StrContains(sBuffer, sText, false) != -1)
            {
                return Plugin_Handled;
            }
        }

        if (g_cDisableTextFilter.BoolValue)
        {
            UpdateMessage(sText, sizeof(sText));
        }
    }

    return Plugin_Continue;
}

void UpdateMessage(char[] message, int size)
{
    ReplaceString(message, size, "а", "ᎴаᎴ");
    ReplaceString(message, size, "о", "ᎴоᎴ");
    ReplaceString(message, size, "с", "ᎴсᎴ");
    ReplaceString(message, size, "е", "ᎴеᎴ");
    ReplaceString(message, size, "р", "ᎴрᎴ");
    ReplaceString(message, size, "у", "ᎴуᎴ");
    ReplaceString(message, size, "х", "ᎴхᎴ");
    ReplaceString(message, size, "п", "ᎴпᎴ");
    ReplaceString(message, size, "б", "ᎴбᎴ");
}
