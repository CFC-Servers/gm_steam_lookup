require "cfclogger"

import Create, Pause, Start from timer
import insert, remove from table
import Replace, format from string

import JSONToTable from util
import GetBySteamID64 from player
import Run from hook
import Read from file

pcall = pcall

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

        Create @timerName, @timerInterval, 0, self\groom

    _addQueryParams: (url, steamId, extraParams={}) =>
        extraParamsStr = ""

        for key, value in pairs extraParams
            extraParamsStr ..= "&#{key}=#{value}"

        "#{url}?key=#{steamKey}&steamids=#{steamId}&format=json#{extraParamsStr}"

    addLookup: (name, urlSuffix, extraParams, top=false) =>
        position = top and 1 or nil

        insert @lookupSteps, name, position
        @lookupStepsCount = #@lookupSteps

        baseUrl = "#{@steamBase}/#{urlSuffix}"
        @lookups[name] = :baseUrl, :extraParams

    add: (ply) =>
        step = 1
        attempts = 0
        steamId = ply\SteamID64!
        @queue[steamId] = :ply, :steamId, :attempts, :step

        insert @queueOrder, steamId
        @start! if @paused

    remove: (steamId) =>
        @queue[steamId] = nil

    pause: () =>
        Pause @timerName
        @paused = true

    start: () =>
        Start @timerName
        @paused = false

    lookup: (steamId, queueItem) =>
        stepName = @lookupSteps[queueItem.step]
        lookup = @lookups[stepName]
        url = @_addQueryParams lookup.baseUrl, steamId, lookup.extraParams

        onSuccess = (body) ->
            @queue[steamId].attempts = 0
            @queue[steamId].step += 1

            data = JSONToTable body

            queueItem.ply[stepName] = data
            Run "CFC_SteamLookup_SuccessfulPlayerData", stepName, ply, data

        onFailure = (err) ->
            @Logger\warn "Failed request to '#{url}', failure: #{err}"

        http.Fetch url, onSuccess, onFailure

    groom: () =>
        queueOrderCount = #@queueOrder

        if queueOrderCount == 0
            @pause!
            @queue = {}
            return

        nextSteamId = @queueOrder[1]
        steamIdInfo = @queue[nextSteamId]

        if steamIdInfo == nil
            @queue[nextSteamId] = nil
            remove @queueOrder, 1
            return

        if steamIdInfo.step > @lookupStepsCount
            @queue[nextSteamId] = nil
            remove @queueOrder, 1
            return

        success, err = @lookup(nextSteamId, steamIdInfo)

        -- Reset the timer
        @start!

        return unless success

        @Logger\error err

export SteamCheckQueue = CheckQueueManager!

hook.Add "PlayerAuthed", "CFC_SteamLookup_QueueLookup", (ply) ->
    pcall -> SteamCheckQueue\add ply
