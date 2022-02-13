-- 
-- AutoLoaderExtendedShowMessageEvent
--
-- Author:  Xentro
-- Website: https://xentro.se, https://github.com/Xentro
--

AutoLoaderExtendedShowMessageEvent = {
    SEND_NUM_BITS = 2
}
local AutoLoaderExtendedShowMessageEvent_mt = Class(AutoLoaderExtendedShowMessageEvent, Event)

InitEventClass(AutoLoaderExtendedShowMessageEvent, "AutoLoaderExtendedShowMessageEvent")

function AutoLoaderExtendedShowMessageEvent.emptyNew()
    local self = Event.new(AutoLoaderExtendedShowMessageEvent_mt)

    return self
end

function AutoLoaderExtendedShowMessageEvent.new(vehicle, messageIndex)
    local self = AutoLoaderExtendedShowMessageEvent.emptyNew()

    self.vehicle = vehicle
    self.messageIndex = messageIndex

    return self
end

function AutoLoaderExtendedShowMessageEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.messageIndex = streamReadUIntN(streamId, AutoLoaderExtendedShowMessageEvent.SEND_NUM_BITS)

    self:run(connection)
end

function AutoLoaderExtendedShowMessageEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteUIntN(streamId, self.messageIndex, AutoLoaderExtendedShowMessageEvent.SEND_NUM_BITS)
end

function AutoLoaderExtendedShowMessageEvent:run(connection)
    self.vehicle:showWarningMessage(self.messageIndex)
end