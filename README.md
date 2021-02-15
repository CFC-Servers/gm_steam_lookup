# cfc_steam_lookup
Automatically looks up players on the Steamworks API when a player joins the server and caches the response.

## Installation
First, you'll need to add your Steam API Key to a new file in your `data` directory, `data/steam_api_key.txt`

**Simple**
 - You can download the latest release .zip from the [Releases]() tab. Extract that and place it in your `addons` directory.

**Source Controlled**
 - You can clone this repository directly into your `addons` directory, but be sure to check out the `lua` branch which contains the compiled Lua from the latest release.

## Usage
This library provides two interactions.

**Listening for lookups**
SteamLookups runs a hook on every successful lookup.
 - `CFC_SteamLookup_SuccessfulPlayerData` will give you `stepName`, `ply`, and `data`.
 - `stepName` is the nice-name of the event (by default, `PlayerSummary` is the only event )
 - `ply` is the player the lookup was done for
 - `data` is the raw response from the Steam API

**Registering new lookups**
If you want SteamLookups to perform another lookup on each player that joins, you may use the `addLookup` method.

`SteamCheckQueue:addLookup` takes four parameters:
 - `name`: The nice-name of the event
 - `urlSuffix`: The Steam API endpoint, everythign that comes after `api.steampowered.com` (without a leading slash)
 - `extraParams`: A table of extra, static parameters that should be added to the API call 
 - `top`: A boolean indicating whether or not this check should be inserted at the top of the step order
