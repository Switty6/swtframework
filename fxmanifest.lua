fx_version 'cerulean'

lua54 'yes'

game 'gta5'

name 'swt_core'
description 'SWT Framework Core - Modular FiveM Framework with Economy, Permissions, and Logging'
version '1.0.0'
author 'SWT Team'

dependency 'oxmysql'

server_scripts {
    'config.lua',
    'utils/logger.lua',
    'server/database.lua',
    'server/logging.lua',
    'server/economy.lua',
    'server/permissions.lua',
    'server/cache.lua',
    'server/setup.lua',
    'server/events.lua',
    'server/main.lua'
}

files {
    'server/migrations/schema.sql'
}
