require("logger")
if SteamCheckQueue then
  return 
end
local insert, tableRemove
do
  local _obj_0 = table
  insert, tableRemove = _obj_0.insert, _obj_0.remove
end
local Pause, Start, timerCreate
do
  local _obj_0 = timer
  Pause, Start, timerCreate = _obj_0.Pause, _obj_0.Start, _obj_0.Create
end
local format
format = string.format
local JSONToTable
JSONToTable = util.JSONToTable
local GetBySteamID64
GetBySteamID64 = player.GetBySteamID64
local pcall
pcall = _G.pcall
local steamKey = CreateConVar("gm_steamlookup_api_key", "", FCVAR_PROTECTED + FCVAR_ARCHIVE + FCVAR_UNREGISTERED)
do
  local _class_0
  local _base_0 = {
    getUrl = function(self, steamId)
      local params = ""
      for k, v in pairs(self.buildParams(steamId)) do
        params = params .. "&" .. tostring(k) .. "=" .. tostring(v)
      end
      return self.baseUrl .. params
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, name, apiRoute, buildParams)
      self.name, self.apiRoute, self.buildParams = name, apiRoute, buildParams
      self.baseUrl = tostring(self.__class.steamBase) .. "/" .. tostring(self.apiRoute) .. "/?key=" .. tostring(steamKey:GetString()) .. "&format=json"
    end,
    __base = _base_0,
    __name = "SteamLookup"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  local self = _class_0
  self.steamBase = "https://api.steampowered.com"
  SteamLookup = _class_0
end
local CheckQueueManager
do
  local _class_0
  local _base_0 = {
    addLookup = function(self, steamLookup)
      local name = steamLookup.name
      if self.lookups[name] then
        return 
      end
      self.Logger:debug("Adding new Lookup. Name: '" .. tostring(name) .. "' | URL: '" .. tostring(steamLookup.apiRoute) .. "'")
      insert(self.lookupSteps, name)
      self.lookupStepsCount = #self.lookupSteps
      self.lookups[name] = steamLookup
    end,
    add = function(self, ply)
      local steamId = ply:SteamID64()
      self.Logger:debug("Adding new player to queue, '" .. tostring(steamId) .. "'")
      self.queue[steamId] = {
        step = 1,
        attempts = 0,
        steamId = steamId,
        ply = ply
      }
      insert(self.queueOrder, steamId)
      if self.paused then
        return self:start()
      end
    end,
    remove = function(self, steamId, queueIndex)
      self.queue[steamId] = nil
      tableRemove(self.queueOrder, queueIndex)
      if #self.queueOrder == 0 then
        return self:pause()
      end
    end,
    pause = function(self)
      Pause(self.timerName)
      self.paused = true
      self.queue = { }
    end,
    start = function(self)
      Start(self.timerName)
      self.paused = false
    end,
    lookup = function(self, steamId)
      local queueItem = self.queue[steamId]
      local stepName = self.lookupSteps[queueItem.step]
      local lookup = self.lookups[stepName]
      local url = lookup:getUrl(steamId)
      self.Logger:debug("Attempting lookup to '" .. tostring(url) .. "'")
      local onSuccess
      onSuccess = function(body, size, headers, code)
        if not (self.queue[steamId]) then
          return 
        end
        self.queue[steamId].attempts = 0
        self.queue[steamId].step = self.queue[steamId].step + 1
        self.Logger:debug("Response info:", size, code)
        self.Logger:debug("Response body:", body)
        local data = JSONToTable(body)
        local ply = queueItem.ply
        if not (IsValid(ply)) then
          return 
        end
        ply.SteamLookup = ply.SteamLookup or { }
        ply.SteamLookup[stepName] = data
        self.Logger:debug("Successful lookup to '" .. tostring(url) .. "' for: ", ply)
        return hook.Run("CFC_SteamLookup_SuccessfulPlayerData", stepName, ply, data)
      end
      local onFailure
      onFailure = function(err)
        if not (self.queue[steamId]) then
          return 
        end
        self.queue[steamId].attempts = self.queue[steamId].attempts + 1
        return self.Logger:warn("Failed request to '" .. tostring(url) .. "', failure: " .. tostring(err))
      end
      return http.Fetch(url, onSuccess, onFailure)
    end,
    groom = function(self)
      local nextSteamId = self.queueOrder[1]
      local steamIdInfo = self.queue[nextSteamId]
      local removeId
      removeId = function()
        return self:remove(nextSteamId, 1)
      end
      if steamIdInfo == nil then
        return removeId()
      end
      if steamIdInfo.step > self.lookupStepsCount then
        return removeId()
      end
      if steamIdInfo.attempts > self.attemptLimit then
        return removeId()
      end
      self:lookup(nextSteamId)
      return self:start()
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self)
      self.queue = { }
      self.queueOrder = { }
      self.attemptLimit = 2
      self.paused = true
      self.Logger = Logger("SteamLookup")
      self.timerName = "CFC_SteamLookup_CheckQueue"
      self.timerInterval = 1.5
      self.lookups = { }
      self.lookupSteps = { }
      self.lookupStepsCount = #self.lookupSteps
      timerCreate(self.timerName, self.timerInterval, 0, function()
        local success, err = pcall((function()
          local _base_1 = self
          local _fn_0 = _base_1.groom
          return function(...)
            return _fn_0(_base_1, ...)
          end
        end)())
        if not (success) then
          return ErrorNoHalt(err)
        end
      end)
      self:pause()
      return self.Logger:info("Loaded!")
    end,
    __base = _base_0,
    __name = "CheckQueueManager"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  CheckQueueManager = _class_0
end
SteamCheckQueue = CheckQueueManager()
hook.Add("PlayerAuthed", "CFC_SteamLookup_QueueLookup", function(ply)
  local success, err = pcall(function()
    return SteamCheckQueue:add(ply)
  end)
  if not (success) then
    ErrorNoHalt(err)
  end
  return nil
end)
return hook.Add("Think", "SteamLookup_Setup", function()
  hook.Remove("Think", "SteamLookup_Setup")
  local name = "PlayerSummary"
  local route = "ISteamUser/GetPlayerSummaries/v2"
  local urlParams
  urlParams = function(steamId)
    return {
      steamids = steamId
    }
  end
  local lookup = SteamLookup(name, route, urlParams)
  return SteamCheckQueue:addLookup(lookup)
end)
