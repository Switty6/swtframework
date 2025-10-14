local Config = require 'config'
local Logger = require 'utils.logger'

local Database = {}

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
                Logger.LogInfo('Database connected successfully')
            else
                Logger.LogError('Database ping failed. Check database credentials and availability.')
            end
        end)
    end)
end

return Database
