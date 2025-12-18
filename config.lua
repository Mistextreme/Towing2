Config = {}

-- ════════════════════════════════════════════════════════════════
-- GENERAL SETTINGS
-- ════════════════════════════════════════════════════════════════

Config.Framework = 'esx' -- Framework type
Config.Locale = 'en' -- Language

-- Jobs allowed to use the system
Config.AllowedJobs = {
    'mechanic',
    'police',
    'ambulance'
}

-- ════════════════════════════════════════════════════════════════
-- KEY BINDINGS
-- ════════════════════════════════════════════════════════════════

Config.Keys = {
    -- In Vehicle Controls
    RaiseBed = 111,          -- NUM 8 - Raise bed/ramp
    LowerBed = 112,          -- NUM 5 - Lower bed/ramp
    AlternativeRaise = 21,   -- SHIFT - Alternative raise
    AlternativeLower = 36,   -- LEFT CTRL - Alternative lower
    
    -- Out of Vehicle Controls
    AttachDetach = 38,       -- E - Attach/Detach vehicle
    DeployRamp = 47,         -- G - Deploy/Remove static ramp
    TakeWinchCable = 108,    -- NUM 4 - Take winch cable
    AttachWinchCable = 109,  -- NUM 6 - Attach winch cable to vehicle
    
    -- Editor Mode
    ToggleEditor = 344,      -- F11 - Toggle editor mode
    SelectEntity = 38,       -- E - Select entity in editor
    ConfirmSelection = 191,  -- ENTER - Confirm selection
    CancelEditor = 177,      -- BACKSPACE - Cancel editor
    SpawnRamp = 47,          -- G - Spawn ramp in editor
    SaveConfiguration = 191  -- ENTER - Save configuration
}

-- ════════════════════════════════════════════════════════════════
-- VEHICLE CONFIGURATIONS
-- ════════════════════════════════════════════════════════════════

-- Vehicles with MOVABLE ramps (using bulldozer arm mechanics)
Config.MovableRampVehicles = {
    ['flatbed'] = {
        label = 'Flatbed Truck',
        bone = 'chassis',
        minPosition = 0.1,      -- Retracted position
        maxPosition = 0.3,      -- Extended position
        speed = 0.005,          -- Movement speed
        attachOffset = vector3(0.0, -2.2, 0.4), -- Offset when attaching vehicles
        winchPoint = vector3(-1.2, -4.75, 0.0)  -- Winch cable attachment point
    },
    ['f550rb'] = {
        label = 'Ford F550 Rollback',
        bone = 'chassis',
        minPosition = 0.1,
        maxPosition = 0.3,
        speed = 0.005,
        attachOffset = vector3(0.0, -2.2, 0.4),
        winchPoint = vector3(-1.2, -4.75, 0.0)
    },
    ['f550rbc'] = {
        label = 'Ford F550 Rollback Crew',
        bone = 'chassis',
        minPosition = 0.1,
        maxPosition = 0.3,
        speed = 0.005,
        attachOffset = vector3(0.0, -2.2, 0.4),
        winchPoint = vector3(-1.2, -4.75, 0.0)
    },
    ['16ramrb'] = {
        label = '2016 RAM Rollback',
        bone = 'chassis',
        minPosition = 0.1,
        maxPosition = 0.3,
        speed = 0.005,
        attachOffset = vector3(0.0, -2.2, 0.4),
        winchPoint = vector3(-1.2, -4.75, 0.0)
    },
    ['16ramrbc'] = {
        label = '2016 RAM Rollback Crew',
        bone = 'chassis',
        minPosition = 0.1,
        maxPosition = 0.3,
        speed = 0.005,
        attachOffset = vector3(0.0, -2.2, 0.4),
        winchPoint = vector3(-1.2, -4.75, 0.0)
    },
    ['20ramrb'] = {
        label = '2020 RAM Rollback',
        bone = 'chassis',
        minPosition = 0.1,
        maxPosition = 0.3,
        speed = 0.005,
        attachOffset = vector3(0.0, -2.2, 0.4),
        winchPoint = vector3(-1.2, -4.75, 0.0)
    },
    ['20ramrbc'] = {
        label = '2020 RAM Rollback Crew',
        bone = 'chassis',
        minPosition = 0.1,
        maxPosition = 0.3,
        speed = 0.005,
        attachOffset = vector3(0.0, -2.2, 0.4),
        winchPoint = vector3(-1.2, -4.75, 0.0)
    }
}

-- Vehicles with STATIC ramps (deploy/remove ramp object)
Config.StaticRampVehicles = {
    ['towtruck'] = {
        label = 'Tow Truck',
        bone = 'chassis',
        rampModel = 'imp_prop_flatbed_ramp',
        rampOffset = vector3(0.0, -4.5, -0.5),
        rampRotation = vector3(180.0, 180.0, 0.0),
        attachOffset = vector3(0.0, -3.0, 0.5),
        winchPoint = vector3(0.0, -4.0, 0.8)
    },
    ['towtruck2'] = {
        label = 'Tow Truck Large',
        bone = 'chassis',
        rampModel = 'imp_prop_flatbed_ramp',
        rampOffset = vector3(0.0, -5.0, -0.5),
        rampRotation = vector3(180.0, 180.0, 0.0),
        attachOffset = vector3(0.0, -3.5, 0.5),
        winchPoint = vector3(0.0, -4.5, 0.8)
    }
}

-- ════════════════════════════════════════════════════════════════
-- WINCH SYSTEM
-- ════════════════════════════════════════════════════════════════

Config.Winch = {
    ropeType = 2,              -- Rope type (2 = standard)
    maxLength = 25.0,          -- Maximum rope length
    ropeLength = 1.0,          -- Initial rope length
    windingSpeed = 0.1,        -- Winding speed
    minDistance = 1.05,        -- Minimum distance before attach
    targetBone = 'bonnet',     -- Bone to attach on target vehicle
    attachHeight = 0.08,       -- Height adjustment for attach
    laserDistance = 15.0,      -- Maximum distance for laser selection
    laserColor = {r = 0, g = 255, b = 0, a = 200} -- Laser color (green)
}

-- ════════════════════════════════════════════════════════════════
-- EDITOR MODE SETTINGS
-- ════════════════════════════════════════════════════════════════

Config.Editor = {
    raycastDistance = 1000.0,   -- Raycast distance
    markerType = 0,             -- Marker type (0 = upside-down cone)
    markerSize = vector3(0.5, 0.5, 0.5),
    markerColor = {r = 255, g = 0, b = 0, a = 200},
    sphereSize = 0.1,
    lineColor = {r = 0, g = 255, b = 0, a = 100},
    helpTextScale = 0.35,
    saveToFile = true,          -- Save to external file (requires server restart)
    saveToDatabase = false      -- Save to database (dynamic loading)
}

-- ════════════════════════════════════════════════════════════════
-- VISUAL SETTINGS
-- ════════════════════════════════════════════════════════════════

Config.Visual = {
    use3DText = true,           -- Use 3D text instead of help text
    drawDebugLines = true,      -- Draw debug lines for attach points
    playHydraulicSounds = true, -- Play hydraulic sounds
    freezeVehicleWhenExtended = true -- Freeze vehicle when bed is extended
}

-- ════════════════════════════════════════════════════════════════
-- NOTIFICATIONS
-- ════════════════════════════════════════════════════════════════

Config.Notifications = {
    entitySelected = {
        title = 'Entity Selected',
        message = 'Entity selected. Proceed with configuration.',
        type = 'success'
    },
    offsetCalculated = {
        title = 'Offset Calculated',
        message = 'Offset copied to clipboard!',
        type = 'success'
    },
    rampDeployed = {
        title = 'Ramp Deployed',
        message = 'Ramp has been successfully deployed.',
        type = 'success'
    },
    rampRemoved = {
        title = 'Ramp Removed',
        message = 'Ramp has been removed.',
        type = 'success'
    },
    vehicleAttached = {
        title = 'Vehicle Attached',
        message = 'Vehicle attached successfully.',
        type = 'success'
    },
    vehicleDetached = {
        title = 'Vehicle Detached',
        message = 'Vehicle detached successfully.',
        type = 'success'
    },
    noPermission = {
        title = 'No Permission',
        message = 'You do not have permission to use this.',
        type = 'error'
    },
    notInVehicle = {
        title = 'Not In Vehicle',
        message = 'You must be in a vehicle.',
        type = 'error'
    },
    wrongVehicle = {
        title = 'Wrong Vehicle',
        message = 'This vehicle is not compatible.',
        type = 'error'
    },
    editorEnabled = {
        title = 'Editor Mode',
        message = 'Editor mode enabled.',
        type = 'info'
    },
    editorDisabled = {
        title = 'Editor Mode',
        message = 'Editor mode disabled.',
        type = 'info'
    },
    configurationSaved = {
        title = 'Configuration Saved',
        message = 'Vehicle configuration saved successfully!',
        type = 'success'
    }
}