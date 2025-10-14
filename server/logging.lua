local Database = require 'server.database'
local Logger = require 'utils.logger'

local Log = {}
local resourceName = GetCurrentResourceName()

-- Helper function to get function name from call stack
local function getFunctionName(level)
    level = level or 2
    local info = debug.getinfo(level, "n")
    return info and info.name or "unknown"
end

-- Helper function to get origin (file:line)
local function getOrigin(level)
    level = level or 2
    local info = debug.getinfo(level, "Sl")
    if info and info.source and info.currentline then
        local source = info.source:gsub("^@", ""):gsub("^.*/", "")
        return source .. ":" .. info.currentline
    end
    return "unknown"
end

-- Helper function to serialize metadata
local function serializeMetadata(metadata)
    if not metadata then
        return nil
    end
    
    if type(metadata) == "table" then
        return json.encode(metadata)
    end
    
    return tostring(metadata)
end

-- Core logging function
local function logToDatabase(level, message, metadata, playerId)
    if not Database.IsConnected() then
        Logger.LogError('Database not connected. Cannot log to database.')
        return
    end

    local functionName = getFunctionName(3)
    local origin = getOrigin(3)
    local serializedMetadata = serializeMetadata(metadata)

    local query = [[
        INSERT INTO logs (level, player_id, resource, origin, function_name, message, metadata, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, NOW())
    ]]

    local params = {
        level,
        playerId,
        resourceName,
        origin,
        functionName,
        message,
        serializedMetadata
    }

    Database.Insert(query, params, function(success)
        if not success then
            Logger.LogError('Failed to log to database: ' .. message)
        end
    end)
end

-- Public logging functions
function Log.Info(message, metadata)
    Logger.LogInfo(message)
    logToDatabase('INFO', message, metadata)
end

function Log.Warning(message, metadata)
    Logger.LogWarning(message)
    logToDatabase('WARNING', message, metadata)
end

function Log.Error(message, metadata)
    Logger.LogError(message)
    logToDatabase('ERROR', message, metadata)
end

function Log.Debug(message, metadata)
    Logger.LogDebug(message)
    logToDatabase('DEBUG', message, metadata)
end

-- Player-specific logging
function Log.Player(identifier, action, metadata)
    local message = string.format('Player action: %s', action)
    local playerMetadata = metadata or {}
    playerMetadata.player_identifier = identifier
    playerMetadata.action = action
    
    Log.Info(message, playerMetadata)
end

-- Resource-specific logging
function Log.Resource(resource, action, metadata)
    local message = string.format('Resource %s: %s', resource, action)
    local resourceMetadata = metadata or {}
    resourceMetadata.resource = resource
    resourceMetadata.action = action
    
    Log.Info(message, resourceMetadata)
end

-- Economy-specific logging
function Log.Economy(identifier, action, currency, amount, metadata)
    local message = string.format('Economy: %s %s %s', action, amount, currency)
    local economyMetadata = metadata or {}
    economyMetadata.player_identifier = identifier
    economyMetadata.action = action
    economyMetadata.currency = currency
    economyMetadata.amount = amount
    
    Log.Info(message, economyMetadata)
end

-- Permission-specific logging
function Log.Permission(identifier, action, permission, metadata)
    local message = string.format('Permission: %s %s', action, permission)
    local permissionMetadata = metadata or {}
    permissionMetadata.player_identifier = identifier
    permissionMetadata.action = action
    permissionMetadata.permission = permission
    
    Log.Info(message, permissionMetadata)
end

-- Query logs with filters
function Log.Query(filter, callback)
    if not Database.IsConnected() then
        Logger.LogError('Database not connected. Cannot query logs.')
        if callback then callback(false, nil) end
        return
    end

    local whereClause = {}
    local params = {}
    local paramIndex = 1

    -- Build WHERE clause based on filter
    if filter.level then
        table.insert(whereClause, 'level = ?')
        params[paramIndex] = filter.level
        paramIndex = paramIndex + 1
    end

    if filter.player_id then
        table.insert(whereClause, 'player_id = ?')
        params[paramIndex] = filter.player_id
        paramIndex = paramIndex + 1
    end

    if filter.resource then
        table.insert(whereClause, 'resource = ?')
        params[paramIndex] = filter.resource
        paramIndex = paramIndex + 1
    end

    if filter.origin then
        table.insert(whereClause, 'origin LIKE ?')
        params[paramIndex] = '%' .. filter.origin .. '%'
        paramIndex = paramIndex + 1
    end

    if filter.function_name then
        table.insert(whereClause, 'function_name = ?')
        params[paramIndex] = filter.function_name
        paramIndex = paramIndex + 1
    end

    if filter.date_from then
        table.insert(whereClause, 'created_at >= ?')
        params[paramIndex] = filter.date_from
        paramIndex = paramIndex + 1
    end

    if filter.date_to then
        table.insert(whereClause, 'created_at <= ?')
        params[paramIndex] = filter.date_to
        paramIndex = paramIndex + 1
    end

    -- Build query
    local query = 'SELECT * FROM logs'
    if #whereClause > 0 then
        query = query .. ' WHERE ' .. table.concat(whereClause, ' AND ')
    end

    query = query .. ' ORDER BY created_at DESC'

    if filter.limit then
        query = query .. ' LIMIT ' .. filter.limit
    end

    Database.Query(query, params, function(success, result)
        if callback then
            callback(success, result)
        end
    end)
end

-- Get logs by player identifier (converts identifier to player_id)
function Log.GetPlayerLogs(identifier, limit, callback)
    if not Database.IsConnected() then
        Logger.LogError('Database not connected. Cannot get player logs.')
        if callback then callback(false, nil) end
        return
    end

    local query = [[
        SELECT l.* FROM logs l
        JOIN users u ON l.player_id = u.id
        WHERE u.identifier = ?
        ORDER BY l.created_at DESC
    ]]

    if limit then
        query = query .. ' LIMIT ' .. limit
    end

    Database.Query(query, {identifier}, function(success, result)
        if callback then
            callback(success, result)
        end
    end)
end

-- Clean old logs (retention policy)
function Log.CleanOldLogs(daysOld, callback)
    if not Database.IsConnected() then
        Logger.LogError('Database not connected. Cannot clean old logs.')
        if callback then callback(false) end
        return
    end

    local query = 'DELETE FROM logs WHERE created_at < DATE_SUB(NOW(), INTERVAL ? DAY)'
    
    Database.Delete(query, {daysOld}, function(success, affectedRows)
        if success then
            Log.Info(string.format('Cleaned %d old log entries (older than %d days)', affectedRows, daysOld))
        end
        
        if callback then
            callback(success, affectedRows)
        end
    end)
end

return Log
