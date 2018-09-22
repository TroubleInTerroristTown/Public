#if defined _ttt_shop_discount_included
    #endinput
#endif
#define _ttt_shop_discount_included

native int TTT_GetItemDiscount(int client, const char[] shortName);

public SharedPlugin __pl_ttt_shop_discount = 
{
    name = "ttt_shop_discount",
    file = "ttt_shop_discount.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_ttt_shop_discount_SetNTVOptional()
{
    MarkNativeAsOptional("TTT_GetItemDiscount");
}
#endif
