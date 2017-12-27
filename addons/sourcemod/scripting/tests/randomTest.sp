#include <sourcemod>

public void OnPluginStart()
{
	RegConsoleCmd("sm_iftest", Command_IfTest);
	RegConsoleCmd("sm_random", Command_Random);
}

public Action Command_IfTest(int client, int args)
{
	int a = 1;
	int b = 2;

	if (a == 1 || 2)
	{
		ReplyToCommand(client, "a is %d", a);
	}

	if (b == 1 || 2)
	{
		ReplyToCommand(client, "b is %d", b);
	}
}

public Action Command_Random(int client, int args)
{
	int count[6][10];
	
	for (int player = 0; player <= 5; player++)
	{
		SetRandomSeed(GetTime() * GetRandomInt(2, 9));
		
		for (int i = 0; i <= 10000; i++)
		{
			int number = GetRandomInt(0, 9);
			count[player][number]++;
		}
	}
	
	for (int player = 0; player <= 5; player++)
	{
		for (int i = 0; i <= 9; i++)
		{
			ReplyToCommand(client, "Player: %d - Number: %d - Count: %d", player, i, count[player][i]);
		}
	}
}

// sm_random with SetRandomSeed (for every player before 10k loop)
/*
	sm_random
		Player: 0 - Number: 0 - Count: 990
		Player: 0 - Number: 1 - Count: 1022
		Player: 0 - Number: 2 - Count: 1015
		Player: 0 - Number: 3 - Count: 1011
		Player: 0 - Number: 4 - Count: 1003
		Player: 0 - Number: 5 - Count: 1040
		Player: 0 - Number: 6 - Count: 942
		Player: 0 - Number: 7 - Count: 1014
		Player: 0 - Number: 8 - Count: 978
		Player: 0 - Number: 9 - Count: 986
		
		Player: 1 - Number: 0 - Count: 1009
		Player: 1 - Number: 1 - Count: 1021
		Player: 1 - Number: 2 - Count: 979
		Player: 1 - Number: 3 - Count: 999
		Player: 1 - Number: 4 - Count: 997
		Player: 1 - Number: 5 - Count: 1041
		Player: 1 - Number: 6 - Count: 1000
		Player: 1 - Number: 7 - Count: 992
		Player: 1 - Number: 8 - Count: 981
		Player: 1 - Number: 9 - Count: 982
		
		Player: 2 - Number: 0 - Count: 1001
		Player: 2 - Number: 1 - Count: 966
		Player: 2 - Number: 2 - Count: 1004
		Player: 2 - Number: 3 - Count: 997
		Player: 2 - Number: 4 - Count: 1002
		Player: 2 - Number: 5 - Count: 1019
		Player: 2 - Number: 6 - Count: 1020
		Player: 2 - Number: 7 - Count: 1003
		Player: 2 - Number: 8 - Count: 990
		Player: 2 - Number: 9 - Count: 999
		
		Player: 3 - Number: 0 - Count: 994
		Player: 3 - Number: 1 - Count: 975
		Player: 3 - Number: 2 - Count: 930
		Player: 3 - Number: 3 - Count: 1048
		Player: 3 - Number: 4 - Count: 1000
		Player: 3 - Number: 5 - Count: 1013
		Player: 3 - Number: 6 - Count: 989
		Player: 3 - Number: 7 - Count: 1047
		Player: 3 - Number: 8 - Count: 996
		Player: 3 - Number: 9 - Count: 1009
		
		Player: 4 - Number: 0 - Count: 990
		Player: 4 - Number: 1 - Count: 973
		Player: 4 - Number: 2 - Count: 955
		Player: 4 - Number: 3 - Count: 996
		Player: 4 - Number: 4 - Count: 1031
		Player: 4 - Number: 5 - Count: 1024
		Player: 4 - Number: 6 - Count: 1055
		Player: 4 - Number: 7 - Count: 980
		Player: 4 - Number: 8 - Count: 1022
		Player: 4 - Number: 9 - Count: 975
		
		Player: 5 - Number: 0 - Count: 1040
		Player: 5 - Number: 1 - Count: 997
		Player: 5 - Number: 2 - Count: 1013
		Player: 5 - Number: 3 - Count: 944
		Player: 5 - Number: 4 - Count: 993
		Player: 5 - Number: 5 - Count: 1001
		Player: 5 - Number: 6 - Count: 978
		Player: 5 - Number: 7 - Count: 966
		Player: 5 - Number: 8 - Count: 1040
		Player: 5 - Number: 9 - Count: 1029
*/

// sm_random without SetRandomSeed
/*
	sm_random
		Player: 0 - Number: 0 - Count: 990
		Player: 0 - Number: 1 - Count: 1022
		Player: 0 - Number: 2 - Count: 1015
		Player: 0 - Number: 3 - Count: 1011
		Player: 0 - Number: 4 - Count: 1003
		Player: 0 - Number: 5 - Count: 1040
		Player: 0 - Number: 6 - Count: 942
		Player: 0 - Number: 7 - Count: 1014
		Player: 0 - Number: 8 - Count: 978
		Player: 0 - Number: 9 - Count: 986
		
		Player: 1 - Number: 0 - Count: 1009
		Player: 1 - Number: 1 - Count: 1021
		Player: 1 - Number: 2 - Count: 979
		Player: 1 - Number: 3 - Count: 999
		Player: 1 - Number: 4 - Count: 997
		Player: 1 - Number: 5 - Count: 1041
		Player: 1 - Number: 6 - Count: 1000
		Player: 1 - Number: 7 - Count: 992
		Player: 1 - Number: 8 - Count: 981
		Player: 1 - Number: 9 - Count: 982
		
		Player: 2 - Number: 0 - Count: 1001
		Player: 2 - Number: 1 - Count: 966
		Player: 2 - Number: 2 - Count: 1004
		Player: 2 - Number: 3 - Count: 997
		Player: 2 - Number: 4 - Count: 1002
		Player: 2 - Number: 5 - Count: 1019
		Player: 2 - Number: 6 - Count: 1020
		Player: 2 - Number: 7 - Count: 1003
		Player: 2 - Number: 8 - Count: 990
		Player: 2 - Number: 9 - Count: 999
		
		Player: 3 - Number: 0 - Count: 994
		Player: 3 - Number: 1 - Count: 975
		Player: 3 - Number: 2 - Count: 930
		Player: 3 - Number: 3 - Count: 1048
		Player: 3 - Number: 4 - Count: 1000
		Player: 3 - Number: 5 - Count: 1013
		Player: 3 - Number: 6 - Count: 989
		Player: 3 - Number: 7 - Count: 1047
		Player: 3 - Number: 8 - Count: 996
		Player: 3 - Number: 9 - Count: 1009
		
		Player: 4 - Number: 0 - Count: 990
		Player: 4 - Number: 1 - Count: 973
		Player: 4 - Number: 2 - Count: 955
		Player: 4 - Number: 3 - Count: 996
		Player: 4 - Number: 4 - Count: 1031
		Player: 4 - Number: 5 - Count: 1024
		Player: 4 - Number: 6 - Count: 1055
		Player: 4 - Number: 7 - Count: 980
		Player: 4 - Number: 8 - Count: 1022
		Player: 4 - Number: 9 - Count: 975
		
		Player: 5 - Number: 0 - Count: 1040
		Player: 5 - Number: 1 - Count: 997
		Player: 5 - Number: 2 - Count: 1013
		Player: 5 - Number: 3 - Count: 944
		Player: 5 - Number: 4 - Count: 993
		Player: 5 - Number: 5 - Count: 1001
		Player: 5 - Number: 6 - Count: 978
		Player: 5 - Number: 7 - Count: 966
		Player: 5 - Number: 8 - Count: 1040
		Player: 5 - Number: 9 - Count: 1029
*/
