# GM Steam Lookup
Automatically looks up players on the Steamworks API when a player joins the server and caches the response.

## Installation
First, you'll need to set the following convar with your [Steam API Key](https://steamcommunity.com/dev/apikey):
```
gm_steamlookup_api_key "<api key>"
```

**Simple**
 - You can download the latest release .zip from the [Releases]() tab. Extract that and place it in your `addons` directory.

**Source Controlled**
 - You can clone this repository directly into your `addons` directory, but be sure to check out the `lua` branch which contains the compiled Lua from the latest release.

## Requirements
 - [Logger](https://github.com/CFC-Servers/gm_logger)

## Usage
This library provides two interactions.

### Listening for lookups
SteamLookups runs a hook on every successful lookup.
 - The `CFC_SteamLookup_SuccessfulPlayerData` hook will be called with `stepName`, `ply`, and `data`.
 - `stepName` is the nice-name of the event (by default, `PlayerSummary` is the only event)
 - `ply` is the player the lookup was done for
 - `data` is the raw response from the Steam API

### Registering new lookups

If you want SteamLookups to perform another lookup on each player that joins, you may use the `addLookup` method.

**`SteamCheckQueue:addLookup`**
```lua
require "steamlookup"

-- This is the stepName you'll be listening for in the previous section
-- Can be any string
local stepName = "PlayerSummary"

-- This is the route portion of the Steam API URL
-- i.e. from: https://api.steampowered.com/[ISteamUser/GetPlayerSummaries/v2]/
-- Take everything between the square brackets
-- (Leave off the leading+trailing slashes)
local route = "ISteamUser/GetPlayerSummaries/v2"

-- This function is called when creating the URL
-- It will convert any table returned here into a set of URL params
-- i.e: "{ steamid: 'test' }" would turn into "&steamid=test"
local urlParams = function( steamID ) return { steamids = steamID } end

-- Create the SteamLookup object
local lookup = SteamLookup( name, route, urlParams )

-- Add it to the SteamCheckQueue
SteamCheckQueue:addLookup( lookup )
```
