-- 
-- AutoLoaderExtendedLoadObjectEvent
--
-- Author:  Xentro
-- Website: https://xentro.se, https://github.com/Xentro
--

AutoLoaderExtendedLoadObjectEvent = {}
local AutoLoaderExtendedLoadObjectEvent_mt = Class(AutoLoaderExtendedLoadObjectEvent, Event)

InitEventClass(AutoLoaderExtendedLoadObjectEvent, "AutoLoaderExtendedLoadObjectEvent")

function AutoLoaderExtendedLoadObjectEvent.emptyNew()
    local self = Event.new(AutoLoaderExtendedLoadObjectEvent_mt)

    return self
end

function AutoLoaderExtendedLoadObjectEvent.new(vehicle, object, spaceIndex, locationIndex)
    local self = AutoLoaderExtendedLoadObjectEvent.emptyNew()

    self.vehicle = vehicle
    self.object = object
    self.spaceIndex = spaceIndex
    self.locationIndex = locationIndex

    return self
end

function AutoLoaderExtendedLoadObjectEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.object = NetworkUtil.readNodeObject(streamId)
    self.spaceIndex = streamReadInt8(streamId)
    self.locationIndex = streamReadInt8(streamId)

    self:run(connection)
end

function AutoLoaderExtendedLoadObjectEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    NetworkUtil.writeNodeObject(streamId, self.object)
    streamWriteInt8(streamId, self.spaceIndex)
    streamWriteInt8(streamId, self.locationIndex)
end

function AutoLoaderExtendedLoadObjectEvent:run(connection)
    local spec = self.vehicle.spec_autoLoaderExtended
    local node = spec.load.loadSpaces[self.spaceIndex].nodes[self.locationIndex]
    
    local x, y, z    = getWorldTranslation(node)
    local rx, ry, rz = getWorldRotation(node)
    local quatX, quatY, quatZ, quatW = mathEulerToQuaternion(rx, ry, rz)
    
    if self.object.nodeId ~= nil then
        self.object:setWorldPositionQuaternion(x, y, z, quatX, quatY, quatZ, quatW, true)    -- Bales
    else
        self.object:setWorldPositionQuaternion(x, y, z, quatX, quatY, quatZ, quatW, 1, true) -- Pallets, Component 1
    end
end