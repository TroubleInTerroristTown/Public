#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Trouble in Terrorist Town"

#define SND_TCHAT "buttons/button18.wav"
#define SND_FLASHLIGHT "items/flashlight1.wav"
#define SND_BLIP "buttons/blip2.wav"
#define SND_BURST "training/firewerks_burst_02.wav"

int g_iConfig[eConfig];

char g_sConfigFile[PLATFORM_MAX_PATH + 1];
char g_sRulesFile[PLATFORM_MAX_PATH + 1];

int g_iCredits[MAXPLAYERS + 1] =  { 0, ... };

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

Handle g_hGraceTime = null;

Handle g_hStartTimer = null;

float g_fRealRoundStart;
Handle g_hCountdownTimer = null;

Handle g_hPlayerArray = null;

Handle g_hDetectives = null;
Handle g_hTraitores = null;

bool g_bRoundStarted = false;
bool g_bCheckPlayers = false;

Handle g_hRoundTimer = null;

bool g_bInactive = false;

int g_iCollisionGroup = -1;

bool g_bKarma[MAXPLAYERS + 1] =  { false, ... };
int g_iKarma[MAXPLAYERS + 1] =  { 0, ... };
int g_iKarmaStart[MAXPLAYERS + 1] =  { 0, ... };
int g_iArmor[MAXPLAYERS + 1] =  { 0, ... };

Handle g_hRagdollArray = null;

int g_iBeamSprite = -1;
int g_iHaloSprite = -1;

bool g_bFound[MAXPLAYERS + 1] =  { false, ... };
bool g_bIsChecking[MAXPLAYERS + 1] =  { false, ... };

int g_iAlive = -1;
int g_iKills = -1;
int g_iDeaths = -1;
int g_iAssists = -1;
int g_iMVPs = -1;

char g_sBadNames[256][MAX_NAME_LENGTH];
int g_iBadNameCount = 0;

Handle g_hDatabase = null;


bool g_bReceivingLogs[MAXPLAYERS + 1] =  { false, ... };

Handle g_hLogsArray;

bool g_bReadRules[MAXPLAYERS + 1] =  { false, ... };
bool g_bKnowRules[MAXPLAYERS + 1] =  { false, ... };

bool g_bConfirmDetectiveRules[MAXPLAYERS + 1] =  { false, ... };

int g_iSite[MAXPLAYERS + 1] =  { 0, ... };

Handle g_hOnRoundStart_Pre = null;
Handle g_hOnRoundStart = null;
Handle g_hOnRoundStartFailed = null;
Handle g_hOnRoundEnd = null;
Handle g_hOnClientGetRole = null;
Handle g_hOnClientDeath = null;
Handle g_hOnBodyFound = null;
Handle g_hOnBodyChecked = null;
Handle g_hOnCreditsGiven_Pre = null;
Handle g_hOnCreditsGiven = null;
Handle g_hOnUpdate = null;

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
Handle g_hCreditsTimer[MAXPLAYERS + 1] =  { null, ... };