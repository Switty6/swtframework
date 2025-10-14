local Config = require 'config'

local prefix = '[swtframework]'

local Logger = {}

local function formatMessage(level, message)
    return string.format('%s [%s] %s', prefix, level, message)
end

function Logger.LogInfo(message)
    print(formatMessage('INFO', message))
end

function Logger.LogError(message)
    print(formatMessage('ERROR', message))
end

function Logger.LogDebug(message)
    if Config.Logging and Config.Logging.debug then
        print(formatMessage('DEBUG', message))
    end
end

return Logger
