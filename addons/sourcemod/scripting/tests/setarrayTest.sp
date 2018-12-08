#include <sourcemod>

enum eEnum {
    iInt1,
    iInt2,
    bool:bBool
};

public void OnPluginStart()
{
    ArrayList aArray = new ArrayList(3);

    int iPush[eEnum];
    iPush[iInt1] = 1;
    iPush[iInt2] = 10;
    iPush[bBool] = true;
    aArray.PushArray(iPush[0]);

    bool bTest = false;
    PrintToServer("bTest: %d -> %d vs %d vs. %d", bTest, !bTest, (!bTest), !(bTest));

    for (int j = 1; j <= 10; j++)
    {
        for (int i = 0; i < aArray.Length; i++)
        {
            int iGet[eEnum];
            aArray.GetArray(i, iGet[0]);

            PrintToServer("Try #%d -> Index: %d iInt1: %d, iInt2: %d, bBool: %d", j, i, iGet[iInt1], iGet[iInt2], iGet[bBool]);

            iGet[iInt1]++;
            iGet[iInt2]--;
            iGet[bBool] = !iGet[bBool];
            aArray.SetArray(i, iGet[0]);
        }
    }
}
