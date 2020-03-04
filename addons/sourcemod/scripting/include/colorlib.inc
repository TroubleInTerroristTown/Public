#if defined _colorlib_included
    #endinput
#endif
#define _colorlib_included

#include <colorlib_map>
 
#define MAX_MESSAGE_LENGTH 250

#define SERVER_INDEX 0
#define NO_INDEX -1
#define NO_PLAYER -2

enum _CL_ProtoBuff
{
    NotChecked = -1,
    DoesNotSupport = 0,
    Supports,
}

/* CL_Colors' properties */
_CL_ProtoBuff _CL_proto_buff_support = NotChecked;
bool _CL_skip_list[MAXPLAYERS + 1] = { false, ... };

/**
 * Prints a message to a specific client in the chat area.
 * Supports color tags.
 *
 * @param client    Client index.
 * @param message   Message (formatting rules).
 * @return          No return
 * 
 * On error/Errors:   If the client is not connected an error will be thrown.
 */
stock void CPrintToChat(int client, const char[] message, any ...)
{
    SetGlobalTransTarget(client);

    char buffer[MAX_MESSAGE_LENGTH];
    int buffer_index = CPreFormat(buffer);
    VFormat(buffer[buffer_index], sizeof(buffer) - buffer_index, message, 3);
    CFormat(buffer[buffer_index], sizeof(buffer) - buffer_index);
    PrintToChat(client, buffer);
    CRemoveColors(buffer, sizeof(buffer));
    PrintToConsole(client, buffer);
}

/**
 * Prints a message to a specific client in the chat area.
 * Supports color tags.
 *
 * @param client    Client index.
 * @param author    Author index whose color will be used for teamcolor tag.
 * @param message   Message (formatting rules).
 * @return          No return
 * 
 * On error/Errors: If the client or author are not connected an error will be thrown.
 */
stock void CPrintToChatEx(int client, int author, const char[] message, any ...)
{
    SetGlobalTransTarget(client);

    char buffer[MAX_MESSAGE_LENGTH];
    int buffer_index = CPreFormat(buffer);
    int buffer_size = sizeof(buffer) - buffer_index;
    VFormat(buffer[buffer_index], buffer_size, message, 4);
    CFormat(buffer[buffer_index], buffer_size, author);
    _CL_SendChatMessage(client, author, buffer);
    CRemoveColors(buffer, sizeof(buffer));
    PrintToConsole(client, buffer);
}

/**
 * Prints a message to all clients in the chat area.
 * Supports color tags.
 *
 * @param client    Client index.
 * @param message   Message (formatting rules)
 * @return          No return
 */
stock void CPrintToChatAll(const char[] message, any ...)
{
    char buffer[MAX_MESSAGE_LENGTH];
    int buffer_index = CPreFormat(buffer);
    int buffer_size = sizeof(buffer) - buffer_index;
    for (int i = 1; i <= MaxClients; ++i)
    {
        if (IsClientInGame(i) && !IsFakeClient(i) && !_CL_skip_list[i])
        {
            SetGlobalTransTarget(i);

            VFormat(buffer[buffer_index], buffer_size, message, 2);
            CFormat(buffer[buffer_index], buffer_size);
            PrintToChat(i, buffer);
            CRemoveColors(buffer, sizeof(buffer));
            PrintToConsole(i, buffer);
        }

        _CL_skip_list[i] = false;
    }
}

/**
 * Prints a message to all clients in the chat area.
 * Supports color tags.
 *
 * @param author    Author index whos color will be used for teamcolor tag.
 * @param message   Message (formatting rules).
 * @return          No return
 * 
 * On error/Errors: If the author is not connected an error will be thrown.
 */
stock void CPrintToChatAllEx(int author, const char[] message, any ...)
{
    char buffer[MAX_MESSAGE_LENGTH];
    int buffer_index = CPreFormat(buffer);
    int buffer_size = sizeof(buffer) - buffer_index;
    for (int i = 1; i <= MaxClients; ++i)
    {
        if (IsClientInGame(i) && !IsFakeClient(i) && !_CL_skip_list[i])
        {
            SetGlobalTransTarget(i);

            VFormat(buffer[buffer_index], buffer_size, message, 3);
            CFormat(buffer[buffer_index], buffer_size, author);
            _CL_SendChatMessage(i, author, buffer);
            CRemoveColors(buffer, sizeof(buffer));
            PrintToConsole(i, buffer);
        }

        _CL_skip_list[i] = false;
    }
}

/**
 * Prints a message to all clients on a specific team.
 * Supports color tags.
 *
 * @param team      Team index.
 * @param message   Message (formatting rules).
 * @return          No return
 * 
 * On error/Errors:   If the client is not connected an error will be thrown.
 */
stock void CPrintToChatTeam(int team, const char[] message, any ...)
{
    char buffer[MAX_MESSAGE_LENGTH];
    int buffer_index = CPreFormat(buffer);
    int buffer_size = sizeof(buffer) - buffer_index;
    for (int i = 1; i <= MaxClients; ++i)
    {
        if (IsClientInGame(i) &&
            !IsFakeClient(i) &&
            !_CL_skip_list[i] &&
            GetClientTeam(i) == team)
        {
            SetGlobalTransTarget(i);

            VFormat(buffer[buffer_index], buffer_size, message, 3);
            CFormat(buffer[buffer_index], buffer_size);
            PrintToChat(i, buffer);
            CRemoveColors(buffer, sizeof(buffer));
            PrintToConsole(i, buffer);
        }

        _CL_skip_list[i] = false;
    }
}

/**
 * Prints a message to all clients on a specific team.
 * Supports color tags.
 *
 * @param team      Team index.
 * @param author    Author index whos color will be used for teamcolor tag.
 * @param message   Message (formatting rules).
 * @return          No return
 * 
 * On error/Errors:   If the client is not connected an error will be thrown.
 */
stock void CPrintToChatTeamEx(int team, int author, const char[] message, any ...)
{
    char buffer[MAX_MESSAGE_LENGTH];
    int buffer_index = CPreFormat(buffer);
    int buffer_size = sizeof(buffer) - buffer_index;
    for (int i = 1; i <= MaxClients; ++i)
    {
        if (IsClientInGame(i) &&
            !IsFakeClient(i) &&
            !_CL_skip_list[i] &&
            GetClientTeam(i) == team)
        {
            SetGlobalTransTarget(i);

            VFormat(buffer[buffer_index], buffer_size, message, 4);
            CFormat(buffer[buffer_index], buffer_size, author);
            _CL_SendChatMessage(i, author, buffer);
            CRemoveColors(buffer, sizeof(buffer));
            PrintToConsole(i, buffer);
        }

        _CL_skip_list[i] = false;
    }
}

/**
 * Prints a message to all admins with the given access flags.
 * Supports color tags.
 *
 * @param flags     Admin flags.
 * @param message   Message (formatting rules).
 * @return          No return
 * 
 * On error/Errors:   If the client is not connected an error will be thrown.
 */
stock void CPrintToChatAdmins(int flags, const char[] message, any ...)
{
    char buffer[MAX_MESSAGE_LENGTH];
    int buffer_index = CPreFormat(buffer);
    int buffer_size = sizeof(buffer) - buffer_index;
    for (int i = 1; i <= MaxClients; ++i)
    {
        if (IsClientInGame(i) && !IsFakeClient(i) && !_CL_skip_list[i])
        {
            if (CheckCommandAccess(i, "colorlib_admin", flags, true))
            {
                SetGlobalTransTarget(i);

                VFormat(buffer[buffer_index], buffer_size, message, 3);
                CFormat(buffer[buffer_index], buffer_size);
                PrintToChat(i, buffer);
                CRemoveColors(buffer, sizeof(buffer));
                PrintToConsole(i, buffer);
            }
        }

        _CL_skip_list[i] = false;
    }
}

/**
 * Reples to a message in a command. A client index of 0 will use PrintToServer().
 * If the command was from the console, PrintToConsole() is used. If the command was from chat, C_PrintToChat() is used.
 * Supports color tags.
 *
 * @param client    Client index, or 0 for server.
 * @param message   Formatting rules.
 * @param ...       Variable number of format parameters.
 * @return          No return
 * 
 * On error/Errors:   If the client is not connected or invalid.
 */
stock void CReplyToCommand(int client, const char[] message, any ...)
{
    SetGlobalTransTarget(client);

    char buffer[MAX_MESSAGE_LENGTH];
    if (client == 0)
    {
        VFormat(buffer, sizeof(buffer), message, 3);
        CRemoveTags(buffer, sizeof(buffer));
        PrintToServer(buffer);
    }
    else if (GetCmdReplySource() == SM_REPLY_TO_CONSOLE)
    {
        VFormat(buffer, sizeof(buffer), message, 3);
        CRemoveTags(buffer, sizeof(buffer));
        PrintToConsole(client, buffer);
    }
    else
    {
        int buffer_index = CPreFormat(buffer);
        int buffer_size = sizeof(buffer) - buffer_index;
        VFormat(buffer[buffer_index], buffer_size, message, 3);
        CFormat(buffer[buffer_index], buffer_size);
        PrintToChat(client, buffer);
    }
}

/**
 * Reples to a message in a command. A client index of 0 will use PrintToServer().
 * If the command was from the console, PrintToConsole() is used. If the command was from chat, C_PrintToChat() is used.
 * Supports color tags.
 *
 * @param client    Client index, or 0 for server.
 * @param author    Author index whose color will be used for teamcolor tag.
 * @param message   Formatting rules.
 * @param ...       Variable number of format parameters.
 * @return          No return
 * 
 * On error/Errors:   If the client is not connected or invalid.
 */
stock void CReplyToCommandEx(int client, int author, const char[] message, any ...)
{
    SetGlobalTransTarget(client);

    char buffer[MAX_MESSAGE_LENGTH];
    if (client == 0)
    {
        VFormat(buffer, sizeof(buffer), message, 4);
        CRemoveTags(buffer, sizeof(buffer));
        PrintToServer("%s", buffer);
    }
    else if (GetCmdReplySource() == SM_REPLY_TO_CONSOLE)
    {
        VFormat(buffer, sizeof(buffer), message, 4);
        CRemoveTags(buffer, sizeof(buffer));
        PrintToConsole(client, "%s", buffer);
    }
    else
    {
        int buffer_index = CPreFormat(buffer);
        int buffer_size = sizeof(buffer) - buffer_index;
        VFormat(buffer[buffer_index], buffer_size, message, 4);
        CFormat(buffer[buffer_index], buffer_size);
        _CL_SendChatMessage(client, author, buffer);
    }
}

/**
 * Displays usage of an admin command to users depending on the setting of the sm_show_activity cvar.
 * This version does not display a message to the originating client if used from chat triggers or menus. If manual replies are used for these cases, then this function will suffice. Otherwise, ShowActivity2() is slightly more useful.
 * Supports color tags.
 *
 * @param client    Client index, or 0 for server.
 * @param message   Formatting rules.
 * @param ...       Variable number of format parameters.
 * @return          No return
 * 
 * On error/Errors:   If the client is not connected or invalid.
 */
stock void CShowActivity(int client, const char[] message, any ...)
{
    SetGlobalTransTarget(client);

    char buffer[MAX_MESSAGE_LENGTH];
    int buffer_index = CPreFormat(buffer);
    int buffer_size = sizeof(buffer) - buffer_index;
    VFormat(buffer[buffer_index], buffer_size, message, 3);
    CFormat(buffer[buffer_index], buffer_size);
    ShowActivity(client, buffer);
    CRemoveColors(buffer, sizeof(buffer));
    PrintToConsole(client, buffer);
}

/**
 * Displays usage of an admin command to users depending on the setting of the sm_show_activity cvar. All users receive a message in their chat text, except for the originating client, who receives the message based on the current ReplySource.
 * Supports color tags.
 *
 * @param client    Client index, or 0 for server.
 * @param message   Formatting rules.
 * @param ...       Variable number of format parameters.
 * @return          No return
 * 
 * On error/Errors:   If the client is not connected or invalid.
 */
stock void CShowActivity2(int client, const char[] tag, const char[] message, any ...)
{
    SetGlobalTransTarget(client);

    char buffer[MAX_MESSAGE_LENGTH], buffer_tag[MAX_MESSAGE_LENGTH];

    int tag_index = CPreFormat(buffer_tag);
    int tag_size = sizeof(buffer_tag) - tag_index;
    strcopy(buffer_tag[tag_index], tag_size, tag);
    CFormat(buffer_tag[tag_index], tag_size);

    int buffer_index = CPreFormat(buffer);
    int buffer_size = sizeof(buffer) - buffer_index;
    VFormat(buffer[buffer_index], buffer_size, message, 4);
    CFormat(buffer[buffer_index], buffer_size);

    ShowActivity2(client, buffer_tag, buffer);
    CRemoveColors(buffer, sizeof(buffer));
    PrintToConsole(client, buffer);
}

/**
 * Same as ShowActivity(), except the tag parameter is used instead of "[SM] " (note that you must supply any spacing).
 * Supports color tags.
 *
 * @param client    Client index, or 0 for server.
 * @param message   Formatting rules.
 * @param ...       Variable number of format parameters.
 * @return          No return
 * 
 * On error/Errors:   If the client is not connected or invalid.
 */
stock void CShowActivityEx(int client, const char[] tag, const char[] message, any ...)
{
    SetGlobalTransTarget(client);

    char buffer[MAX_MESSAGE_LENGTH], buffer_tag[MAX_MESSAGE_LENGTH];

    int tag_index = CPreFormat(buffer_tag);
    int tag_size = sizeof(buffer_tag) - tag_index;
    strcopy(buffer_tag[tag_index], tag_size, tag);
    CFormat(buffer_tag[tag_index], tag_size);

    int buffer_index = CPreFormat(buffer);
    int buffer_size = sizeof(buffer) - buffer_index;
    VFormat(buffer[buffer_index], buffer_size, message, 4);
    CFormat(buffer[buffer_index], buffer_size);

    ShowActivityEx(client, buffer_tag, buffer);
    CRemoveColors(buffer, sizeof(buffer));
    PrintToConsole(client, buffer);
}

/**
 * Replaces PrintToServer.
 * Removes color tags.
 *
 * @param message   Formatting rules.
 * @param ...       Variable number of format parameters.
 * @return          No return
 */
stock void CPrintToServer(const char[] message, any ...)
{
    char buffer[MAX_MESSAGE_LENGTH];
    VFormat(buffer, sizeof(buffer), message, 2);
    CRemoveTags(buffer, sizeof(buffer));
    PrintToServer(buffer);
}

/**
 * Removes color tags from the string.
 *
 * @param message   String.
 * @return          No return
 */
stock void CRemoveTags(char[] message, int maxlength)
{
    int index = 0;
    for (int i = 0; i < maxlength; ++i)
    {
        if (message[i] == 0x00)
        {
            break;
        }

        if (message[i] == '\\')
        {
            ++i;
            if (message[i] == '{')
            {
                message[index] = '{';
            }
            else
            {
                message[index] = '\\';
                --i;
            }

            ++index;
        }
        else if (message[i] == '{')
        {
            ++i;
            while (message[i] != '}')
            {
                ++i;
            }
        }
        else if (index != i)
        {
            message[index] = message[i];
            ++index;
        }
    }

    message[index] = 0x00;
}

/**
 * Removes colors from the string.
 *
 * @param message   String.
 * @return          No return
 */
stock void CRemoveColors(char[] message, int maxlength)
{
    int index = 0;
    for (int i = 0; i < maxlength; ++i)
    {
        if (message[i] == 0x00)
        {
            break;
        }

        if (message[i] >= 0x1 && message[i] <= 0x10)
        {
            ++i;
        }

        message[index] = message[i];
        ++index;
    }
}

/**
 * This function should only be used right in front of
 * C_PrintToChatAll or C_PrintToChatAllEx and it tells
 * to those funcions to skip specified client when printing
 * message to all clients. After message is printed client will
 * no more be skipped.
 * 
 * @param client    Client index
 * @return          No return
 */
stock void CSkipNextClient(int client)
{
    if (client < 1 || client > MaxClients)
        ThrowError("Invalid client index %d", client);

    _CL_skip_list[client] = true;
}

/**
 * Initialises the buffer for color formatting
 *
 * @param message   String.
 * @return          First free index in the array
 */
stock int CPreFormat(char[] message)
{
    int index = 1;
    message[0] = 0x01;

    // If CS:GO set invisible precolor
    if (GetEngineVersion() == Engine_CSGO)
    {
        message[index] = ' ';
        ++index;
    }

    return index;
}

/**
 * Replaces color tags in a string with color codes
 *
 * @param message   String.
 * @param maxlength Maximum length of the string buffer.
 * @return          Client index that can be used for SayText2 author index
 * 
 * On error/Errors: If there is more then one team color is used an error will be thrown.
 */
stock void CFormat(char[] message, int maxlength, int author = NO_INDEX)
{
    int index = 0;
    char buffer[250];
    for (int i = 0; i < maxlength; ++i)
    {
        if (message[i] == 0x00)
        {
            break;
        }

        if (message[i] == '\\')
        {
            ++i;
            if (message[i] == '{')
            {
                buffer[index] = '{';
            }
            else
            {
                buffer[index] = '\\';
                --i;
            }

            ++index;
        }
        else if (message[i] == '{')
        {
            ++i;
            char color[16];
            for (int icolor = 0; icolor < sizeof(color); ++icolor)
            {
                if (message[i] == '}')
                {
                    break;
                }

                color[icolor] = message[i];
                ++i;
            }

            buffer[index] = view_as<char>(_CL_ColorMap(color));
            ++index;
        }
        else
        {
            buffer[index] = message[i];
            ++index;
        }
    }

    strcopy(message, maxlength, buffer);
}

/**
 * Checks for ProtoBuff support for CSayText2.
 *
 * @return          No return.
 */
stock bool _CL_SupportsProtoBuf()
{
    if (_CL_proto_buff_support == NotChecked)
    {
        _CL_proto_buff_support = (GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available) && (GetUserMessageType() == UM_Protobuf) ? Supports : DoesNotSupport;
    }
    return _CL_proto_buff_support == Supports;
}

/**
 * Sends a SayText2 usermessage to a client
 *
 * @param message   Client index
 * @param author    Author index
 * @param message   Message
 * @return          No return.
 */
stock void CSayText2(int client, int author, const char[] message)
{
    if (_CL_SupportsProtoBuf())
    {
        Protobuf pbMessage = view_as<Protobuf>(StartMessageOne("SayText2", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS));
        pbMessage.SetInt("ent_idx", author);
        pbMessage.SetBool("chat", true);
        pbMessage.SetString("msg_name", message);
        pbMessage.AddString("params", "");
        pbMessage.AddString("params", "");
        pbMessage.AddString("params", "");
        pbMessage.AddString("params", "");
    }
    else
    {
        Handle hMessage = StartMessageOne("SayText2", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS);
        BfWriteByte(hMessage, author);
        BfWriteByte(hMessage, true);
        BfWriteString(hMessage, message);
    }

    EndMessage();
}

/**
 * Sends a message to a client.
 *
 * @param message   Client index
 * @param author    Author index
 * @param message   Message
 * @return          No return.
 */
stock void _CL_SendChatMessage(int client, int author, char[] message)
{
    if (author)
    {
        CSayText2(client, author, message);
    }
    else
    {
        PrintToChat(client, message);
    }
}
