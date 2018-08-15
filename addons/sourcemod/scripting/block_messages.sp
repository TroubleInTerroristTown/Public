#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

ArrayList g_aMessages = null;

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
        char sText[64];
        msg.ReadString("params", sText, sizeof(sText), 0);
        
        
        char sBuffer[64];
        for (int i = 0; i < g_aMessages.Length; i++)
        {
            g_aMessages.GetString(i, sBuffer, sizeof(sBuffer));
            if (StrContains(sBuffer, sText, false) != -1)
            {
                return Plugin_Handled;
            }
        }
    }
    
    return Plugin_Continue;
}
