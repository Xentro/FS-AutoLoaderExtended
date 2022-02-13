-- 
-- AutoLoaderExtendedSetUnloadSideEvent
--
-- Author:  Xentro
-- Website: https://xentro.se, https://github.com/Xentro
--

AutoLoaderExtendedSetUnloadSideEvent = {}
local AutoLoaderExtendedSetUnloadSideEvent_mt = Class(AutoLoaderExtendedSetUnloadSideEvent, Event)

InitEventClass(AutoLoaderExtendedSetUnloadSideEvent, "AutoLoaderExtendedSetUnloadSideEvent")

function AutoLoaderExtendedSetUnloadSideEvent.emptyNew()
    local self = Event.new(AutoLoaderExtendedSetUnloadSideEvent_mt)

    return self
end

function AutoLoaderExtendedSetUnloadSideEvent.new(vehicle, sideIndex)
    local self = AutoLoaderExtendedSetUnloadSideEvent.emptyNew()

    self.vehicle = vehicle
    self.sideIndex = sideIndex

    return self
end

function AutoLoaderExtendedSetUnloadSideEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.sideIndex = streamReadInt8(streamId)

    self:run(connection)
end

function AutoLoaderExtendedSetUnloadSideEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteInt8(streamId, self.sideIndex)
end

function AutoLoaderExtendedSetUnloadSideEvent:run(connection)
    if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
		self.vehicle:setUnloadSide(self.sideIndex, true)
	end

    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.vehicle)
    end
end

function AutoLoaderExtendedSetUnloadSideEvent.sendEvent(vehicle, sideIndex, noEventSend)
    if noEventSend == nil or not noEventSend then
        if g_server ~= nil then
            -- Server -> Client
            g_server:broadcastEvent(AutoLoaderExtendedSetUnloadSideEvent.new(vehicle, sideIndex), nil, nil, vehicle)
        else
            -- Client -> Server
            g_client:getServerConnection():sendEvent(AutoLoaderExtendedSetUnloadSideEvent.new(vehicle, sideIndex))
        end
    end
end