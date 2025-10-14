local Logger = require 'utils.logger'

local Cache = {}
local players = {}

function Cache.Add(playerData)
    if not playerData or not playerData.identifier then
        Logger.LogError('Attempted to cache player without identifier.')
        return
    end

    players[playerData.identifier] = playerData
end

function Cache.RemoveByIdentifier(identifier)
    if not identifier then
        return
    end

    players[identifier] = nil
end

function Cache.RemoveBySource(source)
    if source == nil then
        return
    end

    for identifier, data in pairs(players) do
        if data.source == source then
            players[identifier] = nil
            return
        end
    end
end

function Cache.Get(identifier)
    local data = players[identifier]
    if not data then
        return nil
    end

    return data
end

function Cache.GetBySource(source)
    if source == nil then
        return nil
    end

    for _, data in pairs(players) do
        if data.source == source then
            return data
        end
    end

    return nil
end

function Cache.GetAll()
    return players
end

return Cache
