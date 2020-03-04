#if defined _ttt_taser_included
    #endinput
#endif
#define _ttt_taser_included

/*
 * Called before a player is tased by another player.
 *
 * @param attacker          The client who tased another player
 * @param victim            The client who was tased by another player
 * @param victimRole        The victims role
 */
forward Action TTT_OnTased_Pre(int attacker, int victim, int& victimRole);

/*
 * Called after a player is tased by another player
 *
 * @param attacker          The client who tased another player
 * @param victim            The client who was tased by another player      
 */
forward void TTT_OnTased_Post(int attacker, int victim);