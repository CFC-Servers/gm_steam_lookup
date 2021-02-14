import Create, Pause, Start from timer
import insert, remove from table
import format from string

import JSONToTable from util
import GetBySteamID64 from player
import Run from hook

pcall = pcall

class CheckQueue
    new: () =>
        @queue = {}
        @queueOrder = {}
        @attemptLimit = 2 -- Per lookup step
        @paused = false

        @timerName = "Gm_SteamLookup_CheckQueue"
        @timerInterval = 1.5

        @steamBase = "https://api.steampowered.com"

        @lookups =
            SharedGame:
                baseUrl: "#{@steamBase}/IPlayerService/IsPlayingSharedGame/v1/"

            PlayerSummary:
                baseUrl: "#{@steamBase}/ISteamUser/GetPlayerSummaries/v2/"

        @lookupSteps = { "SharedGame", "PlayerSummary" }

        @lookupStepsCount = #@lookupSteps

        Create @timerName, @timerInterval, 0, self\groom

    _addQueryParams: (url, steamId, extraParams={}) =>
        extraParamsStr = ""

        for key, value in pairs(extraParams)
            extraParamsStr ..= "&#{key}=#{value}"

        "#{url}?key=#{@steamKey}&steamids=#{steamId}&format=json#{extraParamsStr}"

    addLookup: (name, urlSuffix, extraParams, top=false) =>
        position = top and 1 or nil

        insert @lookupSteps, name, position
        @lookupStepsCount = #@lookupSteps

        baseUrl = "#{@steamBase}/#{urlSuffix}"
        @lookups[name] = :baseUrl, :extraParams

    add: (steamId) =>
        @queue[steamId] =
            attempts: 0
            step: 1

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
            ply = GetBySteamID64 steamId
            return unless ply

            ply[stepName] = data
            Run @successName, stepName, ply, data

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

        success, err = pcall -> lookup(nextSteamId, steamIdInfo)

        -- Reset the timer
        @start!

        return unless success

        @Logger\error err
