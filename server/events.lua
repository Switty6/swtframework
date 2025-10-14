local Logger = require 'utils.logger'
local Cache = require 'server.cache'

local function getFivemIdentifier(src)
    local identifier = GetPlayerIdentifierByType(src, 'fivem')
    if type(identifier) == 'string' and identifier ~= '' then
        return identifier
    end

    local identifiers = GetPlayerIdentifiers(src)
    if not identifiers then
        return nil
    end

    for _, value in ipairs(identifiers) do
        if type(value) == 'string' and value:sub(1, 6) == 'fivem:' then
            return value
        end
    end

    return nil
end

AddEventHandler('playerConnecting', function(playerName, setKickReason, deferrals)
    local src = source
    local fivemIdentifier = getFivemIdentifier(src)

    if not fivemIdentifier then
        local message = 'SWT Framework: FiveM identifier missing. Connection refused.'
        if deferrals then
            deferrals.defer()
            Wait(0)
            deferrals.done(message)
        elseif setKickReason then
            setKickReason(message)
        end

        CancelEvent()
        Logger.LogError(('Connection refused for %s: missing FiveM identifier.'):format(playerName))
        return
    end

    if deferrals then
        deferrals.defer()
        Wait(0)
        deferrals.update('License verified. Joining server...')
        deferrals.done()
    end
end)

AddEventHandler('playerJoining', function(_)
    local src = source
    local fivemIdentifier = getFivemIdentifier(src)

    if not fivemIdentifier then
        return
    end

    local playerName = GetPlayerName(src) or 'Unknown'
    local joinTime = os.date('%Y-%m-%d %H:%M:%S')

    local playerData = {
        id = src,
        identifier = fivemIdentifier,
        name = playerName,
        source = src,
        join_time = joinTime
    }

    Cache.Add(playerData)

    Logger.LogInfo(('Player joined: %s (%s) at %s'):format(playerName, fivemIdentifier, joinTime))

    TriggerEvent('swt:playerJoined', Cache.Get(fivemIdentifier))
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    local cachedPlayer = Cache.GetBySource(src)

    if cachedPlayer then
        Cache.RemoveBySource(src)
        Logger.LogInfo(('Player disconnected: %s (%s) at %s. Reason: %s'):format(
            cachedPlayer.name or 'Unknown',
            cachedPlayer.identifier or 'Unknown',
            os.date('%Y-%m-%d %H:%M:%S'),
            reason or 'Unknown'
        ))
    end
end)
