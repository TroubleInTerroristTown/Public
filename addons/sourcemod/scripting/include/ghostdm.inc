#if defined _ghostdm_included
    #endinput
#endif
#define _ghostdm_included

/*
 * Check if the client in redie mode
 * NOTE: Redie Mode != Deathmatch Mode
 *
 * @param   client          The client index
 * @return                  True if the client in redie mode, otherwise false
 */
native bool GhostDM_IsClientInRedie(int client);

/*
 * Check if the client in deathmatch mode
 * NOTE: Redie Mode != Deathmatch Mode
 *
 * @param   client          The client index
 * @return                  True if the client in deathmatch mode, otherwise false
 */
native bool GhostDM_IsClientInDeathmatch(int client);

public SharedPlugin __pl_ghostdm = 
{
    name = "ghostdm",
    file = "ghostdm.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_ghostdm_SetNTVOptional()
{
    MarkNativeAsOptional("GhostDM_IsClientInRedie");
    MarkNativeAsOptional("GhostDM_IsClientInDeathmatch");
}
#endif
