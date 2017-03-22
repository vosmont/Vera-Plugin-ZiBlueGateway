--[[
  This file is part of the plugin ZiBlue Gateway.
  https://github.com/vosmont/Vera-Plugin-ZiBlueGateway
  Copyright (c) 2017 Vincent OSMONT
  This code is released under the MIT License, see LICENSE.
--]]

module( "L_ZiBlueGateway1", package.seeall )

-- Load libraries
local status, json = pcall( require, "dkjson" )


-- **************************************************
-- Plugin constants
-- **************************************************

_NAME = "ZiBlueGateway"
_DESCRIPTION = "ZiBlue gateway for the Vera"
_VERSION = "0.5"
_AUTHOR = "vosmont"


-- **************************************************
-- Generic utilities
-- **************************************************

function log( msg, methodName, lvl )
	local lvl = lvl or 50
	if ( methodName == nil ) then
		methodName = "UNKNOWN"
	else
		methodName = "(" .. _NAME .. "::" .. tostring( methodName ) .. ")"
	end
	luup.log( string_rpad( methodName, 45 ) .. " " .. tostring( msg ), lvl )
end

local function debug() end

local function warning( msg, methodName )
	log( msg, methodName, 2 )
end

local g_errors = {}
local function error( msg, methodName, notifyOnUI )
	table.insert( g_errors, { os.time(), methodName or "", tostring( msg ) } )
	if ( #g_errors > 100 ) then
		table.remove( g_errors, 1 )
	end
	log( msg, methodName, 1 )
	if ( notifyOnUI ~= false ) then
		UI.showError( "Error (see tab)" )
	end
end


-- **************************************************
-- Constants
-- **************************************************

-- This table defines all device variables that are used by the plugin
-- Each entry is a table of 4 elements:
-- 1) the service ID
-- 2) the variable name
-- 3) true if the variable is not updated when the value is unchanged
-- 4) variable that is used for the timestamp
local VARIABLE = {
	-- Sensors
	TEMPERATURE = { "urn:upnp-org:serviceId:TemperatureSensor1", "CurrentTemperature", true },
	HUMIDITY = { "urn:micasaverde-com:serviceId:HumiditySensor1", "CurrentLevel", true },
	LIGHT_LEVEL = { "urn:micasaverde-com:serviceId:LightSensor1", "CurrentLevel", true },
	PRESSURE = { "urn:micasaverde-com:serviceId:BarometerSensor1", "CurrentPressure", true },
	FORECAST = { "urn:micasaverde-com:serviceId:BarometerSensor1", "Forecast", true },
	WIND_DIRECTION = { "urn:micasaverde-com:serviceId:WindSensor1", "Direction", true },
	WIND_GUST_SPEED = { "urn:micasaverde-com:serviceId:WindSensor1", "GustSpeed", true },
	WIND_AVERAGE_SPEED = { "urn:micasaverde-com:serviceId:WindSensor1", "AvgSpeed", true },
	RAIN = { "urn:upnp-org:serviceId:RainSensor1", "CurrentTRain", true },
	RAIN_RATE = { "urn:upnp-org:serviceId:RainSensor1", "CurrentRain", true }, -- TODO ??
	UV = { "urn:micasaverde-com:serviceId:UvSensor1", "CurrentLevel", true },
	-- Switches
	SWITCH_POWER = { "urn:upnp-org:serviceId:SwitchPower1", "Status", true },
	DIMMER_LEVEL = { "urn:upnp-org:serviceId:Dimming1", "LoadLevelStatus", true },
	DIMMER_LEVEL_OLD = { "urn:upnp-org:serviceId:ZiBlueDevice1", "LoadLevelStatus", true },
	DIMMER_DIRECTION = { "urn:upnp-org:serviceId:ZiBlueDevice1", "LoadLevelDirection", true },
	DIMMER_STEP = { "urn:upnp-org:serviceId:ZiBlueDevice1", "DimmingStep", true },
	--PULSE_MODE = { "urn:upnp-org:serviceId:ZiBlueDevice1", "PulseMode", true },
	--TOGGLE_MODE = { "urn:upnp-org:serviceId:ZiBlueDevice1", "ToggleMode", true },
	--IGNORE_BURST_TIME = { "urn:upnp-org:serviceId:ZiBlueDevice1", "IgnoreBurstTime", true },
	-- Security
	ARMED = { "urn:micasaverde-com:serviceId:SecuritySensor1", "Armed", true },
	TRIPPED = { "urn:micasaverde-com:serviceId:SecuritySensor1", "Tripped", false, "LAST_TRIP" },
	ARMED_TRIPPED = { "urn:micasaverde-com:serviceId:SecuritySensor1", "ArmedTripped", false, "LAST_TRIP" },
	LAST_TRIP = { "urn:micasaverde-com:serviceId:SecuritySensor1", "LastTrip", true },
	TAMPER_ALARM = { "urn:micasaverde-com:serviceId:SecuritySensor1", "sl_TamperAlarm", false }, -- TODO : date pour alarm ?
	--LAST_TAMPER = { "urn:micasaverde-com:serviceId:SecuritySensor1", "LastTamper", true },
	-- Battery
	BATTERY_LEVEL = { "urn:micasaverde-com:serviceId:HaDevice1", "BatteryLevel", true, "BATTERY_DATE" },
	BATTERY_DATE = { "urn:micasaverde-com:serviceId:HaDevice1", "BatteryDate", true },
	-- Energy metering
	WATTS = { "urn:micasaverde-com:serviceId:EnergyMetering1", "Watts", true },
	KWH = { "urn:micasaverde-com:serviceId:EnergyMetering1", "KWH", true, "KWH_DATE" },
	KWH_DATE = { "urn:micasaverde-com:serviceId:EnergyMetering1", "KWHReading", true },
	-- IO connection
	IO_DEVICE = { "urn:micasaverde-com:serviceId:HaDevice1", "IODevice", true },
	IO_PORT_PATH = { "urn:micasaverde-com:serviceId:HaDevice1", "IOPortPath", true },
	BAUD = { "urn:micasaverde-org:serviceId:SerialPort1", "baud", true },
	STOP_BITS = { "urn:micasaverde-org:serviceId:SerialPort1", "stopbits", true },
	DATA_BITS = { "urn:micasaverde-org:serviceId:SerialPort1", "databits", true },
	PARITY = { "urn:micasaverde-org:serviceId:SerialPort1", "parity", true },
	-- Communication failure
	COMM_FAILURE = { "urn:micasaverde-com:serviceId:HaDevice1", "CommFailure", false, "COMM_FAILURE_TIME" },
	COMM_FAILURE_TIME = { "urn:micasaverde-com:serviceId:HaDevice1", "CommFailureTime", true },
	-- ZiBlue gateway
	PLUGIN_VERSION = { "urn:upnp-org:serviceId:ZiBlueGateway1", "PluginVersion", true },
	DEBUG_MODE = { "urn:upnp-org:serviceId:ZiBlueGateway1", "DebugMode", true },
	LAST_DISCOVERED = { "urn:upnp-org:serviceId:ZiBlueGateway1", "LastDiscovered", true },
	LAST_UPDATE = { "urn:upnp-org:serviceId:ZiBlueGateway1", "LastUpdate", true },
	LAST_MESSAGE = { "urn:upnp-org:serviceId:ZiBlueGateway1", "LastMessage", true },
	ZIBLUE_VERSION = { "urn:upnp-org:serviceId:ZiBlueGateway1", "ZiBlueVersion", true },
	ZIBLUE_MAC = { "urn:upnp-org:serviceId:ZiBlueGateway1", "ZiBlueMac", true },
	-- ZiBlue device
	FEATURE = { "urn:upnp-org:serviceId:ZiBlueDevice1", "Feature", true },
	ASSOCIATION = { "urn:upnp-org:serviceId:ZiBlueDevice1", "Association", true },
	SETTING = { "urn:upnp-org:serviceId:ZiBlueDevice1", "Setting", true },
	BURST = { "urn:upnp-org:serviceId:ZiBlueDevice1", "Burst", true }
}

-- Device types (with ZiBlue commands/actions)
local DEVICE = {
	SERIAL_PORT = {
		type = "urn:micasaverde-org:device:SerialPort:1", file = "D_SerialPort1.xml"
	},
	DOOR_SENSOR = {
		name = "ui7_device_type_door_sensor",
		type = "urn:schemas-micasaverde-com:device:DoorSensor:1", file = "D_DoorSensor1.xml",
		parameters = { { "ARMED", "0" }, { "TRIPPED", "0" } },
		commands = {
			[ "ON" ] = function( ziBlueDevice, feature )
				DeviceHelper.setTripped( ziBlueDevice, feature, "1" )
			end,
			[ "OFF" ] = function( ziBlueDevice, feature )
				DeviceHelper.setTripped( ziBlueDevice, feature, "0" )
			end
		}
	},
	MOTION_SENSOR = {
		name = "ui7_device_type_motion_sensor",
		type = "urn:schemas-micasaverde-com:device:MotionSensor:1", file = "D_MotionSensor1.xml",
		--jsonFile = "D_MotionSensorWithTamper1.json",
		parameters = { { "ARMED", "0" }, { "TRIPPED", "0" } },
		commands = {
			[ "ON" ] = function( ziBlueDevice, feature )
				DeviceHelper.setTripped( ziBlueDevice, feature, "1" )
			end,
			[ "OFF" ] = function( ziBlueDevice, feature )
				DeviceHelper.setTripped( ziBlueDevice, feature, "0" )
			end
		}
	},
	SMOKE_SENSOR = {
		name = "ui7_device_type_smoke_sensor",
		type = "urn:schemas-micasaverde-com:device:SmokeSensor:1", file = "D_SmokeSensor1.xml",
		parameters = { { "ARMED", "0" }, { "TRIPPED", "0" } },
		commands = {
			[ "ON" ] = function( ziBlueDevice, feature )
				DeviceHelper.setTripped( ziBlueDevice, feature, "1" )
			end,
			[ "OFF" ] = function( ziBlueDevice, feature )
				DeviceHelper.setTripped( ziBlueDevice, feature, "0" )
			end
		}
	},
	WIND_SENSOR = {
		name = "ui7_device_type_wind_sensor",
		type = "urn:schemas-micasaverde-com:device:WindSensor:1", file = "D_WindSensor1.xml",
		parameters = { { "WIND_DIRECTION", "0" }, { "WIND_GUST_SPEED", "0" }, { "WIND_AVERAGE_SPEED", "0" } },
		commands = {
			[ "wind speed" ] = function( ziBlueDevice, feature, data )
				DeviceHelper.setWindSpeed( ziBlueDevice, feature, data )
			end,
			[ "direction" ] = function( ziBlueDevice, feature )
				DeviceHelper.setWindDirection( ziBlueDevice, feature, data )
			end
		}
	},
	BAROMETER_SENSOR = {
		name = "ui7_device_type_barometer_sensor",
		type = "urn:schemas-micasaverde-com:device:BarometerSensor:1", file = "D_BarometerSensor1.xml",
		parameters = { { "PRESSURE", "0" }, { "FORECAST", "" } },
		commands = {
			[ "pressure" ] = function( ziBlueDevice, feature, data )
				DeviceHelper.setPressure( ziBlueDevice, feature, data )
			end
		}
	},
	UV_SENSOR = {
		name = "ui7_device_type_uv_sensor",
		type = "urn:schemas-micasaverde-com:device:UvSensor:1", file = "D_UvSensor.xml",
		parameters = { { "UV", "0" } },
		commands = {
			[ "uv" ] = function( ziBlueDevice, feature, data )
				DeviceHelper.setUv( ziBlueDevice, feature, data )
			end
		}
	},
	BINARY_LIGHT = {
		name = "ui7_device_type_binary_light",
		type = "urn:schemas-upnp-org:device:BinaryLight:1", file = "D_BinaryLight1.xml",
		parameters = { { "SWITCH_POWER", "0" } },
		commands = {
			[ "ON" ] = function( ziBlueDevice, feature )
				DeviceHelper.setStatus( ziBlueDevice, feature, "1", nil, true )
			end,
			[ "OFF" ] = function( ziBlueDevice, feature )
				DeviceHelper.setStatus( ziBlueDevice, feature, "0", nil, true )
			end
		}
	},
	DIMMABLE_LIGHT = {
		name = "ui7_device_type_dimmable_light",
		type = "urn:schemas-upnp-org:device:DimmableLight:1", file = "D_DimmableLight1.xml",
		parameters = { { "SWITCH_POWER", "0" }, { "DIMMER_LEVEL", "0" } },
		commands = {
			[ "ON" ] = function( ziBlueDevice, feature )
				DeviceHelper.setStatus( ziBlueDevice, feature, "1", nil, true )
			end,
			[ "OFF" ] = function( ziBlueDevice, feature )
				DeviceHelper.setStatus( ziBlueDevice, feature, "0", nil, true )
			end
		}
	},
	TEMPERATURE_SENSOR = {
		name = "ui7_device_type_temperature_sensor",
		type = "urn:schemas-micasaverde-com:device:TemperatureSensor:1", file = "D_TemperatureSensor1.xml",
		parameters = { { "TEMPERATURE", "0" } },
		commands = {
			[ "temperature" ] = function( ziBlueDevice, feature, data )
				DeviceHelper.setTemperature( ziBlueDevice, feature, data )
			end
		}
	},
	HUMIDITY_SENSOR = {
		name = "ui7_device_type_humidity_sensor",
		type = "urn:schemas-micasaverde-com:device:HumiditySensor:1", file = "D_HumiditySensor1.xml",
		parameters = { { "HUMIDITY", "0" } },
		commands = {
			[ "hygrometry" ] = function( ziBlueDevice, feature, data )
				DeviceHelper.setHumidity( ziBlueDevice, feature, data )
			end
		}
	},
	POWER_METER = {
		name = "ui7_device_type_power_meter",
		type = "urn:schemas-micasaverde-com:device:PowerMeter:1", file = "D_PowerMeter1.xml",
		parameters = { { "WATTS", "0" }, { "KWH", "0" } },
		commands = {
			[ "energy" ] = function( ziBlueDevice, feature, data )
				DeviceHelper.setKWH( ziBlueDevice, feature, data )
			end,
			[ "power" ] = function( ziBlueDevice, feature, data )
				DeviceHelper.setWatts( ziBlueDevice, feature, data )
			end
		}
	},
	SHUTTER = {
		name = "ui7_device_type_window_covering",
		type = "urn:schemas-micasaverde-com:device:WindowCovering:1", file = "D_WindowCovering1.xml",
		parameters = { { "DIMMER_LEVEL", "0" } }
	},
	PORTAL  = { -- TODO
		name = "ui7_device_type_window_covering",
		type = "urn:schemas-micasaverde-com:device:WindowCovering:1", file = "D_WindowCovering1.xml",
		parameters = { { "DIMMER_LEVEL", "0" } }
	}
}

local _indexDeviceTypeInfos = {}
for deviceTypeName, deviceTypeInfos in pairs( DEVICE ) do
	_indexDeviceTypeInfos[ deviceTypeInfos.type ] = deviceTypeInfos
end

local function _getDeviceTypeInfos( deviceType )
	local deviceTypeInfos = DEVICE[ deviceType ]
	if ( deviceTypeInfos == nil ) then
		deviceTypeInfos = _indexDeviceTypeInfos[ deviceType ]
	end
	if ( deviceTypeInfos == nil ) then
		warning( "Can not get infos for device type " .. tostring( deviceType ), "getDeviceTypeInfos" )
	end
	return deviceTypeInfos
end

local function _getEncodedParameters( deviceTypeInfos )
	local parameters = ""
	if ( deviceTypeInfos and deviceTypeInfos.parameters ) then
		for _, param in ipairs( deviceTypeInfos.parameters ) do
			local variable = VARIABLE [ param[1] ]
			parameters = parameters .. variable[1] .. "," .. variable[2] .. "=" .. ( param[2] or "" ) .. "\n"
		end
	end
	return parameters
end

local JOB_STATUS = {
	NONE = -1,
	WAITING_TO_START = 0,
	IN_PROGRESS = 1,
	ERROR = 2,
	ABORTED = 3,
	DONE = 4,
	WAITING_FOR_CALLBACK = 5
}

-- **************************************************
-- ZiBlue
-- **************************************************

local ZIBLUE_INFOS = {
	[ "0" ] = {
		{ features = { ["state"] = {} }, deviceTypes = { "BINARY_LIGHT", "DIMMABLE_LIGHT" }, settings = { "button", "pulse" } }
	},
	[ "1" ] = {
		{ features = { ["state"] = {} }, deviceTypes = { "BINARY_LIGHT", "DOOR_SENSOR", "MOTION_SENSOR", "SMOKE_SENSOR" } }
	},
	[ "2;0" ] = { -- VISONIC detector/sensor
		{ features = {
			["Tamper"] = {}, ["alarm"] = {}, ["state"] = {}
		}, deviceTypes = { "DOOR_SENSOR", "MOTION_SENSOR", "SMOKE_SENSOR" } } -- TODO
	},
	[ "2;1" ] = { --  VISONIC remote control
		{ features = { ["button/command"] = {}, ["state"] = {} }, deviceTypes = { "BINARY_LIGHT" }, settings = { "button", "pulse" } }
	},
	[ "3;0" ] = { -- RTS shutter
		{ features = { ["state"] = {} }, deviceTypes = { "SHUTTER" } }
	},
	[ "3;1" ] = { -- RTS portal
		{ features = { ["state"] = {} }, deviceTypes = { "PORTAL" } }
	},
	[ "4" ] = { -- Scientific Oregon
		{ features = { ["temperature"] = {} }, deviceTypes = { "TEMPERATURE_SENSOR" } },
		{ features = { ["hygrometry"] = {} }, deviceTypes = { "HUMIDITY_SENSOR" } }
	},
	[ "5" ] = { -- Scientific Oregon
		{ features = { ["temperature"] = {} }, deviceTypes = { "TEMPERATURE_SENSOR" } },
		{ features = { ["hygrometry"] = {} }, deviceTypes = { "HUMIDITY_SENSOR" } },
		{ features = { ["pressure"] = {} }, deviceTypes = { "BAROMETER_SENSOR" } }
	},
	[ "6" ] = {
		{ features = { ["direction"] = {}, ["wind speed"] = {} }, deviceTypes = { "WIND_SENSOR" } }
	},
	[ "7" ] = {
		{ features = { ["uv"] = {} }, deviceTypes = { "UV_SENSOR" } }
	},
	[ "8" ] = {
		{ features = { ["energy"] = {}, ["power"] = {} }, deviceTypes = { "POWER_METER" } },
		{ features = { ["P1"] = {} }, deviceTypes = { "POWER_METER" } },
		{ features = { ["P2"] = {} }, deviceTypes = { "POWER_METER" } },
		{ features = { ["P3"] = {} }, deviceTypes = { "POWER_METER" } }
	},
	[ "9" ] = {
		{ features = { ["total rain"] = {}, ["current rain"] = {} }, deviceTypes = { "RAIN_METER" } } -- TODO
	},
	
	[ "11;0" ] = {
		{ features = { ["totalrain"] = {}, ["rain"] = {} }, deviceTypes = { "RAIN_METER" } } -- TODO
	},
	[ "11;1" ] = {
		{ features = { ["totalrain"] = {}, ["rain"] = {} }, deviceTypes = { "RAIN_METER" } } -- TODO
	},
}


local ZIBLUE_SEND_PROTOCOL = {
	VISONIC433 = { name = "Visonic 433Mhz" },
	VISONIC868 = { name = "Visonic 868Mhz" },
	CHACON = { name = "Chacon 433Mhz" },
	DOMIA = { name = "Domia 433Mhz" },
	X10 = { name = "Visonic 433Mhz" },
	X2D433 = { name = "X2D 433Mhz" },
	X2D868 = { name = "X2D 868Mhz" },
	X2DSHUTTER = { name = "X2D Shutter 868Mhz" },
	X2DELEC = { name = "X2D Elec 868Mhz" },
	X2DGAS = { name = "X2D Gaz 868Mhz" },
	RTS = {
		name = "Somfy RTS 433Mhz",
		deviceTypes = { "BINARY_LIGHT", "SHUTTER;qualifier=0", "PORTAL;qualifier=1" },
		settings = {
			{ variable = "qualifier", name = "Qualifier", type = "string" }
		}
	},
	BLYSS = { name = "Blyss 433Mhz" },
	PARROT = {
		name = "* ZiBlue Parrot",
		--deviceTypes = { "BINARY_LIGHT", "DOOR_SENSOR", "MOTION_SENSOR", "SMOKE_SENSOR" },
		settings = {
			{ variable = "comment", name = "Reminder", type = "string" },
			{ variable = "action", name = "Action", type = "select", values = { "ON", "OFF" } }
		}
	},
	KD101 = { name = "KD101 433Mhz" }
}

local ZIBLUE_DATA_FLAG = {
    [ "-1" ] = "",
	[ "0" ] = "433",
	[ "1" ] = "868"
}

local ZIBLUE_SEND_ACTION = {
	OFF             = 0,
	ON              = 1,
	DIM             = 2,
	BRIGHT          = 3,
	ALL_OFF         = 4,
	ALL_ON          = 5,
	ASSOC           = 6,
	DISSOC          = 7,
	ASSOC_OFF       = 8,
	ASSOC_ON        = 9
}
local function _getZiBlueSendActionName( CMD )
	for actionName, actionCode in pairs( ZIBLUE_SEND_ACTION ) do
		if ( actionCode == CMD ) then
			return actionName
		end
	end
	return "UNKNOW(" .. number_toHex( CMD ) .. ")"
end


-- **************************************************
-- Globals
-- **************************************************

local DEVICE_ID      -- The device # of the parent device

local g_maxId = 0           -- A number that increments with every device learned.
local g_baseId = ""

-- **************************************************
-- Number functions
-- **************************************************

-- Formats a number as hex.
function number_toHex( n )
	if ( type( n ) == "number" ) then
		return string.format( "%02X", n )
	end
	return tostring( n )
end

-- **************************************************
-- Table functions
-- **************************************************

do -- extend table
	-- Merges (deeply) the contents of one table (t2) into another (t1)
	function table_extend( t1, t2, excludedKeys )
		if ( ( t1 == nil ) or ( t2 == nil ) ) then
			return
		end
		local exclKeys
		if ( type( excludedKeys ) == "table" ) then
			exclKeys = {}
			for _, key in ipairs( excludedKeys ) do
				exclKeys[ key ] = true
			end
		end
		for key, value in pairs( t2 ) do
			if ( not exclKeys or not exclKeys[ key ] ) then
				if ( type( value ) == "table" ) then
					if ( type( t1[key] ) == "table" ) then
						t1[key] = table_extend( t1[key], value, excludedKeys )
					else
						t1[key] = table_extend( {}, value, excludedKeys )
					end
				elseif ( value ~= nil ) then
					if ( type( t1[key] ) == type( value ) ) then
						t1[key] = value
					else
						-- Try to keep the former type
						if ( type( t1[key] ) == "number" ) then
							luup.log( "table_extend : convert '" .. key .. "' to number " , 2 )
							t1[key] = tonumber( value )
						elseif ( type( t1[key] ) == "boolean" ) then
							luup.log( "table_extend : convert '" .. key .. "' to boolean" , 2 )
							t1[key] = ( value == true )
						elseif ( type( t1[key] ) == "string" ) then
							luup.log( "table_extend : convert '" .. key .. "' to string" , 2 )
							t1[key] = tostring( value )
						else
							t1[key] = value
						end
					end
				end
			elseif ( value ~= nil ) then
				t1[key] = value
			end
		end
		return t1
	end

	-- Checks if a table contains the given item.
	-- Returns true and the key / index of the item if found, or false if not found.
	function table_contains( t, item )
		if ( t == nil ) then
			return
		end
		for k, v in pairs( t ) do
			if ( v == item ) then
				return true, k
			end
		end
		return false
	end

	-- Checks if table contains all the given items (table).
	function table_containsAll( t1, items )
		if ( ( type( t1 ) ~= "table" ) or ( type( t2 ) ~= "table" ) ) then
			return false
		end
		for _, v in pairs( items ) do
			if not table_contains( t1, v ) then
				return false
			end
		end
		return true
	end

	-- Appends the contents of the second table at the end of the first table
	function table_append( t1, t2, noDuplicate )
		if ( ( t1 == nil ) or ( t2 == nil ) ) then
			return
		end
		local table_insert = table.insert
		if ( type( t2 ) == "table" ) then
			table.foreach(
				t2,
				function ( _, v )
					if ( noDuplicate and table_contains( t1, v ) ) then
						return
					end
					table_insert( t1, v )
				end
			)
		else
			if ( noDuplicate and table_contains( t1, t2 ) ) then
				return
			end
			table_insert( t1, t2 )
		end
		return t1
	end

	-- Extracts a subtable from the given table
	function table_extract( t, start, length )
		if ( start < 0 ) then
			start = #t + start + 1
		end
		length = length or ( #t - start + 1 )

		local t1 = {}
		for i = start, start + length - 1 do
			t1[#t1 + 1] = t[i]
		end
		return t1
	end

	--[[
	function table_concatChar( t )
		local res = ""
		for i = 1, #t do
			res = res .. string.char( t[i] )
		end
		return res
	end
	--]]

	-- Concatenates a table of numbers into a string with Hex separated by the given separator.
	function table_concatHex( t, sep, start, length )
		sep = sep or "-"
		start = start or 1
		if ( start < 0 ) then
			start = #t + start + 1
		end
		length = length or ( #t - start + 1 )
		local s = number_toHex( t[start] )
		if ( length > 1 ) then
			for i = start + 1, start + length - 1 do
				s = s .. sep .. number_toHex( t[i] )
			end
		end
		return s
	end

	function table_filter( t, filter )
		local out = {}
		for k, v in pairs( t ) do
			if filter( k, v ) then
				if ( type(k) == "number" ) then
					table.insert( out, v )
				else
					out[ k ] = v
				end
			end
		end
		return out
	end

	function table_getKeys( t )
		local keys = {}
		for key, value in pairs( t ) do
			table.insert( keys, key )
		end
		return keys
	end
end


-- **************************************************
-- String functions
-- **************************************************

do -- extend string
	-- Pads string to given length with given char from left.
	function string_lpad( s, length, c )
		s = tostring( s )
		length = length or 2
		c = c or " "
		return c:rep( length - #s ) .. s
	end

	-- Pads string to given length with given char from right.
	function string_rpad( s, length, c )
		s = tostring( s )
		length = length or 2
		c = char or " "
		return s .. c:rep( length - #s )
	end

	-- Returns if a string is empty (nil or "")
	function string_isEmpty( s )
		return ( ( s == nil ) or ( s == "" ) ) 
	end

	function string_trim( s )
		return s:match( "^%s*(.-)%s*$" )
	end

	-- Splits a string based on the given separator. Returns a table.
	function string_split( s, sep, convert, convertParam )
		if ( type( convert ) ~= "function" ) then
			convert = nil
		end
		if ( type( s ) ~= "string" ) then
			return {}
		end
		sep = sep or " "
		local t = {}
		--for token in s:gmatch( "[^" .. sep .. "]+" ) do
		for token in ( s .. sep ):gmatch( "([^" .. sep .. "]*)" .. sep ) do
			if ( convert ~= nil ) then
				token = convert( token, convertParam )
			end
			table.insert( t, token )
		end
		return t
	end

	-- Formats a string into hex.
	function string_formatToHex( s, sep )
		sep = sep or "-"
		local result = ""
		if ( s ~= nil ) then
			for i = 1, string.len( s ) do
				if ( i > 1 ) then
					result = result .. sep
				end
				result = result .. string.format( "%02X", string.byte( s, i ) )
			end
		end
		return result
	end
end


-- **************************************************
-- Variable management
-- **************************************************

Variable = {
	-- Check if variable (service) is supported
	isSupported = function( deviceId, variable )
		if not luup.device_supports_service( variable[1], deviceId ) then
			warning( "Device #" .. tostring( deviceId ) .. " does not support service " .. variable[1], "Variable.isSupported" )
			return false
		end
		return true
	end,

	-- Get variable timestamp
	getTimestamp = function( deviceId, variable )
		if ( ( type( variable ) == "table" ) and ( type( variable[4] ) == "string" ) ) then
			local variableTimestamp = VARIABLE[ variable[4] ]
			if ( variableTimestamp ~= nil ) then
				return tonumber( ( luup.variable_get( variableTimestamp[1], variableTimestamp[2], deviceId ) ) )
			end
		end
		return nil
	end,

	-- Set variable timestamp
	setTimestamp = function( deviceId, variable, timestamp )
		if ( variable[4] ~= nil ) then
			local variableTimestamp = VARIABLE[ variable[4] ]
			if ( variableTimestamp ~= nil ) then
				luup.variable_set( variableTimestamp[1], variableTimestamp[2], ( timestamp or os.time() ), deviceId )
			end
		end
	end,

	-- Get variable value (can deal with unknown variable)
	get = function( deviceId, variable )
		deviceId = tonumber( deviceId )
		if ( deviceId == nil ) then
			error( "deviceId is nil", "Variable.get" )
			return
		elseif ( variable == nil ) then
			error( "variable is nil", "Variable.get" )
			return
		end
		local value, timestamp = luup.variable_get( variable[1], variable[2], deviceId )
		if ( value ~= "0" ) then
			local storedTimestamp = Variable.getTimestamp( deviceId, variable )
			if ( storedTimestamp ~= nil ) then
				timestamp = storedTimestamp
			end
		end
		return value, timestamp
	end,

	getUnknown = function( deviceId, serviceId, variableName )
		local variable = indexVariable[ tostring( serviceId ) .. ";" .. tostring( variableName ) ]
		if ( variable ~= nil ) then
			return Variable.get( deviceId, variable )
		else
			return luup.variable_get( serviceId, variableName, deviceId )
		end
	end,

	-- Set variable value
	set = function( deviceId, variable, value )
		deviceId = tonumber( deviceId )
		if ( deviceId == nil ) then
			error( "deviceId is nil", "Variable.set" )
			return
		elseif ( variable == nil ) then
			error( "variable is nil", "Variable.set" )
			return
		elseif ( value == nil ) then
			error( "value is nil", "Variable.set" )
			return
		end
		if ( type( value ) == "number" ) then
			value = tostring( value )
		end
		local doChange = true
		local currentValue = luup.variable_get( variable[1], variable[2], deviceId )
		local deviceType = luup.devices[deviceId].device_type
		--[[
		if (
			(variable == VARIABLE.TRIPPED)
			and (currentValue == value)
			and (
				(deviceType == DEVICE.MOTION_SENSOR.type)
				or (deviceType == DEVICE.DOOR_SENSOR.type)
				or (deviceType == DEVICE.SMOKE_SENSOR.type)
			)
			and (luup.variable_get(VARIABLE.REPEAT_EVENT[1], VARIABLE.REPEAT_EVENT[2], deviceId) == "0")
		) then
			doChange = false
		elseif (
				(luup.devices[deviceId].device_type == tableDeviceTypes.LIGHT[1])
			and (variable == VARIABLE.LIGHT)
			and (currentValue == value)
			and (luup.variable_get(VARIABLE.VAR_REPEAT_EVENT[1], VARIABLE.VAR_REPEAT_EVENT[2], deviceId) == "1")
		) then
			luup.variable_set(variable[1], variable[2], "-1", deviceId)
		else--]]
		if ( ( currentValue == value ) and ( ( variable[3] == true ) or ( value == "0" ) ) ) then
			-- Variable is not updated when the value is unchanged
			doChange = false
		end

		if doChange then
			luup.variable_set( variable[1], variable[2], value, deviceId )
		end

		-- Updates linked variable for timestamp (just for active value)
		if ( value ~= "0" ) then
			Variable.setTimestamp( deviceId, variable, os.time() )
		end
	end,

	-- Get variable value and init if value is nil or empty
	getOrInit = function( deviceId, variable, defaultValue )
		local value, timestamp = Variable.get( deviceId, variable )
		if ( ( value == nil ) or (  value == "" ) ) then
			value = defaultValue
			Variable.set( deviceId, variable, value )
			timestamp = os.time()
			Variable.setTimestamp( deviceId, variable, timestamp )
		end
		return value, timestamp
	end,

	watch = function( deviceId, variable, callback )
		luup.variable_watch( callback, variable[1], variable[2], lul_device )
	end
}


-- **************************************************
-- UI messages
-- **************************************************

UI = {
	show = function( message )
		debug( "Display message: " .. tostring( message ), "UI.show" )
		Variable.set( DEVICE_ID, VARIABLE.LAST_MESSAGE, message )
	end,

	showError = function( message )
		debug( "Display message: " .. tostring( message ), "UI.showError" )
		--message = '<div style="color:red">' .. tostring( message ) .. '</div>'
		message = '<font color="red">' .. tostring( message ) .. '</font>'
		Variable.set( DEVICE_ID, VARIABLE.LAST_MESSAGE, message )
	end,

	clearMessage = function()
		Variable.set( DEVICE_ID, VARIABLE.LAST_MESSAGE, "" )
	end
}


-- **************************************************
-- Device functions
-- **************************************************



local function _getZiBlueId( ziBlueDevice, feature )
	return ziBlueDevice.protocol .. ";" .. ziBlueDevice.protocolDeviceId .. ";" .. tostring( feature.name ) .. ";" .. tostring( feature.deviceId )
end


-- **************************************************
-- Device helper
-- **************************************************

DeviceHelper = {
	-- Switch OFF/ON/TOGGLE
	setStatus = function( ziBlueDevice, feature, status, isLongPress, noAction )
		if status then
			status = tostring( status )
		end
		local deviceId = feature.deviceId
		local formerStatus = Variable.get( deviceId, VARIABLE.SWITCH_POWER ) or "0"
		local msg = "ZiBlue device '" .. _getZiBlueId( ziBlueDevice, feature ) .. "'"
		if ( feature.settings[ "receiver" ] ) then
			msg = msg .. " (receiver)"
		end

		-- Pulse
		local isPulse = ( feature.settings[ "pulse" ] == true )
		-- Toggle
		local isToggle = ( feature.settings[ "toggle" ] == true )
		if ( isToggle or ( status == nil ) or ( status == "" ) ) then
			if isPulse then
				-- Always ON in pulse and toggle mode
				msg = msg .. " - Switch"
				status = "1"
			else
				msg = msg .. " - Toggle"
				if ( formerStatus == "1" ) then
					status = "0"
				else
					status = "1"
				end
			end
		else
			msg = msg .. " - Switch"
		end

		-- Has status changed ?
		if ( status == formerStatus ) then
			debug( msg .. " - Status has not changed", "DeviceHelper.setStatus" )
			return
		end

		-- Update status variable
		local loadLevel
		if ( status == "1" ) then
			msg = msg .. " ON device #" .. tostring( deviceId )
			if luup.device_supports_service( VARIABLE.DIMMER_LEVEL[1], deviceId ) then
				loadLevel = Variable.get( deviceId, VARIABLE.DIMMER_LEVEL_OLD ) or "100"
				if ( loadLevel == "0" ) then
					loadLevel = "100"
				end
				msg = msg .. " at " .. loadLevel .. "%"
			end
		else
			msg = msg .. " OFF device #" .. tostring( deviceId )
			status = "0"
			if luup.device_supports_service( VARIABLE.DIMMER_LEVEL[1], deviceId ) then
				msg = msg .. " at 0%"
				loadLevel = 0
			end
		end
		if isLongPress then
			msg = msg .. " (long press)"
		end
		debug( msg, "DeviceHelper.setStatus" )
		Variable.set( deviceId, VARIABLE.SWITCH_POWER, status )
		if loadLevel then
			if ( loadLevel == 0 ) then
				Variable.set( deviceId, VARIABLE.DIMMER_LEVEL_OLD, Variable.get( deviceId, VARIABLE.DIMMER_LEVEL ) )
			end
			Variable.set( deviceId, VARIABLE.DIMMER_LEVEL, loadLevel )
		end

		-- Send command if needed
		if ( ( feature.settings[ "receiver" ] ) and not ( noAction == true ) ) then
			local cmd
			if ( status == "1" ) then
				cmd = "ON"
			else
				cmd = "OFF"
			end
			local qualifier = feature.settings[ "qualifier" ] and ( " QUALIFIER " .. ( ( feature.settings[ "qualifier" ] == "1" ) and "1" or "0" ) ) or ""
			if loadLevel then 
				Network.send( "ZIA++DIM ID " .. ziBlueDevice.protocolDeviceId .. " " .. ziBlueDevice.protocol .. " %" .. tostring(loadLevel) .. qualifier )
			else
				Network.send( "ZIA++" .. cmd .. " ID " .. ziBlueDevice.protocolDeviceId .. " " .. ziBlueDevice.protocol .. qualifier )
			end
		end

		if ( isPulse and ( status == "1" ) ) then
			-- TODO : OFF après 200ms : voir multiswitch
			msg = "ZiBlue device '" .. _getZiBlueId( ziBlueDevice, feature ) .. "' - Pulse OFF device #" .. tostring( deviceId )
			if luup.device_supports_service( VARIABLE.DIMMER_LEVEL[1], deviceId ) then
				debug( msg .. " at 0%", "DeviceHelper.setStatus" )
				Variable.set( deviceId, VARIABLE.SWITCH_POWER, "0" )
				Variable.set( deviceId, VARIABLE.DIMMER_LEVEL_OLD, Variable.get( deviceId, VARIABLE.DIMMER_LEVEL ) )
				Variable.set( deviceId, VARIABLE.DIMMER_LEVEL, 0 )
			else
				debug( msg, "DeviceHelper.setStatus" )
				Variable.set( deviceId, VARIABLE.SWITCH_POWER, "0" )
			end
		end

		-- Association
		Association.propagate( feature.association, status, loadLevel, isLongPress )
		if ( isPulse and ( status == "1" ) ) then
			Association.propagate( feature.association, "0", nil, isLongPress )
		end

		return status
	end,

	-- Dim OFF/ON/TOGGLE
	setLoadLevel = function( ziBlueDevice, feature, loadLevel, direction, isLongPress, noAction )
		loadLevel = tonumber( loadLevel )
		local deviceId = feature.deviceId
		local formerLoadLevel, lastLoadLevelChangeTime = Variable.get( deviceId, VARIABLE.DIMMER_LEVEL )
		formerLoadLevel = tonumber( formerLoadLevel ) or 0
		local msg = "Dim"

		if ( isLongPress and not luup.device_supports_service( VARIABLE.DIMMER_LEVEL[1], deviceId ) ) then
			-- Long press handled by a switch
			return DeviceHelper.setStatus( ziBlueDevice, feature, nil, isLongPress )

		elseif ( loadLevel == nil ) then
			-- Toggle dim
			loadLevel = formerLoadLevel
			if ( direction == nil ) then
				direction = Variable.getOrInit( deviceId, VARIABLE.DIMMER_DIRECTION, "up" )
				if ( os.difftime( os.time(), lastLoadLevelChangeTime ) > 2 ) then
					-- Toggle direction after 2 seconds of inactivity
					msg = "Toggle dim"
					if ( direction == "down" ) then
						direction = "up"
						Variable.set( deviceId, VARIABLE.DIMMER_DIRECTION, "up" )
					else
						direction = "down"
						Variable.set( deviceId, VARIABLE.DIMMER_DIRECTION, "down" )
					end
				end
			end
			if ( direction == "down" ) then
				loadLevel = loadLevel - 3
				msg = msg .. "-"
			else
				loadLevel = loadLevel + 3
				msg = msg .. "+"
			end
		end

		-- Update load level variable
		if ( loadLevel < 3 ) then
			loadLevel = 0
		elseif ( loadLevel > 100 ) then
			loadLevel = 100
		end

		-- Has load level changed ?
		if ( loadLevel == formerLoadLevel ) then
			debug( msg .. " - Load level has not changed", "DeviceHelper.setLoadLevel" )
			return
		end

		debug( msg .. " device #" .. tostring( deviceId ) .. " at " .. tostring( loadLevel ) .. "%", "DeviceHelper.setLoadLevel" )
		Variable.set( deviceId, VARIABLE.DIMMER_LEVEL, loadLevel )
		if ( loadLevel > 0 ) then
			Variable.set( deviceId, VARIABLE.SWITCH_POWER, "1" )
		else
			Variable.set( deviceId, VARIABLE.SWITCH_POWER, "0" )
		end

		-- Send command if needed
		if ( ( feature.settings[ "receiver" ] ) and not ( noAction == true ) ) then
			local qualifier = feature.settings[ "qualifier" ] and ( " QUALIFIER " .. ( ( feature.settings[ "qualifier" ] == "1" ) and "1" or "0" ) ) or ""
			if ( loadLevel > 0 ) then
				Network.send( "ZIA++DIM ID " .. ziBlueDevice.protocolDeviceId .. " " .. ziBlueDevice.protocol .. " %" .. tostring(loadLevel) .. qualifier )
			else
				Network.send( "ZIA++OFF ID " .. ziBlueDevice.protocolDeviceId .. " " .. ziBlueDevice.protocol .. qualifier )
			end
		end

		-- Association
		Association.propagate( feature.association, nil, loadLevel, isLongPress )

		return loadLevel
	end,

	-- Set armed
	setArmed = function( ziBlueDevice, feature, armed )
		local deviceId = feature.deviceId
		if not Variable.isSupported( deviceId, VARIABLE.ARMED ) then
			return
		end
		armed = tostring( armed or "0" )
		if ( armed == "1" ) then
			debug( "Arm device #" .. tostring( deviceId ), "DeviceHelper.setArmed" )
		else
			debug( "Disarm device #" .. tostring( deviceId ), "DeviceHelper.setArmed" )
		end
		Variable.set( deviceId, VARIABLE.ARMED, armed )
		if ( armed == "0" ) then
			Variable.set( deviceId, VARIABLE.ARMED_TRIPPED, "0" )
		end
	end,

	-- Set tripped
	setTripped = function( ziBlueDevice, feature, tripped )
		local deviceId = feature.deviceId
		if not Variable.isSupported( deviceId, VARIABLE.TRIPPED ) then
			return
		end
		tripped = tostring( tripped or "0" )
		if ( tripped == "1" ) then
			debug( "Device #" .. tostring( deviceId ) .. " is tripped", "DeviceHelper.setTripped" )
		else
			debug( "Device #" .. tostring( deviceId ) .. " is untripped", "DeviceHelper.setTripped" )
		end
		Variable.set( deviceId, VARIABLE.TRIPPED, tripped )
		if ( ( tripped == "1" ) and ( Variable.get( deviceId, VARIABLE.ARMED) == "1" ) ) then
			Variable.set( deviceId, VARIABLE.ARMED_TRIPPED, "1" )
		else
			Variable.set( deviceId, VARIABLE.ARMED_TRIPPED, "0" )
		end
	end,

	-- Set tamper alarm
	setTamperAlarm  = function( ziBlueDevice, feature, alarm )
		local deviceId = feature.deviceId
		if not Variable.isSupported( deviceId, VARIABLE.TAMPER_ALARM ) then
			return
		end
		debug( "Set device #" .. tostring(deviceId) .. " tamper alarm to '" .. tostring( alarm ) .. "'", "DeviceHelper.setTamperAlarm" )
		Variable.set( deviceId, VARIABLE.TAMPER_ALARM, alarm )
	end,

	-- Set temperature
	setTemperature = function( ziBlueDevice, feature, data )
		local deviceId = feature.deviceId
		if not Variable.isSupported( deviceId, VARIABLE.TEMPERATURE ) then
			return
		end
		local temperature = tonumber( data.value ) -- degree celcius
		-- TODO : manage Fahrenheit
		debug( "Set device #" .. tostring(deviceId) .. " temperature to " .. tostring( temperature ) .. "°C", "DeviceHelper.setTemperature" )
		Variable.set( deviceId, VARIABLE.TEMPERATURE, temperature )
	end,

	-- Set humidity
	setHumidity = function( ziBlueDevice, feature, data )
		local deviceId = feature.deviceId
		if not Variable.isSupported( deviceId, VARIABLE.HUMIDITY ) then
			return
		end
		local humidity = tonumber( data.value )
		if ( humidity and humidity ~= 0 ) then
			debug( "Set device #" .. tostring(deviceId) .. " humidity to " .. tostring( humidity ) .. "%", "DeviceHelper.setHygrometry" )
			Variable.set( deviceId, VARIABLE.HUMIDITY, humidity )
		end
	end,

	-- Set watts
	setWatts = function( ziBlueDevice, feature, data )
		local deviceId = feature.deviceId
		if not Variable.isSupported( deviceId, VARIABLE.WATTS ) then
			return
		end
		local watts = tonumber( data.value )
		debug( "Set device #" .. tostring(deviceId) .. " watts to " .. tostring( watts ) .. "W", "DeviceHelper.setWatts" )
		Variable.set( deviceId, VARIABLE.WATTS, watts )
	end,

	-- Set KWH
	setKWH = function( ziBlueDevice, feature, data )
		local deviceId = feature.deviceId
		if not Variable.isSupported( deviceId, VARIABLE.KWH ) then
			return
		end
		local KWH = tonumber( data.value )
		debug( "Set device #" .. tostring(deviceId) .. " watt to " .. tostring( KWH ) .. "Wh", "DeviceHelper.setKWH" )
		Variable.set( deviceId, VARIABLE.KWH, KWH )
	end,

	-- Set battery level
	setBatteryLevel = function( ziBlueDevice, feature, batteryLevel )
		-- TODO : comment identifier un périphérique à pile ?
		--[[
		if not ziBlueDevice.isBatteryPowered then
			return
		end
		--]]
		local deviceId = feature.deviceId
		local batteryLevel = tonumber(batteryLevel) or 0
		if (batteryLevel < 0) then
			batteryLevel = 0
		elseif (batteryLevel > 100) then
			batteryLevel = 100
		end
		debug("Set device #" .. tostring(deviceId) .. " battery level to " .. tostring(batteryLevel) .. "%", "DeviceHelper.setBatteryLevel")
		Variable.set( deviceId, VARIABLE.BATTERY_LEVEL, batteryLevel )
	end,

	-- Manage roller shutter
	moveShutter = function( ziBlueDevice, feature, direction, noAction )
		debug( "Shutter #" .. tostring(feature.deviceId) .. " direction: " .. tostring(direction), "DeviceHelper.moveShutter" )
		
		debug("TODO");
	end
}


-- **************************************************
-- Message (incomming data)
-- **************************************************

local g_messageToProcessQueue = {}
local g_isProcessingMessage = false
local g_lastCommandsByZiBlueId = {}

Message = {
	process = function( source, qualifier, data )
		local header = data.frame.header
		local protocol = header.protocolMeaning
		local infoType = header.infoType
		local dataFlag = header.dataFlag
		local rfQuality = tonumber( header.rfQuality )
		local infos = data.frame.infos
		local subType = infos.subType
		local protocolDeviceId = infos.id or infos.adr_channel
		local id = protocol .. ";" .. protocolDeviceId

		local info = tostring( header.protocolMeaning ) .. " " .. ( infos.subTypeMeaning or infos.id_PHYMeaning) 

		local msg = "ZiBlue device '" .. id .. "'"

		local function _addCommand( commandName, featureName, data )
			if not commandName then
				return
			end
			local ziBlueDevice, feature = ZiBlueDevices.getById( id, featureName )
			if ( ziBlueDevice and feature ) then
				-- ZiBlue device is known for this feature
				if ( type( data ) == "table" ) then
					feature.state = data.value .. " " .. data.unit
				else
					feature.state = data
				end
				local deviceTypeInfos = _getDeviceTypeInfos( feature.deviceType )
				if ( deviceTypeInfos == nil ) then
					error( msg .. " - Device type " .. feature.deviceType .. " is unknown", "Message.process" )
				elseif ( deviceTypeInfos.commands[ commandName ] ~= nil ) then
					debug( msg .. " - Feature command " .. commandName, "Message.process" )
					table.insert( g_messageToProcessQueue, { ziBlueDevice, feature, deviceTypeInfos.commands[ commandName ], data } )
				else
					warning( msg .. " - Feature command " .. commandName .. " not yet implemented for this device type " .. feature.deviceType, "Message.process" )
				end
			elseif ziBlueDevice then
				-- ZiBlue device is known (but not for this feature)
				if ( commandName == "LowBatt" ) then
					DeviceHelper.setBatteryLevel( ziBlueDevice, { deviceId = ziBlueDevice.mainDeviceId }, 10 )
				end
			end
			if ( ziBlueDevice == nil ) then
				-- Add this device to the discovered ZiBlue devices (but not yet known)
				if DiscoveredDevices.add( protocol, protocolDeviceId, dataFlag, rfQuality, infoType, subType, featureName, data ) then
					debug( "This message is from an unknown ZiBlue device '" .. id .. "' for feature '" .. featureName .. "'", "Message.process" )
				else
					debug( "This message is from an ZiBlue device already discovered '" .. id .. "'", "Message.process" )
				end
			else
				ziBlueDevice.rfQuality = rfQuality
			end
		end

		-- Battery
		if ( infos.lowBatt == "1" ) then
			_addCommand( "LowBatt", "LowBatt", "LowBatt" )
		end

		-- State
		if ( infos.subTypeMeaning ) then
			_addCommand( infos.subTypeMeaning, "state", infos.subTypeMeaning )
		end

		-- Measures
		if ( infos.measures ) then
			for _, measure in ipairs( infos.measures ) do
				_addCommand( measure.type, measure.type, measure )
			end
		end

		-- Flags (can be "LowBatt")
		if ( infos.qualifierMeaning and infos.qualifierMeaning.flags ) then
			for _, flag in ipairs( infos.qualifierMeaning.flags ) do
				_addCommand( flag, flag, flag )
			end
		end

		if ( #g_messageToProcessQueue > 0 ) then
			luup.call_delay( "ZiBlueGateway.Message.deferredProcess", 0 )
		end
	end,

	deferredProcess = function()
		if g_isProcessingMessage then
			debug( "Processing is already in progress", "Message.deferredProcess" )
			return
		end
		g_isProcessingMessage = true
		local status, err = pcall( Message.protectedProcess )
		if err then
			error( "Error: " .. tostring( err ), "Message.deferredProcess" )
		end
		g_isProcessingMessage = false
	end,

	protectedProcess = function()
		while g_messageToProcessQueue[1] do
			local ziBlueDevice, feature, commandFunction, data = unpack( g_messageToProcessQueue[1] )
			if commandFunction( ziBlueDevice, feature, data ) then
				--channel.lastCommand = message.CMD
				--channel.lastCommandReceiveTime = os.clock()
			end
			table.remove( g_messageToProcessQueue, 1 )
		end
	end
}

-- **************************************************
-- Incoming data
-- **************************************************

function handleIncoming( lul_data )
	if lul_data then
		local sync = string.sub( lul_data, 1, 2 )
		if ( sync == "ZI" ) then
			local data
			local source = string.sub( lul_data, 3, 3 )
			local qualifier = string.sub( lul_data, 4, 5 )
			local jsonData = string.sub( lul_data, 6 )

			if ( string.sub( jsonData, 1, 1 ) == "{" ) then
				local decodeSuccess, data, _, jsonError = pcall( json.decode, jsonData )
				if ( decodeSuccess and data ) then
					debug( source .. " " .. qualifier .. ": " .. json.encode( data ), "handleIncoming")
					if data.systemStatus then
						Tools.updateSystemStatus( data.systemStatus.info )
					elseif data.parrotStatus then
						Tools.updateParrotStatus( data.parrotStatus.info )
					else
						Message.process( source, qualifier, data )
					end
				else
					error( "JSON error: " .. tostring( jsonError ) )
				end
			else
				if ( string.sub( jsonData, 1, 7 ) ~= "Welcome" ) then
					error( "Unkown message: " .. tostring( lul_data ) )
				end 
			end

		else
			debug( "Unkown data: " .. tostring( lul_data ), "handleIncoming")
		end
	end
end


-- **************************************************
-- Network (outgoing data)
-- **************************************************

local g_messageToSendQueue = {}   -- The outbound message queue
local g_isSendingMessage = false

Network = {

	-- Send a message (add to send queue)
	send = function( message, delay )
		if ( luup.attr_get( "disabled", DEVICE_ID ) == "1" ) then
			warning( "Can not send message: ZiBlue Gateway is disabled", "Network.send" )
			return
		end

		-- Delayed message
		if delay then
			luup.call_delay( "ZiBlueGateway.Network.send", delay, string.formatToHex( packet, "-" ) )
			return
		end

		table.insert( g_messageToSendQueue, message )
		if not g_isSendingMessage then
			Network.flush()
		end
	end,

	-- Send the packets in the queue to ZiBlue dongle
	flush = function ()
		if ( luup.attr_get( "disabled", DEVICE_ID ) == "1" ) then
			debug( "Can not send message: ZiBlue Gateway is disabled", "Network.flush" )
			return
		end
		-- If we don't have any message to send, return.
		if ( #g_messageToSendQueue == 0 ) then
			g_isSendingMessage = false
			return
		end

		g_isSendingMessage = true
		while g_messageToSendQueue[1] do
			--debug( "Send message: ".. string.formatToHex(g_messageToSendQueue[1]), "Network.flush" )
			debug( "Send message: " .. g_messageToSendQueue[1], "Network.flush" )
			if not luup.io.write( g_messageToSendQueue[1] ) then
				error( "Failed to send packet", "Network.flush" )
				return
			end
			table.remove( g_messageToSendQueue, 1 )
		end

		g_isSendingMessage = false
	end
}


-- **************************************************
-- Poll engine (Not used)
-- **************************************************

PollEngine = {
	poll = function ()
		log( "Start poll", "PollEngine.start" )
	end
}


-- **************************************************
-- Tools
-- **************************************************

Tools = {
	-- Get PID (array representation of the Product ID)
	getPID = function (productId)
		if (productId == nil) then
			return nil
		end
		local PID = {}
		for i, strHex in ipairs(string_split(productId, "-")) do
			PID[i] = tonumber(strHex, 16)
		end
		return PID
	end,

	-- Generate virtual ZiBlue Product ID
	-- TODO : juste un compteur ?
	generateProductId = function ()
		local virtualPID = { 0xFF }
		for i = 1, 3 do
			virtualPID[i] = math.random(0xFF + 1) - 1
		end
		return table_concatHex(virtualPID)
	end,

	extractInfos = function( infos )
		local result = {}
		for _, info in ipairs( infos ) do
			if not string_isEmpty( info.n ) then
				result[ info.n ] = info.v
			end
			for key, value in pairs( info ) do
				if ( string.len( key ) > 1 ) then
				result[ key ] = value
				end
			end
		end
		return result
	end,

	updateSystemStatus = function( infos )
		local status = Tools.extractInfos( infos )
		Variable.set( DEVICE_ID, VARIABLE.ZIBLUE_VERSION, status.Version )
		Variable.set( DEVICE_ID, VARIABLE.ZIBLUE_MAC,     status.Mac )
	end,

	updateParrotStatus = function( infos )
		local status = Tools.extractInfos( infos )
		if not ZiBlueDevices.get( "PARROT", status.id ) then
			-- Add the Parrot device to discovered devices
			DiscoveredDevices.add( "PARROT", status.id, "-1", -1, 0, status.action, "state", ( ( status.action == "1" ) and "ON" or "OFF" ), status.reminder )
		end
	end

}


-- **************************************************
-- Associations
-- **************************************************

Association = {
	-- Get associations from string
	get = function( strAssociation )
		local association = {}
		for _, encodedAssociation in pairs( string_split( strAssociation or "", "," ) ) do
			local linkedId, level, isScene, isZiBlue = nil, 1, false, false
			while ( encodedAssociation ) do
				local firstCar = string.sub( encodedAssociation, 1 , 1 )
				if ( firstCar == "*" ) then
					isScene = true
					encodedAssociation = string.sub( encodedAssociation, 2 )
				elseif ( firstCar == "%" ) then
					isZiBlue = true
					encodedAssociation = string.sub( encodedAssociation, 2 )
				elseif ( firstCar == "+" ) then
					level = level + 1
					if ( level > 2 ) then
						break
					end
					encodedAssociation = string.sub( encodedAssociation, 2 )
				else
					linkedId = tonumber( encodedAssociation )
					encodedAssociation = nil
				end
			end
			if linkedId then
				if isScene then
					if ( luup.scenes[ linkedId ] ) then
						if ( association.scenes == nil ) then
							association.scenes = { {}, {} }
						end
						table.insert( association.scenes[ level ], linkedId )
					else
						error( "Associated scene #" .. tostring( linkedId ) .. " is unknown", "Associations.get" )
					end
				elseif isZiBlue then
					if ( luup.devices[ linkedId ] ) then
						if ( association.ziBlueDevices == nil ) then
							association.ziBlueDevices = { {}, {} }
						end
						table.insert( association.ziBlueDevices[ level ], linkedId )
					else
						error( "Associated ZiBlue device #" .. tostring( linkedId ) .. " is unknown", "Associations.get" )
					end
				else
					if ( luup.devices[ linkedId ] ) then
						if ( association.devices == nil ) then
							association.devices = { {}, {} }
						end
						table.insert( association.devices[ level ], linkedId )
					else
						error( "Associated device #" .. tostring( linkedId ) .. " is unknown", "Associations.get" )
					end
				end
			end
		end
		return association
	end,

	getEncoded = function( association )
		local function _getEncodedAssociations( associations, prefix )
			local encodedAssociations = {}
			for level = 1, 2 do
				for _, linkedId in pairs( associations[ level ] ) do
					table.insert( encodedAssociations, string.rep( "+", level - 1 ) .. prefix .. tostring( linkedId ) )
				end
			end
			return encodedAssociations
		end
		local result = {}
		if association.devices then
			table_append( result, _getEncodedAssociations( association.devices, "" ) )
		end
		if association.scenes then
			table_append( result, _getEncodedAssociations( association.scenes, "*" ) )
		end
		if association.ziBlueDevices then
			table_append( result, _getEncodedAssociations( association.ziBlueDevices, "%" ) )
		end
		return table.concat( result, "," )
	end,

	propagate = function( association, status, loadLevel, isLongPress )
		if ( association == nil ) then
			return
		end

		local status = status or ""
		local loadLevel = tonumber( loadLevel ) or -1
		local level = 1
		if isLongPress then
			level = 2
		end

		-- Associated devices
		if association.devices then
			for _, linkedDeviceId in ipairs( association.devices[ level ] ) do
				--debug( "Linked device #" .. tostring( linkedDeviceId ), "Association.propagate")
				if ( ( loadLevel > 0 ) and luup.device_supports_service( VARIABLE.DIMMER_LEVEL[1], linkedDeviceId ) ) then
					debug( "Dim associated device #" .. tostring( linkedDeviceId ) .. " to " .. tostring( loadLevel ) .. "%", "Association.propagate" )
					luup.call_action( VARIABLE.DIMMER_LEVEL[1], "SetLoadLevelTarget", { newLoadlevelTarget = loadLevel }, linkedDeviceId )
				elseif luup.device_supports_service( VARIABLE.SWITCH_POWER[1], linkedDeviceId ) then
					if ( ( status == "1" ) or ( loadLevel > 0 ) ) then
						debug( "Switch ON associated device #" .. tostring( linkedDeviceId ), "Association.propagate" )
						luup.call_action( VARIABLE.SWITCH_POWER[1], "SetTarget", { newTargetValue = "1" }, linkedDeviceId )
					else
						debug( "Switch OFF associated device #" .. tostring( linkedDeviceId ), "Association.propagate" )
						luup.call_action( VARIABLE.SWITCH_POWER[1], "SetTarget", { newTargetValue = "0" }, linkedDeviceId )
					end
				else
					error( "Associated device #" .. tostring( linkedDeviceId ) .. " does not support services Dimming or SwitchPower", "Association.propagate" )
				end
			end
		end

		-- Associated scenes (just if status is ON)
		if ( association.scenes and ( ( status == "1" ) or ( loadLevel > 0 ) ) ) then
			for _, linkedSceneId in ipairs( association.scenes[ level ] ) do
				debug( "Call associated scene #" .. tostring(linkedSceneId), "Association.propagate" )
				luup.call_action( "urn:micasaverde-com:serviceId:HomeAutomationGateway1", "RunScene", { SceneNum = linkedSceneId }, 0 )
			end
		end
	end
}


-- **************************************************
-- Discovered ZiBlue devices
-- **************************************************

local g_discoveredDevices = {}
local g_indexDiscoveredDevicesById = {}

DiscoveredDevices = {
	add = function( protocol, protocolDeviceId, dataFlag, rfQuality, infoType, subType, featureName, data, comment )
		local hasBeenAdded = false
		local id = protocol .. ";" .. protocolDeviceId
		local discoveredDevice = g_indexDiscoveredDevicesById[ id ]
		if ( discoveredDevice == nil ) then
			local ziblueInfos = ZIBLUE_INFOS[ tostring( infoType ) .. ";" .. tostring(subType) ] or ZIBLUE_INFOS[ tostring( infoType ) ] or {}
			discoveredDevice = {
				protocol = protocol,
				protocolFlag = ( ( dataFlag ~= "-1 " ) and tostring( ZIBLUE_DATA_FLAG[ dataFlag ] ) or "" ),
				protocolDeviceId = protocolDeviceId,
				comment = comment,
				featureGroups = table_extend( {}, ziblueInfos )
			}
			for _, info in ipairs( discoveredDevice.featureGroups ) do
				if not ( info.isUsed == true ) then
					info.isUsed = false
				end
			end
			table.insert( g_discoveredDevices, discoveredDevice )
			g_indexDiscoveredDevicesById[ id ] = discoveredDevice
			hasBeenAdded = true
			debug( "Discovered ZiBlue device '" .. id .. "'", "DiscoveredDevices.add" )
		end
		discoveredDevice.rfQuality = tonumber( rfQuality )
		-- Features
		local hasBeenFound = false
		for _, info in ipairs( discoveredDevice.featureGroups ) do
			if info.features[ featureName ] then
				hasBeenFound = true
				info.features[ featureName ].isUsed = true
				if ( type( data ) == "table" ) then
					info.features[ featureName ].state = data.value .. " " .. data.unit
					if ( ( featureName == "hygrometry" ) and ( data.value == "0" ) ) then
						info.features[ featureName ].isUsed = false
					end
				else
					info.features[ featureName ].state = data
				end
				info.isUsed = false
				for _, feature in pairs( info.features ) do
					if feature.isUsed then
						info.isUsed = true
					end
				end
				debug( "Discovered ZiBlue device '" .. id .. "' and new feature '" .. featureName .. "'", "DiscoveredDevices.add" )
				break
			end
		end
		if not hasBeenFound then
			if ( featureName ~= "LowBatt" ) then
				warning( "Feature '" .. featureName .. "' is not known for ZiBlue device '" .. id .. "'", "DiscoveredDevices.add" )
			end
		end
		discoveredDevice.lastUpdate = os.time()
		if hasBeenAdded then
			Variable.set( DEVICE_ID, VARIABLE.LAST_DISCOVERED, os.time() )
			UI.show( "New device discovered" )
		end
		--debug( json.encode(g_discoveredDevices), "DiscoveredDevices.retrieve" )
		return hasBeenAdded
	end,

	get = function( protocol, protocolDeviceId )
		if ( ( protocol ~= nil ) and ( protocolDeviceId ~= nil ) ) then
			local id = protocol .. ";" .. protocolDeviceId
			return g_indexDiscoveredDevicesById[ id ]
		else
			return g_discoveredDevices
		end
	end,

	remove = function( protocol, protocolDeviceId )
		if ( ( protocol ~= nil ) and ( protocolDeviceId ~= nil ) ) then
			local id = protocol .. ";" .. protocolDeviceId
			local discoveredDevice = g_indexDiscoveredDevicesById[ id ]
			for i, device in ipairs( g_discoveredDevices ) do
				if ( device == discoveredDevice ) then
					table.remove( g_discoveredDevices, i )
					g_indexDiscoveredDevicesById[ id ] = nil
					break
				end
			end
		end
	end
}


-- **************************************************
-- Ziblue Devices
-- **************************************************

local g_ziBlueDevices = {}   -- The list of all our child devices
local g_indexZiBlueDevicesById = {}
local g_indexZiBlueDevicesByDeviceId = {}
local g_indexZiBlueFeaturesById = {}
local g_deviceIdsById = {} -- TODO : ça sert où ?

ZiBlueDevices = {

	-- Get a list with all our child devices.
	retrieve = function()
		local formerZiBlueDevices = g_ziBlueDevices
		g_ziBlueDevices = {}
		g_indexZiBlueDevicesById = {}
		g_indexZiBlueDevicesByDeviceId = {}
		g_indexZiBlueFeaturesById = {}
		g_deviceIdsById = {}
		for deviceId, device in pairs( luup.devices ) do
			if ( device.device_num_parent == DEVICE_ID ) then
				local protocol, protocolDeviceId, deviceNum = unpack( string_split( device.id or "", ";" ) )
				deviceNum = tonumber(deviceNum) or 1
				if ( ( protocol == nil ) or ( protocolDeviceId == nil ) or ( deviceNum == nil ) ) then
					debug( "Found child device #".. tostring( deviceId ) .."(".. device.description .."), but id '" .. tostring( device.id ) .. "' does not match pattern '[0-9]+;[0-9]+;[0-9]+'", "ZiBlueDevices.retrieve" )
				else
					local id = protocol .. ";" .. protocolDeviceId
					local ziBlueDevice = g_indexZiBlueDevicesById[ id ]
					if ( ziBlueDevice == nil ) then
						ziBlueDevice = {
							protocol = protocol,
							protocolDeviceId = protocolDeviceId,
							dataFlag = 0, -- TODO : attention nécessaire pour l'envoi ?
							rfQuality = -1,
							features = {}
						}
						table.insert( g_ziBlueDevices, ziBlueDevice )
						g_indexZiBlueDevicesById[ id ] = ziBlueDevice
						g_indexZiBlueFeaturesById[ id ] = {}
						g_deviceIdsById[ id ] = {}
					end
					--
					if ( deviceNum == 1 ) then
						-- Main device
						ziBlueDevice.mainDeviceId = deviceId
					elseif not ziBlueDevice.mainDeviceId then
						ziBlueDevice.mainDeviceId = deviceId
					end
					g_deviceIdsById[ id ][ deviceNum ] = deviceId
					-- Features
					local featureNames = string_split( Variable.get( deviceId, VARIABLE.FEATURE ) or "default", "," )
					-- Settings
					local settings = {}
					for _, encodedSetting in ipairs( string_split( Variable.get( deviceId, VARIABLE.SETTING ) or "", "," ) ) do
						local settingName, value = string.match( encodedSetting, "([^=]*)=?(.*)" )
						if not string_isEmpty( settingName ) then
							settings[ settingName ] = not string_isEmpty( value ) and value or true
						end
					end
					for _, featureName in ipairs( featureNames ) do
						local feature = g_indexZiBlueFeaturesById[ id ][ featureName ]
						if ( feature ~= nil ) then
							-- TODO
							--[[
							warning(
								"Found device #".. tostring( deviceId ) .."(".. device.description ..")," ..
								" productId=" .. productId .. ", channelId=" .. channelId ..
								" but this channel is already defined for device #" .. tostring( ziBlueDevice.channels[ channelId ].deviceId ) .. "(" .. luup.devices[ ziBlueDevice.channels[ channelId ].deviceId ].description .. ")",
								"ZiBlueDevices.retrieve"
							)
							--]]
						else
							local deviceTypeInfos = _getDeviceTypeInfos( device.device_type )
							feature = {
								name = featureName,
								deviceId = deviceId,
								deviceName = device.description,
								deviceType = device.device_type,
								deviceTypeName = deviceTypeInfos and deviceTypeInfos.name or "UNKOWN",
								lastCommand = 0,
								lastCommandReceiveTime = 0,
								settings = settings,
								association = Association.get( Variable.get( deviceId, VARIABLE.ASSOCIATION ) )
							}
							table.insert( ziBlueDevice.features, feature )
							g_indexZiBlueFeaturesById[ id ][ featureName ] = feature
							-- Add to index
							if ( g_indexZiBlueDevicesByDeviceId[ tostring( deviceId ) ] == nil ) then
								g_indexZiBlueDevicesByDeviceId[ tostring( deviceId ) ] = { ziBlueDevice, { feature } }
							else
								table.insert( g_indexZiBlueDevicesByDeviceId[ tostring( deviceId ) ][2], feature )
							end
						end
						debug( "Found device #" .. tostring(deviceId) .. "(" .. feature.deviceName .. "), protocol " .. protocol .. ", id " .. protocolDeviceId .. ", feature " .. featureName, "ZiBlueDevices.retrieve" )
					end
				end
			end
		end
		-- Retrieve former states
		for _, formerZiBlueDevice in ipairs( formerZiBlueDevices ) do
			local id = formerZiBlueDevice.protocol .. ";" .. formerZiBlueDevice.protocolDeviceId
			local ziBlueDevice = g_indexZiBlueDevicesById[ id ]
			if ( ziBlueDevice ) then
				for _, formerFeature in ipairs( formerZiBlueDevice.features ) do
					local feature = g_indexZiBlueFeaturesById[ id ][ formerFeature.name ]
					if ( feature ) then
						feature.state = formerFeature.state
					end
				end
			elseif ( formerZiBlueDevice.isNew ) then
				-- Add newly created ZiBlue device (not present in luup.devices until a reload of the luup engine)
				table.insert( g_ziBlueDevices, formerZiBlueDevice )
				g_indexZiBlueDevicesById[ id ] = formerZiBlueDevice
				g_indexZiBlueFeaturesById[ id ] = {}
				g_deviceIdsById[ id ] = {}
				for _, feature in ipairs( formerZiBlueDevice.features ) do
					g_indexZiBlueFeaturesById[ id ][ feature.name ] = feature 
				end
			end
		end
		formerZiBlueDevices = nil
		--debug( json.encode(g_ziBlueDevices), "ZiBlueDevices.retrieve" )
	end,

	add = function( protocol, protocolDeviceId, deviceTypeInfos, featureNames, deviceId, deviceName )
		local id = tostring(protocol) .. ";" .. tostring(protocolDeviceId)
		debug( "Add ZiBlue device '" .. id .. "', features " .. json.encode( featureNames or "" ) .. ", deviceId #" .. tostring(deviceId) .."(".. tostring(deviceName) ..")", "ZiBlueDevices.add" )
		local newZiBlueDevice = g_indexZiBlueDevicesById[ id ]
		if ( newZiBlueDevice == nil ) then
			newZiBlueDevice = {
				isNew = true,
				protocol = protocol,
				protocolDeviceId = protocolDeviceId,
				rfQuality = -1,
				features = {}
			}
			table.insert( g_ziBlueDevices, newZiBlueDevice )
			g_indexZiBlueDevicesById[ id ] = newZiBlueDevice
			g_indexZiBlueFeaturesById[ id ] = {}
		end
		for _, featureName in ipairs( featureNames ) do
			local feature = {
				name = featureName,
				deviceId = deviceId,
				deviceName = deviceName,
				deviceType = deviceTypeInfos.type,
				deviceTypeName = deviceTypeInfos.name or "UNKOWN",
				association = Association.get( "" )
			}
			table.insert( newZiBlueDevice.features, feature )
			g_indexZiBlueFeaturesById[ id ][ featureName ] = feature
		end
	end,

	getById = function( id, featureName )
		if ( id ~= nil ) then
			local ziBlueDevice = g_indexZiBlueDevicesById[ id ]
			if ( ziBlueDevice ~= nil ) then
				if ( featureName ~= nil ) then
					local feature = g_indexZiBlueFeaturesById[ id ][ featureName ]
					if ( feature ~= nil ) then
						return ziBlueDevice, feature
					end
				end
				return ziBlueDevice, nil
			end
			return nil
		else
			return g_ziBlueDevices
		end
	end,

	get = function( protocol, protocolDeviceId, featureName )
		if ( ( protocol ~= nil ) and ( protocolDeviceId ~= nil ) ) then
			local id = tostring(protocol) .. ";" .. tostring(protocolDeviceId)
			return ZiBlueDevices.getById( id, featureName )
		else
			return g_ziBlueDevices
		end
	end,

	getFromDeviceId = function( deviceId )
		local index = g_indexZiBlueDevicesByDeviceId[ tostring( deviceId ) ]
		if index then
			return index[1], index[2][1]
		else
			warning( "ZiBlue device with deviceId #" .. tostring( deviceId ) .. "' is unknown", "ZiBlueDevices.getFromDeviceId" )
		end
		return nil
	end,

	log = function()
		local nbZiBlueDevices = 0
		local nbDevicesByFeature = {}
		for _, ziBlueDevice in pairs( g_ziBlueDevices ) do
			nbZiBlueDevices = nbZiBlueDevices + 1
			for _, feature in ipairs( ziBlueDevice.features ) do
				if (nbDevicesByFeature[feature.name] == nil) then
					nbDevicesByFeature[feature.name] = 1
				else
					nbDevicesByFeature[feature.name] = nbDevicesByFeature[feature.name] + 1
				end
			end
		end
		log("* ZiBlue devices: " .. tostring(nbZiBlueDevices), "ZiBlueDevices.log")
		for featureName, nbDevices in pairs(nbDevicesByFeature) do
			log("*" .. string_lpad(featureName, 20) .. ": " .. tostring(nbDevices), "ZiBlueDevices.log")
		end
	end
}


-- **************************************************
-- Serial connection
-- **************************************************

SerialConnection = {
	-- Check IO connection
	check = function()
		if not luup.io.is_connected( DEVICE_ID ) then
			-- Try to connect by ip (openLuup)
			local ip = luup.attr_get( "ip", DEVICE_ID )
			if ( ( ip ~= nil ) and ( ip ~= "" ) ) then
				local ipaddr, port = string.match( ip, "(.-):(.*)" )
				if ( port == nil ) then
					ipaddr = ip
					port = 80
				end
				log( "Open connection on ip " .. ipaddr .. " and port " .. port, "SerialConnection.check" )
				luup.io.open( DEVICE_ID, ipaddr, tonumber( port ) )
			end
		end
		if not luup.io.is_connected( DEVICE_ID ) then
			error( "Serial port not connected. First choose the serial port and restart the lua engine.", "SerialConnection.check", false )
			UI.showError( "Choose the Serial Port" )
			return false
		else
			local ioDevice = tonumber(( Variable.get( DEVICE_ID, VARIABLE.IO_DEVICE ) ))
			if ioDevice then
				-- Check serial settings
				-- TODO : si valeur vide forcer la valeur ?
				local baud = Variable.get( ioDevice, VARIABLE.BAUD ) or "115200"
				if ( baud ~= "115200" ) then
					error( "Incorrect setup of the serial port. Select 115200 bauds.", "SerialConnection.check", false )
					UI.showError( "Select 115200 bauds for the Serial Port" )
					return false
				end
				log( "Baud is 115200", "SerialConnection.check" )

				-- TODO : Check Parity none / Data bits 8 / Stop bit 1
			end
		end
		log( "Serial port is connected", "SerialConnection.check" )
		return true
	end
}


-- **************************************************
-- HTTP request handler
-- **************************************************

local _handlerCommands = {
	["default"] = function( params, outputFormat )
		return "Unknown command '" .. tostring( params["command"] ) .. "'", "text/plain"
	end,

	["getDevicesInfos"] = function( params, outputFormat )
		log( "Get device list", "handleCommand.getDevicesInfos" )
		result = { devices = ZiBlueDevices.get(), discoveredDevices = DiscoveredDevices.get() }
		return tostring( json.encode( result ) ), "application/json"
	end,

	["getDeviceParams"] = function( params, outputFormat )
		log( "Get device params", "handleCommand.getDeviceParams" )
		result = {}
		return tostring( json.encode( result ) ), "application/json"
	end,

	["getProtocolsInfos"] = function( params, outputFormat )
		log( "Get protocols", "handleCommand.getProtocolsInfos" )
		return tostring( json.encode( ZIBLUE_SEND_PROTOCOL ) ), "application/json"
	end,

	["getErrors"] = function( params, outputFormat )
		return tostring( json.encode( g_errors ) ), "application/json"
	end
}
setmetatable(_handlerCommands,{
	__index = function(t, command, outputFormat)
		log( "No handler for command '" ..  tostring(command) .. "'", "handlerZiBlueGateway" )
		return _handlerCommands["default"]
	end
})

local function _handleCommand( lul_request, lul_parameters, lul_outputformat )
	--log("lul_request: " .. tostring(lul_request), "handleCommand")
	--log("lul_parameters: " .. tostring(json.encode(lul_parameters)), "handleCommand")
	--log("lul_outputformat: " .. tostring(lul_outputformat), "handleCommand")

	local command = lul_parameters["command"] or "default"
	log( "Get handler for command '" .. tostring(command) .."'", "handleCommand" )
	return _handlerCommands[command]( lul_parameters, lul_outputformat )
end


-- **************************************************
-- Action implementations for childs
-- **************************************************

Child = {

	setTarget = function( childDeviceId, newTargetValue )
		local ziBlueDevice, feature = ZiBlueDevices.getFromDeviceId( childDeviceId )
		if (ziBlueDevice == nil) then
			error( "Device #" .. tostring( childDeviceId ) .. " is not an ZiBlue device", "Child.setTarget" )
			return JOB_STATUS.ERROR
		end
		DeviceHelper.setStatus( ziBlueDevice, feature, newTargetValue )
		return JOB_STATUS.DONE
	end,

	setLoadLevelTarget = function( childDeviceId, newLoadlevelTarget )
		local ziBlueDevice, feature = ZiBlueDevices.getFromDeviceId( childDeviceId )
		if ( ziBlueDevice == nil ) then
			error( "Device #" .. tostring( childDeviceId ) .. " is not an ZiBlue device", "Child.setLoadLevelTarget" )
			return JOB_STATUS.ERROR
		end
		DeviceHelper.setLoadLevel( ziBlueDevice, feature, newLoadlevelTarget )
		return JOB_STATUS.DONE
	end,

	setArmed = function( childDeviceId, newArmedValue )
		local ziBlueDevice, feature = ZiBlueDevices.getFromDeviceId( childDeviceId )
		if ( ziBlueDevice == nil ) then
			error( "Device #" .. tostring( childDeviceId ) .. " is not an ZiBlue device", "Child.setArmed" )
			return JOB_STATUS.ERROR
		end
		DeviceHelper.setArmed( ziBlueDevice, feature, newArmedValue or "0" )
		return JOB_STATUS.DONE
	end,

	moveShutter = function( childDeviceId, direction )
		local ziBlueDevice, feature = ZiBlueDevices.getFromDeviceId( childDeviceId )
		if ( ziBlueDevice == nil ) then
			error( "Device #" .. tostring( childDeviceId ) .. " is not an ZiBlue device", "Child.moveShutter" )
			return JOB_STATUS.ERROR
		end
		DeviceHelper.moveShutter( ziBlueDevice, feature, direction )
		return JOB_STATUS.DONE
	end

}


-- **************************************************
-- Main action implementations
-- **************************************************

function refresh()
	debug( "Refresh ZiBlue devices", "refresh" )
	ZiBlueDevices.retrieve()
	ZiBlueDevices.log()
	return JOB_STATUS.DONE
end

function getDeviceMaxID( protocol )
    
end

local function _createDevice( protocol, protocolDeviceId, deviceNum, deviceName, deviceTypeInfos, roomId, parameters, featureNames )
	local id = protocol .. ";" .. protocolDeviceId
	local internalId = id .. ";" .. tostring(deviceNum)
	if ( not deviceTypeInfos or not deviceTypeInfos.file ) then
		error( "Device infos are missing for ZiBlue device '" .. id .. "'", "createDevice" )
		return
	end
	debug( "Add ZiBlue productId '" .. internalId .. "', deviceFile '" .. deviceTypeInfos.file .. "'", "createDevice" )
	local newDeviceId = luup.create_device(
		'', -- device_type
		internalId,
		deviceName,
		deviceTypeInfos.file,
		'', -- upnp_impl
		'', -- ip
		'', -- mac
		false, -- hidden
		false, -- invisible
		DEVICE_ID, -- parent
		roomId,
		0, -- pluginnum
		parameters,
		0, -- pnpid
		'', -- nochildsync
		'', -- aeskey
		false, -- reload
		false -- nodupid
	)

	ZiBlueDevices.add( protocol, protocolDeviceId, deviceTypeInfos, featureNames, newDeviceId, deviceName )

	return newDeviceId
end

function createDevices( productIds )
	debug( "Create devices " .. tostring(productIds), "createDevices" )
	local hasBeenCreated = false
	local roomId = luup.devices[ DEVICE_ID ].room_num or 0
	for _, productId in ipairs( string_split( productIds, "|" ) ) do

		local protocol, protocolDeviceId, deviceTypeNames, settings, deviceName = unpack( string_split( productId, ";" ) )
		deviceTypeNames = string_split( deviceTypeNames or "", ",", string_trim )
		settings = string_split( settings or "", ",", string_trim )
		local id = protocol .. ";" .. protocolDeviceId
		local msg = "ZiBlue device '" .. id .. "'"
		if ZiBlueDevices.getById( id ) then
			error( msg .. " already exists", "createDevices" )
		else
			local discoveredDevice = DiscoveredDevices.get( protocol, protocolDeviceId )
			if ( discoveredDevice ~= nil ) then
				-- First, get the feature groups that will be created on the Vera (give the number of devices)
				local featureGroups = {}
				for _, featureGroup in ipairs( discoveredDevice.featureGroups ) do
					if not ( featureGroup.isUsed == false ) then
						table.insert( featureGroups, featureGroup )
					end
				end
				for i, featureGroup in ipairs( featureGroups ) do
					local deviceTypeName = deviceTypeNames[i]
					if ( ( deviceTypeName == nil ) or not table_contains( featureGroup.deviceTypes, deviceTypeName ) ) then
						deviceTypeName = deviceTypeNames[1]
						-- TODO : log pb
					end

					-- Add new device
					debug( msg .. ", create device " .. deviceTypeName .. " from discovered ZiBlue device", "createDevices" )
					local deviceTypeInfos = _getDeviceTypeInfos( deviceTypeName )
					local parameters = _getEncodedParameters( deviceTypeInfos )
					local featureNames = table_getKeys( table_filter( featureGroup.features, function( k, v ) return not ( v.isUsed == false ) end ) )
					parameters = parameters .. VARIABLE.FEATURE[1] .. "," .. VARIABLE.FEATURE[2] .. "=" .. table.concat( featureNames, "," ) .. "\n"
					parameters = parameters .. VARIABLE.ASSOCIATION[1] .. "," .. VARIABLE.ASSOCIATION[2] .. "=\n"
					parameters = parameters .. VARIABLE.SETTING[1] .. "," .. VARIABLE.SETTING[2] .. "=" .. table.concat( table_append( settings, featureGroup.settings or {}, true ), "," ) .. "\n"
					if ( featureGroup.isBatteryPowered ) then
						parameters = parameters .. VARIABLE.BATTERY_LEVEL[1] .. "," .. VARIABLE.BATTERY_LEVEL[2] .. "=\n"
					end

					deviceName = protocol .. " " .. protocolDeviceId .. ( ( #featureGroups > 1 ) and ( "/" .. tostring(i) ) or "" )
					local newDeviceId = _createDevice( protocol, protocolDeviceId, i, deviceName, deviceTypeInfos, roomId, parameters, featureNames )

					debug( msg .. ", device #" .. tostring(newDeviceId) .. "(" .. deviceName .. ") has been created", "createDevices" )
					hasBeenCreated = true
				end
				DiscoveredDevices.remove( protocol, protocolDeviceId )
			else
				local deviceTypeName = deviceTypeNames[1]

				-- Create a new device without template (not from a discovered device)
				debug( msg .. ", create device " .. deviceTypeName, "createDevices" )

				local deviceTypeInfos = _getDeviceTypeInfos( deviceTypeName )
				local parameters = _getEncodedParameters( deviceTypeInfos )
				parameters = parameters .. VARIABLE.FEATURE[1] .. "," .. VARIABLE.FEATURE[2] .. "=state\n"
				if ( protocol == "PARROT" ) then
					parameters = parameters .. VARIABLE.SETTING[1] .. "," .. VARIABLE.SETTING[2] .. "=" .. table.concat( table_append( settings, { "receiver", "button" } ), "," )  .. "\n"
				else
					parameters = parameters .. VARIABLE.SETTING[1] .. "," .. VARIABLE.SETTING[2] .. "=" .. table.concat( table_append( settings, "receiver" ), "," ) .. "\n"
				end
				if ( not deviceName or deviceName == "" ) then
					deviceName = protocol .. " " .. protocolDeviceId
				end
				local newDeviceId = _createDevice( protocol, protocolDeviceId, 1, deviceName, deviceTypeInfos, roomId, parameters, { "state" } )

				debug( msg .. ", device #" .. tostring(newDeviceId) .. "(" .. tostring(deviceName) .. ") has been created", "createDevices" )
				hasBeenCreated = true
			end

		end
	end

	if hasBeenCreated then
		ZiBlueDevices.retrieve()
		ZiBlueDevices.log()
		Variable.set( DEVICE_ID, VARIABLE.LAST_UPDATE, os.time() )
	end

	return JOB_STATUS.DONE
end

-- Teach a receiver (or Parrot). This is done on an unknown device (it wil be created)
function teachIn( productId, action, comment )
	local protocol, protocolDeviceId = unpack( string_split( productId, ";" ) )
	protocolDeviceId = tonumber(protocolDeviceId)
	if ( ( protocol == nil ) or ( protocolDeviceId == nil ) ) then
		error( "Protocol and device id are mandatory", "teachIn" )
		return JOB_STATUS.ERROR
	end
	if ( protocol == "PARROT" ) then
		-- PARROTLEARN
		if ( ( protocolDeviceId < 0 ) or ( protocolDeviceId > 239 ) ) then
			error( "Id of the Parrot device " .. tostring(protocolDeviceId) .. " is not between 0 and 239", "teachIn" )
			return JOB_STATUS.ERROR, nil
		end
		action = ( action == "OFF" ) and "OFF" or "ON"
		debug( "Start Parrot learning for #" .. tostring(protocolDeviceId) .. ", action " .. action .. " and reminder '" .. tostring(comment) .. "'", "teachIn" )
		Network.send( "ZIA++PARROTLEARN ID " .. tostring(protocolDeviceId) .. " " .. action .. ( comment and ( " [" .. tostring(comment) .. "]" ) or "" ) )
	else
		if ( ( protocolDeviceId < 0 ) or ( protocolDeviceId > 255 ) ) then
			error( "Id of the device " .. tostring(protocolDeviceId) .. " is not between 0 and 255", "teachIn" )
			return JOB_STATUS.ERROR, nil
		end
		debug("Teach in " .. productId, "teachIn")
		Network.send( "ZIA++ASSOC " .. protocol .. " ID " .. tostring(protocolDeviceId) )
	end
	return JOB_STATUS.DONE
end

-- Associate a feature to devices on the Vera
function associate( productId, featureName, strAssociation )
	local ziBlueDevice, feature = ZiBlueDevices.getById( productId, featureName )
	if ( ( ziBlueDevice == nil ) or ( feature == nil ) ) then
		return JOB_STATUS.ERROR
	end
	debug("Associate ZiBlue device '" .. tostring( ziBlueDevice.id ) .. "' and feature #" .. feature.name .. " with " .. tostring( strAssociation ), "associate" )
	feature.association = Association.get( strAssociation )
	Variable.set( feature.deviceId, VARIABLE.ASSOCIATION, Association.getEncoded( feature.association ) )
	return JOB_STATUS.DONE
end

function setTarget( productId, newTargetValue )
	local protocol, protocolDeviceId, qualifier = unpack( string_split( productId, ";" ) )
	if ( ( protocol == nil ) or ( protocolDeviceId == nil ) ) then
		error( "Protocol and device id are mandatory", "setTarget" )
		return JOB_STATUS.ERROR
	end
	local cmd = ( newTargetValue == "1" ) and "ON" or "OFF"
	debug("Set " .. cmd .. " " .. productId, "setTarget")
	Network.send( "ZIA++" .. cmd .. " ID " .. tostring(protocolDeviceId) .. " " .. tostring(protocol) .. ( qualifier and ( " QUALIFIER " .. tostring(qualifier) ) or "" ) )
	return JOB_STATUS.DONE
end

-- DEBUG METHOD
function sendMessage( message, job )
	debug( "Send message: " .. message, "sendMessage" )
	Network.send( message )
	return JOB_STATUS.DONE
end


-- **************************************************
-- Startup
-- **************************************************

-- Init plugin instance
local function _initPluginInstance()
	log( "Init", "initPluginInstance" )

	-- Update the Debug Mode
	local debugMode = ( Variable.getOrInit( DEVICE_ID, VARIABLE.DEBUG_MODE, "0" ) == "1" ) and true or false
	if debugMode then
		log( "DebugMode is enabled", "init" )
		debug = log
	else
		log( "DebugMode is disabled", "init" )
		debug = function() end
	end

	Variable.set( DEVICE_ID, VARIABLE.PLUGIN_VERSION, _VERSION )
	Variable.set( DEVICE_ID, VARIABLE.LAST_UPDATE, os.time() )
	Variable.set( DEVICE_ID, VARIABLE.LAST_MESSAGE, "" )
	Variable.getOrInit( DEVICE_ID, VARIABLE.LAST_DISCOVERED, "" )
end

-- Register with ALTUI once it is ready
local function _registerWithALTUI()
	for deviceId, device in pairs( luup.devices ) do
		if ( device.device_type == "urn:schemas-upnp-org:device:altui:1" ) then
			if luup.is_ready( deviceId ) then
				log( "Register with ALTUI main device #" .. tostring( deviceId ), "registerWithALTUI" )
				luup.call_action(
					"urn:upnp-org:serviceId:altui1",
					"RegisterPlugin",
					{
						newDeviceType = "urn:schemas-upnp-org:device:ZiBlueGateway:1",
						newScriptFile = "J_ZiBlueGateway1.js",
						newDeviceDrawFunc = "ZiBlueGateway.ALTUI_drawDevice"
					},
					deviceId
				)
			else
				log( "ALTUI main device #" .. tostring( deviceId ) .. " is not yet ready, retry to register in 10 seconds...", "registerWithALTUI" )
				luup.call_delay( "ZiBlueGateway.registerWithALTUI", 10 )
			end
			break
		end
	end
end

function init( lul_device )
	log( "Start plugin '" .. _NAME .. "' (v" .. _VERSION .. ")", "startup" )

	-- Get the master device
	DEVICE_ID = lul_device

	-- Init
	_initPluginInstance()

	if ( type( json ) == "string" ) then
		UI.showError( "No JSON decoder" )
	elseif SerialConnection.check() then
		-- Get the list of the child devices
		math.randomseed( os.time() )
		ZiBlueDevices.retrieve()
		ZiBlueDevices.log()

		-- Open the connection with the RFP1000
		Network.send( "ZIA++HELLO" )
		Network.send( "ZIA++FORMAT JSON" )

		Network.send( "ZIA++STATUS SYSTEM JSON" )
		Network.send( "ZIA++STATUS PARROT JSON" )
		
	end

	-- Watch setting changes
	Variable.watch( DEVICE_ID, VARIABLE.DEBUG_MODE, "ZiBlueGateway.initPluginInstance" )

	-- HTTP Handlers
	log( "Register handler ZiBlueGateway", "init" )
	luup.register_handler( "ZiBlueGateway.handleCommand", "ZiBlueGateway" )

	-- Register with ALTUI
	luup.call_delay( "ZiBlueGateway.registerWithALTUI", 10 )

	if ( luup.version_major >= 7 ) then
		luup.set_failure( 0, DEVICE_ID )
	end

	log( "Startup successful", "init" )
	return true, "Startup successful", _NAME
end


-- Promote the functions used by Vera's luup.xxx functions to the global name space
_G["ZiBlueGateway.handleCommand"] = _handleCommand
_G["ZiBlueGateway.Message.deferredProcess"] = Message.deferredProcess
_G["ZiBlueGateway.Network.send"] = Network.send

_G["ZiBlueGateway.initPluginInstance"] = _initPluginInstance
_G["ZiBlueGateway.registerWithALTUI"] = _registerWithALTUI
