require "logger"

return if SteamCheckQueue

{:insert, remove: tableRemove} = table
{:Pause, :Start, Create: timerCreate} = timer

import format from string
import JSONToTable from util
import GetBySteamID64 from player
import pcall from _G

steamKey = CreateConVar "gm_steamlookup_api_key", "", FCVAR_PROTECTED + FCVAR_ARCHIVE + FCVAR_UNREGISTERED

export class SteamLookup
    @steamBase: "https://api.steampowered.com"

    new: (@name, @apiRoute, @buildParams) =>
        @baseUrl = "#{@@steamBase}/#{@apiRoute}/?key=#{steamKey\GetString!}&format=json"

    getUrl: (steamId) =>
        params = ""

        for k, v in pairs self.buildParams steamId
            params ..= "&#{k}=#{v}"

        @baseUrl .. params

class CheckQueueManager
    new: () =>
        @queue = {}
        @queueOrder = {}
        @attemptLimit = 2 -- Per lookup step
        @paused = true
        @Logger = Logger "SteamLookup"

        @timerName = "CFC_SteamLookup_CheckQueue"
        @timerInterval = 1.5

        @lookups = {}
        @lookupSteps = {}
        @lookupStepsCount = #@lookupSteps

        timerCreate @timerName, @timerInterval, 0, ->
            success, err = pcall self\groom
            ErrorNoHalt err unless success

        @pause!

        @Logger\info "Loaded!"

    addLookup: (steamLookup) =>
        name = steamLookup.name
        return if @lookups[name]

        @Logger\info "Adding new Lookup. Name: '#{name}' | URL: '#{steamLookup.apiRoute}'"

        insert @lookupSteps, name
        @lookupStepsCount = #@lookupSteps

        @lookups[name] = steamLookup

    add: (ply) =>
        steamId = ply\SteamID64!

        @Logger\info "Adding new player to queue, '#{steamId}'"

        @queue[steamId] =
            step: 1
            attempts: 0
            steamId: steamId
            ply: ply

        insert @queueOrder, steamId
        @start! if @paused

    remove: (steamId, queueIndex) =>
        @queue[steamId] = nil
        tableRemove @queueOrder, queueIndex
        @pause! if #@queueOrder == 0

    pause: () =>
        Pause @timerName
        @paused = true
        @queue = {}

    start: () =>
        Start @timerName
        @paused = false

    lookup: (steamId) =>
        queueItem = @queue[steamId]
        stepName = @lookupSteps[queueItem.step]
        lookup = @lookups[stepName]

        url = lookup\getUrl steamId
        @Logger\info "Attempting lookup to '#{url}'"

        onSuccess = (body, size, headers, code) ->
            return unless @queue[steamId]

            @queue[steamId].attempts = 0
            @queue[steamId].step += 1

            @Logger\debug "Response info:", size, code
            @Logger\debug "Response body:", body

            data = JSONToTable body

            ply = queueItem.ply
            ply.SteamLookup or= {}
            ply.SteamLookup[stepName] = data

            @Logger\info "Successful lookup to '#{url}' for: ", ply
            hook.Run "CFC_SteamLookup_SuccessfulPlayerData", stepName, ply, data

        onFailure = (err) ->
            return unless @queue[steamId]
            @queue[steamId].attempts += 1
            @Logger\warn "Failed request to '#{url}', failure: #{err}"

        http.Fetch url, onSuccess, onFailure

    groom: () =>
        nextSteamId = @queueOrder[1]
        steamIdInfo = @queue[nextSteamId]

        removeId = -> @remove nextSteamId, 1

        return removeId! if steamIdInfo == nil
        return removeId! if steamIdInfo.step > @lookupStepsCount
        return removeId! if steamIdInfo.attempts > @attemptLimit

        @lookup nextSteamId

        -- Reset the timer
        @start!

export SteamCheckQueue = CheckQueueManager!

hook.Add "PlayerAuthed", "CFC_SteamLookup_QueueLookup", (ply) ->
    success, err = pcall -> SteamCheckQueue\add ply
    ErrorNoHalt err unless success
    return nil

hook.Add "Think", "SteamLookup_Setup", ->
    hook.Remove "Think", "SteamLookup_Setup"

    name = "PlayerSummary"
    route = "ISteamUser/GetPlayerSummaries/v2"
    urlParams = (steamId) -> { steamids: steamId }

    lookup = SteamLookup name, route, urlParams
    SteamCheckQueue\addLookup lookup
