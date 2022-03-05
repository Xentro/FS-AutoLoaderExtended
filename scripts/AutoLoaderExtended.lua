-- 
-- AutoLoaderExtended
--
-- Author:  Xentro
-- Website: https://xentro.se, https://github.com/Xentro
--

AutoLoaderExtended = {
    MOD_NAME    = g_currentModName,
}

function AutoLoaderExtended.prerequisitesPresent(specializations)
    return true
end

function AutoLoaderExtended.initSpecialization()
    local schema         = Vehicle.xmlSchema
    local schemaSavegame = Vehicle.xmlSchemaSavegame

    schema:setXMLSpecializationType("AutoLoaderExtended")
    schema:register(XMLValueType.BOOL,          "vehicle.autoLoader#useTensionBelts",    "Automatically mount tension belts")
    schema:register(XMLValueType.INT,           "vehicle.autoLoader#maxUnloadDistance",  "How far we can move vehicle from unload location before aborting unload")
    schema:register(XMLValueType.INT,           "vehicle.autoLoader#allowBaleToSetTime", "How long after loading object before strapping load")
    schema:register(XMLValueType.INT,           "vehicle.autoLoader#unloadTime",         "Unloading time between objects")
    schema:register(XMLValueType.L10N_STRING,   "vehicle.autoLoader#unloadText",         "Unload text", "autoLoader_unloadSide")
    
	schema:register(XMLValueType.STRING,        "vehicle.autoLoader.pickup(?)#filename", "Shared pickup filename")
	schema:register(XMLValueType.NODE_INDEX,    "vehicle.autoLoader.pickup(?)#linkNode", "Link node", "0>")

    schema:register(XMLValueType.STRING,        "vehicle.autoLoader.loadSpace(?)#type",           "Allowed types to load")
    schema:register(XMLValueType.NODE_INDEX,    "vehicle.autoLoader.loadSpace(?)#nodeToChildren", "Load child nodes of this node")
    schema:register(XMLValueType.VECTOR_TRANS,  "vehicle.autoLoader.loadSpace(?)#checkSize",      "Check size around load place node")
    
    schema:register(XMLValueType.NODE_INDEX,    "vehicle.autoLoader.unloadTrigger#node",   "Used to tell if something has been unloaded when we are unloading already")

    schema:register(XMLValueType.L10N_STRING,   "vehicle.autoLoader.unloadSide(?)#name",   "Info text")
    schema:register(XMLValueType.NODE_INDEX,    "vehicle.autoLoader.unloadSide(?)#start",  "Node where unload should start")
    schema:register(XMLValueType.BOOL,          "vehicle.autoLoader.unloadSide(?)#isLeft", "Start node is left of vehicle, tells how we position objects upon unload")
    schema:register(XMLValueType.FLOAT,         "vehicle.autoLoader.unloadSide(?)#offsetY","")
    schema:register(XMLValueType.STRING,        "vehicle.autoLoader.unload(?)#type",       "Allowed types to unload")
    schema:register(XMLValueType.INT,           "vehicle.autoLoader.unload(?)#width",      "Unload width")
    schema:register(XMLValueType.INT,           "vehicle.autoLoader.unload(?)#height",     "Unload height")
    schema:setXMLSpecializationType()
    
    local sharedPickupXMLSchema = XMLSchema.new("sharedPickup")
	sharedPickupXMLSchema:register(XMLValueType.STRING,                   "pickup.filename",       "Path to i3d file", nil, true)
	sharedPickupXMLSchema:register(XMLValueType.NODE_INDEX,               "pickup.trigger#node",   "Pickup trigger node")
	sharedPickupXMLSchema:register(XMLValueType.NODE_INDEX,               "pickup.helper#node",    "Visual for trigger")
	sharedPickupXMLSchema:register(XMLValueType.FLOAT,                    "pickup.helper#offsetY", "")
	AutoLoaderExtended.registerSharedPickupXMLPath(sharedPickupXMLSchema, "pickup.helper.loading")
	AutoLoaderExtended.registerSharedPickupXMLPath(sharedPickupXMLSchema, "pickup.helper.full")
    AutoLoaderExtended.sharedPickupXMLSchema = sharedPickupXMLSchema

    -- schemaSavegame:register(XMLValueType.INT, string.format("vehicles.vehicle(?).%s.autoLoaderExtended#loadSpaceId", AutoLoaderExtended.MOD_NAME), "Last used loadSpace id")
    schemaSavegame:register(XMLValueType.INT, "vehicles.vehicle(?).autoLoaderExtended#loadSpaceId",  "Last used load space id")
    schemaSavegame:register(XMLValueType.INT, "vehicles.vehicle(?).autoLoaderExtended#unloadSideId", "Last used unload side id")
end

function AutoLoaderExtended.registerSharedPickupXMLPath(schema, key)
    schema:register(XMLValueType.NODE_INDEX, key .. "#node",       "Visual status node")
    schema:register(XMLValueType.COLOR,      key .. "#color",      "Color on mesh")
    schema:register(XMLValueType.COLOR,      key .. "#colorBlind", "colorBlind, Color on mesh")
end

function AutoLoaderExtended.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "onPickupI3DLoaded", AutoLoaderExtended.onPickupI3DLoaded)
	SpecializationUtil.registerFunction(vehicleType, "loadSharedHelperStatus", AutoLoaderExtended.loadSharedHelperStatus)
    
    SpecializationUtil.registerFunction(vehicleType, "setMode", AutoLoaderExtended.setMode)
    SpecializationUtil.registerFunction(vehicleType, "setState", AutoLoaderExtended.setState)
    
    SpecializationUtil.registerFunction(vehicleType, "setHelperStatus", AutoLoaderExtended.setHelperStatus)
    SpecializationUtil.registerFunction(vehicleType, "getIsAutoLoadingAllowed", AutoLoaderExtended.getIsAutoLoadingAllowed)
    SpecializationUtil.registerFunction(vehicleType, "getLoadSpaceStatus", AutoLoaderExtended.getLoadSpaceStatus)
    SpecializationUtil.registerFunction(vehicleType, "getIsObjectValid", AutoLoaderExtended.getIsObjectValid)
    SpecializationUtil.registerFunction(vehicleType, "getIsObjectValidInSpace", AutoLoaderExtended.getIsObjectValidInSpace)
    SpecializationUtil.registerFunction(vehicleType, "getIsObjectAttached", AutoLoaderExtended.getIsObjectAttached)
    
    SpecializationUtil.registerFunction(vehicleType, "getNextUnloadSide", AutoLoaderExtended.getNextUnloadSide)
    SpecializationUtil.registerFunction(vehicleType, "setUnloadSide", AutoLoaderExtended.setUnloadSide)
    SpecializationUtil.registerFunction(vehicleType, "placeDummyObjects", AutoLoaderExtended.placeDummyObjects)
    
    SpecializationUtil.registerFunction(vehicleType, "autoLoaderPickupTriggerCallback", AutoLoaderExtended.autoLoaderPickupTriggerCallback)
    SpecializationUtil.registerFunction(vehicleType, "autoLoaderUnloadTriggerCallback", AutoLoaderExtended.autoLoaderUnloadTriggerCallback)
    SpecializationUtil.registerFunction(vehicleType, "checkLoadSpaceCallback", AutoLoaderExtended.checkLoadSpaceCallback)
    SpecializationUtil.registerFunction(vehicleType, "findUnloadObjectsCallback", AutoLoaderExtended.findUnloadObjectsCallback)
    SpecializationUtil.registerFunction(vehicleType, "checkUnloadAreaCallback", AutoLoaderExtended.checkUnloadAreaCallback)
    
    SpecializationUtil.registerFunction(vehicleType, "showWarningMessage", AutoLoaderExtended.showWarningMessage)
end

function AutoLoaderExtended.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getDynamicMountTimeToMount", AutoLoaderExtended.getDynamicMountTimeToMount)
end

function AutoLoaderExtended.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", AutoLoaderExtended)
	SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", AutoLoaderExtended)
    SpecializationUtil.registerEventListener(vehicleType, "onDelete", AutoLoaderExtended)
	SpecializationUtil.registerEventListener(vehicleType, "onReadStream", AutoLoaderExtended)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", AutoLoaderExtended)
	SpecializationUtil.registerEventListener(vehicleType, "onReadUpdateStream", AutoLoaderExtended)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteUpdateStream", AutoLoaderExtended)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdate", AutoLoaderExtended)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", AutoLoaderExtended)
	SpecializationUtil.registerEventListener(vehicleType, "onPostDetach", AutoLoaderExtended)
	SpecializationUtil.registerEventListener(vehicleType, "onLeaveRootVehicle", AutoLoaderExtended)
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", AutoLoaderExtended)
end



function AutoLoaderExtended:onLoad(savegame)
	self.spec_autoLoaderExtended = self["spec_" .. AutoLoaderExtended.MOD_NAME .. ".autoLoaderExtended"] -- Yeah... I won't be doing this too many times! 
    local spec = self.spec_autoLoaderExtended

    spec.currentMode      = AutoLoaderExtended.MODE_INACTIVE
    spec.lastMode         = spec.currentMode
    spec.currentState     = AutoLoaderExtended.STATE_INACTIVE
    spec.forceActiveState = false

    spec.pickup = {
        triggers         = {},
        showHelper       = nil,
        helperStatusSent = nil,
        pending          = {
            unsorted = {},
            sorted   = {}
        }
    }
    
    spec.xmlLoadingHandles   = {}
	spec.sharedLoadRequestId = {}

    local i = 0
    while true do
        local key = string.format("vehicle.autoLoader.pickup(%d)", i)
        if not self.xmlFile:hasProperty(key) then break end

        local xmlFilename = self.xmlFile:getValue(key .. "#filename")
        
        if xmlFilename ~= nil then
            xmlFilename = Utils.getFilename(xmlFilename, self.baseDirectory)
            local pickupXMLFile = XMLFile.load("sharedPickup", xmlFilename, AutoLoaderExtended.sharedPickupXMLSchema)

            if pickupXMLFile ~= nil then
                local filename = pickupXMLFile:getValue("pickup.filename")

                if filename == nil then
                    Logging.xmlWarning(pickupXMLFile, "Missing pickup i3d filename!")
                    pickupXMLFile:delete()
    
                    break
                end

                local entry = {
                    linkNode = self.xmlFile:getValue(key .. "#linkNode", "0>", self.components, self.i3dMappings)
                }

                if entry.linkNode == nil then
                    Logging.xmlWarning(xmlFile, "Missing pickup linkNode in '%s'!", key)
                    pickupXMLFile:delete()
    
                    break
                end

                filename = Utils.getFilename(filename, self.baseDirectory)
                local sharedLoadRequestId = self:loadSubSharedI3DFile(filename, false, false, self.onPickupI3DLoaded, self, {
                    self.xmlFile,
                    key,
                    pickupXMLFile,
                    entry,
                    spec.pickup.triggers
                })

                table.insert(spec.sharedLoadRequestId, sharedLoadRequestId)
            end
        end
        
        i = i + 1
    end
    
    self:setHelperStatus(0) -- Update colors

    spec.load = {
        currentSpaceIndex = 0,
        loadSpaces        = {},
        useTensionBelts   = self.xmlFile:getValue("vehicle.autoLoader#useTensionBelts", true)
    }

    local i = 0
    while true do
        local key = string.format("vehicle.autoLoader.loadSpace(%d)", i)
        if not self.xmlFile:hasProperty(key) then break end

        local type = self.xmlFile:getValue(key .. "#type")
        if type ~= nil then
            local parentNode = self.xmlFile:getValue(key .. "#nodeToChildren", nil, self.components, self.i3dMappings)

            if parentNode ~= nil then
                local numChildren = getNumOfChildren(parentNode)

                if numChildren > 0 then
                    local nodes = {}

                    for index = 0, numChildren - 1 do
                        table.insert(nodes,  getChildAt(parentNode, index))
                    end

                    local entry = {
                        type      = type:lower(),
                        nodes     = nodes,
                        checkSize = {self.xmlFile:getValue(key .. "#checkSize", "1 1 1")},
                        isBale    = string.find(type:lower(), "bale") ~= nil,
                        isPallet  = string.find(type:lower(), "pallet") ~= nil
                    }

                    if entry.isBale and entry.isPallet then
                        -- We don't support both at the same time
                    else
                        table.insert(spec.load.loadSpaces, entry)
                    end
                end
            end
        end
        
        i = i + 1
    end
    assert(#spec.load.loadSpaces ~= 0, "AutoLoaderExtended: Couldn't find any vehicle.autoLoader.loadSpace")

    spec.unload = {
        currentSideIndex = 1,
        unloadText  = self.xmlFile:getValue("vehicle.autoLoader#unloadText", "autoLoader_unloadSide", self.customEnvironment, false),
        sides       = {},
        types       = {},
        trigger     = self.xmlFile:getValue("vehicle.autoLoader.unloadTrigger#node", nil, self.components, self.i3dMappings), -- We use this to make sure player dont mess with unload, instead of looping loadspace
        pending     = {
            num      = 0,
            unsorted = {}
        },
        current              = nil,   -- Created upon init of unload
        showUnloadInput      = false, -- Show unload key binding if we got something to unload
        allowUnloadInput     = false, -- Unload collision check sets this
        allowUnloadInputSent = false, -- 
        distanceLast         = 0,     -- 
        distanceMax          = self.xmlFile:getValue("vehicle.autoLoader#maxUnloadDistance", 7),
        dirtyFlag            = self:getNextDirtyFlag() 
    }

    local i = 0
    while true do
        local key = string.format("vehicle.autoLoader.unloadSide(%d)", i)
        if not self.xmlFile:hasProperty(key) then break end

        local name = self.xmlFile:getValue(key .. "#name", i, self.customEnvironment, false)
        local side = self.xmlFile:getValue(key .. "#start", nil, self.components, self.i3dMappings)
        
        if side ~= nil then
            table.insert(spec.unload.sides, {
                name = name, 
                node = side, 
                isLeft = self.xmlFile:getValue(key .. "#isLeft", false),
                offsetY = self.xmlFile:getValue(key .. "#offsetY", 0)
            })
        end

        i = i + 1
    end
    assert(#spec.unload.sides ~= 0, "AutoLoaderExtended: Couldn't find any vehicle.autoLoader.unloadSide")

    local i = 0
    while true do
        local key = string.format("vehicle.autoLoader.unload(%d)", i)
        if not self.xmlFile:hasProperty(key) then break end

        local type = self.xmlFile:getValue(key .. "#type")

        if type ~= nil then
            local entry = {
                type     = type:lower(),
                width    = self.xmlFile:getValue(key .. "#width", "4"),
                height   = self.xmlFile:getValue(key .. "#height", "2"),
                isBale   = string.find(type:lower(), "bale") ~= nil,
                isPallet = string.find(type:lower(), "pallet") ~= nil
            }

            table.insert(spec.unload.types, entry)
        end
        
        i = i + 1
    end
    assert(#spec.unload.types ~= 0, "AutoLoaderExtended: Couldn't find any vehicle.autoLoader.unload")

    spec.times = {
        current    = 0,
        loading    = 150,
        strapping  = self.xmlFile:getValue("vehicle.autoLoader#allowBaleToSetTime", 200),  -- Let object settle before attach
        full       = 2500,  -- Time between checks
        unloading  = self.xmlFile:getValue("vehicle.autoLoader#unloadTime", 100)
    }

    if self.isServer then
        if spec.unload.trigger ~= nil then
            addTrigger(spec.unload.trigger, "autoLoaderUnloadTriggerCallback", self)
        end
    end
end

function AutoLoaderExtended:onPostLoad(savegame)
    local spec = self.spec_autoLoaderExtended

    if savegame ~= nil then
        if not savegame.resetVehicles then
            spec.load.currentSpaceIndex  = Utils.getNoNil(savegame.xmlFile:getValue(savegame.key .. ".autoLoaderExtended#loadSpaceId"),  0)
            spec.unload.currentSideIndex = Utils.getNoNil(savegame.xmlFile:getValue(savegame.key .. ".autoLoaderExtended#unloadSideId"), 1)

            if spec.load.currentSpaceIndex > #spec.load.loadSpaces then
                spec.load.currentSpaceIndex = 0
            end
        end
    end
end

function AutoLoaderExtended:onPickupI3DLoaded(i3dNode, failedReason, args)
    local spec = self.spec_autoLoaderExtended
	local xmlFile, key, pickupXMLFile, entry, targetTable = unpack(args)

    if i3dNode ~= 0 then
		entry.node = pickupXMLFile:getValue("pickup.trigger#node", "0", i3dNode)
		entry.helper = pickupXMLFile:getValue("pickup.helper#node", nil, i3dNode)

        if self.isServer then
            addTrigger(entry.node, "autoLoaderPickupTriggerCallback", self)
        end

        if entry.helper ~= nil then
            setVisibility(entry.helper, false)

            entry.status = {}
            self:loadSharedHelperStatus(pickupXMLFile, "pickup.helper.loading", i3dNode, entry, "1 1 0", false)
            self:loadSharedHelperStatus(pickupXMLFile, "pickup.helper.full",    i3dNode, entry, "1 0 0", false)
            -- ColorBlind
            self:loadSharedHelperStatus(pickupXMLFile, "pickup.helper.loading", i3dNode, entry, "1 1 0", true)
            self:loadSharedHelperStatus(pickupXMLFile, "pickup.helper.full",    i3dNode, entry, "0 0 1", true)

            link(entry.linkNode, entry.helper)

            setTranslation(entry.helper, 0, pickupXMLFile:getValue("pickup.helper#offsetY", 0), 0)
        end
        link(entry.linkNode, entry.node)

        delete(i3dNode)
		table.insert(targetTable, entry)
    end

	pickupXMLFile:delete()

	spec.xmlLoadingHandles[pickupXMLFile] = nil
end

function AutoLoaderExtended:loadSharedHelperStatus(xmlFile, key, i3dNode, entry, defaultColor, loadColorBlind)
    local node = xmlFile:getValue(key .. "#node", nil, i3dNode)
    
    if node ~= nil then
        if I3DUtil.getIsLinkedToNode(entry.helper, node) then
            setVisibility(node, false)

            if not loadColorBlind then 
                table.insert(entry.status, {
                    node = node,
                    color = xmlFile:getValue(key .. "#color", defaultColor, true)
                })
            else
                table.insert(entry.status, {
                    color = xmlFile:getValue(key .. "#colorBlind", defaultColor, true)
                })
            end
        else
            Logging.xmlWarning(xmlFile, "Defined node '%s' is not a child of the helper node '%s' in '%s!", getName(node), getName(entry.linkNode), key)
        end
    else
        Logging.xmlWarning(xmlFile, "Could not find node for '%s'!", key)
    end
end

function AutoLoaderExtended:saveToXMLFile(xmlFile, key, usedModNames)
    local spec = self.spec_autoLoaderExtended
    local keyUpdate = key:gsub("." .. AutoLoaderExtended.MOD_NAME, "") -- I do not want the mod name...
    
    xmlFile:setValue(keyUpdate .. "#loadSpaceId", spec.load.currentSpaceIndex)
    xmlFile:setValue(keyUpdate .. "#unloadSideId", spec.unload.currentSideIndex)
end


function AutoLoaderExtended:onDelete()
	local spec = self.spec_autoLoaderExtended

	if spec.xmlLoadingHandles ~= nil then
		for xmlFile, _ in pairs(spec.xmlLoadingHandles) do
			xmlFile:delete()

			spec.xmlLoadingHandles[xmlFile] = nil
		end
	end

    if self.isServer then
        spec.pickup.pending.sorted = {}
        spec.pickup.pending.unsorted = {}
        spec.pendingObject = nil
        spec.unload.pending = {}

        if spec.unload.current ~= nil then
            self:setState(AutoLoaderExtended.STATE_UNLOAD_COMPLETE) -- Clean up
        end

        for i, v in ipairs (spec.pickup.triggers) do 
			removeTrigger(v.node)
		end
        if spec.unload.trigger ~= nil then
            removeTrigger(spec.unload.trigger)
        end
    end

    for i, v in ipairs (spec.pickup.triggers) do 
        delete(v.node)
        delete(v.helper)
    end

	if spec.sharedLoadRequestIds ~= nil then
		for _, sharedLoadRequestId in ipairs(spec.sharedLoadRequestIds) do
			g_i3DManager:releaseSharedI3DFile(sharedLoadRequestId)
		end
	end
end

function AutoLoaderExtended:onReadStream(streamId, connection)
    self:setMode(streamReadUIntN(streamId, AutoLoaderExtended.SEND_NUM_BITS), true)
    local helperStatus = streamReadUIntN(streamId, AutoLoaderExtendedSetHelperEvent.SEND_NUM_BITS)
    self:setHelperStatus(-helperStatus)
    self:setUnloadSide(streamReadInt8(streamId), true)

    local spec = self.spec_autoLoaderExtended
    spec.unload.showUnloadInput = streamReadBool(streamId)
    AutoLoaderExtended.updateActionText(self)
    spec.unload.allowUnloadInput = streamReadBool(streamId)

    local hasCurrent = streamReadBool(streamId)
    if hasCurrent then
        AutoLoaderExtendedUnloadStateEvent.run({vehicle = self, state = AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_INIT_UNLOAD}) -- Create current table 

        local numTypes = streamReadInt8(streamId)
        
        self.synchronizedOnUpdate = {
            objects = {}
        }

        for _ = 1, numTypes do
            local typeId = streamReadInt8(streamId)
            local numObjects = streamReadInt8(streamId)
            
            if self.synchronizedOnUpdate.objects[typeId] == nil then
                self.synchronizedOnUpdate.objects[typeId] = {}
            end
            
            for i = 1, numObjects do
                if streamReadBool(streamId) then
                    table.insert(self.synchronizedOnUpdate.objects[typeId], {typeId = typeId, id = NetworkUtil.readNodeObjectId(streamId)})
                end
            end
        end
    end
end

function AutoLoaderExtended:onWriteStream(streamId, connection)
    local spec = self.spec_autoLoaderExtended

    streamWriteUIntN(streamId, spec.currentMode, AutoLoaderExtended.SEND_NUM_BITS)
    streamWriteUIntN(streamId, math.abs(spec.pickup.helperStatusSent), AutoLoaderExtendedSetHelperEvent.SEND_NUM_BITS)
    streamWriteInt8(streamId, spec.unload.currentSideIndex)

    streamWriteBool(streamId, spec.unload.showUnloadInput)
    streamWriteBool(streamId, spec.unload.allowUnloadInput)

    streamWriteBool(streamId, spec.unload.current ~= nil)
    if spec.unload.current ~= nil then
        streamWriteInt8(streamId, table.size(spec.unload.current.objects)) -- Types

        for typeId, v in pairs (spec.unload.current.objects) do
            streamWriteInt8(streamId, typeId)
            streamWriteInt8(streamId, #v.sorted)

            for i, object in ipairs (v.sorted) do
                streamWriteBool(streamId, object.autoLoaderHasLoaded ~= nil)

                if object.autoLoaderHasLoaded ~= nil then
		            NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(object))
                end
            end
        end
    end
end

function AutoLoaderExtended:onReadUpdateStream(streamId, timestamp, connection)
	if connection:getIsServer() then -- Client
		local spec = self.spec_autoLoaderExtended

		if streamReadBool(streamId) then
			spec.unload.allowUnloadInput = streamReadBool(streamId)

            if streamReadBool(streamId) then
                local distance = streamReadFloat32(streamId)

                if spec.unload.distanceLast ~= distance then
                    spec.unload.distanceLast = distance

                    if distance >= spec.unload.distanceMax then             
                        self:showWarningMessage(AutoLoaderExtended.WARNING_DISTANCE_MAX, true, distance)
                    elseif distance >= (spec.unload.distanceMax * 0.5) then
                        self:showWarningMessage(AutoLoaderExtended.WARNING_DISTANCE, true, distance)
                    end
                end
            end
		end
	end
end

function AutoLoaderExtended:onWriteUpdateStream(streamId, connection, dirtyMask)
	if not connection:getIsServer() then -- Server
		local spec = self.spec_autoLoaderExtended

		if streamWriteBool(streamId, bitAND(dirtyMask, spec.unload.dirtyFlag) ~= 0) then
			streamWriteBool(streamId, spec.unload.allowUnloadInput)

            streamWriteBool(streamId, spec.currentState == AutoLoaderExtended.STATE_UNLOAD_UNLOADING)
            if spec.currentState == AutoLoaderExtended.STATE_UNLOAD_UNLOADING then
                streamWriteFloat32(streamId, spec.unload.distanceLast)
            end
		end
	end
end

function AutoLoaderExtended:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local spec = self.spec_autoLoaderExtended
    
    if self.finishedFirstUpdate then
        if self.synchronizedOnUpdate ~= nil then
            for typeId, o in pairs(self.synchronizedOnUpdate.objects) do 
                for i, v in ipairs(o) do 
                    local object = NetworkUtil.getObject(v.id)

                    -- object will be nil until its been loaded which seems to happen when player gets close to the object

                    if object ~= nil then
                        AutoLoaderExtendedUnloadStateEvent.run({
                            vehicle = self, 
                            state = AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_LOAD_TEMP_OBJECT, 
                            typeId = typeId, 
                            object = object
                        })

                        table.remove(self.synchronizedOnUpdate.objects, i)
                    else
                        break
                    end
                end

                if #o == 0 then
                    self.synchronizedOnUpdate.objects[typeId] = nil
                end
            end
            
            if next(self.synchronizedOnUpdate.objects) == nil and self.synchronizedOnUpdate.eventRequested == nil then
                -- Since some time could have passed, get current state...
                g_client:getServerConnection():sendEvent(AutoLoaderExtendedSynchEvent.new(self, AutoLoaderExtendedSynchEvent.CLIENT_REQUEST_UPDATE))
                self.synchronizedOnUpdate.eventRequested = true
            end
        end
    end

    local offsetY = 7
    local txt = ""

    if VehicleDebug.state == VehicleDebug.DEBUG then
        if self.isServer then
            for i, v in ipairs (spec.pickup.pending.sorted) do 
                local node = v.nodeId or v.components[1].node
                
                if entityExists(node) then
                    DebugUtil.drawDebugNode(node, "Pending " .. i, false, 0)
                end
            end

            local ls = spec.load.loadSpaces[spec.load.currentSpaceIndex]
            if ls ~= nil then
                for i, node in ipairs (ls.nodes) do
                    local x, y, z = unpack(ls.checkSize)
                    DebugUtil.drawDebugCube(node, x, y, z, 0, 1, 0)
                end
            end
        end

        if spec.unload.current ~= nil then
            for type, objects in ipairs (spec.unload.current.objects) do 
                for i, v in ipairs (objects.sorted) do 
                    local node = v.nodeId or v.components[1].node
                    
                    if entityExists(node) then
                        DebugUtil.drawDebugNode(node, "u" .. i, false, 0) -- Unload order
                    end
                end
            end

            for i, v in ipairs (spec.unload.current.tempVisual) do
                DebugUtil.drawDebugNode(v.objectRoot, "temp " .. i, false, 0) -- Unload order
            end
        end

    end

    -- txt = txt .. "actionText " .. tostring(g_currentMission.hud.contextActionDisplay.actionText) .. "\n"

    -- DebugUtil.drawDebugNode(self.components[1].node, txt, false, offsetY)

    if self:getIsActive() then
        if isActiveForInputIgnoreSelection then
            if spec.unload.current ~= nil and spec.unload.current.overlapBoxLocation ~= nil then
                local r, g, b          = 0, 1, 0
                local x, y, z          = getWorldTranslation(spec.unload.current.overlapBoxLocation)
                local xRot, yRot, zRot = getWorldRotation(spec.unload.current.overlapBoxLocation)
                local width, height, length = spec.unload.current.unloadSize[1], spec.unload.current.unloadSize[2], spec.unload.current.unloadSize[3]

                if not spec.unload.allowUnloadInput then
                    r, g, b = 1, 0, 0
                end

                if g_gameSettings:getValue(GameSettings.SETTING.USE_COLORBLIND_MODE) then
                    r, g, b = 1, 1, 0
                    
                    if not spec.unload.allowUnloadInput then
                        r, g, b = 0, 0, 1
                    end
                end

                DebugUtil.drawOverlapBox(x, y, z, xRot, yRot, zRot, width / 2, height / 2, length / 2, r, g, b)

                if spec.unload.allowUnloadInput then
                    g_currentMission.hud.contextActionDisplay:setContext(InputAction.IMPLEMENT_EXTRA, ContextActionDisplay.CONTEXT_ICON.TIP, g_i18n:getText("autoLoader_confirm_1"))
                end
            end
        end
    end
end

function AutoLoaderExtended:onUpdateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local spec = self.spec_autoLoaderExtended

    if self.isServer then
        if self:getIsActive() or spec.forceActiveState then
            if spec.times.current <= 0 then
                if self:getIsAutoLoadingAllowed() then
                    if spec.currentState == AutoLoaderExtended.STATE_LOAD_SEARCHING then
                        local pendingObject = spec.pickup.pending.sorted[1]

                        if pendingObject ~= nil then
                            if not self:getIsObjectAttached(pendingObject) then
                                local pendingLoadSpaceIndex = spec.pickup.pending.unsorted[pendingObject]
                                
                                if spec.load.currentSpaceIndex == 0 then
                                    spec.load.currentSpaceIndex = pendingLoadSpaceIndex
                                end

                                local status, foundSpaceLocation, firstFoundObject = self:getLoadSpaceStatus(spec.load.currentSpaceIndex, AutoLoaderExtended.GET_LOADSPACE_MODE_FREE_SPACE)

                                if status == AutoLoaderExtended.STATUS_LOADSPACE_NO_SPACE_NO_OBJECT then
                                    self:setState(AutoLoaderExtended.STATE_LOAD_FULL)
                                else
                                    -- Found no object while looking for free space
                                    if firstFoundObject == nil then
                                        local newLoadSpaceIndex = pendingLoadSpaceIndex
                                        local status, object, id = AutoLoaderExtended.STATUS_LOADSPACE_NO_SPACE_NO_OBJECT

                                        -- We dont take into account if more then 1 type is loaded
                                        for i, v in ipairs (spec.load.loadSpaces) do
                                            local s, _, _ = self:getLoadSpaceStatus(i, AutoLoaderExtended.GET_LOADSPACE_MODE_FIRST_OBJECT)

                                            if s == AutoLoaderExtended.STATUS_LOADSPACE_OBJECT_FOUND then
                                                newLoadSpaceIndex = i
                                                break
                                            end
                                        end

                                        if spec.load.currentSpaceIndex ~= newLoadSpaceIndex then
                                            spec.load.currentSpaceIndex = newLoadSpaceIndex

                                            status, foundSpaceLocation, firstFoundObject = self:getLoadSpaceStatus(spec.load.currentSpaceIndex, AutoLoaderExtended.GET_LOADSPACE_MODE_FREE_SPACE)
                                        end
                                    else
                                        -- Lets assume we loaded this object
                                    end

                                    if spec.load.currentSpaceIndex == pendingLoadSpaceIndex then
                                        self:setState(AutoLoaderExtended.STATE_LOAD_LOADING, pendingObject, foundSpaceLocation)
                                    end
                                end
                                
                                self:setHelperStatus(status)
                            end

                            -- We have done what we want with this object
                            AutoLoaderExtended.removeFromPickup(self, pendingObject, 1)
                        end

                    elseif spec.currentState == AutoLoaderExtended.STATE_LOAD_LOADING then
                        local pendingObject = spec.pendingObject.object
                        
                        if pendingObject ~= nil then
                            if spec.load.useTensionBelts and self.setAllTensionBeltsActive ~= nil then
                                self:setAllTensionBeltsActive(false)
                            end

                            local node       = spec.load.loadSpaces[spec.load.currentSpaceIndex].nodes[spec.pendingObject.location]
                            local objectNode = pendingObject.nodeId or pendingObject.components[1].node
                            local vx, vy, vz = getLinearVelocity(self:getParentComponent(node))
        
                            removeFromPhysics(objectNode)

                            -- Move object in place server/client
                            g_server:broadcastEvent(AutoLoaderExtendedLoadObjectEvent.new(self, pendingObject, spec.load.currentSpaceIndex, spec.pendingObject.location), true, nil, self)

                            addToPhysics(objectNode)
                            -- setLinearVelocity(objectNode, vx, vy, vz)

                            spec.pendingObject = nil
                            self:setState(AutoLoaderExtended.STATE_LOAD_STRAPPING)
                        end
                            
                    elseif spec.currentState == AutoLoaderExtended.STATE_LOAD_STRAPPING then
                        if spec.load.useTensionBelts and self.setAllTensionBeltsActive ~= nil then
                            self:setAllTensionBeltsActive(true)
                        end

                        self:setState(AutoLoaderExtended.STATE_LOAD_SEARCHING)

                    elseif spec.currentState == AutoLoaderExtended.STATE_LOAD_FULL then
                        -- Only check if pickup found something
                        if spec.pickup.pending.sorted[1] ~= nil then
                            local status, _ = self:getLoadSpaceStatus(spec.load.currentSpaceIndex, AutoLoaderExtended.GET_LOADSPACE_MODE_FREE_SPACE)

                            if status == AutoLoaderExtended.STATUS_LOADSPACE_NO_SPACE_NO_OBJECT then
                                self:setState(AutoLoaderExtended.STATE_LOAD_FULL) -- We are still full, reset timer
                            else
                                self:setState(AutoLoaderExtended.STATE_LOAD_SEARCHING)
                            end
                        end
                    end

                else -- Either its off or in unload mode
                    if spec.currentMode == AutoLoaderExtended.MODE_UNLOAD then
                        if spec.currentState == AutoLoaderExtended.STATE_UNLOAD_INIT then
                            local ls = spec.load.loadSpaces[spec.load.currentSpaceIndex]
                            local current = spec.unload.current

                            if current == nil then
                                g_server:broadcastEvent(AutoLoaderExtendedUnloadStateEvent.new(self, AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_INIT_UNLOAD), true, nil, self)

                                current = spec.unload.current
                                current.counter = {
                                    toLoad = #ls.nodes,
                                    checked = 0
                                }
                            end
                            
                            local checked, currentTypeId = 0
                            local found = false -- Keep it going until it finds something... We dont want the delay if we arent fully loaded

                            for i = #ls.nodes - current.counter.checked, 1, -1 do
                                checked = checked + 1

                                if checked > 1 and found then
                                    found = false
                                    break -- Need to catch my breath...
                                else
                                    local x, y, z    = getWorldTranslation(ls.nodes[i])
                                    local rx, ry, rz = getWorldRotation(ls.nodes[i])
                                    local sx, sy, sz = unpack(ls.checkSize)
                                    local offsetX, offsetY, offsetZ = 0, -0.05, 0

                                    spec.foundObjects = {}
                                    local overlapping = overlapBox(x + offsetX, y + offsetY + offsetZ, z, rx, ry, rz, sx / 2, sy / 2, sz / 2, "findUnloadObjectsCallback", self, 18874368, true, false, true) -- Collision mask bit 21 and 24
                                    
                                    for object, o in pairs (spec.foundObjects) do
                                        if current.objects[o.typeId] == nil then
                                            current.objects[o.typeId] = {sorted = {}, unsorted = {}}
                                        end

                                        if current.objects[o.typeId].unsorted[object] == nil then
                                            found = true
                                            currentTypeId = o.typeId
                                            table.insert(current.objects[currentTypeId].sorted, object)
                                            current.objects[currentTypeId].unsorted[object] = {typeId = currentTypeId, index = #current.objects[currentTypeId].sorted}
                                        end
                                    end

                                    current.counter.checked = current.counter.checked + 1
                                end
                            end

                            local initIsDone = current.counter.checked >= current.counter.toLoad

                            if currentTypeId ~= nil then
                                for i, object in ipairs (current.objects[currentTypeId].sorted) do
                                    if not object.autoLoaderHasLoaded then
                                        object.autoLoaderHasLoaded = true

                                        local entry = {
                                            object = object,
                                            typeId = currentTypeId
                                        }

                                        g_server:broadcastEvent(AutoLoaderExtendedUnloadStateEvent.new(self, AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_LOAD_TEMP_OBJECT, entry), true, nil, self)
                                    end
                                end
                            end

                            spec.unload.current = current

                            if initIsDone then
                                g_server:broadcastEvent(AutoLoaderExtendedUnloadStateEvent.new(self, AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_ALLOW_SIDES), true, nil, self)
                                self:setState(AutoLoaderExtended.STATE_UNLOAD_PLAYER)
                            end

                        elseif spec.currentState == AutoLoaderExtended.STATE_UNLOAD_PLAYER then
                            local width, height, length = spec.unload.current.unloadSize[1], spec.unload.current.unloadSize[2], spec.unload.current.unloadSize[3]
                            local wx, wy, wz       = getWorldTranslation(spec.unload.current.overlapBoxLocation)
                            local xRot, yRot, zRot = getWorldRotation(spec.unload.current.overlapBoxLocation)

                            spec.unload.allowUnloadInput = true
                            overlapBox(wx, wy, wz, xRot, yRot, zRot, width/2, height/2, length/2, "checkUnloadAreaCallback", self, 97050, true, true, true)
                            
                            -- Show the max size defined in xml
                            if VehicleDebug.state == VehicleDebug.DEBUG then
                                for typeId, _ in pairs (spec.unload.current.objects) do
                                    local type = spec.unload.types[typeId]

                                    if width == nil or width < type.width then
                                        width = type.width
                                    end
                                    if height == nil or height < type.height then
                                        height = type.height
                                    end
                                end

                                local side = spec.unload.sides[spec.unload.currentSideIndex]
                                local x, y, z = width / 2, height / 2, length / 2
                                
                                if not side.isLeft then
                                    x = -x
                                end

                                wx, wy, wz = localToWorld(side.node, x, y + side.offsetY, -z)

                                DebugUtil.drawOverlapBox(wx, wy, wz, xRot, yRot, zRot, width/2, height/2, length/2, 0, 0, 1)
                            end

                            if spec.unload.allowUnloadInput ~= spec.unload.allowUnloadInputSent then
                                spec.unload.allowUnloadInputSent = spec.unload.allowUnloadInput
                                self:raiseDirtyFlags(spec.unload.dirtyFlag)
                            end

                        elseif spec.currentState == AutoLoaderExtended.STATE_UNLOAD_UNLOADING then
                            if spec.load.useTensionBelts and self.setAllTensionBeltsActive ~= nil then
                                self:setAllTensionBeltsActive(false)
                            end

                            function getFirst(t)
                                local toRemove = {}

                                for typeId, v in pairs (t) do
                                    for i, object in ipairs (v.sorted) do
                                        object.autoLoaderHasLoaded = nil

                                        local objectNode = object.nodeId or object.components[1].node

                                        if entityExists(objectNode) then
                                            return toRemove, typeId, i, object, objectNode
                                        else
                                            table.insert(toRemove, {typeId = typeId, index = i, object = object})
                                        end
                                    end
                                end

                                return toRemove
                            end
                            local toRemove, typeId, index, object, objectNode = getFirst(spec.unload.current.objects)

                            -- Entity dont exist since it got deleted somewhere...
                            for i, v in ipairs (toRemove) do
                                spec.unload.current.objects[v.typeId].unsorted[v.object] = nil
                                table.remove(spec.unload.current.objects[v.typeId].sorted, v.index)

                                local entry = {
                                    typeId = v.typeId,
                                    index = v.index
                                }
                                g_server:broadcastEvent(AutoLoaderExtendedUnloadStateEvent.new(self, AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_DELETE_TEMP_OBJECT, entry), true, nil, self)
                            end

                            if object ~= nil then
                                spec.unload.current.objects[typeId].unsorted[object] = nil
                                table.remove(spec.unload.current.objects[typeId].sorted, index)

                                -- Remove from unload trigger since we remove object from physics 
                                if spec.unload.pending.unsorted[object] ~= nil then
                                    spec.unload.pending.unsorted[object] = nil
                                    spec.unload.pending.num = spec.unload.pending.num - 1
                                end

                                local entry = {
                                    typeId = typeId,
                                    index = index,
                                    object = object
                                }

                                removeFromPhysics(objectNode)
                                g_server:broadcastEvent(AutoLoaderExtendedUnloadStateEvent.new(self, AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_UNLOADING, entry), true, nil, self)
                                addToPhysics(objectNode)
                                
                                self:setState(AutoLoaderExtended.STATE_UNLOAD_UNLOADING) -- Reset timer
                                self:raiseActive()
                            else
                                self:setMode(AutoLoaderExtended.MODE_INACTIVE) -- Turn it off since we are done
                            end
                        end
                    end
                end
            else
                spec.times.current = spec.times.current - dt
                
                if spec.currentState ~= AutoLoaderExtended.STATE_LOAD_FULL and spec.currentState ~= AutoLoaderExtended.STATE_LOAD_SEARCHING and spec.currentState ~= AutoLoaderExtended.STATE_UNLOAD_PLAYER then
                    self:raiseActive()
                end
            end

            -- Distance check
            if spec.currentState == AutoLoaderExtended.STATE_UNLOAD_UNLOADING then
                local sx, sy, sz = getWorldTranslation(spec.unload.sides[spec.unload.currentSideIndex].node)
                local mx, my, mz = getWorldTranslation(spec.unload.current.masterUnloadNode)

                local distance = MathUtil.round(MathUtil.vector3Length(sx - mx, sy - my, sz - mz), 1)
                local distanceMax = spec.unload.distanceMax

                if spec.unload.distanceLast ~= distance then
                    spec.unload.distanceLast = distance
                    self:raiseDirtyFlags(spec.unload.dirtyFlag)

                    if distance >= distanceMax then
                        self:showWarningMessage(AutoLoaderExtended.WARNING_DISTANCE_MAX, true, distance)
                        self:setMode(AutoLoaderExtended.MODE_INACTIVE)
                    elseif distance >= (distanceMax * 0.5) then
                        self:showWarningMessage(AutoLoaderExtended.WARNING_DISTANCE, true, distance)
                    end
                end
            end
            
            local state = spec.unload.pending.num >= 1
            -- local state = next(spec.unload.pending.unsorted) ~= nil

            if spec.unload.pending.last ~= state then
                -- Update allowed to unload state
                g_server:broadcastEvent(AutoLoaderExtendedUnloadStateEvent.new(self, AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_SHOW_UNLOAD, state), true, nil, self)
                spec.unload.pending.last = state
            end

        end
    end

    if self.isClient then
        local showHelper = false
        
        if spec.currentMode == AutoLoaderExtended.MODE_LOAD then
            showHelper = isActiveForInputIgnoreSelection
        end

        if spec.pickup.showHelper ~= showHelper then
            for i, v in ipairs (spec.pickup.triggers) do
                if v.helper ~= nil then
                    setVisibility(v.helper, showHelper)
                end
            end

            spec.pickup.showHelper = showHelper
        end

        -- Update helper color for colorblind
        if spec.pickup.showHelper and isActiveForInputIgnoreSelection then
            local colorBlind = g_gameSettings:getValue(GameSettings.SETTING.USE_COLORBLIND_MODE)

            if spec.pickup.lastColorBlind ~= colorBlind then
                self:setHelperStatus(spec.pickup.helperStatusSent)
                spec.pickup.lastColorBlind = colorBlind
            end
        end

        if spec.unload.current ~= nil then
            local show = isActiveForInputIgnoreSelection

            if VehicleDebug.state == VehicleDebug.DEBUG then
                show = true
            end

            if spec.unload.current.showObjects ~= show then
                setVisibility(spec.unload.current.masterUnloadNode, show)
                spec.unload.current.showObjects = show
            end
        end
    end
end

function AutoLoaderExtended:onPostDetach()
    if self.spec_autoLoaderExtended.currentMode ~= AutoLoaderExtended.MODE_INACTIVE then
        self:setMode(AutoLoaderExtended.MODE_INACTIVE, true)
    end
end

function AutoLoaderExtended:onLeaveRootVehicle()
    local spec = self.spec_autoLoaderExtended

    if spec.currentMode == AutoLoaderExtended.MODE_LOAD then
        self:setMode(AutoLoaderExtended.MODE_INACTIVE, true)
    elseif spec.currentMode == AutoLoaderExtended.MODE_UNLOAD then
        if self.isServer then
            if spec.currentState == AutoLoaderExtended.STATE_UNLOAD_UNLOADING then
                spec.forceActiveState = true -- Keep going until unload is complete
            end
        end
    end
end

-- 

AutoLoaderExtended.MODE_INACTIVE = 0
AutoLoaderExtended.MODE_LOAD     = 1
AutoLoaderExtended.MODE_UNLOAD   = 2
AutoLoaderExtended.SEND_NUM_BITS = 2

function AutoLoaderExtended:setMode(id, noEventSend)
    local spec = self.spec_autoLoaderExtended

    -- Go back to where it was before
    if id == AutoLoaderExtended.MODE_UNLOAD then
        if id == spec.currentMode then
            id = spec.lastMode
        end
    end

    -- Force active until cycle is done
    if self.isServer then
        local isLoading = spec.currentState == AutoLoaderExtended.STATE_LOAD_LOADING or spec.currentState == AutoLoaderExtended.STATE_LOAD_STRAPPING
        
        if id == AutoLoaderExtended.MODE_INACTIVE or id == AutoLoaderExtended.MODE_LOAD then
            if spec.unload.current ~= nil then
                self:setState(AutoLoaderExtended.STATE_UNLOAD_COMPLETE)
            end
        end

        if id == AutoLoaderExtended.MODE_INACTIVE then
            if isLoading then
                spec.forceActiveState = true
            else
                self:setState(AutoLoaderExtended.STATE_INACTIVE)
            end

        elseif id == AutoLoaderExtended.MODE_LOAD then
            if isLoading then
                spec.forceActiveState = true
            else
                self:setState(AutoLoaderExtended.STATE_LOAD_SEARCHING)
            end

        elseif id == AutoLoaderExtended.MODE_UNLOAD then
            if isLoading then
                spec.forceActiveState = true
            else
                self:setState(AutoLoaderExtended.STATE_UNLOAD_INIT)
            end
        end
    end

    spec.lastMode    = spec.currentMode 
    spec.currentMode = id

    AutoLoaderExtended.updateActionText(self)
    AutoLoaderExtendedSetModeEvent.sendEvent(self, id, noEventSend)
end

AutoLoaderExtended.STATE_INACTIVE         = 0

AutoLoaderExtended.STATE_LOAD_SEARCHING   = 1 -- Waiting on object
AutoLoaderExtended.STATE_LOAD_LOADING     = 2 -- Loading object
AutoLoaderExtended.STATE_LOAD_STRAPPING   = 3 -- Strapping load
AutoLoaderExtended.STATE_LOAD_FULL        = 4

AutoLoaderExtended.STATE_UNLOAD_INIT      = 5 -- Fetch object to unload
AutoLoaderExtended.STATE_UNLOAD_PLAYER    = 6 -- Player decide on unload position
AutoLoaderExtended.STATE_UNLOAD_UNLOADING = 7 -- Unloading objects
AutoLoaderExtended.STATE_UNLOAD_COMPLETE  = 8

function AutoLoaderExtended:setState(id, pendingObject, pendingLocation)
    local spec = self.spec_autoLoaderExtended

    if self.isServer then
        if id == AutoLoaderExtended.STATE_UNLOAD_COMPLETE then
            spec.forceActiveState = false

            if spec.unload.current ~= nil then
                for typeId, v in pairs (spec.unload.current.objects) do
                    for i, object in ipairs (v.sorted) do
                        object.autoLoaderHasLoaded = nil
                    end
                end
                
                g_server:broadcastEvent(AutoLoaderExtendedUnloadStateEvent.new(self, AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_END_UNLOAD), true, nil, self)
            end

            if spec.unload.pending.num == 0 then
                self:setHelperStatus(AutoLoaderExtended.STATUS_LOADSPACE_FREE_SPACE_FOUND)
            end
        end

        if spec.forceActiveState then
            local isLoading = id == AutoLoaderExtended.STATE_LOAD_LOADING or id == AutoLoaderExtended.STATE_LOAD_STRAPPING
            local isUnloading = id == AutoLoaderExtended.STATE_UNLOAD_PLAYER or id == AutoLoaderExtended.STATE_UNLOAD_UNLOADING
            
            if spec.currentMode == AutoLoaderExtended.MODE_INACTIVE then
                if not isLoading and not isUnloading then
                    spec.forceActiveState = false
                    id = AutoLoaderExtended.STATE_INACTIVE
                end

            elseif spec.currentMode == AutoLoaderExtended.MODE_LOAD then
                if not isUnloading then
                    spec.forceActiveState = false
                    id = AutoLoaderExtended.STATE_LOAD_SEARCHING
                end

            elseif spec.currentMode == AutoLoaderExtended.MODE_UNLOAD then
                if not isLoading then
                    if not id == AutoLoaderExtended.STATE_UNLOAD_UNLOADING then
                        spec.forceActiveState = false
                    end

                    if not isUnloading then
                        id = AutoLoaderExtended.STATE_UNLOAD_INIT
                    end
                end
            end
        end

        if id == AutoLoaderExtended.STATE_LOAD_LOADING then
            spec.times.current = spec.times.loading
            
            spec.pendingObject = {
                object   = pendingObject,
                location = pendingLocation
            }

        elseif id == AutoLoaderExtended.STATE_LOAD_STRAPPING then
            spec.times.current = spec.times.strapping

        elseif id == AutoLoaderExtended.STATE_LOAD_FULL then
            spec.times.current = spec.times.full
        elseif id == AutoLoaderExtended.STATE_UNLOAD_UNLOADING then
            spec.times.current = spec.times.unloading
        end

        if id ~= spec.currentState then
            spec.currentState = id
        end
    end
end

-- Pickup / Loading

function AutoLoaderExtended:setHelperStatus(status)
    local spec = self.spec_autoLoaderExtended
    local colorBlind = g_gameSettings:getValue(GameSettings.SETTING.USE_COLORBLIND_MODE)

    if spec.pickup.helperStatusSent ~= status or spec.pickup.lastColorBlind ~= colorBlind then
        for i, v in ipairs (spec.pickup.triggers) do 
            if v.helper ~= nil then
                if getHasShaderParameter(v.helper, "colorMat") then
                    local loadingNode = v.status[1].node
                    local fullNode    = v.status[2].node

                    local loadingColor = v.status[1].color
                    local fullColor    = v.status[2].color
                    
                    if colorBlind then
                        loadingColor = v.status[3].color
                        fullColor    = v.status[4].color
                    end
                    
                    if loadingNode ~= nil then
                        if status == AutoLoaderExtended.STATUS_LOADSPACE_NO_SPACE_NO_OBJECT then
                            setVisibility(loadingNode, false)
                        else
                            setVisibility(loadingNode, true)
                            setShaderParameter(loadingNode, "colorMat", loadingColor[1], loadingColor[2], loadingColor[3], 0, false)
                        end
                    end

                    if fullNode ~= nil then
                        if status == AutoLoaderExtended.STATUS_LOADSPACE_NO_SPACE_NO_OBJECT then
                            setVisibility(fullNode, true)
                            setShaderParameter(fullNode, "colorMat", fullColor[1], fullColor[2], fullColor[3], 0, false)
                        else
                            setVisibility(fullNode, false)
                        end
                    end

                    if status == AutoLoaderExtended.STATUS_LOADSPACE_NO_SPACE_NO_OBJECT then
                        setShaderParameter(v.helper, "colorMat", fullColor[1], fullColor[2], fullColor[3], 0, false)
                    else
                        setShaderParameter(v.helper, "colorMat", loadingColor[1], loadingColor[2], loadingColor[3], 0, false)
                    end
                end
            end
        end
        
        spec.pickup.helperStatusSent = status

        if self.isServer and status ~= 0 then
            g_server:broadcastEvent(AutoLoaderExtendedSetHelperEvent.new(self, status), nil, nil, self)
        end
    end
end

function AutoLoaderExtended:getIsAutoLoadingAllowed()
	local spec = self.spec_autoLoaderExtended

    -- Check if the vehicle has not fallen to side
    local _, y1, _ = getWorldTranslation(self.components[1].node)
    local _, y2, _ = localToWorld(self.components[1].node, 0, 1, 0)
    if y2 - y1 < 0.5 then
        return false
    end

    -- Keep it going until cycle is done
    if spec.currentState == AutoLoaderExtended.STATE_LOAD_LOADING or spec.currentState == AutoLoaderExtended.STATE_LOAD_STRAPPING then
        return true
    end

    if spec.currentMode == AutoLoaderExtended.MODE_INACTIVE or spec.currentMode == AutoLoaderExtended.MODE_UNLOAD then
        return false
    end

	return true
end

AutoLoaderExtended.GET_LOADSPACE_MODE_FREE_SPACE       = 0  -- Get first free spot, return STATUS_LOADSPACE_NO_SPACE_NO_OBJECT if full
AutoLoaderExtended.GET_LOADSPACE_MODE_FIRST_OBJECT     = 1  -- Get first valid object, return STATUS_LOADSPACE_NO_SPACE_NO_OBJECT if none found

AutoLoaderExtended.STATUS_LOADSPACE_NO_SPACE_NO_OBJECT = -1 -- Read above
AutoLoaderExtended.STATUS_LOADSPACE_FREE_SPACE_FOUND   = -2 -- Found free space
AutoLoaderExtended.STATUS_LOADSPACE_OBJECT_FOUND       = -3 -- Object found

function AutoLoaderExtended:getLoadSpaceStatus(index, mode)
    local spec = self.spec_autoLoaderExtended
    local ls = spec.load.loadSpaces[index]
    local status = AutoLoaderExtended.STATUS_LOADSPACE_NO_SPACE_NO_OBJECT
    local obj 

    for i = 1, #ls.nodes do
        local x, y, z = getWorldTranslation(ls.nodes[i])
        local rx, ry, rz = getWorldRotation(ls.nodes[i])
        local offsetX, offsetY, offsetZ = 0, 0, 0 --unpack(spec.loadPlaceOffset)
        local sx, sy, sz = unpack(ls.checkSize)
        spec.foundObject = nil
        
        local overlapping = overlapBox(x + offsetX, y + offsetY + offsetZ, z, rx, ry, rz, sx / 2, sy / 2, sz / 2, "checkLoadSpaceCallback", self, 97050, true, false, true)
        
        if mode == AutoLoaderExtended.GET_LOADSPACE_MODE_FREE_SPACE then
            if spec.foundObject == nil then
                return AutoLoaderExtended.STATUS_LOADSPACE_FREE_SPACE_FOUND, i, obj
            else
                if self:getIsObjectValid(spec.foundObject, index) then
                    obj = spec.foundObject
                end
            end
        else
            if spec.foundObject ~= nil then
                if mode == AutoLoaderExtended.GET_LOADSPACE_MODE_FIRST_OBJECT then
                    if self:getIsObjectValid(spec.foundObject, index) then
                        return AutoLoaderExtended.STATUS_LOADSPACE_OBJECT_FOUND, spec.foundObject, i
                    end
                end
            end
        end
    end

    return status
end

function AutoLoaderExtended:getIsObjectValid(object, index, unload)
    local spec = self.spec_autoLoaderExtended
    local objectFilename = object.configFileName or object.i3dFilename
    
    if object == self or objectFilename == nil then
        return false
    end

    if not g_currentMission.accessHandler:canFarmAccess(self:getActiveFarm(), object) then
        return false
    end

    if not unload then
        -- Requested to validate from getLoadSpaceStatus
        if index ~= nil then
            if self.getIsObjectValidInSpace(spec.load.loadSpaces[index], object, objectFilename) then
                return true, index
            end

        -- Requested from pickup trigger, do normal check
        else
            if self:getIsObjectAttached(object) then
                return false -- We don't want attached object...
            end

            for i, v in ipairs (spec.load.loadSpaces) do 
                if self.getIsObjectValidInSpace(v, object, objectFilename) then
                    return true, i
                end
            end

        end
    else
        -- We need to do some validation when entering unload trigger too
        
        for i, v in ipairs (spec.unload.types) do 
            if self.getIsObjectValidInSpace(v, object, objectFilename) then
                return true, i
            end
        end
    end
    
    return false
end

function AutoLoaderExtended:getIsObjectValidInSpace(object, objectFilename)
    if string.find(objectFilename:lower(), self.type) ~= nil then
        if self.isBale then
            if not object:isa(Bale) or object.getAllowPickup ~= nil and not object:getAllowPickup() then
                return false
            end
        elseif self.isPallet then
            if not object.supportsPickUp then
                return false
            end
        end

        return true
    end

    return false
end

function AutoLoaderExtended:getIsObjectAttached(object)
    if object.dynamicMountJointIndex ~= nil or object.dynamicMountObject ~= nil or object.tensionMountObject ~= nil then
        return true
    end

    return false
end

function AutoLoaderExtended:removeFromPickup(object, index)
    local spec = self.spec_autoLoaderExtended
    
    if index == nil then
        for i, v in ipairs (spec.pickup.pending.sorted) do 
            if v == object then
                table.remove(spec.pickup.pending.sorted, i)
                break
            end
        end
    else
        table.remove(spec.pickup.pending.sorted, index)
    end
    
    spec.pickup.pending.unsorted[object] = nil
end

function AutoLoaderExtended:getDynamicMountTimeToMount(superFunc)
	return self:getIsAutoLoadingAllowed() and -1 or math.huge
end

-- Unload

function AutoLoaderExtended:getNextUnloadSide()
    local spec = self.spec_autoLoaderExtended
    local next = spec.unload.currentSideIndex + 1

    if next > #spec.unload.sides then
        return 1
    else
        return next
    end
end

function AutoLoaderExtended:setUnloadSide(index, noEventSend)
    local spec = self.spec_autoLoaderExtended

    spec.unload.currentSideIndex = index

    if spec.unload.current ~= nil then
        local side = spec.unload.sides[index]
        link(side.node, spec.unload.current.masterUnloadNode)
        setTranslation(spec.unload.current.masterUnloadNode, 0, side.offsetY, 0)

        -- Reset and reposition temp objects to new side
        spec.unload.current.curSize    = {0, 0, 0}
        spec.unload.current.curPos     = {0, 0, 0}
        spec.unload.current.unloadSize = {0, 0, 0}
        spec.unload.current.lastTypeId = nil

        for i, v in ipairs (spec.unload.current.tempVisual) do 
            self:placeDummyObjects(spec.unload.current, false, i)
        end

        local width, height, length = spec.unload.current.unloadSize[1], spec.unload.current.unloadSize[2], spec.unload.current.unloadSize[3]
        local x, y, z = width / 2, height / 2, length / 2
    
        if not side.isLeft then
            x = -x
        end
    
        link(side.node, spec.unload.current.overlapBoxLocation)
        setTranslation(spec.unload.current.overlapBoxLocation, x, y + side.offsetY, -z)
    end

    AutoLoaderExtendedSetUnloadSideEvent.sendEvent(self, index, noEventSend)
    AutoLoaderExtended.updateActionText(self)
end

function AutoLoaderExtended:placeDummyObjects(current, init, entry)
    function getPosition(value, add, offset) 
        if value == 0 then
            return add / 2
        else
            return value + add + offset
        end
    end

    local spec = self.spec_autoLoaderExtended
    local type, typeId, objectNode, sharedLoadRequestId
    local width, height, length
    local offset = {0.1, 0.05, 0.1} -- Space between objects
    
    if init then
        local object = entry[4]
        type = spec.unload.types[entry[1]]
        typeId = entry[1]
        objectNode = entry[2]

        link(current.masterUnloadNode, objectNode)

        if type.isBale then
            if object.isRoundbale then
                setRotation(objectNode, math.rad(90), 0, 0) -- todo set trough xml
                
                width = object.diameter
                height = object.width
                length = object.diameter
            else
                width = object.width
                height = object.height
                length = object.length
            end

        elseif type.isPallet then
            -- todo - sizes arent accurate, unloading wont be as accurate as it should be 
            width  = object.size.width
            height = object.size.height
            length = object.size.length
        end

        table.insert(current.tempVisual, {
            objectRoot = objectNode,
            typeId = entry[1],
            sharedLoadRequestId = entry[3],
            size = {width, height, length}
        })
    else
        local temp = current.tempVisual[entry]

        objectNode = temp.objectRoot
        type = spec.unload.types[temp.typeId]
        typeId = temp.typeId
        width, height, length = temp.size[1], temp.size[2], temp.size[3]
    end
    
    if current.curSize[1] > type.width then
        current.curSize[2] = current.curSize[2] + height + offset[2]
    end

    if current.curSize[1] == 0 or current.curSize[1] > type.width or current.curSize[2] > type.height or current.lastTypeId ~= typeId then
        current.curPos[1]  = 0
        current.curSize[1] = width
    end

    if current.curSize[2] == 0 or current.curSize[2] > type.height or current.lastTypeId ~= typeId then
        current.curPos[2]  = 0
        current.curSize[2] = height
    end

    -- First on width and height, add to length (Z)
    if current.curPos[1] == 0 and current.curPos[2] == 0 then
        current.curPos[3]  = getPosition(current.curPos[3], length, offset[3])
        current.curSize[3] = current.curSize[3] + length + offset[3]
    end

    if current.curPos[1] == 0 then
        current.curPos[2] = getPosition(current.curPos[2], height, offset[2])
        current.curPos[2] = current.curPos[2]
    end

    -- 
    current.unloadSize[1] = math.max(current.unloadSize[1], current.curSize[1]) -- Width
    current.unloadSize[2] = math.max(current.unloadSize[2], current.curSize[2]) -- Height
    current.unloadSize[3] = math.max(current.unloadSize[3], current.curSize[3]) -- Length

    current.curPos[1]  = getPosition(current.curPos[1], width, offset[1])
    current.curSize[1] = current.curSize[1] + width + offset[1]
    current.lastTypeId = typeId
    
    local side = spec.unload.sides[spec.unload.currentSideIndex]
    local newX = current.curPos[1]

    if not side.isLeft then
        newX = -newX
    end
    
    setTranslation(objectNode, newX, current.curPos[2], current.curPos[3] * -1) -- inverse, place backwards
end

-- Callbacks

function AutoLoaderExtended:autoLoaderPickupTriggerCallback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId) -- Pickup Trigger
    if otherActorId ~= 0 then
        local spec = self.spec_autoLoaderExtended
        local object = g_currentMission:getNodeObject(otherActorId)

        if object ~= nil then
            if onEnter then
                if not self:getIsObjectAttached(object) then
                    local isValid, validLoadSpace = self:getIsObjectValid(object)

                    if isValid then
                        if spec.pickup.pending.unsorted[object] == nil then
                            spec.pickup.pending.unsorted[object] = validLoadSpace
                            table.insert(spec.pickup.pending.sorted, object)
                        end
                    else
                        if spec.currentMode == AutoLoaderExtended.MODE_LOAD then
                            self:showWarningMessage(AutoLoaderExtended.WARNING_INVALID)
                        end
                    end
                end
            elseif onLeave then
                if spec.pickup.pending.unsorted[object] ~= nil then
                    AutoLoaderExtended.removeFromPickup(self, object)
                end
            end
        end
    end
end

function AutoLoaderExtended:autoLoaderUnloadTriggerCallback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId) -- Unload Trigger
    if otherActorId ~= 0 then
        local spec = self.spec_autoLoaderExtended
        local object = g_currentMission:getNodeObject(otherActorId)

        if object ~= nil and object ~= self then
            if onEnter then
                local isValid, validType = self:getIsObjectValid(object, nil, true)
                                
                if isValid then
                    if spec.unload.pending.unsorted[object] == nil then
                        spec.unload.pending.unsorted[object] = {typeId = validType}
                        spec.unload.pending.num = spec.unload.pending.num + 1
                    end
                end
            elseif onLeave then
                if spec.unload.pending.unsorted[object] ~= nil then
                    spec.unload.pending.unsorted[object] = nil
                    spec.unload.pending.num = spec.unload.pending.num - 1

                    if spec.unload.current ~= nil then
                        for typeId, v in pairs (spec.unload.current.objects) do
                            if spec.unload.current.objects[typeId].unsorted[object] ~= nil then
                                self:showWarningMessage(AutoLoaderExtended.WARNING_UNLOADED)
                                
                                -- Clean up and abort
                                self:setMode(AutoLoaderExtended.MODE_INACTIVE)
                                break
                            end
                        end
                    end
                end
            end
        end
    end
end

function AutoLoaderExtended:checkLoadSpaceCallback(transformId) -- OverlapBox callback
	if transformId ~= 0 and getHasClassId(transformId, ClassIds.SHAPE) then
		local object = g_currentMission:getNodeObject(transformId)

		if object ~= nil and object ~= self then
			self.spec_autoLoaderExtended.foundObject = object
		end
	end

	return true
end

function AutoLoaderExtended:findUnloadObjectsCallback(transformId) -- OverlapBox callback
	if transformId ~= 0 and getHasClassId(transformId, ClassIds.SHAPE) then
        local spec = self.spec_autoLoaderExtended
		local object = g_currentMission:getNodeObject(transformId)

		if object ~= nil and object ~= self then
            if spec.unload.pending.unsorted[object] ~= nil then
                spec.foundObjects[object] = spec.unload.pending.unsorted[object]
            end
		end
	end

	return true
end

function AutoLoaderExtended:checkUnloadAreaCallback(transformId) -- OverlapBox callback
    if transformId ~= 0 then -- or transformId == g_currentMission.terrainRootNode then
		self.spec_autoLoaderExtended.unload.allowUnloadInput = false
		return false
	end

    return true
end

function AutoLoaderExtended:actionEventStateCallback(actionName, inputValue, callbackState, isAnalog)
    local spec = self.spec_autoLoaderExtended

    if actionName == InputAction.IMPLEMENT_EXTRA then       -- On / Off
        if spec.currentMode == AutoLoaderExtended.MODE_INACTIVE then
            self:setMode(AutoLoaderExtended.MODE_LOAD)

        elseif spec.currentMode == AutoLoaderExtended.MODE_LOAD then
            self:setMode(AutoLoaderExtended.MODE_INACTIVE)

        elseif spec.currentMode == AutoLoaderExtended.MODE_UNLOAD then
            if spec.unload.allowUnloadInput then
                g_client:getServerConnection():sendEvent(AutoLoaderExtendedUnloadStateEvent.new(self, AutoLoaderExtendedUnloadStateEvent.SERVER_STATE_PRE_UNLOAD))
            else
                self:showWarningMessage(AutoLoaderExtended.WARNING_COLLISION, true)
            end
        end
    
    elseif actionName == InputAction.IMPLEMENT_EXTRA2 then  -- Unload
        self:setMode(AutoLoaderExtended.MODE_UNLOAD)

    elseif actionName == InputAction.TOGGLE_TIPSIDE then    -- Toggle unload sides
        self:setUnloadSide(self:getNextUnloadSide())
    end
end

-- Key inputs

function AutoLoaderExtended:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
	if self.isClient then
		local spec = self.spec_autoLoaderExtended

		self:clearActionEventsTable(spec.actionEvents)

		if isActiveForInput then
            local state, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.IMPLEMENT_EXTRA, self, AutoLoaderExtended.actionEventStateCallback, false, true, false, true, nil)
            g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)

            state, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.IMPLEMENT_EXTRA2, self, AutoLoaderExtended.actionEventStateCallback, false, true, false, true, nil)
            g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)

            if #spec.unload.sides > 1 then
                state, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.TOGGLE_TIPSIDE, self, AutoLoaderExtended.actionEventStateCallback, false, true, false, true, nil)
                g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
            end

            AutoLoaderExtended.updateActionText(self)
		end
	end
end

function AutoLoaderExtended:updateActionText()
    local spec = self.spec_autoLoaderExtended

	if self.isClient then
        local unloadInPlayerState = spec.unload.current ~= nil and spec.unload.current.allowToggleUnloadSide
		local actionEvent = spec.actionEvents[InputAction.IMPLEMENT_EXTRA]

		if actionEvent ~= nil then
            local showAction = false

            if spec.currentMode == AutoLoaderExtended.MODE_INACTIVE then
                g_inputBinding:setActionEventText(actionEvent.actionEventId, g_i18n:getText("autoLoader_activate"))
                showAction = true

            elseif spec.currentMode == AutoLoaderExtended.MODE_LOAD then
                g_inputBinding:setActionEventText(actionEvent.actionEventId, g_i18n:getText("autoLoader_deactivate"))
                showAction = true

            elseif spec.currentMode == AutoLoaderExtended.MODE_UNLOAD then
                if unloadInPlayerState then
                    g_inputBinding:setActionEventText(actionEvent.actionEventId, g_i18n:getText("autoLoader_confirm"))
                    showAction = true
                end
            end

            g_inputBinding:setActionEventActive(actionEvent.actionEventId, showAction)
        end

        local actionEvent = spec.actionEvents[InputAction.IMPLEMENT_EXTRA2]
        if actionEvent ~= nil then
            if spec.currentMode ~= AutoLoaderExtended.MODE_UNLOAD then
                g_inputBinding:setActionEventText(actionEvent.actionEventId, g_i18n:getText("autoLoader_activate_unload"))
            else
                g_inputBinding:setActionEventText(actionEvent.actionEventId, g_i18n:getText("autoLoader_deactivate_unload"))
            end
            
            g_inputBinding:setActionEventActive(actionEvent.actionEventId, spec.unload.showUnloadInput)
        end

        local actionEvent = spec.actionEvents[InputAction.TOGGLE_TIPSIDE]
        if actionEvent ~= nil then
            local showAction = false

            if #spec.unload.sides > 1 then -- Do we need this here?
                if spec.currentMode == AutoLoaderExtended.MODE_UNLOAD then
                    if unloadInPlayerState then
                        local text = string.format(spec.unload.unloadText, spec.unload.sides[spec.unload.currentSideIndex].name)
                        g_inputBinding:setActionEventText(actionEvent.actionEventId, text)
                        showAction = true
                    end
                end
            end

            g_inputBinding:setActionEventActive(actionEvent.actionEventId, showAction)
        end
    end
end

-- Messages

AutoLoaderExtended.WARNING_COLLISION    = 0
AutoLoaderExtended.WARNING_UNLOADED     = 1
AutoLoaderExtended.WARNING_DISTANCE     = 2
AutoLoaderExtended.WARNING_DISTANCE_MAX = 3
AutoLoaderExtended.WARNING_INVALID      = 4

function AutoLoaderExtended:showWarningMessage(index, noEventSend, distance)
    if self:getIsActiveForInput(true) then
        local txt = {
            g_i18n:getText("autoLoader_warning_0"), -- Collision check
            g_i18n:getText("autoLoader_warning_1"), -- Abort, unloaded by someone else
            g_i18n:getText("autoLoader_warning_2"), -- Distance warning
            g_i18n:getText("autoLoader_warning_3"), -- Distance abort
            g_i18n:getText("autoLoader_warning_4")  -- Invalid type
        }

        g_currentMission:showBlinkingWarning(string.format(txt[index + 1], distance, self.spec_autoLoaderExtended.unload.distanceMax), 2000)
    end

    if self.isServer then
        if noEventSend == nil or not noEventSend then
            g_server:broadcastEvent(AutoLoaderExtendedShowMessageEvent.new(self, index), nil, nil, self)
        end
    end
end

-- Fix wrapping state

function AutoLoaderExtended.createDummyBale(xmlFilename, fillTypeIndex, wrappingState, wrappingColor)
    local baleId, sharedLoadRequestId = Bale.createDummyBale(xmlFilename, fillTypeIndex)

    if baleId ~= nil then
        local xmlFile = XMLFile.load("TempBale", xmlFilename, BaleManager.baleXMLSchema)
        local _, baseDirectory = Utils.getModNameAndBaseDirectory(xmlFilename)

        local meshes = Bale.loadVisualMeshesFromXML(baleId, xmlFile, baseDirectory)

        for i = 1, #meshes do
            local meshData = meshes[i]
            if meshData.supportsWrapping then
                setShaderParameter(meshData.node, "wrappingState", wrappingState, 0, 0, 0, false)
                setShaderParameter(meshData.node, "colorScale", wrappingColor[1], wrappingColor[2], wrappingColor[3], wrappingColor[4], false)
            end
        end

        Bale.updateVisualMeshVisibility(meshes, fillTypeIndex, wrappingState ~= 0)

        xmlFile:delete()
    end

    return baleId, sharedLoadRequestId
end

function AutoLoaderExtended.createDummyPallet(i3dFilename)
    local palletId
    local palletRoot, sharedLoadRequestId = g_i3DManager:loadSharedI3DFile(i3dFilename, false, false)

    if palletRoot ~= 0 then
        palletId = getChildAt(palletRoot, 0)
        setRigidBodyType(palletId, RigidBodyType.NONE)
        unlink(palletId)
        delete(palletRoot)
    end

    return palletId, sharedLoadRequestId
end

-- Debug

function AutoLoaderExtended:updateDebugValues(values)
    local spec = self.spec_autoLoaderExtended
    
    local txtModes = {
        "Off",
        "Load",
        "Unload"
    }
    
    local txtStates = {
        "Off",
        "Loading: Searching",
        "Loading: Loading object",
        "Loading: Strapping load",
        "Loading: Fully loaded!",
        "Unloading: Init",
        "Unloading: Confirm position",
        "Unloading: Unloading",
        "Unloading: Complete"
    }

    table.insert(values, {name = "Mode -", value = string.format("%s", txtModes[spec.currentMode + 1])})

    if self.isServer then
        table.insert(values, {name = "State -",               value = string.format("%s", txtStates[spec.currentState + 1])})
    end

    table.insert(values, {name = "Allowed to unload",     value = string.format("%s", tostring(spec.unload.showUnloadInput))})
    table.insert(values, {name = "Current unload side -", value = string.format("%d", spec.unload.currentSideIndex)})
    
    if self.isServer then
        table.insert(values, {name = "Current loadSpaceId -", value = string.format("%d", spec.load.currentSpaceIndex)})
        table.insert(values, {name = "Force Active State -",  value = string.format("%s", tostring(spec.forceActiveState))})
        -- table.insert(values, {name = "AutoLoading Allowed -", value = string.format("%s", tostring(self:getIsAutoLoadingAllowed()))})
        table.insert(values, {name = "Timer -",               value = string.format("%.4f", math.max(spec.times.current, 0))})
        
        table.insert(values, {name = "Pending pickup objects -",   value = string.format("%d", #spec.pickup.pending.sorted)})
        table.insert(values, {name = "Inside Unload trigger -", value = string.format("%d", spec.unload.pending.num)}) -- Fail safe
    end

    if spec.unload.current ~= nil then
        table.insert(values, {name = "Pending unload objects -",  value = string.format("%d", #spec.unload.current.tempVisual)})
    end

    -- table.insert(values, {name = "Collision check, allow unload -",  value = string.format("%s", tostring(spec.unload.allowUnloadInput))})
end
