#pragma semicolon 1

#include <sourcemod>
#include <discord>
#include <ttt>

ConVar g_cBotToken = null;
ConVar g_cChannelName = null;
ConVar g_cChannelID = null;

char g_sChannelID[32];

DiscordBot g_dBot = null;

public void OnPluginStart()
{
    AutoExecConfig_SetCreateDirectory(true);
    AutoExecConfig_SetCreateFile(true);
    AutoExecConfig_SetFile("ttt-discord2");
    g_cBotToken = CreateConVar("ttt_discord2_chat_bot_token", "bot token...", "Set the bot token", FCVAR_PROTECTED);
    g_cChannelName = CreateConVar("ttt_discord2_chat_get_channel_name", "channel name...", "Channel name that will be read", FCVAR_PROTECTED);
    g_cChannelID = CreateConVar("ttt_discord2_chat_get_channel_id", "channel id...", "Channel ID that will be read", FCVAR_PROTECTED);
    AutoExecConfig_ExecuteFile();
    AutoExecConfig_CleanFile();
}

public void OnConfigsExecuted()
{
    if (g_dBot != null)
    {
        g_dBot.StopListening();
        delete g_dBot;
    }

    LogMessage("OnConfigsExecuted 1");
    char sToken[72];
    g_cBotToken.GetString(sToken, sizeof(sToken));
    g_dBot = new DiscordBot(sToken);
    g_dBot.MessageCheckInterval = 1.0;
    g_dBot.GetGuilds(GuildList);
    LogMessage("OnConfigsExecuted 2");
}

public void GuildList(DiscordBot bot, char[] id, char[] name, char[] icon, bool owner, int permissions, any data)
{
    g_dBot.GetGuildChannels(id, ChannelList, INVALID_FUNCTION, data);
}

public void TTT_OnRoundEnd(int winner, Handle array)
{
    ArrayList aLogs = view_as<ArrayList>(array);

    if (g_dBot != null && aLogs.Length > 0)
    {
        char sWinner[24], sBuffer[512];
        TTT_GetRoleNameByID(winner, sWinner, sizeof(sWinner));
        
        Format(sBuffer, sizeof(sBuffer), "[TEST!] Winner: %s", sWinner);
        LogMessage("TTT_OnRoundEnd - 1");
        g_dBot.SendMessageToChannelID(g_sChannelID, sBuffer, INVALID_FUNCTION);

        for (int i = 0; i < aLogs.Length; i++)
        {
            aLogs.GetString(i, sBuffer, sizeof(sBuffer));
            Format(sBuffer, sizeof(sBuffer), "[TEST!] %s", sBuffer);
            LogMessage("TTT_OnRoundEnd - 2");
            g_dBot.SendMessageToChannelID(g_sChannelID, sBuffer, INVALID_FUNCTION);
        }
    }
}

public void ChannelList(DiscordBot bot, char[] guild, DiscordChannel Channel, any data)
{
    char sChannelName[32], sChannelID[32], sCVarChannelID[32], sCVarChannelName[32];

    g_cChannelName.GetString(sCVarChannelName, sizeof(sCVarChannelName));
    g_cChannelID.GetString(sCVarChannelID, sizeof(sCVarChannelID));
    Channel.GetID(sChannelID, sizeof(sChannelID));
    Channel.GetName(sChannelName, sizeof(sChannelName));
    LogMessage("ChannelList 1 - Channel: %s", sChannelName);
    if(Channel.IsText && (StrContains(sChannelName, sCVarChannelName, false) != -1 && StrEqual(sChannelID, sCVarChannelID, false)))
    {
        LogMessage("ChannelList 2 - Channel: %s", sChannelName);
        strcopy(g_sChannelID, sizeof(g_sChannelID), sChannelID);
    }
}
