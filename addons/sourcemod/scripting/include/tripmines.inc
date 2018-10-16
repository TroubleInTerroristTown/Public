#if defined _tripmines_included
    #endinput
#endif
#define _tripmines_included

/*
 * Called before planting, useful to block planting while something.
 *
 * @param client            The client/planter index
 */
forward Action Tripmine_OnPlant(int client);

/*
 * Called after planted, can't blocked anymore.
 *
 * @param client            The client/planter index
 * @param entity            The entity index
 * @param beam                The beam index
 */
forward void Tripmine_Planted(int client, int entity, int beam);

/*
 * Called when tripmine is ready to use.
 *
 * @param client            The client/planter index
 * @param entity            The entity index
 * @param beam                The beam index
 */
forward void Tripmine_Ready(int client, int entity, int beam);

/*
 * Returns the amount of mines of a client
 *
 * @param client            The client index
 * @return                    returns the amount of mines for the client
 */
native int Tripmine_GetClientMines(int client);

/*
 * Adds the amount of mines for a client
 *
 * @param client            The client index
 * @return                    returns the (new) amount of mines for the client
 */
native int Tripmine_AddClientMines(int client, int amount);


/*
 * Sets the amount of mines for a client
 *
 * @param client            The client index
 * @return                    returns the (new) amount of mines for the client
 */
native int Tripmine_SetClientMines(int client, int amount);

public SharedPlugin __pl_tripmines = 
{
    name = "tripmines",
    file = "tripmines.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_tripmines_SetNTVOptional()
{
    // MarkNativeAsOptional("");
}
#endif
