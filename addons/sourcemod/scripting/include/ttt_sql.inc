#if defined _ttt_sql_included
	#endinput
#endif
#define _ttt_sql_included

native void TTT_Query(const char[] debugname, const char[] query);
native Database TTT_GetSQLConnection();

forward void TTT_OnSQLConnect(Database db);