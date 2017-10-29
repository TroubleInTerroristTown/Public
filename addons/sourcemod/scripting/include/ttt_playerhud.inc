#if defined _ttt_playerhud_included
	#endinput
#endif
#define _ttt_playerhud_included
/*
 * Called when a HUD is send to a player. Return Plugin_Stop
 * to prevent the HUD from beeing send.
 *
 * @param client            	The client who is targeting another player.
 * @param target            	The client who is targeted by another player.
 * @param sName      			The name string that will be send to the client.
 * @param sNameLength      		The length of the name string.
 * @param sPlayerName      		The playerhealth string that will be send to the client.
 * @param sPlayerNameLength     The length of the playername string.
 * @param sHealth      			The heatlh string that will be send to the client.
 * @param sHealthLength     	The length of the health string.
 * @param sPlayerHealth    		The playerhealth string that will be send to the client.
 * @param sPlayerHealthLength 	The length of the playerhealth string.
 * @param sKarma      			The karma string that will be send to the client.
 * @param sKarmaLength     		The length of the karma string.
 * @param sPlayerKarma      	The playerkarma string that will be send to the client.
 * @param sPlayerKarmaLength    The length of the playerkarma string.
 */
forward void TTT_OnHudSend_Pre(int client, int target, char[] sName, int iNameLength, char[] sPlayerName, int iPlayerNameLength, char[] sHealth, int iHealthLength, char[] sPlayerHealth, int iPlayerHealthLength, char[] sKarma, int iKarmaLength, char[] sPlayerKarma, int iPlayerKarmaLength);
