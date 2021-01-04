#define SND_TCHAT "buttons/button18.wav"
#define SND_FLASHLIGHT "items/flashlight1.wav"
#define SND_BLIP "buttons/blip2.wav"
#define SND_BURST "training/firewerks_burst_02.wav"

#define MAX_LOG_LENGTH 512

char g_sRulesFile[PLATFORM_MAX_PATH + 1];
char g_sErrorFile[PLATFORM_MAX_PATH + 1];
char g_sLogFile[PLATFORM_MAX_PATH + 1];
char g_sKarmaFile[PLATFORM_MAX_PATH + 1];
char g_sTag[64];
char g_sDefaultPrimary[32];
char g_sDefaultSecondary[32];
char g_sRoundStartedFontColor[12];
char g_sRoundStartFontColor[12];
char g_sFSSecondary[32];
char g_sFSPrimary[32];

bool g_bBlockKill = false;
bool g_bDisabled = false;

int g_iTeamSelectTime = 0;
int g_iRoundTime = -1;

ConVar g_cGraceTime = null;
ConVar g_cRoundTime = null;
ConVar g_cFreezeTime = null;

Handle g_hStartTimer = null;

float g_fRealRoundStart;
Handle g_hCountdownTimer = null;

ArrayList g_aForceTraitor;
ArrayList g_aForceDetective;

bool g_bCheckPlayers = false;

Handle g_hRoundTimer = null;

int g_iBeamSprite = -1;
int g_iHaloSprite = -1;

int g_iAlive = -1;
int g_iHealth = -1;
int g_iKills = -1;
int g_iDeaths = -1;
int g_iAssists = -1;
int g_iMVPs = -1;

char g_sBadNames[256][MAX_NAME_LENGTH];
int g_iBadNameCount = 0;

Database g_dDB = null;

ArrayList g_aLogs = null;

GlobalForward g_fwOnRoundStart_Pre = null;
GlobalForward g_fwOnRoundStart = null;
GlobalForward g_fwOnRoundStartFailed = null;
GlobalForward g_fwOnRoundEnd = null;
GlobalForward g_fwOnClientGetRole = null;
GlobalForward g_fwOnTakeDamage = null;
GlobalForward g_fwOnClientDeath = null;
GlobalForward g_fwOnClientDeathPre = null;
GlobalForward g_fwOnButtonPress = null;
GlobalForward g_fwOnButtonRelease = null;
GlobalForward g_fwOnModelUpdate = null;
GlobalForward g_fwOnPlayerDeathPre = null;
GlobalForward g_fwOnPreKarmaUpdate = null;
GlobalForward g_fwOnKarmaUpdate = null;
GlobalForward g_fwOnRulesMenu = null;
GlobalForward g_fwOnDetectiveMenu = null;
GlobalForward g_fwOnCheckCommandAccess = null;
GlobalForward g_fwOnPlayerRespawn = null;
GlobalForward g_fwOnRoundSlay = null;
GlobalForward g_fwOnRoleSelection = null;
GlobalForward g_fOnVersionCheck = null;
GlobalForward g_fOnRoundTimerStart_Pre = null;

bool g_bDetectiveBans = false;
bool g_bSourcebans = false;
bool g_bBodies = false;
bool g_bIonCannon = false;
bool g_bGhostDM = false;

char g_sRadioCMDs[][] =  {
    "coverme",
    "takepoint",
    "holdpos",
    "regroup",
    "followme",
    "takingfire",
    "go",
    "fallback",
    "sticktog",
    "getinpos",
    "stormfront",
    "report",
    "roger",
    "enemyspot",
    "needbackup",
    "sectorclear",
    "inposition",
    "reportingin",
    "getout",
    "negative",
    "enemydown",
    "compliment",
    "thanks",
    "cheer",
    "go_a",
    "go_b",
    "needrop",
    "sorry"
};

char g_sRemoveEntityList[][] =  {
    "func_bomb_target",
    "func_buyzone",
    "hostage_entity",
    "func_hostage_rescue",
    "info_hostage_spawn"
};

// Convars...
ConVar g_crequiredPlayersD = null;
ConVar g_crequiredPlayers = null;
ConVar g_cstartKarma = null;
ConVar g_ckarmaBan = null;
ConVar g_ckarmaBanLength = null;
ConVar g_cmaxKarma = null;
ConVar g_ckarmaFlag = null;
ConVar g_cmaxKarmaVip = null;
ConVar g_cspawnHPT = null;
ConVar g_cspawnHPD = null;
ConVar g_cspawnHPI = null;
ConVar g_ckarmaII = null;
ConVar g_ckarmaIT = null;
ConVar g_ckarmaID = null;
ConVar g_ckarmaTI = null;
ConVar g_ckarmaTT = null;
ConVar g_ckarmaTD = null;
ConVar g_ckarmaDI = null;
ConVar g_ckarmaDT = null;
ConVar g_ckarmaDD = null;
ConVar g_cshowDeathMessage = null;
ConVar g_cshowKillMessage = null;
ConVar g_cshowEarnKarmaMessage = null;
ConVar g_cshowLoseKarmaMessage = null;
ConVar g_cmessageTypKarma = null;
ConVar g_cblockSuicide = null;
ConVar g_cSkipOwnSuicide = null;
ConVar g_callowFlash = null;
ConVar g_caflashVolume = null;
ConVar g_cblockLookAtWeapon = null;
ConVar g_cblockRadioMessage = null;
ConVar g_cenableNoBlock = null;
ConVar g_cpluginTag = null;
ConVar g_ckadRemover = null;
ConVar g_crulesClosePunishment = null;
ConVar g_cpunishInnoKills = null;
ConVar g_cpunishTraitorKills = null;
ConVar g_cpunishDetectiveKills = null;
ConVar g_ctimeToReadRules = null;
ConVar g_ctimeToReadDetectiveRules = null;
ConVar g_cshowRulesMenu = null;
ConVar g_cshowDetectiveMenu = null;
ConVar g_ckickImmunity = null;
ConVar g_clogsAccess = null;
ConVar g_cLogsDeadOnly = null;
ConVar g_cLogsNotifyAlive = null;
ConVar g_cupdateClientModel = null;
ConVar g_cremoveHostages = null;
ConVar g_cremoveBomb = null;
ConVar g_ctraitorRatio = null;
ConVar g_cdetectiveRatio = null;
ConVar g_cdenyFire = null;
ConVar g_cslayAfterStart = null;
ConVar g_cremoveBuyzone = null;
ConVar g_cforceTeams = null;
ConVar g_crandomWinner = null;
ConVar g_clogFile = null;
ConVar g_cerrFile = null;
ConVar g_cKarmaFile = null;
ConVar g_cdefaultPriD = null;
ConVar g_cdefaultSec = null;
ConVar g_cendwithD = null;
ConVar g_chideTeams = null;
ConVar g_cpublicKarma = null;
ConVar g_ckarmaRound = null;
ConVar g_ckarmaRoundMessage = null;
ConVar g_cstripWeapons = null;
ConVar g_ckarmaDMG = null;
ConVar g_ckarmaDMG_up = null;
ConVar g_croundDelay = null;
ConVar g_cnextRoundAlert = null;
ConVar g_croundendDamage = null;
ConVar g_cignoreDeaths = null;
ConVar g_cignoreRDMMenu = null;
ConVar g_cRoundStartedFontSize = null;
ConVar g_cRoundStartedFontColor = null;
ConVar g_cRoundStartFontSize = null;
ConVar g_cRoundStartFontColor = null;
ConVar g_ctChatToDead = null;
ConVar g_cdChatToDead = null;
ConVar g_cTranfserArmor = null;
ConVar g_cShowTraitors = null;
ConVar g_cRespawnDeadPlayers = null;
ConVar g_cmaxTraitors = null;
ConVar g_cmaxDetectives = null;
ConVar g_cminKarmaDetective = null;
ConVar g_cEnableDamage = null;
ConVar g_cGiveWeaponsOnFailStart = null;
ConVar g_cFSPrimary = null;
ConVar g_cFSSecondary = null;
ConVar g_cshowKarmaOnSpawn = null;
ConVar g_cDebugMessages = null;
ConVar g_cfakeHealth = null;
ConVar g_cfakeLife = null;
ConVar g_cSetRole = null;
ConVar g_cKarmaReset = null;
ConVar g_cSetKarma = null;
ConVar g_cAddSteamIDtoLogs = null;
ConVar g_cSteamIDLogFormat = null;
ConVar g_cDisableDamageSelection = null;
ConVar g_cRoundSlayInno = null;
ConVar g_cRoundSlayTraitor = null;
ConVar g_cRoundSlayDetective = null;
ConVar g_cRoundSlayPlayerRDM = null;
ConVar g_cRoundSlayDestroyTrigger = null;
ConVar g_cRoundSlayAccess = null;
ConVar g_cDebug = null;
ConVar g_cBanKarmaDead = null;
ConVar g_cSwitchSpec = null;
ConVar g_cRulesMenu = null;
ConVar g_cDRulesMenu = null;
ConVar g_cCheckPlayers = null;
ConVar g_cCheckDuringWarmup = null;
ConVar g_cPrimaryWeaponUpdate = null;
ConVar g_cSecondaryWeaponUpdate = null;
ConVar g_cEnableDamageKarma = null;
ConVar g_cDamageKarmaII = null;
ConVar g_cDamageKarmaIT = null;
ConVar g_cDamageKarmaID = null;
ConVar g_cDamageKarmaTI = null;
ConVar g_cDamageKarmaTT = null;
ConVar g_cDamageKarmaTD = null;
ConVar g_cDamageKarmaDI = null;
ConVar g_cDamageKarmaDT = null;
ConVar g_cDamageKarmaDD = null;
ConVar g_cDoublePushInno = null;
ConVar g_cDoublePushDete = null;
ConVar g_cKarmaDecreaseWhenKillPlayerWhoHurt = null;
ConVar g_cLogButtons = null;
ConVar g_cLogButtonsSpam = null;
ConVar g_cOpenRulesOnPunish = null;
ConVar g_cRulesURLReopenMenu = null;
ConVar g_cNameChangePunish = null;
ConVar g_cNameChangeLength = null;
ConVar g_cShowInnoRDMMenu = null;
ConVar g_cFlashlightOption = null;
ConVar g_cRespawnAccess = null;
ConVar g_cPlayerHUDMessage = null;
ConVar g_cShowURL = null;
ConVar g_cDisableRounds = null;
ConVar g_cClearRounds = null;
ConVar g_cClearLogs = null;
ConVar g_cStartMelee = null;
ConVar g_cAdditionalMeleeRole = null;
ConVar g_cAdditionalMeleeWeapon = null;
ConVar g_cUnloadPlugins = null;
ConVar g_cRemovePlugins = null;
ConVar g_cFixThirdperson = null;
ConVar g_cShowRoundIDMessage = null;
ConVar g_cVersionCheck = null;
ConVar g_cVersionMessage = null;
ConVar g_cSendServerData = null;
ConVar g_cClanTagUpperLower = null;
ConVar g_cSaveLogsInSQL = null;
ConVar g_cDeleteLogsAfterDays = null;
ConVar g_cAutoAssignTeam = null;
ConVar g_cBlockSwitchSelection = null;
ConVar g_cShowTeamsSelectedMessage = null;
ConVar g_cShowReceivingLogsMessage = null;
ConVar g_cMicCheckFlag = null;
ConVar g_cNameFix = null;

Cookie g_coRules = null;
Cookie g_coDRules = null;

bool g_bPressed[2048] = { false, ... };

Handle g_hWeAreSync = null;
Handle g_hRemainingSync = null;

RoundStatus g_iStatus = Round_Inactive;

int g_iRoundID = -1;
char g_sDriver[18];

enum struct PlayerData {
    int Role;
    int LastRole;
    int Karma;
    int KarmaStart;
    int Armor;
    int Site;
    int HurtedPlayer1;
    int HurtedPlayer2;
    int InnocentKills;
    int DetectiveKills;
    int TraitorKills;
    int RDMAttacker;
    int RoundSlays;
    int LastButtons;
    int ID;

    bool KarmaReady;
    bool Alive;
    bool Respawn;
    bool ReceivingLogs;
    bool Rules;
    bool DetectiveRules;
    bool ReadRules;
    bool KnowRules;
    bool AvoidDetective;
    bool ImmuneRDMManager;
    bool ResetHurt;
    bool Ready;

    Handle RDMTimer;

    char Name[MAX_NAME_LENGTH];
}

PlayerData g_iPlayer[MAXPLAYERS + 1];

int g_iVersion = -1;

bool g_bSpawnAllowed = true;
