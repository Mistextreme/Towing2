-- ════════════════════════════════════════════════════════════════
-- MAIN CLIENT SCRIPT - INITIALIZATION & COORDINATION
-- ════════════════════════════════════════════════════════════════

-- Global state
local isReady = false

-- ════════════════════════════════════════════════════════════════
-- INITIALIZATION
-- ════════════════════════════════════════════════════════════════

CreateThread(function()
    while not ESX.IsPlayerLoaded() do
        Wait(100)
    end
    
    isReady = true
    print('^2[Flatbed System]^7 Client initialized successfully')
end)

-- ════════════════════════════════════════════════════════════════
-- RESOURCE CLEANUP
-- ════════════════════════════════════════════════════════════════

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    print('^3[Flatbed System]^7 Cleaning up resources...')
    
    -- Clean up all movable ramps
    for vehicle, _ in pairs(Ramps.movableRamps) do
        if DoesEntityExist(vehicle) then
            if Ramps.movableRamps[vehicle].frozen then
                FreezeEntityPosition(vehicle, false)
            end
        end
    end
    
    -- Clean up all static ramps
    for vehicle, ramp in pairs(Ramps.staticRamps) do
        if DoesEntityExist(ramp) then
            DeleteEntity(ramp)
        end
    end
    
    -- Clean up winch rope
    if Winch.rope then
        DeleteRope(Winch.rope)
    end
    
    -- Clean up editor spawned entities
    if Editor.spawnedRamp and DoesEntityExist(Editor.spawnedRamp) then
        DeleteEntity(Editor.spawnedRamp)
    end
    
    print('^2[Flatbed System]^7 Cleanup complete')
end)

-- ════════════════════════════════════════════════════════════════
-- PLAYER RESPAWN HANDLER
-- ════════════════════════════════════════════════════════════════

AddEventHandler('esx:onPlayerDeath', function()
    -- Release winch cable if carrying
    if Winch.carryingCable then
        Winch:ReleaseCable()
    end
end)

AddEventHandler('esx:onPlayerSpawn', function()
    -- Nothing specific needed on spawn
end)

-- ════════════════════════════════════════════════════════════════
-- JOB CHANGE HANDLER
-- ════════════════════════════════════════════════════════════════

RegisterNetEvent('esx:setJob', function(job)
    -- Update job data
    ESX.PlayerData.job = job
end)

-- ════════════════════════════════════════════════════════════════
-- DEBUG COMMANDS (Remove in production if needed)
-- ════════════════════════════════════════════════════════════════

if Config.Editor and Config.Editor.debugMode then
    RegisterCommand('flatbed_debug', function()
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        
        if vehicle ~= 0 then
            local model = GetEntityModel(vehicle)
            local displayName = GetDisplayNameFromVehicleModel(model):lower()
            local config = Utils.GetVehicleConfig(vehicle)
            
            print('═══════════════════════════════════════')
            print('FLATBED SYSTEM DEBUG')
            print('═══════════════════════════════════════')
            print('Vehicle Model: ' .. displayName)
            print('Is Movable Ramp: ' .. tostring(Utils.IsMovableRampVehicle(vehicle)))
            print('Is Static Ramp: ' .. tostring(Utils.IsStaticRampVehicle(vehicle)))
            
            if config then
                print('Configuration Found:')
                print('  Bone: ' .. tostring(config.bone))
                if config.winchPoint then
                    print('  Winch Point: ' .. Utils.FormatVector3(config.winchPoint))
                end
                if config.attachOffset then
                    print('  Attach Offset: ' .. Utils.FormatVector3(config.attachOffset))
                end
            else
                print('No configuration found!')
            end
            
            if Utils.IsMovableRampVehicle(vehicle) then
                local rampData = Ramps.movableRamps[vehicle]
                if rampData then
                    print('Ramp State:')
                    print('  Position: ' .. string.format('%.3f', rampData.position))
                    print('  Extended: ' .. tostring(rampData.extended))
                    print('  Frozen: ' .. tostring(rampData.frozen))
                end
            end
            
            if Attach.attachedVehicles[vehicle] then
                print('Attached Vehicle: ' .. tostring(Attach.attachedVehicles[vehicle].vehicle))
            end
            
            print('═══════════════════════════════════════')
        else
            print('[Flatbed System] You must be in a vehicle to use debug command')
        end
    end, false)
    
    RegisterCommand('flatbed_list_vehicles', function()
        print('═══════════════════════════════════════')
        print('CONFIGURED VEHICLES')
        print('═══════════════════════════════════════')
        print('MOVABLE RAMP VEHICLES:')
        for model, config in pairs(Config.MovableRampVehicles) do
            print('  - ' .. model .. ' (' .. config.label .. ')')
        end
        print('\nSTATIC RAMP VEHICLES:')
        for model, config in pairs(Config.StaticRampVehicles) do
            print('  - ' .. model .. ' (' .. config.label .. ')')
        end
        print('═══════════════════════════════════════')
    end, false)
end

-- ════════════════════════════════════════════════════════════════
-- HELPFUL NOTIFICATIONS ON FIRST USE
-- ════════════════════════════════════════════════════════════════

local hasShownTutorial = false

CreateThread(function()
    while not isReady do
        Wait(1000)
    end
    
    Wait(5000) -- Wait 5 seconds after player loads
    
    if not hasShownTutorial and Utils.HasJob() then
        hasShownTutorial = true
        
        ESX.ShowNotification('~b~Flatbed System~w~\nYou have access to the flatbed system.\nPress ~y~F11~w~ to open the editor for vehicle configuration.', 'info', 10000)
        
        Wait(2000)
        
        ESX.ShowNotification('~b~Quick Guide~w~\n~y~NUM 8/5~w~ - Raise/Lower bed\n~y~NUM 4~w~ - Take winch cable\n~y~E~w~ - Attach/Detach vehicle\n~y~/deployramp~w~ - Deploy static ramp', 'info', 10000)
    end
end)

-- ════════════════════════════════════════════════════════════════
-- PERFORMANCE MONITORING (Optional)
-- ════════════════════════════════════════════════════════════════

if Config.Editor and Config.Editor.performanceMonitoring then
    local lastReportTime = GetGameTimer()
    
    CreateThread(function()
        while true do
            Wait(60000) -- Every minute
            
            local currentTime = GetGameTimer()
            if currentTime - lastReportTime >= 60000 then
                lastReportTime = currentTime
                
                local stats = {
                    movableRamps = Utils.TableCount(Ramps.movableRamps),
                    staticRamps = Utils.TableCount(Ramps.staticRamps),
                    attachedVehicles = Utils.TableCount(Attach.attachedVehicles),
                    winchActive = Winch.carryingCable,
                    editorActive = Editor.active
                }
                
                print(string.format(
                    '^3[Flatbed System Performance]^7 Movable: %d | Static: %d | Attached: %d | Winch: %s | Editor: %s',
                    stats.movableRamps,
                    stats.staticRamps,
                    stats.attachedVehicles,
                    tostring(stats.winchActive),
                    tostring(stats.editorActive)
                ))
            end
        end
    end)
end

-- ════════════════════════════════════════════════════════════════
-- COMPATIBILITY CHECK
-- ════════════════════════════════════════════════════════════════

CreateThread(function()
    Wait(2000)
    
    -- Check for required exports
    local requiredExports = {'es_extended'}
    local missingExports = {}
    
    for _, export in ipairs(requiredExports) do
        if not GetResourceState(export) or GetResourceState(export) ~= 'started' then
            table.insert(missingExports, export)
        end
    end
    
    if #missingExports > 0 then
        print('^1[Flatbed System ERROR]^7 Missing required resources:')
        for _, resource in ipairs(missingExports) do
            print('  - ' .. resource)
        end
        print('^1Please ensure all dependencies are installed and started!^7')
    else
        print('^2[Flatbed System]^7 All dependencies loaded successfully')
    end
end)

-- ════════════════════════════════════════════════════════════════
-- EXPORTS FOR OTHER RESOURCES
-- ════════════════════════════════════════════════════════════════

exports('IsMovableRampVehicle', function(vehicle)
    return Utils.IsMovableRampVehicle(vehicle)
end)

exports('IsStaticRampVehicle', function(vehicle)
    return Utils.IsStaticRampVehicle(vehicle)
end)

exports('GetVehicleConfig', function(vehicle)
    return Utils.GetVehicleConfig(vehicle)
end)

exports('IsRampExtended', function(vehicle)
    return Ramps:IsMovableRampExtended(vehicle)
end)

exports('IsRampDeployed', function(vehicle)
    return Ramps:IsStaticRampDeployed(vehicle)
end)

exports('IsVehicleAttached', function(vehicle)
    return IsEntityAttached(vehicle)
end)

exports('AttachVehicle', function(towVehicle, targetVehicle)
    return Attach:AttachVehicle(towVehicle, targetVehicle)
end)

exports('DetachVehicle', function(vehicle)
    return Attach:DetachVehicle(vehicle)
end)

-- ════════════════════════════════════════════════════════════════
-- END OF CLIENT MAIN
-- ════════════════════════════════════════════════════════════════

print('^2[Flatbed System]^7 Main client script loaded')