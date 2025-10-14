fx_version 'cerulean'

lua54 'yes'

game 'gta5'

name 'swt_core'
description 'SWT Framework Core'
version '1.0.0'

dependency 'oxmysql'

server_scripts {
    'config.lua',
    'utils/logger.lua',
    'server/database.lua',
    'server/cache.lua',
    'server/events.lua',
    'server/main.lua'
}
