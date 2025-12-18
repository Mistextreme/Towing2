-- ════════════════════════════════════════════════════════════════
-- SERVER SCRIPT - SYNCHRONIZATION & DATA PERSISTENCE
-- ════════════════════════════════════════════════════════════════

-- Global state storage
local vehicleAttachments = {} -- {[towVehicleNetId] = {targetVehicleNetId, timestamp}}
local vehicleRampStates = {} -- {[vehicleNetId] = {position, extended}}
local savedConfigurations = {} -- Stores dynamically saved configurations

-- ════════════════════════════════════════════════════════════════
-- DATABASE INITIALIZATION
-- ════════════════════════════════════════════════════════════════

CreateThread(function()
    -- Create table for saved configurations if using database
    if Config.Editor and Config.Editor.saveToDatabase then
        MySQL.Sync.execute([[
            CREATE TABLE IF NOT EXISTS flatbed_configurations (
                id INT AUTO_INCREMENT PRIMARY KEY,
                vehicle_model VARCHAR(50) UNIQUE NOT NULL,
                config_type ENUM('movable', 'static') NOT NULL,
                config_data TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            )
        ]])
        
        print('^2[Flatbed System]^7 Database table initialized')
        
        -- Load saved configurations
        LoadSavedConfigurations()
    end
end)

function LoadSavedConfigurations()
    MySQL.Async.fetchAll('SELECT * FROM flatbed_configurations', {}, function(results)
        if results then
            for _, row in ipairs(results) do
                savedConfigurations[row.vehicle_model] = {
                    type = row.config_type,
                    data = json.decode(row.config_data)
                }
            end
            print(string.format('^2[Flatbed System]^7 Loaded %d saved configurations', #results))
        end
    end)
end

-- ════════════════════════════════════════════════════════════════
-- ATTACHMENT SYNCHRONIZATION
-- ════════════════════════════════════════════════════════════════

RegisterNetEvent('flatbed:syncAttachment', function(towVehicleNetId, targetVehicleNetId, isAttached)
    local source = source
    
    if not towVehicleNetId or not targetVehicleNetId then
        print('^1[Flatbed System ERROR]^7 Invalid network IDs in syncAttachment')
        return
    end
    
    if isAttached then
        vehicleAttachments[towVehicleNetId] = {
            targetVehicle = targetVehicleNetId,
            timestamp = os.time(),
            owner = source
        }
        
        -- Broadcast to all clients except sender
        TriggerClientEvent('flatbed:syncAttachmentClient', -1, towVehicleNetId, targetVehicleNetId, true)
        
        if Config.Editor and Config.Editor.debugMode then
            print(string.format('^3[Flatbed System]^7 Vehicle %s attached to %s by player %s', 
                targetVehicleNetId, towVehicleNetId, source))
        end
    else
        vehicleAttachments[towVehicleNetId] = nil
        
        -- Broadcast to all clients except sender
        TriggerClientEvent('flatbed:syncAttachmentClient', -1, towVehicleNetId, targetVehicleNetId, false)
        
        if Config.Editor and Config.Editor.debugMode then
            print(string.format('^3[Flatbed System]^7 Vehicle %s detached from %s by player %s', 
                targetVehicleNetId, towVehicleNetId, source))
        end
    end
end)

-- ════════════════════════════════════════════════════════════════
-- RAMP STATE SYNCHRONIZATION
-- ════════════════════════════════════════════════════════════════

RegisterNetEvent('flatbed:syncRampState', function(vehicleNetId, position, extended)
    local source = source
    
    if not vehicleNetId then
        print('^1[Flatbed System ERROR]^7 Invalid network ID in syncRampState')
        return
    end
    
    vehicleRampStates[vehicleNetId] = {
        position = position,
        extended = extended,
        timestamp = os.time(),
        owner = source
    }
    
    -- Broadcast to all clients except sender
    TriggerClientEvent('flatbed:syncRampStateClient', -1, vehicleNetId, position, extended)
end)

-- ════════════════════════════════════════════════════════════════
-- CONFIGURATION SAVING (FROM EDITOR)
-- ════════════════════════════════════════════════════════════════

RegisterNetEvent('flatbed:saveVehicleConfig', function(configType, configData)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        print('^1[Flatbed System ERROR]^7 Player not found')
        return
    end
    
    -- Check if player has permission (optional - can add admin check here)
    local hasPermission = false
    for _, job in ipairs(Config.AllowedJobs) do
        if xPlayer.job.name == job then
            hasPermission = true
            break
        end
    end
    
    if not hasPermission then
        TriggerClientEvent('esx:showNotification', source, '~r~You do not have permission to save configurations')
        return
    end
    
    if not configData or not configData.vehicleName then
        print('^1[Flatbed System ERROR]^7 Invalid configuration data')
        return
    end
    
    local vehicleModel = configData.vehicleName:lower()
    
    -- Save to memory
    savedConfigurations[vehicleModel] = {
        type = configType,
        data = configData
    }
    
    print(string.format('^2[Flatbed System]^7 Configuration saved for vehicle: %s (Type: %s)', 
        vehicleModel, configType))
    
    -- Save to database if enabled
    if Config.Editor and Config.Editor.saveToDatabase then
        MySQL.Async.execute([[
            INSERT INTO flatbed_configurations (vehicle_model, config_type, config_data)
            VALUES (@model, @type, @data)
            ON DUPLICATE KEY UPDATE
                config_type = @type,
                config_data = @data,
                updated_at = CURRENT_TIMESTAMP
        ]], {
            ['@model'] = vehicleModel,
            ['@type'] = configType,
            ['@data'] = json.encode(configData)
        }, function(affectedRows)
            if affectedRows > 0 then
                print(string.format('^2[Flatbed System]^7 Configuration saved to database for: %s', vehicleModel))
            end
        end)
    end
    
    -- Save to file if enabled
    if Config.Editor and Config.Editor.saveToFile then
        SaveConfigurationToFile(vehicleModel, configType, configData)
    end
    
    -- Notify player
    TriggerClientEvent('esx:showNotification', source, 
        string.format('~g~Configuration saved for %s!~w~\nRestart the server to apply changes.', vehicleModel))
end)

function SaveConfigurationToFile(vehicleModel, configType, configData)
    local configString = GenerateConfigString(vehicleModel, configType, configData)
    local filename = string.format('flatbed_config_%s.txt', vehicleModel)
    
    SaveResourceFile(GetCurrentResourceName(), filename, configString, -1)
    
    print(string.format('^2[Flatbed System]^7 Configuration saved to file: %s', filename))
end

function GenerateConfigString(vehicleModel, configType, data)
    local configString = ''
    
    if configType == 'movable' then
        configString = string.format([[
-- Add this to Config.MovableRampVehicles in config.lua
['%s'] = {
    label = '%s',
    bone = '%s',
    minPosition = %.2f,
    maxPosition = %.2f,
    speed = %.3f,
    attachOffset = vector3(%.2f, %.2f, %.2f),
    winchPoint = vector3(%.2f, %.2f, %.2f)
},
]], 
            vehicleModel,
            data.vehicleLabel or vehicleModel,
            data.bone or 'chassis',
            data.minPosition or 0.1,
            data.maxPosition or 0.3,
            data.speed or 0.005,
            data.attachOffset.x, data.attachOffset.y, data.attachOffset.z,
            data.winchPoint.x, data.winchPoint.y, data.winchPoint.z
        )
    elseif configType == 'static' then
        configString = string.format([[
-- Add this to Config.StaticRampVehicles in config.lua
['%s'] = {
    label = '%s',
    bone = '%s',
    rampModel = '%s',
    rampOffset = vector3(%.2f, %.2f, %.2f),
    rampRotation = vector3(%.2f, %.2f, %.2f),
    attachOffset = vector3(%.2f, %.2f, %.2f),
    winchPoint = vector3(%.2f, %.2f, %.2f)
},
]], 
            vehicleModel,
            data.vehicleLabel or vehicleModel,
            data.bone or 'chassis',
            data.rampModel or 'imp_prop_flatbed_ramp',
            data.rampOffset.x, data.rampOffset.y, data.rampOffset.z,
            data.rampRotation.x, data.rampRotation.y, data.rampRotation.z,
            data.attachOffset.x, data.attachOffset.y, data.attachOffset.z,
            data.winchPoint.x, data.winchPoint.y, data.winchPoint.z
        )
    end
    
    return configString
end

-- ════════════════════════════════════════════════════════════════
-- CONFIGURATION REQUEST (Dynamic Loading)
-- ════════════════════════════════════════════════════════════════

RegisterNetEvent('flatbed:requestVehicleConfig', function(vehicleModel)
    local source = source
    
    if savedConfigurations[vehicleModel] then
        TriggerClientEvent('flatbed:receiveVehicleConfig', source, vehicleModel, savedConfigurations[vehicleModel])
    end
end)

ESX.RegisterServerCallback('flatbed:getVehicleConfig', function(source, cb, vehicleModel)
    cb(savedConfigurations[vehicleModel])
end)

-- ════════════════════════════════════════════════════════════════
-- PERMISSION CHECKS
-- ════════════════════════════════════════════════════════════════

ESX.RegisterServerCallback('flatbed:hasPermission', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb(false)
        return
    end
    
    for _, job in ipairs(Config.AllowedJobs) do
        if xPlayer.job.name == job then
            cb(true)
            return
        end
    end
    
    cb(false)
end)

-- ════════════════════════════════════════════════════════════════
-- CLEANUP & MAINTENANCE
-- ════════════════════════════════════════════════════════════════

-- Clean up old attachment data
CreateThread(function()
    while true do
        Wait(300000) -- Every 5 minutes
        
        local currentTime = os.time()
        local cleanupCount = 0
        
        for netId, data in pairs(vehicleAttachments) do
            -- Remove attachments older than 30 minutes (likely vehicle despawned)
            if currentTime - data.timestamp > 1800 then
                vehicleAttachments[netId] = nil
                cleanupCount = cleanupCount + 1
            end
        end
        
        for netId, data in pairs(vehicleRampStates) do
            -- Remove ramp states older than 30 minutes
            if currentTime - data.timestamp > 1800 then
                vehicleRampStates[netId] = nil
            end
        end
        
        if cleanupCount > 0 then
            print(string.format('^3[Flatbed System]^7 Cleaned up %d old attachment records', cleanupCount))
        end
    end
end)

-- ════════════════════════════════════════════════════════════════
-- ADMIN COMMANDS (Optional)
-- ════════════════════════════════════════════════════════════════

RegisterCommand('flatbed_reset', function(source, args, rawCommand)
    if source == 0 then -- Console only
        vehicleAttachments = {}
        vehicleRampStates = {}
        print('^2[Flatbed System]^7 All attachment and ramp states have been reset')
    else
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer and xPlayer.getGroup() == 'admin' then
            vehicleAttachments = {}
            vehicleRampStates = {}
            TriggerClientEvent('esx:showNotification', source, '~g~Flatbed system reset successfully')
        end
    end
end, true)

RegisterCommand('flatbed_stats', function(source, args, rawCommand)
    if source == 0 then -- Console only
        print('═══════════════════════════════════════')
        print('FLATBED SYSTEM STATISTICS')
        print('═══════════════════════════════════════')
        print('Active Attachments: ' .. GetTableCount(vehicleAttachments))
        print('Active Ramp States: ' .. GetTableCount(vehicleRampStates))
        print('Saved Configurations: ' .. GetTableCount(savedConfigurations))
        print('═══════════════════════════════════════')
    else
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer and xPlayer.getGroup() == 'admin' then
            TriggerClientEvent('chat:addMessage', source, {
                color = {85, 170, 255},
                multiline = true,
                args = {'Flatbed Stats', string.format(
                    'Attachments: %d | Ramp States: %d | Configs: %d',
                    GetTableCount(vehicleAttachments),
                    GetTableCount(vehicleRampStates),
                    GetTableCount(savedConfigurations)
                )}
            })
        end
    end
end, true)

function GetTableCount(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

-- ════════════════════════════════════════════════════════════════
-- RESOURCE STOP HANDLER
-- ════════════════════════════════════════════════════════════════

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    print('^3[Flatbed System]^7 Server shutting down, saving data...')
    
    -- Could save current states to database here if needed
    
    print('^2[Flatbed System]^7 Server shutdown complete')
end)

-- ════════════════════════════════════════════════════════════════
-- SERVER INITIALIZATION
-- ════════════════════════════════════════════════════════════════

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    print('═══════════════════════════════════════')
    print('^2[Flatbed System]^7 Server starting...')
    print('Version: 2.0.0')
    print('Framework: ESX-Legacy')
    print('═══════════════════════════════════════')
    
    Wait(1000)
    
    print('^2[Flatbed System]^7 Server initialized successfully')
end)

print('^2[Flatbed System]^7 Server script loaded')