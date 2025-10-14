local Logger = require 'utils.logger'
local Economy = require 'server.economy'
local Permissions = require 'server.permissions'

local Cache = {}
local players = {}
local playerCurrencies = {}
local playerRoles = {}
local playerPermissions = {}

-- Player cache functions (existing)
function Cache.Add(playerData)
    if not playerData or not playerData.identifier then
        Logger.LogError('Attempted to cache player without identifier.')
        return
    end

    players[playerData.identifier] = playerData
    
    -- Initialize currency and permission caches for this player
    Cache.RefreshPlayerData(playerData.identifier)
end

function Cache.RemoveByIdentifier(identifier)
    if not identifier then
        return
    end

    players[identifier] = nil
    playerCurrencies[identifier] = nil
    playerRoles[identifier] = nil
    playerPermissions[identifier] = nil
end

function Cache.RemoveBySource(source)
    if source == nil then
        return
    end

    for identifier, data in pairs(players) do
        if data.source == source then
            Cache.RemoveByIdentifier(identifier)
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

-- Enhanced cache functions for currencies, roles, and permissions
function Cache.RefreshPlayerData(identifier)
    if not identifier then
        return
    end

    -- Refresh currency cache
    Cache.RefreshPlayerCurrencies(identifier)
    
    -- Refresh role and permission cache
    Cache.RefreshPlayerRoles(identifier)
    Cache.RefreshPlayerPermissions(identifier)
end

function Cache.RefreshPlayerCurrencies(identifier)
    if not identifier then
        return
    end

    -- Get all currencies and their balances for this player
    local currencies = Economy.GetAllCurrencies()
    playerCurrencies[identifier] = {}

    for slug, currency in pairs(currencies) do
        playerCurrencies[identifier][slug] = Economy.GetBalance(identifier, slug)
    end
end

function Cache.RefreshPlayerRoles(identifier)
    if not identifier then
        return
    end

    playerRoles[identifier] = Permissions.GetUserRoles(identifier)
end

function Cache.RefreshPlayerPermissions(identifier)
    if not identifier then
        return
    end

    playerPermissions[identifier] = Permissions.GetUserPermissions(identifier)
end

-- Currency cache functions
function Cache.GetPlayerCurrency(identifier, currencySlug)
    if not identifier or not currencySlug then
        return 0.00
    end

    if not playerCurrencies[identifier] then
        Cache.RefreshPlayerCurrencies(identifier)
    end

    return playerCurrencies[identifier] and playerCurrencies[identifier][currencySlug] or 0.00
end

function Cache.GetPlayerCurrencies(identifier)
    if not identifier then
        return {}
    end

    if not playerCurrencies[identifier] then
        Cache.RefreshPlayerCurrencies(identifier)
    end

    return playerCurrencies[identifier] or {}
end

function Cache.UpdatePlayerCurrency(identifier, currencySlug, amount)
    if not identifier or not currencySlug then
        return
    end

    if not playerCurrencies[identifier] then
        playerCurrencies[identifier] = {}
    end

    playerCurrencies[identifier][currencySlug] = amount
end

-- Role cache functions
function Cache.GetPlayerRoles(identifier)
    if not identifier then
        return {}
    end

    if not playerRoles[identifier] then
        Cache.RefreshPlayerRoles(identifier)
    end

    return playerRoles[identifier] or {}
end

function Cache.PlayerHasRole(identifier, roleName)
    if not identifier or not roleName then
        return false
    end

    local roles = Cache.GetPlayerRoles(identifier)
    return roles[roleName] ~= nil
end

-- Permission cache functions
function Cache.GetPlayerPermissions(identifier)
    if not identifier then
        return {}
    end

    if not playerPermissions[identifier] then
        Cache.RefreshPlayerPermissions(identifier)
    end

    return playerPermissions[identifier] or {}
end

function Cache.PlayerHasPermission(identifier, permissionSlug)
    if not identifier or not permissionSlug then
        return false
    end

    local permissions = Cache.GetPlayerPermissions(identifier)
    return permissions[permissionSlug] == true
end

-- Cache invalidation functions
function Cache.InvalidatePlayerCurrency(identifier, currencySlug)
    if not identifier then
        return
    end

    if currencySlug then
        -- Invalidate specific currency
        if playerCurrencies[identifier] then
            playerCurrencies[identifier][currencySlug] = nil
        end
    else
        -- Invalidate all currencies for this player
        playerCurrencies[identifier] = nil
    end
end

function Cache.InvalidatePlayerRoles(identifier)
    if not identifier then
        return
    end

    playerRoles[identifier] = nil
    playerPermissions[identifier] = nil -- Permissions depend on roles
end

function Cache.InvalidatePlayerPermissions(identifier)
    if not identifier then
        return
    end

    playerPermissions[identifier] = nil
end

-- Global cache refresh functions
function Cache.RefreshAllCurrencies()
    for identifier, _ in pairs(players) do
        Cache.RefreshPlayerCurrencies(identifier)
    end
end

function Cache.RefreshAllRoles()
    for identifier, _ in pairs(players) do
        Cache.RefreshPlayerRoles(identifier)
    end
end

function Cache.RefreshAllPermissions()
    for identifier, _ in pairs(players) do
        Cache.RefreshPlayerPermissions(identifier)
    end
end

-- Cache statistics
function Cache.GetStats()
    local stats = {
        players = 0,
        currencies = 0,
        roles = 0,
        permissions = 0
    }

    for _ in pairs(players) do
        stats.players = stats.players + 1
    end

    for identifier, currencies in pairs(playerCurrencies) do
        for _ in pairs(currencies) do
            stats.currencies = stats.currencies + 1
        end
    end

    for identifier, roles in pairs(playerRoles) do
        for _ in pairs(roles) do
            stats.roles = stats.roles + 1
        end
    end

    for identifier, permissions in pairs(playerPermissions) do
        for _ in pairs(permissions) do
            stats.permissions = stats.permissions + 1
        end
    end

    return stats
end

return Cache
