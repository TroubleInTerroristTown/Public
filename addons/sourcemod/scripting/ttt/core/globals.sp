#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Trouble in Terrorist Town"

#define SND_TCHAT "buttons/button18.wav"
#define SND_FLASHLIGHT "items/flashlight1.wav"
#define SND_BLIP "buttons/blip2.wav"
#define SND_BURST "training/firewerks_burst_02.wav"
#define SND_BEEP "weapons/c4/c4_beep1.wav"
#define SND_DISARM "weapons/c4/c4_disarm.wav"

#define MDL_C4 "models/weapons/w_c4_planted.mdl"

enum eConfig
{
	i_shopDNA,
	i_shopID,
	i_shopFAKEID,
	i_shopT,
	i_shopD,
	i_shopTASER,
	i_shopJIHADBOMB,
	i_shopC4,
	i_requiredPlayersD,
	i_requiredPlayers,
	i_startKarma,
	i_karmaBan,
	i_karmaBanLength,
	i_maxKarma,
	i_spawnHPT,
	i_spawnHPD,
	i_spawnHPI,
	i_karmaII,
	i_karmaIT,
	i_karmaID,
	i_karmaTI,
	i_karmaTT,
	i_karmaTD,
	i_karmaDI,
	i_karmaDT,
	i_karmaDD,
	i_creditsII,
	i_creditsIT,
	i_creditsID,
	i_creditsTI,
	i_creditsTT,
	i_creditsTD,
	i_creditsDI,
	i_creditsDT,
	i_creditsDD,
	i_creditsFoundBody,
	i_creditsTaserHurtTraitor,
	i_traitorloseAliveNonTraitors,
	i_traitorloseDeadNonTraitors,
	i_traitorwinAliveTraitors,
	i_traitorwinDeadTraitors,
	bool:b_showDeathMessage,
	bool:b_showKillMessage,
	bool:b_showEarnKarmaMessage,
	bool:b_showEarnCreditsMessage,
	bool:b_showLoseKarmaMessage,
	bool:b_showLoseCreditsMessage,
	i_messageTypKarma,
	i_messageTypCredits,
	bool:b_blockSuicide,
	bool:b_allowFlash,
	bool:b_blockLookAtWeapon,
	bool:b_blockGrenadeMessage,
	bool:b_blockRadioMessage,
	bool:b_enableNoBlock,
	String:s_pluginTag[MAX_MESSAGE_LENGTH],
	bool:b_kadRemover,
	i_rulesClosePunishment,
	i_punishInnoKills,
	i_timeToReadRules,
	i_timeToReadDetectiveRules,
	bool:b_showRulesMenu,
	bool:b_showDetectiveMenu,
	String:s_kickImmunity[16],
	bool:b_updateClientModel,
	bool:b_removeHostages,
	bool:b_removeBomb,
	bool:b_roleAgain,
	i_traitorRatio,
	i_detectiveRatio,
	bool:b_taserAllow,
	Float:f_jihadPreparingTime,
	bool:b_denyFire,
	bool:b_slayAfterStart,
	i_c4ShakeRadius,
	Float:f_c4DamageRadius,
	i_startCredits,
	bool:b_removeBuyzone,
	bool:b_forceTeams,
	bool:b_randomWinner,
	bool:b_forceModel,
	String:s_modelCT[PLATFORM_MAX_PATH],
	String:s_modelT[PLATFORM_MAX_PATH],
	String:s_logFile[PLATFORM_MAX_PATH],
	String:s_errFile[PLATFORM_MAX_PATH],
	String:s_defaultPri_D[64],
	String:s_defaultSec[64],
	bool:b_endwithD,
	bool:b_hideTeams,
	bool:b_publicKarma,
	bool:b_stripWeapons,
	bool:b_C4Beam,
	bool:b_karmaDMG,
	bool:b_karmaDMG_up,
	Float:f_roundDelay,
	bool:b_nextRoundAlert,
	bool:b_endroundDMG
};

// TODO: Move this to (adt) array
int g_iCustomItemCount = 0;
char g_cCustomItems_Long[MAX_CUSTOM_ITEMS][64];
char g_cCustomItems_Short[MAX_CUSTOM_ITEMS][16];
int g_iCustomItems_Price[MAX_CUSTOM_ITEMS] = { 0, ... };
int g_iCustomItems_Role[MAX_CUSTOM_ITEMS] = { 0, ... };

int g_iConfig[eConfig];

char g_sConfigFile[PLATFORM_MAX_PATH + 1];
char g_sRulesFile[PLATFORM_MAX_PATH + 1];
char g_sCFile[PLATFORM_MAX_PATH + 1];

int g_iCredits[MAXPLAYERS + 1] =  { 0, ... };

bool g_bHasC4[MAXPLAYERS + 1] =  { false, ... };
bool g_bRoundEnded = false;

int g_iRDMAttacker[MAXPLAYERS + 1] =  { -1, ... };
Handle g_hRDMTimer[MAXPLAYERS + 1] =  { null, ... };
bool g_bImmuneRDMManager[MAXPLAYERS + 1] =  { false, ... };
bool g_bHoldingProp[MAXPLAYERS + 1] =  { false, ... };
bool g_bHoldingSilencedWep[MAXPLAYERS + 1] =  { false, ... };

int g_iAccount;

Handle g_hExplosionTimer[MAXPLAYERS + 1] =  { null, ... };
bool g_bHasActiveBomb[MAXPLAYERS + 1] =  { false, ... };
int g_iWire[MAXPLAYERS + 1] =  { -1, ... };
int g_iDefusePlayerIndex[MAXPLAYERS + 1] =  { -1, ... };

bool g_bScan[MAXPLAYERS + 1] =  { false, ... };
bool g_bJihadBomb[MAXPLAYERS + 1] =  { false, ... };
bool g_bID[MAXPLAYERS + 1] =  { false, ... };
Handle g_hJihadBomb[MAXPLAYERS + 1] =  { null, ... };
int g_iRole[MAXPLAYERS + 1] =  { 0, ... };

int g_iInnoKills[MAXPLAYERS + 1] =  { 0, ... };

Handle g_hGraceTime = null;

Handle g_hStartTimer = null;

float g_fRealRoundStart;
Handle g_hCountdownTimer = null;

Handle g_hPlayerArray = null;

Handle g_hDetectives = null;
Handle g_hTraitores = null;

int g_iIcon[MAXPLAYERS + 1] =  { 0, ... };

bool g_bRoundStarted = false;

Handle g_hRoundTimer = null;

bool g_bInactive = false;

int g_iCollisionGroup = -1;

bool g_bKarma[MAXPLAYERS + 1] =  { false, ... };
int g_iKarma[MAXPLAYERS + 1] =  { 0, ... };

Handle g_hRagdollArray = null;

int g_iBeamSprite = -1;
int g_iC4BeamSprite = -1;
int g_iHaloSprite = -1;

bool g_bFound[MAXPLAYERS + 1] = {false, ...};
bool g_bDetonate[MAXPLAYERS + 1] = {false, ...};

int g_iAlive = -1;
int g_iKills = -1;
int g_iDeaths = -1;
int g_iAssists = -1;
int g_iMVPs = -1;

char g_sBadNames[256][MAX_NAME_LENGTH];
int g_iBadNameCount = 0;

Handle g_hDatabase = null;

DataPack g_dPack;

enum Ragdolls
{
	ent,
	victim,
	attacker,
	String:victimName[MAX_NAME_LENGTH],
	String:attackerName[MAX_NAME_LENGTH],
	bool:scanned,
	Float:gameTime,
	String:weaponused[32],
	bool:found
}

bool g_bReceivingLogs[MAXPLAYERS + 1] =  { false, ... };

Handle g_hLogsArray;

bool g_bReadRules[MAXPLAYERS + 1] =  { false, ... };
bool g_bKnowRules[MAXPLAYERS + 1] =  { false, ... };

bool g_bConfirmDetectiveRules[MAXPLAYERS + 1] =  { false, ... };

int g_iSite[MAXPLAYERS + 1] =  { 0, ... };

Handle g_hOnRoundStart_Pre = null;
Handle g_hOnRoundStart = null;
Handle g_hOnRoundStartFailed = null;
Handle g_hOnClientGetRole = null;
Handle g_hOnClientDeath = null;
Handle g_hOnBodyFound = null;
Handle g_hOnBodyScanned = null;
Handle g_hOnItemPurchased = null;
Handle g_hOnCreditsGiven_Pre = null;
Handle g_hOnCreditsGiven = null;

char g_sShopCMDs[][] = {
	"menu",
	"shop"
};

char g_sRadioCMDs[][] = {
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

char g_sRemoveEntityList[][] = {
	"func_bomb_target",
	"hostage_entity",
	"func_hostage_rescue",
	"info_hostage_spawn",
	"func_buyzone"
};