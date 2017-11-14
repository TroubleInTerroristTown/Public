#define SND_TCHAT "buttons/button18.wav"
#define SND_FLASHLIGHT "items/flashlight1.wav"
#define SND_BLIP "buttons/blip2.wav"
#define SND_BURST "training/firewerks_burst_02.wav"

#define COLLISION_GROUP_DEBRIS_TRIGGER 2

char g_sRulesFile[PLATFORM_MAX_PATH + 1];
char g_sErrorFile[PLATFORM_MAX_PATH + 1];
char g_sLogFile[PLATFORM_MAX_PATH + 1];
char g_sTag[64];
char g_sKickImmunity[18];
char g_sLogAccess[18];
char g_sDefaultPrimary[32];
char g_sDefaultSecondary[32];
char g_sRoundStartedFontColor[12];
char g_sRoundStartFontColor[12];
char g_sFSSecondary[32];
char g_sFSPrimary[32];
char g_sSetRole[18];
char g_sKarmaReset[18];
char g_sSetKarma[18];

bool g_bRoundEnded = false;

int g_iRDMAttacker[MAXPLAYERS + 1] =  { -1, ... };
Handle g_hRDMTimer[MAXPLAYERS + 1] =  { null, ... };
bool g_bImmuneRDMManager[MAXPLAYERS + 1] =  { false, ... };
bool g_bHoldingProp[MAXPLAYERS + 1] =  { false, ... };
bool g_bHoldingSilencedWep[MAXPLAYERS + 1] =  { false, ... };

int g_iRole[MAXPLAYERS + 1] =  { 0, ... };

int g_iInnoKills[MAXPLAYERS + 1] =  { 0, ... };
int g_iTraitorKills[MAXPLAYERS + 1] =  { 0, ... };
int g_iDetectiveKills[MAXPLAYERS + 1] =  { 0, ... };

int g_iTeamSelectTime = 0;

Handle g_hGraceTime = null;

Handle g_hStartTimer = null;

float g_fRealRoundStart;
Handle g_hCountdownTimer = null;

ArrayList g_aForceTraitor;
ArrayList g_aForceDetective;

bool g_bRoundStarted = false;
bool g_bSelection = false;
bool g_bCheckPlayers = false;

int g_iLastRole[MAXPLAYERS + 1] =  {TTT_TEAM_UNASSIGNED, ...};
bool g_bAvoidDetective[MAXPLAYERS + 1] =  { false, ... };

Handle g_hRoundTimer = null;

bool g_bInactive = false;

int g_iCollisionGroup = -1;

bool g_bKarma[MAXPLAYERS + 1] =  { false, ... };
int g_iKarma[MAXPLAYERS + 1] =  { 0, ... };
int g_iKarmaStart[MAXPLAYERS + 1] =  { 0, ... };
int g_iArmor[MAXPLAYERS + 1] =  { 0, ... };

int g_iBeamSprite = -1;
int g_iHaloSprite = -1;

bool g_bFound[MAXPLAYERS + 1] =  { false, ... };
bool g_bIsChecking[MAXPLAYERS + 1] =  { false, ... };

int g_iAlive = -1;
int g_iHealth = -1;
int g_iKills = -1;
int g_iDeaths = -1;
int g_iAssists = -1;
int g_iMVPs = -1;

char g_sBadNames[256][MAX_NAME_LENGTH];
int g_iBadNameCount = 0;

Database g_dDB = null;


bool g_bReceivingLogs[MAXPLAYERS + 1] =  { false, ... };

ArrayList g_aLogs = null;
ArrayList g_aRagdoll = null;

bool g_bReadRules[MAXPLAYERS + 1] =  { false, ... };
bool g_bKnowRules[MAXPLAYERS + 1] =  { false, ... };

int g_iSite[MAXPLAYERS + 1] =  { 0, ... };

Handle g_hOnRoundStart_Pre = null;
Handle g_hOnRoundStart = null;
Handle g_hOnRoundStartFailed = null;
Handle g_hOnRoundEnd = null;
Handle g_hOnClientGetRole = null;
Handle g_hOnClientDeath = null;
Handle g_hOnBodyFound = null;
Handle g_hOnBodyChecked = null;
Handle g_hOnUpdate5 = null;
Handle g_hOnUpdate1 = null;
Handle g_hOnButtonPress = null;
Handle g_hOnButtonRelease = null;
Handle g_hOnModelUpdate = null;

bool g_bSourcebans = false;

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
	"cheer"
};

char g_sRemoveEntityList[][] =  {
	"func_bomb_target",
	"hostage_entity",
	"func_hostage_rescue",
	"info_hostage_spawn",
	"func_buyzone"
};

bool g_bRoundEnding = false;
int g_iLastButtons[MAXPLAYERS + 1] =  { 0, ... };

// Convars...
ConVar g_crequiredPlayersD = null;
ConVar g_crequiredPlayers = null;
ConVar g_cstartKarma = null;
ConVar g_ckarmaBan = null;
ConVar g_ckarmaBanLength = null;
ConVar g_cmaxKarma = null;
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
ConVar g_callowFlash = null;
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
ConVar g_cforceModel = null;
ConVar g_cmodelCT = null;
ConVar g_cmodelT = null;
ConVar g_clogFile = null;
ConVar g_cerrFile = null;
ConVar g_cdefaultPriD = null;
ConVar g_cdefaultSec = null;
ConVar g_cendwithD = null;
ConVar g_chideTeams = null;
ConVar g_cpublicKarma = null;
ConVar g_ckarmaRound = null;
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

Handle g_hRSCookie = null;
int g_iRoundSlays[MAXPLAYERS + 1] =  { 0, ... };
