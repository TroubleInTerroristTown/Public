/**
 *
 * WebFix.inc
 *
 * WebFix Include for CSGO allowing proper usage of MOTD's without caching first URL visited.
 * Fixes issue introduced in June 2017 CSGO/Steam updates.
 * 
 * Made by: Byte (https://forums.alliedmods.net/member.php?u=261613)
 * Method by: Boomix (https://forums.alliedmods.net/member.php?u=260232)
 *
 * Version: 1.00
 *
 */

#if defined _webfix_included
 #endinput
#endif
#define _webfix_included

#define WEBFIX_TITLE_LENGTH 512
#define WEBFIX_URL_LENGTH 2000

//Global statics
static char s_WebFix_RedirectUrl[WEBFIX_URL_LENGTH];
static bool s_WebFix_IsRedirectUrlSet = false;

/**
 * Sets the WebFix Redirect URL
 * Call this before calling WebFix_OpenUrl if 'webfix_redirecturl.txt' is not used.
 *
 * @param url			URL to WebFix Redirection Script
 */
stock void WebFix_SetRedirectUrl(char[] url)
{
  Format(s_WebFix_RedirectUrl, sizeof(s_WebFix_RedirectUrl), url);
  s_WebFix_IsRedirectUrlSet = true;
}

/**
 * Open a URL on a client using WebFix
 *
 * @param client			Client which MOTD window will be opened on.
 * @param title			Window title.
 * @param url			URL to open. Must be prefixed with http:// or https:// protocols.
 * @param hidden			Override type (specific command or group).
 * @param width			Optional pointer to store allow/deny setting. 0 (default) uses clients full screen width.
 * @param height			Optional pointer to store allow/deny setting. 0 (default) uses clients full screen height.
 * @return				true if successful, false if error encountered.
 */
stock bool WebFix_OpenUrl(int client, const char[] title, const char[] url, bool hidden = false, int width = 0, int height = 0)
{
  //Attempt to read redirect url from config file
  if (!s_WebFix_IsRedirectUrlSet) {
    WebFix_ReadRedirectUrlFromConfig();
  }

  //If url is still not set and we're using non-hidden mode, fail 
  if (!s_WebFix_IsRedirectUrlSet && !hidden) {
    LogError("Attempting to use WebFix_OpenUrl in non-hidden mode without a redirect URL being set.");
    return false;
  }
  
  //Confirm URL is valid
  if (StrContains(url, "http://", false) != 0 && StrContains(url, "https://", false) != 0 && !StrEqual(url, "about:blank")) {
    LogError("Invalid protocol provided. Only 'http://', 'https://' and 'about:blank' are supported.");
    return false;
  }
  
  if (!IsClientInGame(client) || IsFakeClient(client))
    return false;
  
  //Load invalid (non-existing) URL
  ShowMOTDPanel(client, "WebFix", "http://invaliddomain.invalidtld", MOTDPANEL_TYPE_URL);
  
  DataPack pack;
  CreateDataTimer(1.0, WebFix_OpenUrl_OpenTarget, pack);
  pack.WriteCell(EntIndexToEntRef(client));
  pack.WriteString(title);
  pack.WriteString(url);
  pack.WriteCell(hidden);
  pack.WriteCell(width);
  pack.WriteCell(height);
  
  return true;
}

/**
 * Open a URL on all clients using WebFix
 *
 * @param title			Window title.
 * @param url			URL to open. Must be prefixed with http:// or https:// protocols.
 * @param hidden			Override type (specific command or group).
 * @param width			Optional pointer to store allow/deny setting. 0 (default) uses clients full screen width.
 * @param height			Optional pointer to store allow/deny setting. 0 (default) uses clients full screen height.
 * @return				true if all successful, false if any errors encountered.
 */
stock bool WebFix_OpenUrlAll(const char[] title, const char[] url, bool hidden = false, int width = 0, int height = 0)
{
  bool returnValue = true;
	for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && !IsFakeClient(i)){
      bool success = WebFix_OpenUrl(i, title, url, hidden, width, height);
      if (!success)
        returnValue = false;
    }
  }
  
  return returnValue;
}

//Internal Command! Do not call.
public Action WebFix_OpenUrl_OpenTarget(Handle timer, DataPack pack)
{
  pack.Reset();
  
  int client = EntRefToEntIndex(pack.ReadCell());
  
  if (!IsClientInGame(client))
    return Plugin_Handled;
  
  char title[WEBFIX_TITLE_LENGTH];
  pack.ReadString(title, sizeof(title));
  char url[WEBFIX_URL_LENGTH];
  pack.ReadString(url, sizeof(url));
  bool hidden = view_as<bool>(pack.ReadCell());
  int width = pack.ReadCell();
  int height = pack.ReadCell();
  
  //Use redirect url for non-hidden windows
  if (!hidden)
    Format(url, sizeof(url), "%s?url=%s&width=%d&height=%d", s_WebFix_RedirectUrl, url, width, height);
  
  //Show VGUI Panel
  Handle panel = CreateKeyValues("data");

  KvSetString(panel, "title", title);
  KvSetNum(panel, "type", MOTDPANEL_TYPE_URL);
  KvSetString(panel, "msg", url);
  ShowVGUIPanel(client, "info", panel, hidden);
  delete panel;
  
  return Plugin_Handled;
}

//Internal Command
static void WebFix_ReadRedirectUrlFromConfig()
{
  char configFilePath[PLATFORM_MAX_PATH];
  Format(configFilePath, sizeof(configFilePath), "configs/webfix_redirecturl.txt");
  BuildPath(Path_SM, configFilePath, PLATFORM_MAX_PATH, configFilePath);
  
  if (FileExists(configFilePath)) {
    //Open config file
    File file = OpenFile(configFilePath, "r");
    
    if (file != null) {
      char buffer[PLATFORM_MAX_PATH];
      if (file.ReadLine(buffer, sizeof(buffer))) { //Read a single line
        
        //Remove final new line
        //buffer length > 0 check needed in case file is completely empty and there is no new line '\n' char after empty string ""
        if (strlen(buffer) > 0 && buffer[strlen(buffer) - 1] == '\n')
          buffer[strlen(buffer) - 1] = '\0';
        
        //Remove any whitespace at either end
        TrimString(buffer);
        
        if (StrContains(buffer, "http://", false) != 0 && StrContains(buffer, "https://", false) != 0)
          LogError("Invalid redirect URL read from config file. Only 'http://' and 'https://' are supported.");
        else
          WebFix_SetRedirectUrl(buffer);
      }
    }
    
    file.Close();
  }
}