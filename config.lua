local Config = {}

Config.Database = {
    host = '127.0.0.1',
    port = 3306,
    user = 'root',
    password = 'password',
    database = 'swtframework',
    charset = 'utf8mb4'
}

Config.Logging = {
    debug = false,
    retention_days = 30,
    levels = {
        'DEBUG', 'INFO', 'WARNING', 'ERROR'
    }
}

Config.Economy = {
    default_currencies = {
        {
            slug = 'cash',
            name = 'Cash',
            description = 'Physical money',
            default_amount = 1000.00
        },
        {
            slug = 'bank',
            name = 'Bank Account',
            description = 'Bank account balance',
            default_amount = 5000.00
        },
        {
            slug = 'gold',
            name = 'Gold',
            description = 'Precious metal currency',
            default_amount = 0.00
        }
    }
}

Config.Permissions = {
    default_roles = {
        {
            name = 'user',
            priority = 0,
            description = 'Basic user role'
        },
        {
            name = 'moderator',
            priority = 50,
            description = 'Moderator role with additional permissions'
        },
        {
            name = 'admin',
            priority = 100,
            description = 'Administrator role with most permissions'
        },
        {
            name = 'superadmin',
            priority = 200,
            description = 'Super administrator with all permissions'
        }
    },
    default_permissions = {
        -- Economy permissions
        'economy.add_money',
        'economy.remove_money',
        'economy.transfer_money',
        'economy.view_balance',
        'economy.view_transactions',
        
        -- Permission management
        'permissions.assign_role',
        'permissions.remove_role',
        'permissions.create_role',
        'permissions.create_permission',
        
        -- Logging
        'logs.view',
        'logs.clean',
        
        -- Player management
        'player.kick',
        'player.ban',
        'player.teleport'
    }
}

Config.Cache = {
    refresh_interval = 300000, -- 5 minutes in milliseconds
    max_cache_size = 1000,
    auto_refresh = true
}

Config.Framework = {
    name = 'SWT Framework',
    version = '1.0.0',
    author = 'SWT Team',
    description = 'Modular FiveM Framework with Economy, Permissions, and Logging'
}

return Config
