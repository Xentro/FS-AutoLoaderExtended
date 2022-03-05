-- 
-- AutoLoaderExtendedUnloadStateEvent
--
-- Author:  Xentro
-- Website: https://xentro.se, https://github.com/Xentro
--

AutoLoaderExtendedUnloadStateEvent = {
    CLIENT_STATE_SHOW_UNLOAD        = 0, -- Show key input for unload
    CLIENT_STATE_INIT_UNLOAD        = 1, -- Create current table
    CLIENT_STATE_LOAD_TEMP_OBJECT   = 2, -- Load dummy objects and place them
    CLIENT_STATE_ALLOW_SIDES        = 3, -- Player input required, allowed to change unload side
    CLIENT_STATE_PRE_UNLOAD         = 4, -- Link key node to world
    CLIENT_STATE_UNLOADING          = 5, -- Unloading object
    CLIENT_STATE_DELETE_TEMP_OBJECT = 6, -- Delete dummy objects as they are unloaded
    CLIENT_STATE_END_UNLOAD         = 7, -- Unloading is done

    SERVER_STATE_PRE_UNLOAD = 8, -- Link key node to world, send position to CLIENT_STATE_PRE_UNLOAD

    SEND_NUM_BITS = 4
}

local AutoLoaderExtendedInitUnloadEvent_mt = Class(AutoLoaderExtendedUnloadStateEvent, Event)

InitEventClass(AutoLoaderExtendedUnloadStateEvent, "AutoLoaderExtendedUnloadStateEvent")

function AutoLoaderExtendedUnloadStateEvent.emptyNew()
    local self = Event.new(AutoLoaderExtendedInitUnloadEvent_mt)

    return self
end

function AutoLoaderExtendedUnloadStateEvent.new(vehicle, state, entry)
    local self = AutoLoaderExtendedUnloadStateEvent.emptyNew()

    self.vehicle = vehicle
    self.state = state

    if self.state == AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_SHOW_UNLOAD then
        self.showUnloadInput = entry

    elseif self.state == AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_LOAD_TEMP_OBJECT then
        self.typeId = entry.typeId
        self.object = entry.object
    
    elseif self.state == AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_PRE_UNLOAD then
        self.position = {entry[1], entry[2], entry[3]}
        self.rotation = {entry[4], entry[5], entry[6]}

    elseif self.state == AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_UNLOADING then
        self.typeId = entry.typeId
        self.index = entry.index
        self.object = entry.object

    elseif self.state == AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_DELETE_TEMP_OBJECT then
        self.typeId = entry.typeId
        self.index = entry.index
    end

    return self
end

function AutoLoaderExtendedUnloadStateEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.state = streamReadUIntN(streamId, AutoLoaderExtendedUnloadStateEvent.SEND_NUM_BITS)

    if self.state == AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_SHOW_UNLOAD then
        self.showUnloadInput = streamReadBool(streamId)

    elseif self.state == AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_LOAD_TEMP_OBJECT 
        or self.state == AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_UNLOADING 
        or self.state == AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_DELETE_TEMP_OBJECT then
        self.typeId = streamReadInt8(streamId)
    end

    if self.state == AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_LOAD_TEMP_OBJECT 
    or self.state == AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_UNLOADING then
        self.object = NetworkUtil.readNodeObject(streamId)
    end

    if self.state == AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_UNLOADING 
    or self.state == AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_DELETE_TEMP_OBJECT then
        self.index = streamReadInt8(streamId)
    end

    if self.state == AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_PRE_UNLOAD then
        self.position ={
            NetworkUtil.readCompressedWorldPosition(streamId, g_currentMission.vehicleXZPosCompressionParams),
            NetworkUtil.readCompressedWorldPosition(streamId, g_currentMission.vehicleYPosCompressionParams),
            NetworkUtil.readCompressedWorldPosition(streamId, g_currentMission.vehicleXZPosCompressionParams)
        }
		self.rotation = {
            NetworkUtil.readCompressedAngle(streamId),
            NetworkUtil.readCompressedAngle(streamId),
            NetworkUtil.readCompressedAngle(streamId)
        }
    end

    self:run(connection)
end

function AutoLoaderExtendedUnloadStateEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteUIntN(streamId, self.state, AutoLoaderExtendedUnloadStateEvent.SEND_NUM_BITS)

    if self.state == AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_SHOW_UNLOAD then
        streamWriteBool(streamId, self.showUnloadInput)

    elseif self.state == AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_LOAD_TEMP_OBJECT 
        or self.state == AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_UNLOADING 
        or self.state == AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_DELETE_TEMP_OBJECT then
        streamWriteInt8(streamId, self.typeId)
    end

    if self.state == AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_LOAD_TEMP_OBJECT 
    or self.state == AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_UNLOADING then
        NetworkUtil.writeNodeObject(streamId, self.object)
    end

    if self.state == AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_UNLOADING 
    or self.state == AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_DELETE_TEMP_OBJECT then
        streamWriteInt8(streamId, self.index)
    end

    if self.state == AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_PRE_UNLOAD then
        NetworkUtil.writeCompressedWorldPosition(streamId, self.position[1], g_currentMission.vehicleXZPosCompressionParams)
		NetworkUtil.writeCompressedWorldPosition(streamId, self.position[2], g_currentMission.vehicleYPosCompressionParams)
		NetworkUtil.writeCompressedWorldPosition(streamId, self.position[3], g_currentMission.vehicleXZPosCompressionParams)
		NetworkUtil.writeCompressedAngle(streamId, self.rotation[1])
		NetworkUtil.writeCompressedAngle(streamId, self.rotation[2])
		NetworkUtil.writeCompressedAngle(streamId, self.rotation[3])
    end
end

function AutoLoaderExtendedUnloadStateEvent:run(connection)
    local spec = self.vehicle.spec_autoLoaderExtended

    if self.state == AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_SHOW_UNLOAD then
        spec.unload.showUnloadInput = self.showUnloadInput
        AutoLoaderExtended.updateActionText(self.vehicle)

    elseif self.state == AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_INIT_UNLOAD then
        if spec.unload.current == nil then
            -- print("Unload, State " .. AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_INIT_UNLOAD .. ": Creating table")

            local current = {
                curSize    = {0, 0, 0}, -- Calculate the placement size
                curPos     = {0, 0, 0}, -- Calculate position for temp object
                unloadSize = {0, 0, 0}, -- Collision box
                lastTypeId = nil,       -- Reset curPos if new type
                objects    = {},        -- found objects
                tempVisual = {},        -- temp objects
                masterUnloadNode     = createTransformGroup("temp_autoLoaderUnloadMaster"), -- link all temp objects to this
                allowToggleUnloadSide = false
            }
            
            local side = spec.unload.sides[spec.unload.currentSideIndex]
            link(side.node, current.masterUnloadNode)
            setTranslation(current.masterUnloadNode, 0, side.offsetY, 0) -- Offset from ground

            spec.unload.current = current
        end

    elseif self.state == AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_LOAD_TEMP_OBJECT then
        -- print("Unload, State " .. AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_LOAD_TEMP_OBJECT .. ": Loading object " .. #spec.unload.current.tempVisual + 1)
        if self.object ~= nil then
            local objectNode, sharedLoadRequestId
            local type = spec.unload.types[self.typeId]
            
            if type.isBale then
                objectNode, sharedLoadRequestId = AutoLoaderExtended.createDummyBale(self.object.xmlFilename, self.object.fillType, self.object.wrappingState, self.object.wrappingColor)
            elseif type.isPallet then
                objectNode, sharedLoadRequestId = AutoLoaderExtended.createDummyPallet(self.object.i3dFilename)
            end

            local entry = {
                self.typeId,
                objectNode,
                sharedLoadRequestId,
                self.object
            }
            self.vehicle:placeDummyObjects(spec.unload.current, true, entry)
        end

    elseif self.state == AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_ALLOW_SIDES then
        -- print("Unload, State " .. AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_ALLOW_SIDES .. ": Loading is done, we loaded " .. #spec.unload.current.tempVisual .. " objects. Player needs to confirm placement")
        
        local width, height, length = spec.unload.current.unloadSize[1], spec.unload.current.unloadSize[2], spec.unload.current.unloadSize[3]
        local side = spec.unload.sides[spec.unload.currentSideIndex]
        local x, y, z = width / 2, height / 2, length / 2
        
        if not side.isLeft then
            x = -x
        end
        
        local temp = createTransformGroup("temp_autoLoaderDrawUnloadOverlapBox")
        link(side.node, temp)
        setTranslation(temp, x, y + side.offsetY, -z)
        
        spec.unload.current.overlapBoxLocation = temp
        spec.unload.current.allowToggleUnloadSide = true
        AutoLoaderExtended.updateActionText(self.vehicle)

    elseif self.state == AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_PRE_UNLOAD or self.state == AutoLoaderExtendedUnloadStateEvent.SERVER_STATE_PRE_UNLOAD then
        if spec.unload.current.overlapBoxLocation ~= nil then
            delete(spec.unload.current.overlapBoxLocation)
        end
        spec.unload.current.allowToggleUnloadSide = false
        spec.unload.current.overlapBoxLocation = nil

        AutoLoaderExtended.updateActionText(self.vehicle)

        if self.state == AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_PRE_UNLOAD then
            -- print("Unload, State " .. AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_PRE_UNLOAD .. ": Pre Unloading - Position from server")
        
            link(getRootNode(), spec.unload.current.masterUnloadNode)

            setTranslation(spec.unload.current.masterUnloadNode, self.position[1], self.position[2], self.position[3])
            setRotation(spec.unload.current.masterUnloadNode, self.rotation[1], self.rotation[2], self.rotation[3])

        elseif self.state == AutoLoaderExtendedUnloadStateEvent.SERVER_STATE_PRE_UNLOAD then
            -- print("Unload, State " .. AutoLoaderExtendedUnloadStateEvent.SERVER_STATE_PRE_UNLOAD .. ": Pre Unloading - Player confirmed placement to server")

            local x, y, z = getWorldTranslation(spec.unload.current.masterUnloadNode)
            local rx, ry, rz = getWorldRotation(spec.unload.current.masterUnloadNode)

            link(getRootNode(), spec.unload.current.masterUnloadNode)

            setTranslation(spec.unload.current.masterUnloadNode, x, y, z)
            setRotation(spec.unload.current.masterUnloadNode, rx, ry, rz)

            if g_server ~= nil then
                g_server:broadcastEvent(AutoLoaderExtendedUnloadStateEvent.new(self.vehicle, AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_PRE_UNLOAD, {x, y, z, rx, ry, rz}), nil, nil, self.vehicle)
                self.vehicle:setState(AutoLoaderExtended.STATE_UNLOAD_UNLOADING)
            end
        end

    elseif self.state == AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_UNLOADING or self.state == AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_DELETE_TEMP_OBJECT then
        local temp = spec.unload.current.tempVisual[self.index]

        if temp ~= nil then
            if self.state == AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_UNLOADING then
                -- print("Unload, State " .. AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_UNLOADING .. ": Unloading " .. #spec.unload.current.tempVisual)

                local x, y, z    = getWorldTranslation(temp.objectRoot)
                local rx, ry, rz = getWorldRotation(temp.objectRoot)
                local quatX, quatY, quatZ, quatW = mathEulerToQuaternion(rx, ry, rz)

                if self.object ~= nil then
                    if self.object.nodeId ~= nil then
                        self.object:setWorldPositionQuaternion(x, y, z, quatX, quatY, quatZ, quatW, true)    -- Bales
                    else
                        self.object:setWorldPositionQuaternion(x, y, z, quatX, quatY, quatZ, quatW, 1, true) -- Pallets, Component 1
                    end
                end
            end

            delete(temp.objectRoot)

            if temp.sharedLoadRequestId ~= nil then
                g_i3DManager:releaseSharedI3DFile(temp.sharedLoadRequestId)
            end

            table.remove(spec.unload.current.tempVisual, self.index)

            -- Remove index we do not want loaded since they been deleted
            if self.vehicle.synchronizedOnUpdate ~= nil then
                table.remove(self.vehicle.synchronizedOnUpdate.objects[self.typeId], self.index)

                if #self.vehicle.synchronizedOnUpdate.objects[self.typeId] == 0 then
                    self.vehicle.synchronizedOnUpdate.objects[self.typeId] = nil
                end

                if next(self.vehicle.synchronizedOnUpdate.objects) == nil then
                    self.vehicle.synchronizedOnUpdate = nil
                end
            end
        end

    elseif self.state == AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_END_UNLOAD then
        -- print("Unload, State " .. AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_END_UNLOAD .. ": Unloading have been completed or aborted, cleaning up!")

        for i, v in ipairs (spec.unload.current.tempVisual) do
            delete(v.objectRoot)

            if v.sharedLoadRequestId ~= nil then
                g_i3DManager:releaseSharedI3DFile(v.sharedLoadRequestId)
            end
        end

        if spec.unload.current.overlapBoxLocation ~= nil then
            delete(spec.unload.current.overlapBoxLocation)
        end
        delete(spec.unload.current.masterUnloadNode)
        spec.unload.current.overlapBoxLocation = nil
        spec.unload.current = nil

        self.vehicle.synchronizedOnUpdate = nil
    end
end