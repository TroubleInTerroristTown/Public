void Config_OnPluginStart()
{
    char sFile[PLATFORM_MAX_PATH + 1];
    BuildPath(Path_SM, sFile, sizeof(sFile), "configs/ghostdm_settings.ini");

    KeyValues kvConfig = new KeyValues("GhostDM-Weapons");

    if (!kvConfig.ImportFromFile(sFile))
    {
        SetFailState("[GhostDM] Can't read \"%s\"! (ImportFromFile)", sFile);
        delete kvConfig;
        return;
    }

    // Get spawn protection time, respawn time and health value
    g_iHealth = kvConfig.GetNum("Health", 100);
    g_fRespawn = kvConfig.GetFloat("Respawn Delay", 5.0);
    g_fSpawnProt = kvConfig.GetFloat("Spawn Protection", 3.0);

    LogMessage("[GhostDM.General] Health: %d - Respawn Delay: %.f - Spawn Protection: %.f", g_iHealth, g_fRespawn, g_fSpawnProt);

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

    LogMessage("[GhostDM.General] Chest: %d - Helm: %d", g_bChest, g_bHelm);

    // Get primary weapons
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

            g_smPrimary.SetString(sClass, sName, true);

            LogMessage("[GhostDM.Primary] Class: %s - Name: %s", sClass, sName);
        }
        while (kvConfig.GotoNextKey(false));
    }
    kvConfig.GoBack();
    kvConfig.GoBack();

    // Get secondary weapons
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

    delete kvConfig;
}
