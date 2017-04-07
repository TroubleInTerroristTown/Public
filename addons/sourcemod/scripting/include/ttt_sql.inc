#if defined _TTT_SQL_included
 #endinput
#endif
#define _TTT_SQL_included

native void TTT_Query(const char[] debugname, const char[] query);
native Database TTT_GetSQLConnection();

forward void TTT_OnSQLConnect(Database db);