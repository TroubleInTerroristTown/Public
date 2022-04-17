#if defined _fourcc_included
    #endinput
#endif
#define _fourcc_included

stock int FourCC_FromString(char[] buffer)
{
    int value = 0;
    value += buffer[0] << 24;
    value += buffer[1] << 16;
    value += buffer[2] << 8;
    value += buffer[3];

    return value;
}

stock void FourCC_ToString(int value, char[] buffer)
{
    buffer[0] = view_as<char>(value >> 24);
    buffer[1] = view_as<char>(value >> 16);
    buffer[2] = view_as<char>(value >> 8);
    buffer[3] = view_as<char>(value);
}
