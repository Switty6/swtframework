local Logger = require 'utils.logger'
local Database = require 'server.database'
local Cache = require 'server.cache'
local Economy = require 'server.economy'
local Permissions = require 'server.permissions'
local Log = require 'server.logging'
local Setup = require 'server.setup'
require 'server.events'

-- Global SWT API
SWT = {
    -- Player management
    GetPlayer = Cache.Get,
    GetPlayerBySource = Cache.GetBySource,
    GetAllPlayers = Cache.GetAll,
    
    -- Economy API
    GetBalance = function(identifier, currencySlug)
        return Economy.GetBalance(identifier, currencySlug)
    end,
    AddMoney = function(identifier, currencySlug, amount, reason)
        return Economy.AddMoney(identifier, currencySlug, amount, reason)
    end,
    RemoveMoney = function(identifier, currencySlug, amount, reason)
        return Economy.RemoveMoney(identifier, currencySlug, amount, reason)
    end,
    SetBalance = function(identifier, currencySlug, amount, reason)
        return Economy.SetBalance(identifier, currencySlug, amount, reason)
    end,
    TransferMoney = function(fromIdentifier, toIdentifier, currencySlug, amount, reason)
        return Economy.TransferMoney(fromIdentifier, toIdentifier, currencySlug, amount, reason)
    end,
    GetTransactionHistory = function(identifier, currencySlug, limit)
        return Economy.GetTransactionHistory(identifier, currencySlug, limit)
    end,
    CreateCurrency = function(slug, name, description, defaultAmount)
        return Economy.CreateCurrency(slug, name, description, defaultAmount)
    end,
    GetCurrency = function(slug)
        return Economy.GetCurrency(slug)
    end,
    GetAllCurrencies = function()
        return Economy.GetAllCurrencies()
    end,
    
    -- Permissions API
    HasPermission = function(identifier, permissionSlug)
        return Permissions.HasPermission(identifier, permissionSlug)
    end,
    GetUserRoles = function(identifier)
        return Permissions.GetUserRoles(identifier)
    end,
    GetUserPermissions = function(identifier)
        return Permissions.GetUserPermissions(identifier)
    end,
    AssignRoleToUser = function(identifier, roleName)
        return Permissions.AssignRoleToUser(identifier, roleName)
    end,
    RemoveRoleFromUser = function(identifier, roleName)
        return Permissions.RemoveRoleFromUser(identifier, roleName)
    end,
    CreateRole = function(name, priority, description)
        return Permissions.CreateRole(name, priority, description)
    end,
    CreatePermission = function(slug, description)
        return Permissions.CreatePermission(slug, description)
    end,
    AssignPermissionToRole = function(roleName, permissionSlug)
        return Permissions.AssignPermissionToRole(roleName, permissionSlug)
    end,
    RemovePermissionFromRole = function(roleName, permissionSlug)
        return Permissions.RemovePermissionFromRole(roleName, permissionSlug)
    end,
    GetRole = function(name)
        return Permissions.GetRole(name)
    end,
    GetPermission = function(slug)
        return Permissions.GetPermission(slug)
    end,
    GetAllRoles = function()
        return Permissions.GetAllRoles()
    end,
    GetAllPermissions = function()
        return Permissions.GetAllPermissions()
    end,
    
    -- Logging API
    Log = {
        Info = Log.Info,
        Warning = Log.Warning,
        Error = Log.Error,
        Debug = Log.Debug,
        Player = Log.Player,
        Resource = Log.Resource,
        Economy = Log.Economy,
        Permission = Log.Permission,
        Query = Log.Query,
        GetPlayerLogs = Log.GetPlayerLogs,
        CleanOldLogs = Log.CleanOldLogs
    },
    
    -- Cache API
    Cache = {
        GetPlayerCurrency = Cache.GetPlayerCurrency,
        GetPlayerCurrencies = Cache.GetPlayerCurrencies,
        GetPlayerRoles = Cache.GetPlayerRoles,
        GetPlayerPermissions = Cache.GetPlayerPermissions,
        PlayerHasRole = Cache.PlayerHasRole,
        PlayerHasPermission = Cache.PlayerHasPermission,
        RefreshPlayerData = Cache.RefreshPlayerData,
        InvalidatePlayerCurrency = Cache.InvalidatePlayerCurrency,
        InvalidatePlayerRoles = Cache.InvalidatePlayerRoles,
        InvalidatePlayerPermissions = Cache.InvalidatePlayerPermissions,
        GetStats = Cache.GetStats
    },
    
    -- Database API
    Database = {
        IsConnected = Database.IsConnected,
        Query = Database.Query,
        Insert = Database.Insert,
        Update = Database.Update,
        Delete = Database.Delete,
        Transaction = Database.Transaction
    },
    
    -- Setup API
    Setup = {
        GetStatus = Setup.GetStatus,
        Reset = Setup.Reset
    }
}

-- Make SWT globally available
_G.SWT = SWT

-- Initialize framework
CreateThread(function()
    Logger.LogInfo('SWT Framework starting initialization...')
    
    -- Connect to database
    Database.Connect()
    
    -- Wait for database connection
    local attempts = 0
    while not Database.IsConnected() and attempts < 30 do
        Wait(1000)
        attempts = attempts + 1
    end
    
    if Database.IsConnected() then
        Logger.LogInfo('Database connected. Running setup...')
        Setup.Initialize()
    else
        Logger.LogError('Failed to connect to database after 30 seconds')
    end
end)

Logger.LogInfo('SWT Framework core loaded and awaiting initialization.')
