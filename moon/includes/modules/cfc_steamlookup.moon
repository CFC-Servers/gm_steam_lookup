require "logger"

import Create, Pause, Start from timer
import format from string
import insert from table
{remove: tableRemove} = table

import JSONToTable from util
import GetBySteamID64 from player
import Run from hook
import pcall from _G

steamKey = CreateConVar "cfc_steam_api_key", "", FCVAR_PROTECTED + FCVAR_UNREGISTERED
steamKey = steamKey\GetString!

export class SteamLookup
    @steamBase: "https://api.steampowered.com"

    new: (@name, @apiRoute, @buildParams) =>
        @baseUrl = "#{@steamBase}/#{@apiRoute}/?key=#{steamKey}&format=json"

    getUrl: (steamId) =>
        params = @buildParams steamId
        params = "&#{k}=#{v}" for k, v in pairs params

        @baseUrl + params

class CheckQueueManager
    new: () =>
        @queue = {}
        @queueOrder = {}
        @attemptLimit = 2 -- Per lookup step
        @paused = false
        @Logger = Logger "CFC_SteamLookup"

        @timerName = "CFC_SteamLookup_CheckQueue"
        @timerInterval = 1.5

        @lookups = {}
        @lookupSteps = {}
        @lookupStepsCount = #@lookupSteps

        Create @timerName, @timerInterval, 0, -> pcall -> self\groom!

        @Logger\info "Loaded!"

    addLookup: (steamLookup) =>
        @Logger\info "Adding new Lookup. Name: '#{steamLookup.name}' | URL: '#{steamLookup.apiRoute}'"

        position = top and 1 or nil

        insert @lookupSteps, name, position
        @lookupStepsCount = #@lookupSteps

        @lookups[name] = steamLookup

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
            @Logger\debug body, size, headers, code
            return unless @queue[steamId]

            @queue[steamId].attempts = 0
            @queue[steamId].step += 1

            @Logger\debug body

            data = JSONToTable body

            ply = queueItem.ply
            ply[stepName] = data

            @Logger\info "Successful lookup to '#{url}'"
            Run "CFC_SteamLookup_SuccessfulPlayerData", stepName, ply, data

        onFailure = (err) ->
            return unless @queue[steamId]
            @queue[steamId].attempts += 1
            @Logger\warn "Failed request to '#{url}', failure: #{err}"

        http.Fetch url, onSuccess, onFailure

    groom: () =>
        nextSteamId = @queueOrder[1]
        steamIdInfo = @queue[nextSteamId]

        removeId = -> @remove nextSteamId, 1

        if steamIdInfo == nil
            return removeId!

        if steamIdInfo.step > @lookupStepsCount
            return removeId!

        if steamIdInfo.attempts > @attemptLimit
            return removeId!

        @lookup nextSteamId

        -- Reset the timer
        @start!

export SteamCheckQueue = CheckQueueManager!

hook.Add "PlayerAuthed", "CFC_SteamLookup_QueueLookup", (ply) ->
    pcall -> SteamCheckQueue\add ply
    return nil

do
    name = "PlayerSummary"
    route = "ISteamUser/GetPlayerSummaries/v2"
    urlParams = (steamId) -> { steamids: steamId }

    lookup = SteamLookup name, route, urlParams

    SteamCheckQueue\addLookup lookup
