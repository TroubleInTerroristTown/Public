#pragma semicolon 1

#include <sourcemod>
#include <discord>
#include <ttt>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Discord"

ConVar g_cBotToken = null;
ConVar g_cChannelName = null;
ConVar g_cChannelID = null;

char g_sChannelID[32];

DiscordBot g_dBot = null;

public Plugin myinfo =
{
    name = PLUGIN_NAME,
    author = TTT_PLUGIN_AUTHOR,
    description = TTT_PLUGIN_DESCRIPTION,
    version = TTT_PLUGIN_VERSION,
    url = TTT_PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("TTT_SendDiscordMessage", Native_SendDiscordMessage);
    
    RegPluginLibrary("ttt_discord");

    return APLRes_Success;
}

public void OnPluginStart()
{
    TTT_StartConfig("discord");
    CreateConVar("ttt2_discord_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cBotToken = AutoExecConfig_CreateConVar("discord_chat_bot_token", "bot token...", "Set the bot token", FCVAR_PROTECTED);
    g_cChannelName = AutoExecConfig_CreateConVar("discord_chat_get_channel_name", "channel name...", "Channel name that will be read", FCVAR_PROTECTED);
    g_cChannelID = AutoExecConfig_CreateConVar("discord_chat_get_channel_id", "channel id...", "Channel ID that will be read", FCVAR_PROTECTED);
    TTT_EndConfig();
}

public void TTT_OnLatestVersion(const char[] version)
{
    TTT_CheckVersion(TTT_PLUGIN_VERSION, TTT_GetCommitsCount());
}

public void OnConfigsExecuted()
{
    if (g_dBot != null)
    {
        g_dBot.StopListening();
        delete g_dBot;
    }

    char sToken[72];
    g_cBotToken.GetString(sToken, sizeof(sToken));
    g_dBot = new DiscordBot(sToken);
    g_dBot.MessageCheckInterval = 1.0;
    g_dBot.GetGuilds(GuildList);
}

public void GuildList(DiscordBot bot, char[] id, char[] name, char[] icon, bool owner, int permissions, any data)
{
    g_dBot.GetGuildChannels(id, ChannelList, INVALID_FUNCTION, data);
}

public void ChannelList(DiscordBot bot, char[] guild, DiscordChannel Channel, any data)
{
    char sChannelName[32], sChannelID[32], sCVarChannelID[32], sCVarChannelName[32];

    g_cChannelName.GetString(sCVarChannelName, sizeof(sCVarChannelName));
    g_cChannelID.GetString(sCVarChannelID, sizeof(sCVarChannelID));
    Channel.GetID(sChannelID, sizeof(sChannelID));
    Channel.GetName(sChannelName, sizeof(sChannelName));
    
    if(Channel.IsText && (StrContains(sChannelName, sCVarChannelName, false) != -1 && StrEqual(sChannelID, sCVarChannelID, false)))
    {
        strcopy(g_sChannelID, sizeof(g_sChannelID), sChannelID);
    }
}

public int Native_SendDiscordMessage(Handle plugin, int numParams)
{
    char message[512];
    int bytes;

    FormatNativeString(0, 1, 2, sizeof(message), bytes, message);
    g_dBot.SendMessageToChannelID(g_sChannelID, message, INVALID_FUNCTION);

    return 0;
}

public void TTT_OnRoundEnd(int winner, Handle array)
{
    ArrayList aLogs = view_as<ArrayList>(array);

    if (g_dBot != null && aLogs.Length > 0)
    {
        ArrayList aMessages = new ArrayList(1998);

        char sWinner[32], sMessage[1998], sDelimiter[64];
        TTT_GetRoleNameByID(winner, sWinner, sizeof(sWinner));
        Format(sDelimiter, sizeof(sDelimiter), "-----------------------------------------------------------\n");
        Format(sMessage, sizeof(sMessage), "%sWinners: %s\n", sDelimiter, sWinner);

        for (int i = 0; i < aLogs.Length; i++)
        {
            char sBuffer[256];
            aLogs.GetString(i, sBuffer, sizeof(sBuffer));

            if (strlen(sMessage) + strlen(sBuffer) >= 1999)
            {
                aMessages.PushString(sMessage);
                strcopy(sMessage, sizeof(sMessage), "");
            }

            Format(sMessage, sizeof(sMessage), "%s%s\n", sMessage, sBuffer);

            /* Last Message - i: 159 (+ 1), Length: 160
            Push last message into the ArrayList */
            if ((i + 1) == aLogs.Length)
            {
                aMessages.PushString(sMessage);
            }
        }

        aMessages.PushString(sDelimiter);

        for (int i = 0; i < aMessages.Length; i++)
        {
            char sBuffer[1998];
            aMessages.GetString(i, sBuffer, sizeof(sBuffer));

            DataPack pack = new DataPack();
            float fTime = (2.4 * float(i + 1));
            CreateTimer(fTime, Timer_SendMessage, pack);
            pack.WriteString(sBuffer);

        }

        delete aMessages;
    }

    delete aLogs;
}

public Action Timer_SendMessage(Handle timer, DataPack pack)
{
    pack.Reset();

    char sMessage[1998];
    pack.ReadString(sMessage, sizeof(sMessage));
    g_dBot.SendMessageToChannelID(g_sChannelID, sMessage, INVALID_FUNCTION);

    delete pack;
}
