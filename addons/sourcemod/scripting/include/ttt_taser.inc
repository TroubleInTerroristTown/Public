#if defined _ttt_taser_included
	#endinput
#endif
#define _ttt_taser_included

/*
 * Called when a player is tased by another player.
 *
 * @param attacker            The client who tased another player
 * @param ragdoll            The client who was tased by anther player
 */
forward Action TTT_OnTased(int attacker, int victim);
