local Database = require 'server.database'
local Log = require 'server.logging'

local Permissions = {}
local roleCache = {}
local permissionCache = {}
local userRoleCache = {}
local rolePermissionCache = {}

-- Cache management
local function refreshRoleCache()
    Database.Query('SELECT * FROM roles ORDER BY priority DESC', {}, function(success, result)
        if success and result then
            roleCache = {}
            for _, role in ipairs(result) do
                roleCache[role.name] = role
            end
        end
    end)
end

local function refreshPermissionCache()
    Database.Query('SELECT * FROM permissions', {}, function(success, result)
        if success and result then
            permissionCache = {}
            for _, permission in ipairs(result) do
                permissionCache[permission.slug] = permission
            end
        end
    end)
end

local function refreshRolePermissionCache()
    local query = [[
        SELECT rp.role_id, rp.permission_id, r.name as role_name, p.slug as permission_slug
        FROM role_permissions rp
        JOIN roles r ON rp.role_id = r.id
        JOIN permissions p ON rp.permission_id = p.id
    ]]
    
    Database.Query(query, {}, function(success, result)
        if success and result then
            rolePermissionCache = {}
            for _, rp in ipairs(result) do
                if not rolePermissionCache[rp.role_name] then
                    rolePermissionCache[rp.role_name] = {}
                end
                rolePermissionCache[rp.role_name][rp.permission_slug] = true
            end
        end
    end)
end

local function refreshUserRoleCache(identifier)
    if not identifier then return end
    
    local query = [[
        SELECT r.name as role_name, r.priority
        FROM user_roles ur
        JOIN roles r ON ur.role_id = r.id
        JOIN users u ON ur.user_id = u.id
        WHERE u.identifier = ?
        ORDER BY r.priority DESC
    ]]
    
    Database.Query(query, {identifier}, function(success, result)
        if success and result then
            userRoleCache[identifier] = {}
            for _, role in ipairs(result) do
                userRoleCache[identifier][role.role_name] = role
            end
        end
    end)
end

-- Initialize caches on startup
CreateThread(function()
    Wait(1000) -- Wait for database connection
    refreshRoleCache()
    refreshPermissionCache()
    refreshRolePermissionCache()
end)

-- Role management
function Permissions.CreateRole(name, priority, description)
    if not name then
        Log.Error('Permissions.CreateRole: name is required')
        return false
    end

    priority = priority or 0
    description = description or ''

    local query = [[
        INSERT INTO roles (name, priority, description)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE
        priority = VALUES(priority),
        description = VALUES(description)
    ]]

    Database.Insert(query, {name, priority, description}, function(success, insertId)
        if success then
            refreshRoleCache()
            Log.Info(string.format('Role created/updated: %s (priority: %d)', name, priority))
        else
            Log.Error(string.format('Failed to create role: %s', name))
        end
    end)

    return true
end

function Permissions.GetRole(name)
    return roleCache[name]
end

function Permissions.GetAllRoles()
    return roleCache
end

-- Permission management
function Permissions.CreatePermission(slug, description)
    if not slug then
        Log.Error('Permissions.CreatePermission: slug is required')
        return false
    end

    description = description or ''

    local query = [[
        INSERT INTO permissions (slug, description)
        VALUES (?, ?)
        ON DUPLICATE KEY UPDATE
        description = VALUES(description)
    ]]

    Database.Insert(query, {slug, description}, function(success, insertId)
        if success then
            refreshPermissionCache()
            Log.Info(string.format('Permission created/updated: %s', slug))
        else
            Log.Error(string.format('Failed to create permission: %s', slug))
        end
    end)

    return true
end

function Permissions.GetPermission(slug)
    return permissionCache[slug]
end

function Permissions.GetAllPermissions()
    return permissionCache
end

-- Role-Permission assignment
function Permissions.AssignPermissionToRole(roleName, permissionSlug)
    if not roleName or not permissionSlug then
        Log.Error('Permissions.AssignPermissionToRole: role_name and permission_slug are required')
        return false
    end

    local query = [[
        INSERT INTO role_permissions (role_id, permission_id)
        SELECT r.id, p.id
        FROM roles r, permissions p
        WHERE r.name = ? AND p.slug = ?
        ON DUPLICATE KEY UPDATE role_id = role_id
    ]]

    Database.Insert(query, {roleName, permissionSlug}, function(success, insertId)
        if success then
            refreshRolePermissionCache()
            Log.Permission(nil, 'ASSIGN_PERMISSION_TO_ROLE', permissionSlug, {role = roleName})
        else
            Log.Error(string.format('Failed to assign permission %s to role %s', permissionSlug, roleName))
        end
    end)

    return true
end

function Permissions.RemovePermissionFromRole(roleName, permissionSlug)
    if not roleName or not permissionSlug then
        Log.Error('Permissions.RemovePermissionFromRole: role_name and permission_slug are required')
        return false
    end

    local query = [[
        DELETE rp FROM role_permissions rp
        JOIN roles r ON rp.role_id = r.id
        JOIN permissions p ON rp.permission_id = p.id
        WHERE r.name = ? AND p.slug = ?
    ]]

    Database.Delete(query, {roleName, permissionSlug}, function(success, affectedRows)
        if success then
            refreshRolePermissionCache()
            Log.Permission(nil, 'REMOVE_PERMISSION_FROM_ROLE', permissionSlug, {role = roleName})
        else
            Log.Error(string.format('Failed to remove permission %s from role %s', permissionSlug, roleName))
        end
    end)

    return true
end

function Permissions.GetRolePermissions(roleName)
    if not roleName then
        return {}
    end

    return rolePermissionCache[roleName] or {}
end

-- User-Role assignment
function Permissions.AssignRoleToUser(identifier, roleName)
    if not identifier or not roleName then
        Log.Error('Permissions.AssignRoleToUser: identifier and role_name are required')
        return false
    end

    local queries = {
        {
            query = [[
                INSERT INTO users (identifier, name)
                VALUES (?, ?)
                ON DUPLICATE KEY UPDATE name = VALUES(name)
            ]],
            params = {identifier, GetPlayerName(GetPlayerFromServerId(identifier)) or 'Unknown'}
        },
        {
            query = [[
                INSERT INTO user_roles (user_id, role_id)
                SELECT u.id, r.id
                FROM users u, roles r
                WHERE u.identifier = ? AND r.name = ?
                ON DUPLICATE KEY UPDATE user_id = user_id
            ]],
            params = {identifier, roleName}
        }
    }

    Database.Transaction(queries, function(success)
        if success then
            refreshUserRoleCache(identifier)
            Log.Permission(identifier, 'ASSIGN_ROLE', roleName)
        else
            Log.Error(string.format('Failed to assign role %s to user %s', roleName, identifier))
        end
    end)

    return true
end

function Permissions.RemoveRoleFromUser(identifier, roleName)
    if not identifier or not roleName then
        Log.Error('Permissions.RemoveRoleFromUser: identifier and role_name are required')
        return false
    end

    local query = [[
        DELETE ur FROM user_roles ur
        JOIN users u ON ur.user_id = u.id
        JOIN roles r ON ur.role_id = r.id
        WHERE u.identifier = ? AND r.name = ?
    ]]

    Database.Delete(query, {identifier, roleName}, function(success, affectedRows)
        if success then
            refreshUserRoleCache(identifier)
            Log.Permission(identifier, 'REMOVE_ROLE', roleName)
        else
            Log.Error(string.format('Failed to remove role %s from user %s', roleName, identifier))
        end
    end)

    return true
end

function Permissions.GetUserRoles(identifier)
    if not identifier then
        return {}
    end

    return userRoleCache[identifier] or {}
end

-- Permission checking with hierarchy support
function Permissions.HasPermission(identifier, permissionSlug)
    if not identifier or not permissionSlug then
        return false
    end

    local userRoles = Permissions.GetUserRoles(identifier)
    if not userRoles or next(userRoles) == nil then
        return false
    end

    -- Check direct role permissions
    for roleName, roleData in pairs(userRoles) do
        local rolePermissions = Permissions.GetRolePermissions(roleName)
        if rolePermissions and rolePermissions[permissionSlug] then
            return true
        end
    end

    -- Check hierarchy (roles with higher priority inherit permissions from lower priority roles)
    local highestPriority = -1
    local highestPriorityRole = nil

    for roleName, roleData in pairs(userRoles) do
        if roleData.priority > highestPriority then
            highestPriority = roleData.priority
            highestPriorityRole = roleName
        end
    end

    if highestPriorityRole then
        -- Get all roles with priority <= highest priority
        local query = [[
            SELECT name FROM roles WHERE priority <= ? ORDER BY priority DESC
        ]]

        local inheritedRoles = {}
        Database.Query(query, {highestPriority}, function(success, result)
            if success and result then
                for _, role in ipairs(result) do
                    table.insert(inheritedRoles, role.name)
                end
            end
        end)

        -- Check permissions for all inherited roles
        for _, roleName in ipairs(inheritedRoles) do
            local rolePermissions = Permissions.GetRolePermissions(roleName)
            if rolePermissions and rolePermissions[permissionSlug] then
                return true
            end
        end
    end

    return false
end

function Permissions.GetUserPermissions(identifier)
    if not identifier then
        return {}
    end

    local userRoles = Permissions.GetUserRoles(identifier)
    local permissions = {}

    for roleName, roleData in pairs(userRoles) do
        local rolePermissions = Permissions.GetRolePermissions(roleName)
        if rolePermissions then
            for permissionSlug, _ in pairs(rolePermissions) do
                permissions[permissionSlug] = true
            end
        end
    end

    return permissions
end

-- Initialize default roles and permissions
function Permissions.InitializeDefaults()
    -- Create default roles
    Permissions.CreateRole('user', 0, 'Basic user role')
    Permissions.CreateRole('moderator', 50, 'Moderator role with additional permissions')
    Permissions.CreateRole('admin', 100, 'Administrator role with most permissions')
    Permissions.CreateRole('superadmin', 200, 'Super administrator with all permissions')

    -- Create default permissions
    Permissions.CreatePermission('economy.add_money', 'Add money to players')
    Permissions.CreatePermission('economy.remove_money', 'Remove money from players')
    Permissions.CreatePermission('economy.transfer_money', 'Transfer money between players')
    Permissions.CreatePermission('economy.view_balance', 'View player balances')
    Permissions.CreatePermission('economy.view_transactions', 'View transaction history')

    Permissions.CreatePermission('permissions.assign_role', 'Assign roles to players')
    Permissions.CreatePermission('permissions.remove_role', 'Remove roles from players')
    Permissions.CreatePermission('permissions.create_role', 'Create new roles')
    Permissions.CreatePermission('permissions.create_permission', 'Create new permissions')

    Permissions.CreatePermission('logs.view', 'View system logs')
    Permissions.CreatePermission('logs.clean', 'Clean old logs')

    Permissions.CreatePermission('player.kick', 'Kick players from server')
    Permissions.CreatePermission('player.ban', 'Ban players from server')
    Permissions.CreatePermission('player.teleport', 'Teleport players')

    -- Assign permissions to roles
    -- User role (basic permissions)
    Permissions.AssignPermissionToRole('user', 'economy.view_balance')

    -- Moderator role (inherits user permissions + additional)
    Permissions.AssignPermissionToRole('moderator', 'economy.view_balance')
    Permissions.AssignPermissionToRole('moderator', 'economy.view_transactions')
    Permissions.AssignPermissionToRole('moderator', 'player.kick')
    Permissions.AssignPermissionToRole('moderator', 'logs.view')

    -- Admin role (inherits moderator permissions + additional)
    Permissions.AssignPermissionToRole('admin', 'economy.add_money')
    Permissions.AssignPermissionToRole('admin', 'economy.remove_money')
    Permissions.AssignPermissionToRole('admin', 'economy.transfer_money')
    Permissions.AssignPermissionToRole('admin', 'permissions.assign_role')
    Permissions.AssignPermissionToRole('admin', 'permissions.remove_role')
    Permissions.AssignPermissionToRole('admin', 'player.ban')
    Permissions.AssignPermissionToRole('admin', 'player.teleport')
    Permissions.AssignPermissionToRole('admin', 'logs.clean')

    -- Superadmin role (all permissions)
    Permissions.AssignPermissionToRole('superadmin', 'permissions.create_role')
    Permissions.AssignPermissionToRole('superadmin', 'permissions.create_permission')
end

return Permissions
