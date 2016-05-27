/*
**
*/
#if defined _TTT_SHOP_included
 #endinput
#endif
#define _TTT_SHOP_included

/*
 * Called when an item is purchased in the menu. Return Plugin_Stop
 * to prevent us subtracting credits and informing the player that
 * the item was purchased.
 *
 * @param client            The client who purchased the item.
 * @param itemshort         The short-tag for the item's name.
 */
forward Action TTT_OnItemPurchased(int client, const char[] itemshort);

/*
 * Registers a custom item in the menu/shop.
 *
 * @param itemshort         The short-tag identifier of the item (must be unique).
 * @param itemlong          The long fancy name for the item.
 * @param price             The price of the item.
 * @param role              The optional role to restrict the item to.
 * @param sort				The priority in Sorting. Buy menu is sorted from high to low.
 */
native bool TTT_RegisterCustomItem(const char[] itemshort, const char[] itemlong, int price, int role = 0, int sort = 0);
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