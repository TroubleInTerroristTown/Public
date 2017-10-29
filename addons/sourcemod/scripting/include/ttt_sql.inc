#if defined _ttt_sql_included
	#endinput
#endif
#define _ttt_sql_included

enum dConnection {
	dSQLite = 0,
	dMySQL
};

native void TTT_Query(const char[] debugname, const char[] query);

native Database TTT_GetSQLConnection();

native dConnection TTT_GetConnectionType();

forward void TTT_OnSQLConnect(Database db);
