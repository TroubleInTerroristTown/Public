#if defined _ttt_inventory_included
    #endinput
#endif
#define _ttt_inventory_included

/*
 * Called when inventory has been reinitialised after the round has started.
 */
forward void TTT_OnInventoryReady();

/*
 * Called when a player selects an item on their inventory. Expected behaviour is to use the item.
 */
forward void TTT_OnInventoryMenuItemSelect(int client, const char[] itemshort);

/*
 * Adds an item in a player's inventory.
 * 
 * @param client        Client index.
 * @param itemshort     Unique name for item.
 * 
 * @return              Returns item index in inventory if registered successfully or item already exists, else -1 if unique item does not exist in shop or client not in game.
 */
native bool TTT_AddInventoryItem(int client, const char[] itemshort);

/*
 * Removes an item in a player's inventory.
 *
 * @param client        Client index.
 * @param itemshort     Unique name of item.
 *
 * @return              Returns true on success or item already not in inventory. False if it fails to remove item.
 */
native bool TTT_RemoveInventoryItem(int client, const char[] itemshort);

/*
 * Checks whether or not the item is in the player's inventory.
 *
 * @param client        Client index.
 * @param itemshort     Unique name of the item.
 *
 * @return              Returns true if item is in inventory.
 */
native bool TTT_IsItemInInventory(int client, const char[] itemshort);

/*
 * Retrieves a map of the inventory items of a player. Note: Close Snapshot after use.
 *
 * @param client        Client index.
 *
 * @return              Snapshot of the client's inventory or null if client is not in game or has an empty inventory.
 */
native StringMapSnapshot TTT_GetInventoryListing(int client);
