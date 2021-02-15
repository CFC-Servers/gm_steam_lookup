require "cfclogger"

import Create, Pause, Start from timer
import insert from table
import Replace, format from string

import JSONToTable from util
import GetBySteamID64 from player
import Run from hook
import Read from file

pcall = pcall
tableRemove = table.remove

steamKey = Read "steam_api_key.txt", "DATA"
steamKey = Replace steamKey, "\r", ""
steamKey = Replace steamKey, "\n", ""

class CheckQueueManager
    new: () =>
        @queue = {}
        @queueOrder = {}
        @attemptLimit = 2 -- Per lookup step
        @paused = false
        @Logger = CFCLogger "CFC_SteamLookup"

        @timerName = "CFC_SteamLookup_CheckQueue"
        @timerInterval = 1.5

        @steamBase = "https://api.steampowered.com"
        @lookups =
            PlayerSummary:
                baseUrl: "#{@steamBase}/ISteamUser/GetPlayerSummaries/v2/"

        @lookupSteps = { "PlayerSummary" }
        @lookupStepsCount = #@lookupSteps

        Create @timerName, @timerInterval, 0, -> pcall -> self\groom!

        @Logger\info "Loaded!"

    _generateParamString: (extraParams) =>
        extraParamsStr = ""

        for key, value in pairs extraParams
            extraParamsStr ..= "&#{key}=#{value}"

        extraParamsStr

    _addQueryParams: (url, steamId, extraParams={}) =>
        extraParams = @_generateParamString extraParams
        "#{url}?key=#{steamKey}&steamids=#{steamId}&format=json#{extraParams}"

    addLookup: (name, urlSuffix, extraParams, top=false) =>
        @Logger\info "Adding new Lookup. Name: '#{name}' | URL: '#{urlSuffix}'"

        position = top and 1 or nil

        insert @lookupSteps, name, position
        @lookupStepsCount = #@lookupSteps

        baseUrl = "#{@steamBase}/#{urlSuffix}"
        @lookups[name] = :baseUrl, :extraParams

    add: (ply) =>
        steamId = ply\SteamID64!

        @Logger\debug "Adding new player to queue, '#{steamId}'"

        @queue[steamId] =
            step: 1
            attempts: 0
            steamId: steamId
            ply: ply

        insert @queueOrder, steamId
        @start! if @paused

    remove: (steamId, queueIndex) =>
        @queue[steamId] = nil
        tableRemove queueOrder, queueIndex
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

        url = @_addQueryParams lookup.baseUrl, steamId, lookup.extraParams
        @Logger\info "Attempting lookup to '#{url}'"

        onSuccess = (body) ->
            @queue[steamId].attempts = 0
            @queue[steamId].step += 1

            data = JSONToTable body

            queueItem.ply[stepName] = data
            @Logger\info "Successful lookup to '#{url}'"
            Run "CFC_SteamLookup_SuccessfulPlayerData", stepName, ply, data

        onFailure = (err) ->
            @queue[steamId].attempts += 1
            @Logger\warn "Failed request to '#{url}', failure: #{err}"

        http.Fetch url, onSuccess, onFailure

    groom: () =>
        @Logger\trace "Grooming queue"

        nextSteamId = @queueOrder[1]
        steamIdInfo = @queue[nextSteamId]

        removeId = -> @remove nextSteamId, 1

        if steamIdInfo == nil
            return

        if steamIdInfo.step > @lookupStepsCount
            return removeId!

        if steamIdInfo.attempts > @attemptLimit
            return removeId!

        success, err = @lookup nextSteamId

        -- Reset the timer
        @start!

        return unless success

        @Logger\error err

export SteamCheckQueue = CheckQueueManager!

hook.Add "PlayerAuthed", "CFC_SteamLookup_QueueLookup", (ply) ->
    pcall -> SteamCheckQueue\add ply
