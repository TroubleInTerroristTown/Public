#if defined _ttt_stock_included
    #endinput
#endif
#define _ttt_stock_included

#define TTT_PLUGIN_NAME "Trouble in Terrorist Town"
#define TTT_PLUGIN_AUTHOR "TTT-Contributors"
#define TTT_PLUGIN_DESCRIPTION "The game is about a group of \"terrorists\" who have traitors among them, out to kill everyone who's not a traitor."
#define TTT_PLUGIN_VERSION "<VERSION>"
#define TTT_PLUGIN_URL "https://github.com/Bara/TroubleinTerroristTown"

#include <autoexecconfig>

stock void TTT_StartConfig(char[] file, char[] directory = "ttt")
{
    AutoExecConfig_SetCreateDirectory(true);
    AutoExecConfig_SetCreateFile(true);
    AutoExecConfig_SetFile(file, directory);
}

stock void TTT_EndConfig()
{
    AutoExecConfig_ExecuteFile();
    AutoExecConfig_CleanFile();
}

stock void TTT_IsGameCSGO()
{
    if (GetEngineVersion() != Engine_CSGO)
    {
        SetFailState("Only CS:GO Support!");
        return;
    }
}
