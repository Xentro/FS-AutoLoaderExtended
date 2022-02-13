-- 
-- AutoLoaderExtendedSynchEvent
--
-- Author:  Xentro
-- Website: https://xentro.se, https://github.com/Xentro
--

AutoLoaderExtendedSynchEvent = {
    CLIENT_REQUEST_UPDATE = 0,
    SERVER_SENT_UPDATE    = 1,

    SEND_NUM_BITS = 2
}
local AutoLoaderExtendedSynchEvent_mt = Class(AutoLoaderExtendedSynchEvent, Event)

InitEventClass(AutoLoaderExtendedSynchEvent, "AutoLoaderExtendedSynchEvent")

function AutoLoaderExtendedSynchEvent.emptyNew()
    local self = Event.new(AutoLoaderExtendedSynchEvent_mt)

    return self
end

function AutoLoaderExtendedSynchEvent.new(vehicle, state, serverState)
    local self = AutoLoaderExtendedSynchEvent.emptyNew()

    self.vehicle = vehicle
    self.state = state
    self.serverState = serverState

    return self
end

function AutoLoaderExtendedSynchEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.state = streamReadUIntN(streamId, AutoLoaderExtendedSynchEvent.SEND_NUM_BITS)

    if self.state == AutoLoaderExtendedSynchEvent.SERVER_SENT_UPDATE then
        self.serverState = streamReadUIntN(streamId, 4)

        if self.serverState == AutoLoaderExtended.STATE_UNLOAD_UNLOADING then
            self.preUnload = {
                vehicle = self.vehicle,
                state = AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_PRE_UNLOAD,
                position = {
                    NetworkUtil.readCompressedWorldPosition(streamId, g_currentMission.vehicleXZPosCompressionParams),
                    NetworkUtil.readCompressedWorldPosition(streamId, g_currentMission.vehicleYPosCompressionParams),
                    NetworkUtil.readCompressedWorldPosition(streamId, g_currentMission.vehicleXZPosCompressionParams)
                },
                rotation = {
                    NetworkUtil.readCompressedAngle(streamId),
                    NetworkUtil.readCompressedAngle(streamId),
                    NetworkUtil.readCompressedAngle(streamId)
                }
            }
        end
    end

    self:run(connection)
end

function AutoLoaderExtendedSynchEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteUIntN(streamId, self.state, AutoLoaderExtendedSynchEvent.SEND_NUM_BITS)

    if self.state == AutoLoaderExtendedSynchEvent.SERVER_SENT_UPDATE then
        streamWriteUIntN(streamId, self.serverState, 4)
        
        if self.serverState == AutoLoaderExtended.STATE_UNLOAD_UNLOADING then
            local node = self.vehicle.spec_autoLoaderExtended.unload.current.masterUnloadNode
            local x, y, z = getWorldTranslation(node)
            local rx, ry, rz = getWorldRotation(node)

            NetworkUtil.writeCompressedWorldPosition(streamId, x, g_currentMission.vehicleXZPosCompressionParams)    
            NetworkUtil.writeCompressedWorldPosition(streamId, y, g_currentMission.vehicleYPosCompressionParams)
            NetworkUtil.writeCompressedWorldPosition(streamId, z, g_currentMission.vehicleXZPosCompressionParams)
            NetworkUtil.writeCompressedAngle(streamId, rx)
            NetworkUtil.writeCompressedAngle(streamId, ry)
            NetworkUtil.writeCompressedAngle(streamId, rz)
        end
    end
end

function AutoLoaderExtendedSynchEvent:run(connection)
    if self.state == AutoLoaderExtendedSynchEvent.CLIENT_REQUEST_UPDATE then
        if g_server ~= nil then
            g_server:broadcastEvent(AutoLoaderExtendedSynchEvent.new(self.vehicle, AutoLoaderExtendedSynchEvent.SERVER_SENT_UPDATE, self.vehicle.spec_autoLoaderExtended.currentState), nil, nil, self.vehicle)
        end

    elseif self.state == AutoLoaderExtendedSynchEvent.SERVER_SENT_UPDATE then
        if self.vehicle.synchronizedOnUpdate ~= nil then
            if self.serverState == AutoLoaderExtended.STATE_UNLOAD_PLAYER then
                -- Allow us to confirm unload, toggle sides
                AutoLoaderExtendedUnloadStateEvent.run({vehicle = self.vehicle, state = AutoLoaderExtendedUnloadStateEvent.CLIENT_STATE_ALLOW_SIDES})

            elseif self.serverState == AutoLoaderExtended.STATE_UNLOAD_UNLOADING then
                -- Link master node to world
                AutoLoaderExtendedUnloadStateEvent.run(self.preUnload)

                -- We shouldnt need to do more since server does the rest 
            end

            self.vehicle.synchronizedOnUpdate = nil
        end
    end
end