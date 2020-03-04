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
 * @param quantity      The quantity to add (Default: 1)
 * 
 * @return              Returns item index in inventory if registered successfully or item already exists, else if unique item does not exist in shop or client not in game.
 */
native bool TTT_AddInventoryItem(int client, const char[] itemshort, int quantity = 1);

/*
 * Removes an item in a player's inventory.
 *
 * @param client        Client index.
 * @param itemshort     Unique name of item.
 * @param quantity      The quantity to add (Default: 1)
 *
 * @return              Returns true on success or item already not in inventory. False if it fails to remove item.
 */
native bool TTT_RemoveInventoryItem(int client, const char[] itemshort, int quantity = 1);

/*
 * Checks whether or not the item is in the player's inventory.
 * If you want to know how much, then you should use TTT_GetClientItemQuantity
 *
 * @param client        Client index.
 * @param itemshort     Unique name of the item.
 *
 * @return              Returns true if item is in inventory.
 */
native bool TTT_IsItemInInventory(int client, const char[] itemshort);
/*
 * Returns the quantity of a item in player's inventory.
 *
 * @param client        Client index.
 * @param itemshort     Unique name of the item.
 *
 * @return              Returns the quantity of the item in players's inventory
                        If the return is -1 then the player has no inventory
 */
native int TTT_GetClientItemQuantity(int client, const char[] itemshort);

/*
 * Retrieves a map of the inventory items of a player. Note: Close Snapshot after use.
 *
 * @param client        Client index.
 *
 * @return              Snapshot of the client's inventory or null if client is not in game or has an empty inventory.
 */
native StringMapSnapshot TTT_GetInventoryListing(int client);
