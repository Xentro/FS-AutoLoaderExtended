-- 
-- AutoLoaderExtendedSetHelperEvent
--
-- Author:  Xentro
-- Website: https://xentro.se, https://github.com/Xentro
--

AutoLoaderExtendedSetHelperEvent = {
    SEND_NUM_BITS = 2
}
local AutoLoaderExtendedSetHelperEvent_mt = Class(AutoLoaderExtendedSetHelperEvent, Event)

InitEventClass(AutoLoaderExtendedSetHelperEvent, "AutoLoaderExtendedSetHelperEvent")

function AutoLoaderExtendedSetHelperEvent.emptyNew()
    local self = Event.new(AutoLoaderExtendedSetHelperEvent_mt)

    return self
end

function AutoLoaderExtendedSetHelperEvent.new(vehicle, status)
    local self = AutoLoaderExtendedSetHelperEvent.emptyNew()

    self.vehicle = vehicle
    self.status = status

    return self
end

function AutoLoaderExtendedSetHelperEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.status = streamReadUIntN(streamId, AutoLoaderExtendedSetHelperEvent.SEND_NUM_BITS)

    self:run(connection)
end

function AutoLoaderExtendedSetHelperEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteUIntN(streamId, math.abs(self.status), AutoLoaderExtended.SEND_NUM_BITS)
end

function AutoLoaderExtendedSetHelperEvent:run(connection)
    if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
        self.vehicle:setHelperStatus(-self.status)
    end
end