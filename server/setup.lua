local Database = require 'server.database'
local Economy = require 'server.economy'
local Permissions = require 'server.permissions'
local Log = require 'server.logging'
local Logger = require 'utils.logger'

local Setup = {}
local isInitialized = false

-- Check if tables exist
local function checkTablesExist()
    local tables = {
        'users', 'currencies', 'user_currencies', 'currency_transactions',
        'roles', 'permissions', 'role_permissions', 'user_roles', 'logs'
    }

    local existingTables = {}
    local missingTables = {}

    for _, tableName in ipairs(tables) do
        local query = string.format("SHOW TABLES LIKE '%s'", tableName)
        
        Database.Query(query, {}, function(success, result)
            if success and result and #result > 0 then
                table.insert(existingTables, tableName)
            else
                table.insert(missingTables, tableName)
            end
        end)
    end

    return existingTables, missingTables
end

-- Create database schema
local function createSchema()
    Logger.LogInfo('Creating database schema...')
    
    Database.ExecuteFile('server/migrations/schema.sql', function(success)
        if success then
            Logger.LogInfo('Database schema created successfully')
            Log.Info('Database schema created successfully')
        else
            Logger.LogError('Failed to create database schema')
            Log.Error('Failed to create database schema')
        end
    end)
end

-- Initialize default currencies
local function initializeCurrencies()
    Logger.LogInfo('Initializing default currencies...')
    
    Economy.InitializeDefaultCurrencies()
    
    Log.Info('Default currencies initialized', {
        currencies = {'cash', 'bank', 'gold'}
    })
end

-- Initialize default roles and permissions
local function initializeRolesAndPermissions()
    Logger.LogInfo('Initializing default roles and permissions...')
    
    Permissions.InitializeDefaults()
    
    Log.Info('Default roles and permissions initialized', {
        roles = {'user', 'moderator', 'admin', 'superadmin'},
        permissions = {
            'economy.add_money', 'economy.remove_money', 'economy.transfer_money',
            'economy.view_balance', 'economy.view_transactions',
            'permissions.assign_role', 'permissions.remove_role', 'permissions.create_role', 'permissions.create_permission',
            'logs.view', 'logs.clean',
            'player.kick', 'player.ban', 'player.teleport'
        }
    })
end

-- Create default admin user (if no superadmin exists)
local function createDefaultAdmin()
    local query = [[
        SELECT COUNT(*) as count
        FROM user_roles ur
        JOIN roles r ON ur.role_id = r.id
        WHERE r.name = 'superadmin'
    ]]

    Database.Query(query, {}, function(success, result)
        if success and result and result[1].count == 0 then
            Logger.LogInfo('No superadmin found. Creating default admin...')
            
            -- You can modify this to use a specific identifier
            local defaultAdminIdentifier = 'fivem:0000000000000000' -- Replace with actual admin identifier
            
            local queries = {
                {
                    query = [[
                        INSERT INTO users (identifier, name, metadata)
                        VALUES (?, ?, ?)
                        ON DUPLICATE KEY UPDATE name = VALUES(name)
                    ]],
                    params = {defaultAdminIdentifier, 'Default Admin', json.encode({is_default_admin = true})}
                },
                {
                    query = [[
                        INSERT INTO user_roles (user_id, role_id)
                        SELECT u.id, r.id
                        FROM users u, roles r
                        WHERE u.identifier = ? AND r.name = 'superadmin'
                    ]],
                    params = {defaultAdminIdentifier}
                }
            }

            Database.Transaction(queries, function(success)
                if success then
                    Logger.LogInfo('Default admin created successfully')
                    Log.Info('Default admin created', {identifier = defaultAdminIdentifier})
                else
                    Logger.LogError('Failed to create default admin')
                    Log.Error('Failed to create default admin', {identifier = defaultAdminIdentifier})
                end
            end)
        end
    end)
end

-- Setup log retention policy
local function setupLogRetention()
    Logger.LogInfo('Setting up log retention policy...')
    
    -- Clean logs older than 30 days (configurable)
    local retentionDays = 30
    
    Log.CleanOldLogs(retentionDays, function(success, affectedRows)
        if success then
            Logger.LogInfo(string.format('Log retention: cleaned %d old entries', affectedRows or 0))
        end
    end)
end

-- Main setup function
function Setup.Initialize()
    if isInitialized then
        Logger.LogInfo('Setup already initialized')
        return
    end

    Logger.LogInfo('Starting SWT Framework setup...')
    Log.Info('SWT Framework setup started')

    -- Wait for database connection
    CreateThread(function()
        local attempts = 0
        local maxAttempts = 30

        while not Database.IsConnected() and attempts < maxAttempts do
            Wait(1000)
            attempts = attempts + 1
        end

        if not Database.IsConnected() then
            Logger.LogError('Database not connected after 30 seconds. Setup aborted.')
            Log.Error('Database connection timeout during setup')
            return
        end

        Logger.LogInfo('Database connected. Proceeding with setup...')

        -- Check if tables exist
        local existingTables, missingTables = checkTablesExist()
        
        if #missingTables > 0 then
            Logger.LogInfo(string.format('Missing tables: %s', table.concat(missingTables, ', ')))
            createSchema()
            
            -- Wait a bit for schema creation
            Wait(2000)
        end

        -- Initialize default data
        initializeCurrencies()
        Wait(1000)
        
        initializeRolesAndPermissions()
        Wait(1000)
        
        createDefaultAdmin()
        Wait(1000)
        
        setupLogRetention()

        isInitialized = true
        Logger.LogInfo('SWT Framework setup completed successfully')
        Log.Info('SWT Framework setup completed successfully', {
            existing_tables = existingTables,
            missing_tables = missingTables
        })
    end)
end

-- Reset function (for development)
function Setup.Reset()
    Logger.LogWarning('Resetting SWT Framework database...')
    Log.Warning('SWT Framework database reset initiated')

    local queries = {
        'SET FOREIGN_KEY_CHECKS = 0',
        'DROP TABLE IF EXISTS logs',
        'DROP TABLE IF EXISTS user_roles',
        'DROP TABLE IF EXISTS role_permissions',
        'DROP TABLE IF EXISTS user_currencies',
        'DROP TABLE IF EXISTS currency_transactions',
        'DROP TABLE IF EXISTS users',
        'DROP TABLE IF EXISTS currencies',
        'DROP TABLE IF EXISTS roles',
        'DROP TABLE IF EXISTS permissions',
        'SET FOREIGN_KEY_CHECKS = 1'
    }

    Database.Transaction(queries, function(success)
        if success then
            Logger.LogInfo('Database reset completed')
            Log.Info('Database reset completed')
            isInitialized = false
            Setup.Initialize()
        else
            Logger.LogError('Database reset failed')
            Log.Error('Database reset failed')
        end
    end)
end

-- Status check
function Setup.GetStatus()
    return {
        initialized = isInitialized,
        database_connected = Database.IsConnected()
    }
end

return Setup
