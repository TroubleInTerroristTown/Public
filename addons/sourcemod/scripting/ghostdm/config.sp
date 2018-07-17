void Config_OnPluginStart()
{
    char sFile[PLATFORM_MAX_PATH + 1];
    BuildPath(Path_SM, sFile, sizeof(sFile), "configs/ghostdm_settings.ini");

    KeyValues kvConfig = CreateKeyValues("GhostDM-Weapons");

    if (!kvConfig.ImportFromFile(sFile))
    {
        SetFailState("[GhostDM] Can't read \"%s\"! (ImportFromFile)", sFile);
        delete kvConfig;
        return;
    }

    // Get health value
    g_iHealth = kvConfig.GetNum("Health", 100);

    // Get armor and helm value
    if (!kvConfig.JumpToKey("Armor", false))
    {
        SetFailState("[GhostDM] Can't find the entry \"Armor\" in \"%s\"! (JumpToKey)", sFile);
        delete kvConfig;
        return;
    }

    g_bChest = view_as<bool>(kvConfig.GetNum("Chest", 1));
    g_bHelm = view_as<bool>(kvConfig.GetNum("Helm", 0));
    kvConfig.GoBack();

    LogMessage("[GhostDM.General] Health: %d - Chest: %d - Helm: %d", g_iHealth, g_bChest, g_bHelm);

    // Get primary weapons
    delete g_aPrimary;
    g_aPrimary = new ArrayList(32);

    delete g_smPrimary;
    g_smPrimary = new StringMap();

    if (!kvConfig.JumpToKey("Primary", false))
    {
        SetFailState("[GhostDM] Can't find the entry \"Primary\" in \"%s\"! (JumpToKey)", sFile);
        delete kvConfig;
        return;
    }

    if (kvConfig.GotoFirstSubKey(false))
    {
        do
        {
            char sClass[32];
            char sName[64];

            kvConfig.GetSectionName(sClass, sizeof(sClass));
            kvConfig.GetString(NULL_STRING, sName, sizeof(sName));

            g_aPrimary.PushString(sClass);
            g_smPrimary.SetString(sClass, sName, true);

            LogMessage("[GhostDM.Primary] Class: %s - Name: %s", sClass, sName);
        }
        while (kvConfig.GotoNextKey(false));
    }
    kvConfig.GoBack();
    kvConfig.GoBack();

    // Get secondary weapons
    delete g_aSecondary;
    g_aSecondary = new ArrayList(32);

    delete g_smSecondary;
    g_smSecondary = new StringMap();

    if (!kvConfig.JumpToKey("Secondary", false))
    {
        SetFailState("[GhostDM] Can't find the entry \"Secondary\" in \"%s\"! (JumpToKey)", sFile);
        delete kvConfig;
        return;
    }

    if (kvConfig.GotoFirstSubKey(false))
    {
        do
        {
            char sClass[32];
            char sName[64];

            kvConfig.GetSectionName(sClass, sizeof(sClass));
            kvConfig.GetString(NULL_STRING, sName, sizeof(sName));

            g_aSecondary.PushString(sClass);
            g_smSecondary.SetString(sClass, sName, true);

            LogMessage("[GhostDM.Secondary] Class: %s - Name: %s", sClass, sName);
        }
        while (kvConfig.GotoNextKey(false));
    }
    kvConfig.GoBack();
    kvConfig.GoBack();

    // Get weapon limits
    delete g_smWeaponLimits;
    g_smWeaponLimits = new StringMap();

    if (!kvConfig.JumpToKey("Limits-Weapons", false))
    {
        SetFailState("[GhostDM] Can't find the entry \"Limits-Weapons\" in \"%s\"! (JumpToKey)", sFile);
        delete kvConfig;
        return;
    }

    if (kvConfig.GotoFirstSubKey(false))
    {
        do
        {
            char sClass[32];

            kvConfig.GetSectionName(sClass, sizeof(sClass));
            int iLimit = kvConfig.GetNum(NULL_STRING);

            g_smWeaponLimits.SetValue(sClass, iLimit, true);

            LogMessage("[GhostDM.Limits-Weapons] Class: %s - Limit: %d", sClass, iLimit);
        }
        while (kvConfig.GotoNextKey(false));
    }
    kvConfig.GoBack();
    kvConfig.GoBack();

    // Get grenades
    delete g_aGrenade;
    g_aGrenade = new ArrayList(32);

    delete g_smGrenade;
    g_smGrenade = new StringMap();

    if (!kvConfig.JumpToKey("Grenades", false))
    {
        SetFailState("[GhostDM] Can't find the entry \"Grenades\" in \"%s\"! (JumpToKey)", sFile);
        delete kvConfig;
        return;
    }

    if (kvConfig.GotoFirstSubKey(false))
    {
        do
        {
            char sClass[32];
            char sName[64];

            kvConfig.GetSectionName(sClass, sizeof(sClass));
            kvConfig.GetString(NULL_STRING, sName, sizeof(sName));

            g_aGrenade.PushString(sClass);
            g_smGrenade.SetString(sClass, sName, true);

            LogMessage("[GhostDM.Grenades] Class: %s - Name: %s", sClass, sName);
        }
        while (kvConfig.GotoNextKey(false));
    }
    kvConfig.GoBack();
    kvConfig.GoBack();

    // Get grenades limits
    delete g_smGrenadeLimits;
    g_smGrenadeLimits = new StringMap();

    if (!kvConfig.JumpToKey("Limits-Grenades", false))
    {
        SetFailState("[GhostDM] Can't find the entry \"Limits-Grenades\" in \"%s\"! (JumpToKey)", sFile);
        delete kvConfig;
        return;
    }

    if (kvConfig.GotoFirstSubKey(false))
    {
        do
        {
            char sClass[32];

            kvConfig.GetSectionName(sClass, sizeof(sClass));
            int iLimit = kvConfig.GetNum(NULL_STRING);

            g_smGrenadeLimits.SetValue(sClass, iLimit, true);

            LogMessage("[GhostDM.Limits-Grenades] Class: %s - Limit: %d", sClass, iLimit);
        }
        while (kvConfig.GotoNextKey(false));
    }
    kvConfig.GoBack();
    kvConfig.GoBack();

    delete kvConfig;
}
