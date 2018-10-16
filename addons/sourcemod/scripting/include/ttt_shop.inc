#if defined _ttt_shop_included
    #endinput
#endif
#define _ttt_shop_included

#define SHOP_ITEM_4ALL 1

/*
 * Called when an item is purchased in the menu. Return Plugin_Stop
 * to prevent us subtracting credits and informing the player that
 * the item was purchased.
 *
 * @param client            The client who purchased the item.
 * @param itemshort         The short-tag for the item's name.
 * @param count             TODO(?)
 * @param price             The price that the item has cost. (0 = Free)
 */
forward Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count, int price);

forward Action TTT_OnItemPurchase(int client, int &price, bool &count, const char[] item);

/*
 * Called when items array was initialized. This was added to avoid "empty items list".
 *
 */
forward void TTT_OnShopReady();

/*
 * Called after a players credits are modified.
 *
 * @param client            Client index.
 * @param credits             The new amount of credits.
 */
forward void TTT_OnCreditsChanged(int client, int &credits);

/*
 * Called before a players credits are modified.
 *
 * @param client            Client index.
 * @param oldcredits        The old amount of credits.
 * @param newcredits          The new amount of credits.
 */
forward Action TTT_OnCreditsChanged_Pre(int client, int oldcredits, int &newcredits);

/*
 * Registers a custom item in the menu/shop.
 *
 * @param itemshort         The short-tag identifier of the item (must be unique).
 * @param itemlong          The long fancy name for the item.
 * @param price             The price of the item.
 * @param role              The optional role to restrict the item to. (Default: 0 - for all)
 * @param sort                The priority in Sorting. Buy menu is sorted from high to low. (Default: 0)
 */
native bool TTT_RegisterCustomItem(const char[] itemshort, const char[] itemlong, int price, int role = 0, int sort = 0);

/*
 * Update shop item.
 *
 * @param itemshort         The short-tag identifier to find the item.
 * @param price             The price of the item.
 * @param sort                The priority in Sorting. Buy menu is sorted from high to low.
 */
native bool TTT_UpdateCustomItem(const char[] itemshort, int price, int sort = 0);

/*
 * Remove shop item.
 *
 * @param itemshort         The short-tag identifier to find the item.
 * @return                    True it was removed, otherwise shop item not found
 */
native bool TTT_RemoveCustomItem(const char[] itemshort);

/*
 * Retrieve a custom item's price.
 *
 * @param item              The short-tag identifier of the item.
 */
native int TTT_GetCustomItemPrice(const char[] item);
/*
 * Retrieve a custom item's role restriction.
 *
 * @param item              The short-tag identifier of the item.
 */
native int TTT_GetCustomItemRole(const char[] item);

/*
 * Retrieve a client's credits.
 *
 * @param client            Client index.
 */
native int TTT_GetClientCredits(int client);

/*
 * Set a client's credits.
 *
 * @param client            Client index.
 */
native int TTT_SetClientCredits(int client, int credits);

/*
 * Add a client's credits (currentCredits+credits).
 *
 * @param client            Client index.
 */
native int TTT_AddClientCredits(int client, int credits);

/*
 * Add item to client (without any costs)
 *
 * @param client            Client Index
 * @param item                Short Item name
 * @return                    True item found/valid, false item not found
 */
native bool TTT_GiveClientItem(int client, const char[] item);
