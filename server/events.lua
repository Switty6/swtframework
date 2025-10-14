local Logger = require 'utils.logger'
local Cache = require 'server.cache'
local Database = require 'server.database'
local Economy = require 'server.economy'
local Permissions = require 'server.permissions'
local Log = require 'server.logging'

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

local function initializePlayerData(identifier, playerName)
    -- Create or update user in database
    local query = [[
        INSERT INTO users (identifier, name, metadata)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE
        name = VALUES(name),
        updated_at = NOW()
    ]]

    local metadata = json.encode({
        first_join = os.date('%Y-%m-%d %H:%M:%S'),
        last_seen = os.date('%Y-%m-%d %H:%M:%S')
    })

    Database.Insert(query, {identifier, playerName, metadata}, function(success, insertId)
        if success then
            Log.Player(identifier, 'USER_CREATED_OR_UPDATED', {name = playerName})
            
            -- Initialize default currencies for new players
            local currencies = Economy.GetAllCurrencies()
            for slug, currency in pairs(currencies) do
                local currentBalance = Economy.GetBalance(identifier, slug)
                if currentBalance == 0.00 and currency.default_amount > 0 then
                    Economy.SetBalance(identifier, slug, currency.default_amount, 'Initial balance')
                end
            end

            -- Assign default role if player has no roles
            local userRoles = Permissions.GetUserRoles(identifier)
            if not userRoles or next(userRoles) == nil then
                Permissions.AssignRoleToUser(identifier, 'user')
                Log.Player(identifier, 'DEFAULT_ROLE_ASSIGNED', {role = 'user'})
            end
        else
            Log.Error(string.format('Failed to initialize player data for %s', identifier))
        end
    end)
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
        Log.Error('Connection refused: missing FiveM identifier', {player_name = playerName, source = src})
        return
    end

    if deferrals then
        deferrals.defer()
        Wait(0)
        deferrals.update('License verified. Initializing player data...')
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

    -- Initialize player data in database
    initializePlayerData(fivemIdentifier, playerName)

    local playerData = {
        id = src,
        identifier = fivemIdentifier,
        name = playerName,
        source = src,
        join_time = joinTime
    }

    Cache.Add(playerData)

    Log.Player(fivemIdentifier, 'PLAYER_JOINED', {
        name = playerName,
        source = src,
        join_time = joinTime
    })

    -- Trigger custom event for other resources
    TriggerEvent('swt:playerJoined', Cache.Get(fivemIdentifier))
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    local cachedPlayer = Cache.GetBySource(src)

    if cachedPlayer then
        local identifier = cachedPlayer.identifier
        local playerName = cachedPlayer.name or 'Unknown'
        local disconnectTime = os.date('%Y-%m-%d %H:%M:%S')

        -- Log player disconnect
        Log.Player(identifier, 'PLAYER_DISCONNECTED', {
            name = playerName,
            source = src,
            reason = reason or 'Unknown',
            disconnect_time = disconnectTime
        })

        -- Update last seen in database
        local query = [[
            UPDATE users 
            SET metadata = JSON_SET(COALESCE(metadata, '{}'), '$.last_seen', ?)
            WHERE identifier = ?
        ]]

        Database.Update(query, {disconnectTime, identifier}, function(success)
            if not success then
                Log.Error(string.format('Failed to update last_seen for player %s', identifier))
            end
        end)

        -- Clear cache
        Cache.RemoveBySource(src)

        -- Trigger custom event for other resources
        TriggerEvent('swt:playerDropped', identifier, reason)
    end
end)

-- Custom events for economy operations
RegisterNetEvent('swt:getBalance', function(currencySlug)
    local src = source
    local player = Cache.GetBySource(src)
    
    if not player then
        return
    end

    local balance = Economy.GetBalance(player.identifier, currencySlug)
    TriggerClientEvent('swt:balanceResult', src, currencySlug, balance)
end)

RegisterNetEvent('swt:transferMoney', function(targetIdentifier, currencySlug, amount, reason)
    local src = source
    local player = Cache.GetBySource(src)
    
    if not player then
        return
    end

    -- Check permission
    if not Permissions.HasPermission(player.identifier, 'economy.transfer_money') then
        Log.Player(player.identifier, 'PERMISSION_DENIED', {
            permission = 'economy.transfer_money',
            action = 'transfer_money'
        })
        return
    end

    local success = Economy.TransferMoney(player.identifier, targetIdentifier, currencySlug, amount, reason)
    
    if success then
        TriggerClientEvent('swt:transferResult', src, true, 'Transfer successful')
        TriggerClientEvent('swt:balanceUpdate', src, currencySlug, Economy.GetBalance(player.identifier, currencySlug))
    else
        TriggerClientEvent('swt:transferResult', src, false, 'Transfer failed')
    end
end)

-- Admin events
RegisterNetEvent('swt:adminAddMoney', function(targetIdentifier, currencySlug, amount, reason)
    local src = source
    local player = Cache.GetBySource(src)
    
    if not player then
        return
    end

    -- Check permission
    if not Permissions.HasPermission(player.identifier, 'economy.add_money') then
        Log.Player(player.identifier, 'PERMISSION_DENIED', {
            permission = 'economy.add_money',
            action = 'admin_add_money'
        })
        return
    end

    local success = Economy.AddMoney(targetIdentifier, currencySlug, amount, reason or 'Admin added money')
    
    if success then
        TriggerClientEvent('swt:adminResult', src, true, 'Money added successfully')
    else
        TriggerClientEvent('swt:adminResult', src, false, 'Failed to add money')
    end
end)

RegisterNetEvent('swt:adminRemoveMoney', function(targetIdentifier, currencySlug, amount, reason)
    local src = source
    local player = Cache.GetBySource(src)
    
    if not player then
        return
    end

    -- Check permission
    if not Permissions.HasPermission(player.identifier, 'economy.remove_money') then
        Log.Player(player.identifier, 'PERMISSION_DENIED', {
            permission = 'economy.remove_money',
            action = 'admin_remove_money'
        })
        return
    end

    local success = Economy.RemoveMoney(targetIdentifier, currencySlug, amount, reason or 'Admin removed money')
    
    if success then
        TriggerClientEvent('swt:adminResult', src, true, 'Money removed successfully')
    else
        TriggerClientEvent('swt:adminResult', src, false, 'Failed to remove money')
    end
end)

RegisterNetEvent('swt:adminAssignRole', function(targetIdentifier, roleName)
    local src = source
    local player = Cache.GetBySource(src)
    
    if not player then
        return
    end

    -- Check permission
    if not Permissions.HasPermission(player.identifier, 'permissions.assign_role') then
        Log.Player(player.identifier, 'PERMISSION_DENIED', {
            permission = 'permissions.assign_role',
            action = 'admin_assign_role'
        })
        return
    end

    local success = Permissions.AssignRoleToUser(targetIdentifier, roleName)
    
    if success then
        TriggerClientEvent('swt:adminResult', src, true, 'Role assigned successfully')
    else
        TriggerClientEvent('swt:adminResult', src, false, 'Failed to assign role')
    end
end)
