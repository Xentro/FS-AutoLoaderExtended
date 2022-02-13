-- 
-- AutoLoaderExtendedSetModeEvent
--
-- Author:  Xentro
-- Website: https://xentro.se, https://github.com/Xentro
--

AutoLoaderExtendedSetModeEvent = {}
local AutoLoaderExtendedSetModeEvent_mt = Class(AutoLoaderExtendedSetModeEvent, Event)

InitEventClass(AutoLoaderExtendedSetModeEvent, "AutoLoaderExtendedSetModeEvent")

function AutoLoaderExtendedSetModeEvent.emptyNew()
    local self = Event.new(AutoLoaderExtendedSetModeEvent_mt)

    return self
end

function AutoLoaderExtendedSetModeEvent.new(vehicle, mode)
    local self = AutoLoaderExtendedSetModeEvent.emptyNew()

    self.vehicle = vehicle
    self.mode = mode

    return self
end

function AutoLoaderExtendedSetModeEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.mode = streamReadUIntN(streamId, AutoLoaderExtended.SEND_NUM_BITS)

    self:run(connection)
end

function AutoLoaderExtendedSetModeEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteUIntN(streamId, self.mode, AutoLoaderExtended.SEND_NUM_BITS)
end

function AutoLoaderExtendedSetModeEvent:run(connection)
    if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
		self.vehicle:setMode(self.mode, true)
	end

    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.vehicle)
    end
end

function AutoLoaderExtendedSetModeEvent.sendEvent(vehicle, mode, noEventSend)
    if noEventSend == nil or not noEventSend then
        if g_server ~= nil then
            -- Server -> Client
            g_server:broadcastEvent(AutoLoaderExtendedSetModeEvent.new(vehicle, mode), nil, nil, vehicle)
        else
            -- Client -> Server
            g_client:getServerConnection():sendEvent(AutoLoaderExtendedSetModeEvent.new(vehicle, mode))
        end
    end
end