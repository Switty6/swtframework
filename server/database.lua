local Config = require 'config'
local Logger = require 'utils.logger'

local Database = {}
local isConnected = false

local function buildConnectionConfig()
    local dbConfig = Config.Database or {}

    return {
        host = dbConfig.host,
        port = dbConfig.port,
        username = dbConfig.user,
        user = dbConfig.user,
        password = dbConfig.password,
        database = dbConfig.database,
        charset = dbConfig.charset or 'utf8mb4'
    }
end

function Database.Connect()
    local connectionConfig = buildConnectionConfig()

    exports.oxmysql:setConfig(connectionConfig, function(success)
        if not success then
            Logger.LogError('Failed to configure database connection. Please verify config.lua values.')
            return
        end

        exports.oxmysql:query('SELECT 1', {}, function(result)
            if result ~= false then
                isConnected = true
                Logger.LogInfo('Database connected successfully')
            else
                Logger.LogError('Database ping failed. Check database credentials and availability.')
            end
        end)
    end)
end

function Database.IsConnected()
    return isConnected
end

-- Wrapper functions for oxmysql with error handling
function Database.Query(query, params, callback)
    if not isConnected then
        Logger.LogError('Database not connected. Cannot execute query: ' .. query)
        if callback then callback(false, nil) end
        return
    end

    exports.oxmysql:query(query, params or {}, function(result)
        if result == false then
            Logger.LogError('Database query failed: ' .. query)
            if callback then callback(false, nil) end
        else
            if callback then callback(true, result) end
        end
    end)
end

function Database.Insert(query, params, callback)
    if not isConnected then
        Logger.LogError('Database not connected. Cannot execute insert: ' .. query)
        if callback then callback(false, nil) end
        return
    end

    exports.oxmysql:insert(query, params or {}, function(insertId)
        if insertId then
            if callback then callback(true, insertId) end
        else
            Logger.LogError('Database insert failed: ' .. query)
            if callback then callback(false, nil) end
        end
    end)
end

function Database.Update(query, params, callback)
    if not isConnected then
        Logger.LogError('Database not connected. Cannot execute update: ' .. query)
        if callback then callback(false, nil) end
        return
    end

    exports.oxmysql:update(query, params or {}, function(affectedRows)
        if affectedRows then
            if callback then callback(true, affectedRows) end
        else
            Logger.LogError('Database update failed: ' .. query)
            if callback then callback(false, nil) end
        end
    end)
end

function Database.Delete(query, params, callback)
    if not isConnected then
        Logger.LogError('Database not connected. Cannot execute delete: ' .. query)
        if callback then callback(false, nil) end
        return
    end

    exports.oxmysql:update(query, params or {}, function(affectedRows)
        if affectedRows then
            if callback then callback(true, affectedRows) end
        else
            Logger.LogError('Database delete failed: ' .. query)
            if callback then callback(false, nil) end
        end
    end)
end

-- Transaction support
function Database.Transaction(queries, callback)
    if not isConnected then
        Logger.LogError('Database not connected. Cannot execute transaction.')
        if callback then callback(false) end
        return
    end

    exports.oxmysql:transaction(queries, function(success)
        if success then
            if callback then callback(true) end
        else
            Logger.LogError('Database transaction failed.')
            if callback then callback(false) end
        end
    end)
end

-- Execute SQL file (for migrations)
function Database.ExecuteFile(filePath, callback)
    if not isConnected then
        Logger.LogError('Database not connected. Cannot execute file: ' .. filePath)
        if callback then callback(false) end
        return
    end

    local file = LoadResourceFile(GetCurrentResourceName(), filePath)
    if not file then
        Logger.LogError('Could not load SQL file: ' .. filePath)
        if callback then callback(false) end
        return
    end

    exports.oxmysql:query(file, {}, function(result)
        if result ~= false then
            Logger.LogInfo('SQL file executed successfully: ' .. filePath)
            if callback then callback(true) end
        else
            Logger.LogError('SQL file execution failed: ' .. filePath)
            if callback then callback(false) end
        end
    end)
end

return Database
