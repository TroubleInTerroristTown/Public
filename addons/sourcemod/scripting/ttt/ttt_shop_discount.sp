#pragma semicolon 1

#include <sourcemod>
#include <ttt>
#include <ttt_shop>

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Shop Discounts"

char g_sFile[PLATFORM_MAX_PATH + 1];

StringMap g_smPercent = null;
StringMap g_smFlag = null;

ConVar g_cPercents = null;
ConVar g_cFlags = null;

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
    CreateNative("TTT_GetItemDiscount", Native_GetItemDiscount);

    RegPluginLibrary("ttt_shop_discount");

    return APLRes_Success;
}

public int Native_GetItemDiscount(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    char sItem[16];
    GetNativeString(2, sItem, sizeof(sItem));

    if (TTT_IsClientValid(client))
    {
        char sFlag[16];
        g_smFlag.GetString(sItem, sFlag, sizeof(sFlag));
        
        int iPercent = 0;
        
        if (!HasFlags(client, sFlag))
        {
            return iPercent;
        }
        
        if (g_smPercent.GetValue(sItem, iPercent))
        {
            return iPercent;
        }
        
        return iPercent;
    }
    
    return -1;
}

public void OnPluginStart()
{
    TTT_IsGameCSGO();

    TTT_LoadTranslations();
    
    TTT_StartConfig("shop_discount");
    CreateConVar("ttt2_shop_discount_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cPercents = AutoExecConfig_CreateConVar("shop_discount_percents", "20", "How much percent discount? It's currently for all items with enabled discount, but we'll add better support with next bigger update.");
    g_cFlags = AutoExecConfig_CreateConVar("shop_discount_flags", "o", "Which flags has access to discount prices? (Default: o)");
    TTT_EndConfig();

    BuildPath(Path_SM, g_sFile, sizeof(g_sFile), "configs/ttt/shop_discounts.ini");
    
    delete g_smPercent;
    delete g_smFlag;
    g_smPercent = new StringMap();
    g_smFlag = new StringMap();
}

public void TTT_OnLatestVersion(const char[] version)
{
    TTT_CheckVersion(TTT_PLUGIN_VERSION, TTT_GetCommitsCount());
}

public void OnConfigsExecuted()
{
    Handle hFile = OpenFile(g_sFile, "rt");

    if (hFile == null)
    {
        SetFailState("[TTT] Can't open File: %s", g_sFile);
    }

    KeyValues kvRules = new KeyValues("Rules");

    if (!kvRules.ImportFromFile(g_sFile))
    {
        SetFailState("Can't read %s correctly! (ImportFromFile)", g_sFile);
        delete kvRules;
        delete hFile;
        return;
    }

    if (!kvRules.GotoFirstSubKey())
    {
        SetFailState("Can't read %s correctly! (GotoFirstSubKey)", g_sFile);
        delete kvRules;
        delete hFile;
        return;
    }

    int iDPercent = g_cPercents.IntValue;

    char sDFlag[16];
    g_cFlags.GetString(sDFlag, sizeof(sDFlag));

    do
    {
        char sShort[16];
        int iPercent;
        char sFlag[16];

        kvRules.GetSectionName(sShort, sizeof(sShort));
        iPercent = kvRules.GetNum("percentage", iDPercent);
        kvRules.GetString("flag", sFlag, sizeof(sFlag), sDFlag);

        if (strlen(sShort) > 1 && iPercent >= 1 && iPercent <= 100)
        {
            g_smPercent.SetValue(sShort, iPercent, true);
            g_smFlag.SetString(sShort, sFlag, true);
        }
    }
    while (kvRules.GotoNextKey());

    delete kvRules;
    delete hFile;
}

public Action TTT_OnItemPurchase(int client, int &price, bool &count, const char[] sItem)
{
    if (TTT_IsClientValid(client) && IsPlayerAlive(client))
    {
        int iPercent = 0;
        if (g_smPercent.GetValue(sItem, iPercent))
        {
            float fPercentage = iPercent / 100.0;
            int iDiscount = RoundToCeil(price * fPercentage);
            int iOld = price;
            price = iOld - iDiscount;
            return Plugin_Changed;
        }
    }
    return Plugin_Continue;
}

bool HasFlags(int client, const char[] flags)
{
    AdminFlag aFlags[24];
    FlagBitsToArray(ReadFlagString(flags), aFlags, sizeof(aFlags));
    
    return _HasFlags(client, aFlags);
}

bool _HasFlags(int client, AdminFlag flags[24])
{
    int iFlags = GetUserFlagBits(client);

    if (iFlags & ADMFLAG_ROOT)
    {
        return true;
    }

    for (int i = 0; i < sizeof(flags); i++)
    {
        if (iFlags & FlagToBit(flags[i]))
        {
            return true;
        }
    }

    return false;
}
