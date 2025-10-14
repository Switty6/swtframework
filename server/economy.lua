local Database = require 'server.database'
local Log = require 'server.logging'

local Economy = {}
local currencyCache = {}
local userBalanceCache = {}

-- Cache management
local function refreshCurrencyCache()
    Database.Query('SELECT * FROM currencies', {}, function(success, result)
        if success and result then
            currencyCache = {}
            for _, currency in ipairs(result) do
                currencyCache[currency.slug] = currency
            end
        end
    end)
end

local function refreshUserBalanceCache(identifier)
    if not identifier then return end
    
    local query = [[
        SELECT uc.amount, c.slug 
        FROM user_currencies uc
        JOIN currencies c ON uc.currency_id = c.id
        JOIN users u ON uc.user_id = u.id
        WHERE u.identifier = ?
    ]]
    
    Database.Query(query, {identifier}, function(success, result)
        if success and result then
            userBalanceCache[identifier] = {}
            for _, balance in ipairs(result) do
                userBalanceCache[identifier][balance.slug] = balance.amount
            end
        end
    end)
end

-- Initialize cache on startup
CreateThread(function()
    Wait(1000) -- Wait for database connection
    refreshCurrencyCache()
end)

-- Currency management
function Economy.CreateCurrency(slug, name, description, defaultAmount)
    if not slug or not name then
        Log.Error('Economy.CreateCurrency: slug and name are required')
        return false
    end

    defaultAmount = defaultAmount or 0.00

    local query = [[
        INSERT INTO currencies (slug, name, description, default_amount)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
        name = VALUES(name),
        description = VALUES(description),
        default_amount = VALUES(default_amount)
    ]]

    Database.Insert(query, {slug, name, description, defaultAmount}, function(success, insertId)
        if success then
            refreshCurrencyCache()
            Log.Info(string.format('Currency created/updated: %s (%s)', name, slug))
        else
            Log.Error(string.format('Failed to create currency: %s', slug))
        end
    end)

    return true
end

function Economy.GetCurrency(slug)
    return currencyCache[slug]
end

function Economy.GetAllCurrencies()
    return currencyCache
end

-- Balance management
function Economy.GetBalance(identifier, currencySlug)
    if not identifier or not currencySlug then
        Log.Error('Economy.GetBalance: identifier and currency_slug are required')
        return 0.00
    end

    -- Check cache first
    if userBalanceCache[identifier] and userBalanceCache[identifier][currencySlug] then
        return userBalanceCache[identifier][currencySlug]
    end

    -- Fallback to database
    local query = [[
        SELECT uc.amount 
        FROM user_currencies uc
        JOIN currencies c ON uc.currency_id = c.id
        JOIN users u ON uc.user_id = u.id
        WHERE u.identifier = ? AND c.slug = ?
    ]]

    local balance = 0.00
    Database.Query(query, {identifier, currencySlug}, function(success, result)
        if success and result and #result > 0 then
            balance = result[1].amount
        end
    end)

    return balance
end

function Economy.SetBalance(identifier, currencySlug, amount, reason)
    if not identifier or not currencySlug or not amount then
        Log.Error('Economy.SetBalance: identifier, currency_slug, and amount are required')
        return false
    end

    reason = reason or 'Balance set'

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
                INSERT INTO user_currencies (user_id, currency_id, amount)
                SELECT u.id, c.id, ?
                FROM users u, currencies c
                WHERE u.identifier = ? AND c.slug = ?
                ON DUPLICATE KEY UPDATE amount = VALUES(amount)
            ]],
            params = {amount, identifier, currencySlug}
        },
        {
            query = [[
                INSERT INTO currency_transactions (from_user_id, to_user_id, currency_id, amount, reason, metadata)
                SELECT NULL, u.id, c.id, ?, ?, ?
                FROM users u, currencies c
                WHERE u.identifier = ? AND c.slug = ?
            ]],
            params = {amount, reason, json.encode({action = 'set_balance'}), identifier, currencySlug}
        }
    }

    Database.Transaction(queries, function(success)
        if success then
            refreshUserBalanceCache(identifier)
            Log.Economy(identifier, 'SET_BALANCE', currencySlug, amount, {reason = reason})
        else
            Log.Error(string.format('Failed to set balance for %s: %s %s', identifier, amount, currencySlug))
        end
    end)

    return true
end

function Economy.AddMoney(identifier, currencySlug, amount, reason)
    if not identifier or not currencySlug or not amount then
        Log.Error('Economy.AddMoney: identifier, currency_slug, and amount are required')
        return false
    end

    if amount <= 0 then
        Log.Error('Economy.AddMoney: amount must be positive')
        return false
    end

    reason = reason or 'Money added'

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
                INSERT INTO user_currencies (user_id, currency_id, amount)
                SELECT u.id, c.id, c.default_amount + ?
                FROM users u, currencies c
                WHERE u.identifier = ? AND c.slug = ?
                ON DUPLICATE KEY UPDATE amount = amount + VALUES(amount)
            ]],
            params = {amount, identifier, currencySlug}
        },
        {
            query = [[
                INSERT INTO currency_transactions (from_user_id, to_user_id, currency_id, amount, reason, metadata)
                SELECT NULL, u.id, c.id, ?, ?, ?
                FROM users u, currencies c
                WHERE u.identifier = ? AND c.slug = ?
            ]],
            params = {amount, reason, json.encode({action = 'add_money'}), identifier, currencySlug}
        }
    }

    Database.Transaction(queries, function(success)
        if success then
            refreshUserBalanceCache(identifier)
            Log.Economy(identifier, 'ADD_MONEY', currencySlug, amount, {reason = reason})
        else
            Log.Error(string.format('Failed to add money for %s: %s %s', identifier, amount, currencySlug))
        end
    end)

    return true
end

function Economy.RemoveMoney(identifier, currencySlug, amount, reason)
    if not identifier or not currencySlug or not amount then
        Log.Error('Economy.RemoveMoney: identifier, currency_slug, and amount are required')
        return false
    end

    if amount <= 0 then
        Log.Error('Economy.RemoveMoney: amount must be positive')
        return false
    end

    reason = reason or 'Money removed'

    -- Check if user has enough money
    local currentBalance = Economy.GetBalance(identifier, currencySlug)
    if currentBalance < amount then
        Log.Warning(string.format('Insufficient funds for %s: %s (has: %s, needs: %s)', identifier, currencySlug, currentBalance, amount))
        return false
    end

    local queries = {
        {
            query = [[
                UPDATE user_currencies uc
                JOIN users u ON uc.user_id = u.id
                JOIN currencies c ON uc.currency_id = c.id
                SET uc.amount = uc.amount - ?
                WHERE u.identifier = ? AND c.slug = ?
            ]],
            params = {amount, identifier, currencySlug}
        },
        {
            query = [[
                INSERT INTO currency_transactions (from_user_id, to_user_id, currency_id, amount, reason, metadata)
                SELECT u.id, NULL, c.id, ?, ?, ?
                FROM users u, currencies c
                WHERE u.identifier = ? AND c.slug = ?
            ]],
            params = {amount, reason, json.encode({action = 'remove_money'}), identifier, currencySlug}
        }
    }

    Database.Transaction(queries, function(success)
        if success then
            refreshUserBalanceCache(identifier)
            Log.Economy(identifier, 'REMOVE_MONEY', currencySlug, amount, {reason = reason})
        else
            Log.Error(string.format('Failed to remove money for %s: %s %s', identifier, amount, currencySlug))
        end
    end)

    return true
end

function Economy.TransferMoney(fromIdentifier, toIdentifier, currencySlug, amount, reason)
    if not fromIdentifier or not toIdentifier or not currencySlug or not amount then
        Log.Error('Economy.TransferMoney: all parameters are required')
        return false
    end

    if amount <= 0 then
        Log.Error('Economy.TransferMoney: amount must be positive')
        return false
    end

    if fromIdentifier == toIdentifier then
        Log.Error('Economy.TransferMoney: cannot transfer to self')
        return false
    end

    reason = reason or 'Money transfer'

    -- Check if sender has enough money
    local senderBalance = Economy.GetBalance(fromIdentifier, currencySlug)
    if senderBalance < amount then
        Log.Warning(string.format('Insufficient funds for transfer from %s: %s (has: %s, needs: %s)', fromIdentifier, currencySlug, senderBalance, amount))
        return false
    end

    local queries = {
        {
            query = [[
                INSERT INTO users (identifier, name)
                VALUES (?, ?), (?, ?)
                ON DUPLICATE KEY UPDATE name = VALUES(name)
            ]],
            params = {
                fromIdentifier, GetPlayerName(GetPlayerFromServerId(fromIdentifier)) or 'Unknown',
                toIdentifier, GetPlayerName(GetPlayerFromServerId(toIdentifier)) or 'Unknown'
            }
        },
        {
            query = [[
                INSERT INTO user_currencies (user_id, currency_id, amount)
                SELECT u.id, c.id, c.default_amount
                FROM users u, currencies c
                WHERE u.identifier IN (?, ?) AND c.slug = ?
                ON DUPLICATE KEY UPDATE amount = amount
            ]],
            params = {fromIdentifier, toIdentifier, currencySlug}
        },
        {
            query = [[
                UPDATE user_currencies uc
                JOIN users u ON uc.user_id = u.id
                JOIN currencies c ON uc.currency_id = c.id
                SET uc.amount = uc.amount - ?
                WHERE u.identifier = ? AND c.slug = ?
            ]],
            params = {amount, fromIdentifier, currencySlug}
        },
        {
            query = [[
                UPDATE user_currencies uc
                JOIN users u ON uc.user_id = u.id
                JOIN currencies c ON uc.currency_id = c.id
                SET uc.amount = uc.amount + ?
                WHERE u.identifier = ? AND c.slug = ?
            ]],
            params = {amount, toIdentifier, currencySlug}
        },
        {
            query = [[
                INSERT INTO currency_transactions (from_user_id, to_user_id, currency_id, amount, reason, metadata)
                SELECT u1.id, u2.id, c.id, ?, ?, ?
                FROM users u1, users u2, currencies c
                WHERE u1.identifier = ? AND u2.identifier = ? AND c.slug = ?
            ]],
            params = {amount, reason, json.encode({action = 'transfer'}), fromIdentifier, toIdentifier, currencySlug}
        }
    }

    Database.Transaction(queries, function(success)
        if success then
            refreshUserBalanceCache(fromIdentifier)
            refreshUserBalanceCache(toIdentifier)
            Log.Economy(fromIdentifier, 'TRANSFER_OUT', currencySlug, amount, {to = toIdentifier, reason = reason})
            Log.Economy(toIdentifier, 'TRANSFER_IN', currencySlug, amount, {from = fromIdentifier, reason = reason})
        else
            Log.Error(string.format('Failed to transfer money from %s to %s: %s %s', fromIdentifier, toIdentifier, amount, currencySlug))
        end
    end)

    return true
end

-- Transaction history
function Economy.GetTransactionHistory(identifier, currencySlug, limit)
    if not identifier then
        Log.Error('Economy.GetTransactionHistory: identifier is required')
        return {}
    end

    limit = limit or 50

    local query = [[
        SELECT ct.*, c.slug as currency_slug, c.name as currency_name,
               u1.identifier as from_identifier, u1.name as from_name,
               u2.identifier as to_identifier, u2.name as to_name
        FROM currency_transactions ct
        JOIN currencies c ON ct.currency_id = c.id
        LEFT JOIN users u1 ON ct.from_user_id = u1.id
        LEFT JOIN users u2 ON ct.to_user_id = u2.id
        WHERE (u1.identifier = ? OR u2.identifier = ?)
    ]]

    local params = {identifier, identifier}

    if currencySlug then
        query = query .. ' AND c.slug = ?'
        table.insert(params, currencySlug)
    end

    query = query .. ' ORDER BY ct.created_at DESC LIMIT ?'
    table.insert(params, limit)

    local transactions = {}
    Database.Query(query, params, function(success, result)
        if success and result then
            transactions = result
        end
    end)

    return transactions
end

-- Initialize default currencies
function Economy.InitializeDefaultCurrencies()
    Economy.CreateCurrency('cash', 'Cash', 'Physical money', 1000.00)
    Economy.CreateCurrency('bank', 'Bank Account', 'Bank account balance', 5000.00)
    Economy.CreateCurrency('gold', 'Gold', 'Precious metal currency', 0.00)
end

return Economy
