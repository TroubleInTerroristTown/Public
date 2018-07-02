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

    g_iHealth = kvConfig.GetNum("Health", 100);

    if (!kvConfig.JumpToKey("Armor", false))
    {
        SetFailState("[GhostDM] Can't find the entry \"Armor\" in \"%s\"! (JumpToKey)", sFile);
        delete kvConfig;
        return;
    }

    g_bChest = view_as<bool>(kvConfig.GetNum("Chest", 1));
    g_bHelm = view_as<bool>(kvConfig.GetNum("Helm", 1));

    kvConfig.GoBack();

    delete kvConfig;
}
