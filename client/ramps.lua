-- ════════════════════════════════════════════════════════════════
-- RAMP SYSTEM - MOVABLE & STATIC RAMPS
-- ════════════════════════════════════════════════════════════════

Ramps = {
    movableRamps = {}, -- Stores state for movable ramps {[vehicle] = {position, extended, frozen}}
    staticRamps = {}   -- Stores deployed static ramps {[vehicle] = rampEntity}
}

-- ════════════════════════════════════════════════════════════════
-- MOVABLE RAMP SYSTEM (Bulldozer Arm Mechanics)
-- ════════════════════════════════════════════════════════════════

function Ramps:InitializeMovableRamp(vehicle)
    if not DoesEntityExist(vehicle) then return end
    if self.movableRamps[vehicle] then return end
    
    local config = Utils.GetVehicleConfig(vehicle)
    if not config then return end
    
    self.movableRamps[vehicle] = {
        position = config.minPosition,
        extended = false,
        frozen = false,
        config = config
    }
    
    SetVehicleBulldozerArmPosition(vehicle, config.minPosition, false)
end

function Ramps:UpdateMovableRamp(vehicle, direction)
    if not DoesEntityExist(vehicle) then return end
    if not self.movableRamps[vehicle] then
        self:InitializeMovableRamp(vehicle)
    end
    
    local rampData = self.movableRamps[vehicle]
    local config = rampData.config
    
    if direction == 'raise' then
        if rampData.position < config.maxPosition then
            rampData.position = math.min(rampData.position + config.speed, config.maxPosition)
            rampData.extended = rampData.position >= config.maxPosition
            Utils.PlayHydraulicSound(vehicle, 'down')
            SetVehicleBulldozerArmPosition(vehicle, rampData.position, false)
            
            -- Freeze vehicle when fully extended
            if rampData.extended and Config.Visual.freezeVehicleWhenExtended then
                FreezeEntityPosition(vehicle, true)
                rampData.frozen = true
            end
        end
    elseif direction == 'lower' then
        if rampData.position > config.minPosition then
            rampData.position = math.max(rampData.position - config.speed, config.minPosition)
            rampData.extended = false
            Utils.PlayHydraulicSound(vehicle, 'up')
            SetVehicleBulldozerArmPosition(vehicle, rampData.position, false)
            
            -- Unfreeze vehicle when retracting
            if rampData.frozen then
                FreezeEntityPosition(vehicle, false)
                rampData.frozen = false
            end
        end
    end
    
    return rampData.position, rampData.extended
end

function Ramps:IsMovableRampExtended(vehicle)
    if not self.movableRamps[vehicle] then return false end
    return self.movableRamps[vehicle].extended
end

function Ramps:GetMovableRampPosition(vehicle)
    if not self.movableRamps[vehicle] then return 0 end
    return self.movableRamps[vehicle].position
end

function Ramps:CleanupMovableRamp(vehicle)
    if self.movableRamps[vehicle] then
        if self.movableRamps[vehicle].frozen then
            FreezeEntityPosition(vehicle, false)
        end
        self.movableRamps[vehicle] = nil
    end
end

-- ════════════════════════════════════════════════════════════════
-- STATIC RAMP SYSTEM (Deploy/Remove Objects)
-- ════════════════════════════════════════════════════════════════

function Ramps:DeployStaticRamp(vehicle)
    if not DoesEntityExist(vehicle) then return false end
    if self.staticRamps[vehicle] then
        Utils.Notify('Ramp already deployed!', 'error')
        return false
    end
    
    local config = Utils.GetVehicleConfig(vehicle)
    if not config or not config.rampModel then return false end
    
    local model = GetHashKey(config.rampModel)
    RequestModel(model)
    
    local timeout = 0
    while not HasModelLoaded(model) and timeout < 5000 do
        Wait(100)
        timeout = timeout + 100
    end
    
    if not HasModelLoaded(model) then
        Utils.Notify('Failed to load ramp model!', 'error')
        return false
    end
    
    -- Calculate world position from offset
    local rampCoords = Utils.GetWorldCoordsFromOffset(vehicle, config.rampOffset)
    
    -- Create ramp object
    local ramp = CreateObject(model, rampCoords.x, rampCoords.y, rampCoords.z, true, false, false)
    
    if not DoesEntityExist(ramp) then
        Utils.Notify('Failed to create ramp!', 'error')
        return false
    end
    
    -- Attach ramp to vehicle
    local boneIndex = GetEntityBoneIndexByName(vehicle, config.bone)
    AttachEntityToEntity(
        ramp, vehicle, boneIndex,
        config.rampOffset.x, config.rampOffset.y, config.rampOffset.z,
        config.rampRotation.x, config.rampRotation.y, config.rampRotation.z,
        false, false, true, false, 0, true
    )
    
    self.staticRamps[vehicle] = ramp
    
    SetModelAsNoLongerNeeded(model)
    Utils.Notify(Config.Notifications.rampDeployed.message, 'success')
    
    return true
end

function Ramps:RemoveStaticRamp(vehicle)
    if not self.staticRamps[vehicle] then
        -- Try to find nearby ramp
        local playerCoords = GetEntityCoords(PlayerPedId())
        local config = Utils.GetVehicleConfig(vehicle)
        
        if config and config.rampModel then
            local rampHash = GetHashKey(config.rampModel)
            local ramp = GetClosestObjectOfType(
                playerCoords.x, playerCoords.y, playerCoords.z,
                10.0, rampHash, false, false, false
            )
            
            if DoesEntityExist(ramp) then
                DeleteEntity(ramp)
                Utils.Notify(Config.Notifications.rampRemoved.message, 'success')
                return true
            end
        end
        
        Utils.Notify('No ramp found nearby!', 'error')
        return false
    end
    
    local ramp = self.staticRamps[vehicle]
    
    if DoesEntityExist(ramp) then
        DeleteEntity(ramp)
        self.staticRamps[vehicle] = nil
        Utils.Notify(Config.Notifications.rampRemoved.message, 'success')
        return true
    end
    
    self.staticRamps[vehicle] = nil
    return false
end

function Ramps:IsStaticRampDeployed(vehicle)
    if not self.staticRamps[vehicle] then return false end
    return DoesEntityExist(self.staticRamps[vehicle])
end

function Ramps:CleanupStaticRamp(vehicle)
    if self.staticRamps[vehicle] then
        if DoesEntityExist(self.staticRamps[vehicle]) then
            DeleteEntity(self.staticRamps[vehicle])
        end
        self.staticRamps[vehicle] = nil
    end
end

-- ════════════════════════════════════════════════════════════════
-- CONTROL THREADS
-- ════════════════════════════════════════════════════════════════

CreateThread(function()
    while true do
        local sleep = 500
        local ped = PlayerPedId()
        
        if IsPedInAnyVehicle(ped, false) then
            local vehicle = GetVehiclePedIsIn(ped, false)
            
            if GetPedInVehicleSeat(vehicle, -1) == ped then -- Driver seat
                if Utils.IsMovableRampVehicle(vehicle) then
                    sleep = 0
                    
                    -- Initialize if not already done
                    if not Ramps.movableRamps[vehicle] then
                        Ramps:InitializeMovableRamp(vehicle)
                    end
                    
                    local rampData = Ramps.movableRamps[vehicle]
                    local config = rampData.config
                    
                    -- Display controls
                    if Config.Visual.use3DText then
                        local controlCoords = Utils.GetWorldCoordsFromOffset(vehicle, config.winchPoint)
                        Utils.DrawText3D(controlCoords, 
                            string.format(
                                '[NUM 8] Raise Bed (%.0f%%) | [NUM 5] Lower Bed',
                                (rampData.position / config.maxPosition) * 100
                            )
                        )
                    else
                        Utils.ShowHelpText(
                            '[~y~NUM 8~w~] Raise Bed | [~y~NUM 5~w~] Lower Bed\n' ..
                            string.format('Position: %.0f%%', (rampData.position / config.maxPosition) * 100)
                        )
                    end
                    
                    -- Handle controls
                    if IsControlPressed(0, Config.Keys.RaiseBed) or IsControlPressed(0, Config.Keys.AlternativeRaise) then
                        Ramps:UpdateMovableRamp(vehicle, 'raise')
                    end
                    
                    if IsControlPressed(0, Config.Keys.LowerBed) or IsControlPressed(0, Config.Keys.AlternativeLower) then
                        Ramps:UpdateMovableRamp(vehicle, 'lower')
                    end
                    
                    Wait(Config.Visual.playHydraulicSounds and 20 or 0)
                end
            end
        end
        
        Wait(sleep)
    end
end)

-- Out of vehicle controls for movable ramps
CreateThread(function()
    while true do
        local sleep = 500
        local ped = PlayerPedId()
        
        if not IsPedInAnyVehicle(ped, false) then
            -- Find nearby movable ramp vehicle
            local coords = GetEntityCoords(ped)
            local vehicle, distance = Utils.GetClosestVehicle(coords, 10.0)
            
            if vehicle and Utils.IsMovableRampVehicle(vehicle) then
                local config = Utils.GetVehicleConfig(vehicle)
                if config then
                    local controlCoords = Utils.GetWorldCoordsFromOffset(vehicle, config.winchPoint)
                    local distToControl = #(coords - controlCoords)
                    
                    if distToControl < 3.0 then
                        sleep = 0
                        
                        -- Initialize if not already done
                        if not Ramps.movableRamps[vehicle] then
                            Ramps:InitializeMovableRamp(vehicle)
                        end
                        
                        local rampData = Ramps.movableRamps[vehicle]
                        
                        -- Display controls
                        if Config.Visual.use3DText then
                            Utils.DrawText3D(controlCoords, 
                                string.format(
                                    '[NUM 8] Raise Bed (%.0f%%) | [NUM 5] Lower Bed',
                                    (rampData.position / config.maxPosition) * 100
                                )
                            )
                        end
                        
                        -- Handle controls
                        if IsControlPressed(0, Config.Keys.RaiseBed) then
                            Ramps:UpdateMovableRamp(vehicle, 'raise')
                        end
                        
                        if IsControlPressed(0, Config.Keys.LowerBed) then
                            Ramps:UpdateMovableRamp(vehicle, 'lower')
                        end
                        
                        Wait(Config.Visual.playHydraulicSounds and 20 or 0)
                    end
                end
            end
        end
        
        Wait(sleep)
    end
end)

-- Static ramp deploy/remove command
RegisterCommand('deployramp', function()
    if not Utils.HasJob() then
        Utils.Notify(Config.Notifications.noPermission.message, 'error')
        return
    end
    
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    
    if vehicle == 0 then
        Utils.Notify(Config.Notifications.notInVehicle.message, 'error')
        return
    end
    
    if not Utils.IsStaticRampVehicle(vehicle) then
        Utils.Notify(Config.Notifications.wrongVehicle.message, 'error')
        return
    end
    
    if Ramps:IsStaticRampDeployed(vehicle) then
        Ramps:RemoveStaticRamp(vehicle)
    else
        Ramps:DeployStaticRamp(vehicle)
    end
end, false)

-- Cleanup on vehicle deletion
CreateThread(function()
    while true do
        Wait(5000)
        
        -- Clean up movable ramps
        for vehicle, _ in pairs(Ramps.movableRamps) do
            if not DoesEntityExist(vehicle) then
                Ramps:CleanupMovableRamp(vehicle)
            end
        end
        
        -- Clean up static ramps
        for vehicle, _ in pairs(Ramps.staticRamps) do
            if not DoesEntityExist(vehicle) then
                Ramps:CleanupStaticRamp(vehicle)
            end
        end
    end
end)