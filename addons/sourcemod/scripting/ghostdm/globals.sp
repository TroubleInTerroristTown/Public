/* Redie */
bool g_bBlockRedie = false;
bool g_bRedie[MAXPLAYERS + 1] = { false, ... };
bool g_bNoclipBlock[MAXPLAYERS + 1] = { false, ... };

Handle g_hNoclip[MAXPLAYERS + 1] = { null, ... };
Handle g_hNoclipReset[MAXPLAYERS + 1] = { null, ... };

/* Health and Armor */
int g_iHealth = -1;
bool g_bChest = false;
bool g_bHelm = false;
