local Logger = require 'utils.logger'
local Database = require 'server.database'
local Cache = require 'server.cache'
require 'server.events'

SWT = {}
SWT.GetPlayer = Cache.Get
_G.SWT = SWT

CreateThread(function()
    Database.Connect()
end)

Logger.LogInfo('swt_core initialized and awaiting player connections.')
