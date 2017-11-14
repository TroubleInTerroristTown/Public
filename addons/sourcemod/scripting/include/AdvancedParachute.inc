#if defined _advanced_parachute_included
  #endinput
#endif
#define _advanced_parachute_included

forward Action OnParachuteOpen(int client);

public SharedPlugin __pl_advanced_parachute = 
{
  name = "AdvancedParachute",
  file = "AdvancedParachute.smx",
#if defined REQUIRE_PLUGIN
  required = 1,
#else
  required = 0,
#endif
};
