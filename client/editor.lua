-- ════════════════════════════════════════════════════════════════
-- EDITOR MODE - DYNAMIC CONFIGURATION SYSTEM
-- ════════════════════════════════════════════════════════════════

Editor = {
    active = false,
    mode = nil, -- 'movable_ramp', 'static_ramp', 'winch_point'
    selectedVehicle = nil,
    selectedRamp = nil,
    spawnedRamp = nil,
    data = {}
}

-- ════════════════════════════════════════════════════════════════
-- MAIN EDITOR FUNCTIONS
-- ════════════════════════════════════════════════════════════════

function Editor:Toggle()
    self.active = not self.active
    
    if self.active then
        self:Enable()
    else
        self:Disable()
    end
end

function Editor:Enable()
    self.active = true
    self.mode = nil
    self.selectedVehicle = nil
    self.selectedRamp = nil
    self.data = {}
    
    Utils.Notify(Config.Notifications.editorEnabled.message, 'info')
    
    CreateThread(function()
        self:MainLoop()
    end)
end

function Editor:Disable()
    self.active = false
    
    -- Clean up spawned ramp
    if self.spawnedRamp and DoesEntityExist(self.spawnedRamp) then
        DeleteEntity(self.spawnedRamp)
        self.spawnedRamp = nil
    end
    
    self.mode = nil
    self.selectedVehicle = nil
    self.selectedRamp = nil
    self.data = {}
    
    Utils.Notify(Config.Notifications.editorDisabled.message, 'info')
end

function Editor:MainLoop()
    while self.active do
        local sleep = 0
        local ped = PlayerPedId()
        local hit, coords, entity = Utils.RaycastCamera(Config.Editor.raycastDistance)
        local plyCoords = GetEntityCoords(ped)
        
        -- Draw raycast line and sphere
        if hit then
            Utils.DrawLine3D(plyCoords, coords, 
                Config.Editor.lineColor.r, 
                Config.Editor.lineColor.g, 
                Config.Editor.lineColor.b, 
                Config.Editor.lineColor.a
            )
            Utils.DrawSphere3D(coords, Config.Editor.sphereSize, 0, 255, 0, 200)
        end
        
        -- Display instructions based on mode
        self:DisplayInstructions()
        
        -- Handle mode-specific logic
        if not self.mode then
            self:HandleModeSelection()
        elseif self.mode == 'movable_ramp' then
            self:HandleMovableRampConfig(hit, coords, entity)
        elseif self.mode == 'static_ramp' then
            self:HandleStaticRampConfig(hit, coords, entity)
        elseif self.mode == 'winch_point' then
            self:HandleWinchPointConfig(hit, coords, entity)
        end
        
        -- Cancel editor
        if IsControlJustPressed(0, Config.Keys.CancelEditor) then
            self:Disable()
        end
        
        Wait(sleep)
    end
end

-- ════════════════════════════════════════════════════════════════
-- MODE SELECTION
-- ════════════════════════════════════════════════════════════════

function Editor:HandleModeSelection()
    Utils.ShowHelpText(
        '~b~Editor Mode~w~\n' ..
        'Press ~g~1~w~ - Configure Movable Ramp Vehicle\n' ..
        'Press ~g~2~w~ - Configure Static Ramp Vehicle\n' ..
        'Press ~g~3~w~ - Configure Winch Point\n' ..
        'Press ~r~BACKSPACE~w~ - Exit Editor'
    )
    
    if IsControlJustPressed(0, 157) then -- NUM 1
        self.mode = 'movable_ramp'
        Utils.Notify('Mode: Movable Ramp Configuration', 'info')
    elseif IsControlJustPressed(0, 158) then -- NUM 2
        self.mode = 'static_ramp'
        Utils.Notify('Mode: Static Ramp Configuration', 'info')
    elseif IsControlJustPressed(0, 160) then -- NUM 3
        self.mode = 'winch_point'
        Utils.Notify('Mode: Winch Point Configuration', 'info')
    end
end

-- ════════════════════════════════════════════════════════════════
-- MOVABLE RAMP CONFIGURATION
-- ════════════════════════════════════════════════════════════════

function Editor:HandleMovableRampConfig(hit, coords, entity)
    if not self.selectedVehicle then
        -- Step 1: Select vehicle
        Utils.ShowHelpText(
            '~y~Movable Ramp Config~w~\n' ..
            'Aim at a vehicle and press ~g~E~w~ to select it\n' ..
            'Press ~r~BACKSPACE~w~ - Cancel'
        )
        
        if hit and entity and IsEntityAVehicle(entity) then
            -- Highlight vehicle
            local vehCoords = GetEntityCoords(entity)
            Utils.DrawMarker3D(vehCoords + vector3(0, 0, 1.0), 0, 
                Config.Editor.markerSize, 
                Config.Editor.markerColor.r,
                Config.Editor.markerColor.g,
                Config.Editor.markerColor.b,
                Config.Editor.markerColor.a
            )
            
            if IsControlJustPressed(0, Config.Keys.SelectEntity) then
                self:SelectMovableRampVehicle(entity)
            end
        end
    else
        -- Step 2: Get attachment offset
        Utils.ShowHelpText(
            '~y~Movable Ramp Config~w~\n' ..
            'Vehicle Selected: ' .. GetDisplayNameFromVehicleModel(GetEntityModel(self.selectedVehicle)) .. '\n' ..
            'Aim at the bed attachment point and press ~g~E~w~\n' ..
            'Press ~r~BACKSPACE~w~ - Cancel'
        )
        
        -- Draw vehicle marker
        local vehCoords = GetEntityCoords(self.selectedVehicle)
        Utils.DrawMarker3D(vehCoords + vector3(0, 0, 1.0), 0, 
            Config.Editor.markerSize, 255, 255, 0, 200)
        
        if hit and IsControlJustPressed(0, Config.Keys.SelectEntity) then
            self:CalculateMovableRampOffsets(coords)
        end
    end
end

function Editor:SelectMovableRampVehicle(vehicle)
    self.selectedVehicle = vehicle
    local model = GetEntityModel(vehicle)
    local displayName = GetDisplayNameFromVehicleModel(model):lower()
    
    self.data = {
        vehicleName = displayName,
        vehicleLabel = GetLabelText(displayName),
        bone = 'chassis',
        minPosition = 0.1,
        maxPosition = 0.3,
        speed = 0.005
    }
    
    Utils.Notify('Vehicle selected: ' .. displayName, 'success')
end

function Editor:CalculateMovableRampOffsets(targetCoords)
    local offset = Utils.GetOffsetBetweenEntities(self.selectedVehicle, targetCoords)
    self.data.attachOffset = offset
    
    -- Calculate winch point (slightly behind attachment point)
    self.data.winchPoint = vector3(offset.x - 1.2, offset.y - 2.5, offset.z)
    
    -- Format and save
    self:SaveMovableRampConfig()
end

function Editor:SaveMovableRampConfig()
    local configString = string.format([[
['%s'] = {
    label = '%s',
    bone = '%s',
    minPosition = %.2f,
    maxPosition = %.2f,
    speed = %.3f,
    attachOffset = vec3(%.2f, %.2f, %.2f),
    winchPoint = vec3(%.2f, %.2f, %.2f)
}]],
        self.data.vehicleName,
        self.data.vehicleLabel,
        self.data.bone,
        self.data.minPosition,
        self.data.maxPosition,
        self.data.speed,
        self.data.attachOffset.x, self.data.attachOffset.y, self.data.attachOffset.z,
        self.data.winchPoint.x, self.data.winchPoint.y, self.data.winchPoint.z
    )
    
    Utils.CopyToClipboard(configString)
    Utils.Notify('Configuration copied to clipboard! Paste it in Config.MovableRampVehicles', 'success')
    
    -- Send to server for saving
    TriggerServerEvent('flatbed:saveVehicleConfig', 'movable', self.data)
    
    -- Reset for next configuration
    self.selectedVehicle = nil
    self.data = {}
end

-- ════════════════════════════════════════════════════════════════
-- STATIC RAMP CONFIGURATION
-- ════════════════════════════════════════════════════════════════

function Editor:HandleStaticRampConfig(hit, coords, entity)
    if not self.selectedVehicle then
        -- Step 1: Select vehicle
        Utils.ShowHelpText(
            '~y~Static Ramp Config~w~\n' ..
            'Aim at a vehicle and press ~g~E~w~ to select it\n' ..
            'Press ~r~BACKSPACE~w~ - Cancel'
        )
        
        if hit and entity and IsEntityAVehicle(entity) then
            local vehCoords = GetEntityCoords(entity)
            Utils.DrawMarker3D(vehCoords + vector3(0, 0, 1.0), 0, 
                Config.Editor.markerSize, 
                Config.Editor.markerColor.r,
                Config.Editor.markerColor.g,
                Config.Editor.markerColor.b,
                Config.Editor.markerColor.a
            )
            
            if IsControlJustPressed(0, Config.Keys.SelectEntity) then
                self:SelectStaticRampVehicle(entity)
            end
        end
    elseif not self.spawnedRamp then
        -- Step 2: Spawn ramp
        Utils.ShowHelpText(
            '~y~Static Ramp Config~w~\n' ..
            'Vehicle Selected: ' .. GetDisplayNameFromVehicleModel(GetEntityModel(self.selectedVehicle)) .. '\n' ..
            'Press ~g~G~w~ to spawn a ramp object\n' ..
            'Press ~r~BACKSPACE~w~ - Cancel'
        )
        
        if IsControlJustPressed(0, Config.Keys.SpawnRamp) then
            self:SpawnRampObject()
        end
    elseif not self.selectedRamp then
        -- Step 3: Position ramp (manual positioning by player)
        Utils.ShowHelpText(
            '~y~Static Ramp Config~w~\n' ..
            'Position the ramp manually, then aim at it and press ~g~E~w~ to select\n' ..
            'Press ~r~BACKSPACE~w~ - Cancel'
        )
        
        if hit and entity == self.spawnedRamp then
            local rampCoords = GetEntityCoords(self.spawnedRamp)
            Utils.DrawMarker3D(rampCoords, 0, Config.Editor.markerSize, 0, 255, 0, 200)
            
            if IsControlJustPressed(0, Config.Keys.SelectEntity) then
                self:SelectRampPosition()
            end
        end
    else
        -- Step 4: Select attachment point
        Utils.ShowHelpText(
            '~y~Static Ramp Config~w~\n' ..
            'Aim at the vehicle bed attachment point and press ~g~E~w~\n' ..
            'Press ~r~BACKSPACE~w~ - Cancel'
        )
        
        if hit and IsControlJustPressed(0, Config.Keys.SelectEntity) then
            self:CalculateStaticRampOffsets(coords)
        end
    end
end

function Editor:SelectStaticRampVehicle(vehicle)
    self.selectedVehicle = vehicle
    local model = GetEntityModel(vehicle)
    local displayName = GetDisplayNameFromVehicleModel(model):lower()
    
    self.data = {
        vehicleName = displayName,
        vehicleLabel = GetLabelText(displayName),
        bone = 'chassis',
        rampModel = 'imp_prop_flatbed_ramp'
    }
    
    Utils.Notify('Vehicle selected: ' .. displayName .. '. Now spawn a ramp.', 'success')
end

function Editor:SpawnRampObject()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local model = GetHashKey(self.data.rampModel)
    
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(100)
    end
    
    local spawnCoords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 3.0, 0.0)
    self.spawnedRamp = CreateObject(model, spawnCoords.x, spawnCoords.y, spawnCoords.z, true, false, false)
    SetEntityHeading(self.spawnedRamp, heading)
    PlaceObjectOnGroundProperly(self.spawnedRamp)
    FreezeEntityPosition(self.spawnedRamp, false)
    
    Utils.Notify('Ramp spawned. Position it manually, then select it.', 'info')
end

function Editor:SelectRampPosition()
    self.selectedRamp = true
    
    local rampCoords = GetEntityCoords(self.spawnedRamp)
    local rampRotation = GetEntityRotation(self.spawnedRamp, 2)
    local vehicleCoords = GetEntityCoords(self.selectedVehicle)
    local vehicleRotation = GetEntityRotation(self.selectedVehicle, 2)
    
    -- Calculate offset and rotation relative to vehicle
    self.data.rampOffset = Utils.GetOffsetBetweenEntities(self.selectedVehicle, rampCoords)
    self.data.rampRotation = vector3(
        rampRotation.x - vehicleRotation.x,
        rampRotation.y - vehicleRotation.y,
        rampRotation.z - vehicleRotation.z
    )
    
    Utils.Notify('Ramp position recorded. Now select attachment point.', 'success')
end

function Editor:CalculateStaticRampOffsets(targetCoords)
    local offset = Utils.GetOffsetBetweenEntities(self.selectedVehicle, targetCoords)
    self.data.attachOffset = offset
    
    -- Calculate winch point
    self.data.winchPoint = vector3(offset.x, offset.y - 1.0, offset.z + 0.3)
    
    -- Clean up spawned ramp
    if self.spawnedRamp and DoesEntityExist(self.spawnedRamp) then
        DeleteEntity(self.spawnedRamp)
        self.spawnedRamp = nil
    end
    
    -- Format and save
    self:SaveStaticRampConfig()
end

function Editor:SaveStaticRampConfig()
    local configString = string.format([[
['%s'] = {
    label = '%s',
    bone = '%s',
    rampModel = '%s',
    rampOffset = vec3(%.2f, %.2f, %.2f),
    rampRotation = vec3(%.2f, %.2f, %.2f),
    attachOffset = vec3(%.2f, %.2f, %.2f),
    winchPoint = vec3(%.2f, %.2f, %.2f)
}]],
        self.data.vehicleName,
        self.data.vehicleLabel,
        self.data.bone,
        self.data.rampModel,
        self.data.rampOffset.x, self.data.rampOffset.y, self.data.rampOffset.z,
        self.data.rampRotation.x, self.data.rampRotation.y, self.data.rampRotation.z,
        self.data.attachOffset.x, self.data.attachOffset.y, self.data.attachOffset.z,
        self.data.winchPoint.x, self.data.winchPoint.y, self.data.winchPoint.z
    )
    
    Utils.CopyToClipboard(configString)
    Utils.Notify('Configuration copied to clipboard! Paste it in Config.StaticRampVehicles', 'success')
    
    -- Send to server for saving
    TriggerServerEvent('flatbed:saveVehicleConfig', 'static', self.data)
    
    -- Reset for next configuration
    self.selectedVehicle = nil
    self.selectedRamp = nil
    self.data = {}
end

-- ════════════════════════════════════════════════════════════════
-- WINCH POINT CONFIGURATION
-- ════════════════════════════════════════════════════════════════

function Editor:HandleWinchPointConfig(hit, coords, entity)
    if not self.selectedVehicle then
        -- Step 1: Select vehicle
        Utils.ShowHelpText(
            '~y~Winch Point Config~w~\n' ..
            'Aim at a vehicle and press ~g~E~w~ to select it\n' ..
            'Press ~r~BACKSPACE~w~ - Cancel'
        )
        
        if hit and entity and IsEntityAVehicle(entity) then
            local vehCoords = GetEntityCoords(entity)
            Utils.DrawMarker3D(vehCoords + vector3(0, 0, 1.0), 0, 
                Config.Editor.markerSize, 
                Config.Editor.markerColor.r,
                Config.Editor.markerColor.g,
                Config.Editor.markerColor.b,
                Config.Editor.markerColor.a
            )
            
            if IsControlJustPressed(0, Config.Keys.SelectEntity) then
                self:SelectWinchVehicle(entity)
            end
        end
    else
        -- Step 2: Select winch point
        Utils.ShowHelpText(
            '~y~Winch Point Config~w~\n' ..
            'Vehicle Selected: ' .. GetDisplayNameFromVehicleModel(GetEntityModel(self.selectedVehicle)) .. '\n' ..
            'Aim at the winch cable attachment point and press ~g~E~w~\n' ..
            'Press ~r~BACKSPACE~w~ - Cancel'
        )
        
        -- Draw vehicle marker
        local vehCoords = GetEntityCoords(self.selectedVehicle)
        Utils.DrawMarker3D(vehCoords + vector3(0, 0, 1.0), 0, 
            Config.Editor.markerSize, 255, 255, 0, 200)
        
        if hit and IsControlJustPressed(0, Config.Keys.SelectEntity) then
            self:CalculateWinchPoint(coords)
        end
    end
end

function Editor:SelectWinchVehicle(vehicle)
    self.selectedVehicle = vehicle
    local model = GetEntityModel(vehicle)
    local displayName = GetDisplayNameFromVehicleModel(model):lower()
    
    self.data = {
        vehicleName = displayName,
        vehicleLabel = GetLabelText(displayName)
    }
    
    Utils.Notify('Vehicle selected: ' .. displayName, 'success')
end

function Editor:CalculateWinchPoint(targetCoords)
    local offset = Utils.GetOffsetBetweenEntities(self.selectedVehicle, targetCoords)
    self.data.winchPoint = offset
    
    local configString = string.format(
        "Winch Point for '%s': vec3(%.2f, %.2f, %.2f)",
        self.data.vehicleName,
        offset.x, offset.y, offset.z
    )
    
    Utils.CopyToClipboard(configString)
    Utils.Notify('Winch point copied to clipboard!', 'success')
    
    -- Reset for next configuration
    self.selectedVehicle = nil
    self.data = {}
end

-- ════════════════════════════════════════════════════════════════
-- DISPLAY FUNCTIONS
-- ════════════════════════════════════════════════════════════════

function Editor:DisplayInstructions()
    -- Display editor status
    local statusText = '~b~EDITOR MODE ACTIVE~w~'
    if self.mode then
        statusText = statusText .. '\n~y~Mode: ' .. self.mode:upper():gsub('_', ' ') .. '~w~'
    end
    
    SetTextFont(0)
    SetTextProportional(1)
    SetTextScale(0.4, 0.4)
    SetTextColour(255, 255, 255, 255)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry("STRING")
    AddTextComponentString(statusText)
    DrawText(0.85, 0.05)
end

-- ════════════════════════════════════════════════════════════════
-- COMMAND REGISTRATION
-- ════════════════════════════════════════════════════════════════

RegisterCommand('flatbed_editor', function()
    if not Utils.HasJob() then
        Utils.Notify(Config.Notifications.noPermission.message, 'error')
        return
    end
    
    Editor:Toggle()
end, false)

-- Key mapping
RegisterKeyMapping('flatbed_editor', 'Toggle Flatbed Editor', 'keyboard', 'F11')