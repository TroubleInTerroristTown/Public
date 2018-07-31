#if defined _turret_core_included
 #endinput
#endif

#define _turret_core_included

native void CreateTurret(int client);
native void RemoveTurret(int client);
native void SetTurretCanAttackClient(int client,bool CanAttack = false);


public SharedPlugin __pl_turret_core = 
{
    name = "turret_core",
    file = "turret_core.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_turret_core_SetNTVOptional()
{
    MarkNativeAsOptional("CreateTurret");
    MarkNativeAsOptional("RemoveTurret");
    MarkNativeAsOptional("SetTurretCanAttackClient");
}
#endif