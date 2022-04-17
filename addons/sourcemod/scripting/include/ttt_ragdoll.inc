#if defined _ttt_ragdoll_included
    #endinput
#endif
#define _ttt_ragdoll_included

enum struct Ragdoll
{
    int EntityRef;
    int Victim;
    int Attacker;
    int VictimTeam;
    int AttackerTeam;
    int VictimAccountID;
    int AttackerAccountID;
    bool Scanned;
    bool Found;
    bool Explode;
    float GameTime;
    char VictimName[MAX_NAME_LENGTH];
    char VictimSteam2[24];
    char VictimSteam3[24];
    char VictimSteamID64[24];
    char AttackerName[MAX_NAME_LENGTH];
    char AttackerSteam2[24];
    char AttackerSteam3[24];
    char AttackerSteamID64[24];
    char Weaponused[32];
    char Model[PLATFORM_MAX_PATH+1];
}
