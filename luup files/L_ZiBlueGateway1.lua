--[[
  This file is part of the plugin ZiBlue Gateway.
  https://github.com/vosmont/Vera-Plugin-ZiBlueGateway
  Copyright (c) 2018 Vincent OSMONT
  This code is released under the MIT License, see LICENSE.

  Device : device on the Vera / openLuup
  Equipment : device handled by the ZiBlue dongle
--]]

module( "L_ZiBlueGateway1", package.seeall )

-- Load libraries
local hasJson, json = pcall( require, "dkjson" )


--https://apps.mios.com/plugin.php?id=1648


-- **************************************************
-- Plugin constants
-- **************************************************

_NAME = "ZiBlueGateway"
_DESCRIPTION = "ZiBlue gateway for the Vera"
_VERSION = "1.2.1"
_AUTHOR = "vosmont"

-- **************************************************
-- Plugin settings
-- **************************************************

local _SERIAL = {
	baudRate = "115200",
	dataBits = "8",
	parity = "none",
	stopBit = "1"
}

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

local debugMode = false
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
	PRESSURE = { "urn:upnp-org:serviceId:BarometerSensor1", "CurrentPressure", true },
	FORECAST = { "urn:upnp-org:serviceId:BarometerSensor1", "Forecast", true },
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
	-- Scene controller
	LAST_SCENE_ID = { "urn:micasaverde-com:serviceId:SceneController1", "LastSceneID", true, "LAST_SCENE_DATE" },
	LAST_SCENE_DATE = { "urn:micasaverde-com:serviceId:SceneController1", "LastSceneTime", false },
	-- Security
	ARMED = { "urn:micasaverde-com:serviceId:SecuritySensor1", "Armed", true },
	TRIPPED = { "urn:micasaverde-com:serviceId:SecuritySensor1", "Tripped", false, "LAST_TRIP" },
	ARMED_TRIPPED = { "urn:micasaverde-com:serviceId:SecuritySensor1", "ArmedTripped", false, "LAST_TRIP" },
	LAST_TRIP = { "urn:micasaverde-com:serviceId:SecuritySensor1", "LastTrip", true },
	TAMPER_ALARM = { "urn:micasaverde-com:serviceId:HaDevice1", "sl_TamperAlarm", false, "LAST_TAMPER" },
	LAST_TAMPER = { "urn:micasaverde-com:serviceId:SecuritySensor1", "LastTamper", true },
	-- Battery
	BATTERY_LEVEL = { "urn:micasaverde-com:serviceId:HaDevice1", "BatteryLevel", true, "BATTERY_DATE" },
	BATTERY_DATE = { "urn:micasaverde-com:serviceId:HaDevice1", "BatteryDate", true },
	-- Energy metering
	WATTS = { "urn:micasaverde-com:serviceId:EnergyMetering1", "Watts", true },
	KWH = { "urn:micasaverde-com:serviceId:EnergyMetering1", "KWH", true, "KWH_DATE" },
	KWH_DATE = { "urn:micasaverde-com:serviceId:EnergyMetering1", "KWHReading", true },
	-- HVAC
	HVAC_MODE_STATE = { "urn:micasaverde-com:serviceId:HVAC_OperatingState1", "ModeState", true },
	HVAC_MODE_STATUS = { "urn:upnp-org:serviceId:HVAC_UserOperatingMode1", "ModeStatus", true },
	HVAC_CURRENT_SETPOINT = { "urn:upnp-org:serviceId:TemperatureSetpoint1", "CurrentSetpoint", true },
	HVAC_CURRENT_SETPOINT_HEAT = { "urn:upnp-org:serviceId:TemperatureSetpoint1_Heat", "CurrentSetpoint", true },
	HVAC_CURRENT_SETPOINT_COOL = { "urn:upnp-org:serviceId:TemperatureSetpoint1_Cool", "CurrentSetpoint", true },
	-- Pilot Wire (Antor)
	PILOTWIRE_STATUS = { "urn:antor-fr:serviceId:PilotWire1", "Status", true },
	PILOTWIRE_TARGET = { "urn:antor-fr:serviceId:PilotWire1", "Target", true },
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
	-- Equipment
	FEATURE = { "urn:upnp-org:serviceId:ZiBlueDevice1", "Feature", true },
	ASSOCIATION = { "urn:upnp-org:serviceId:ZiBlueDevice1", "Association", true },
	SETTING = { "urn:upnp-org:serviceId:ZiBlueDevice1", "Setting", true }
}

-- Device types
local DEVICE = {
	SERIAL_PORT = {
		type = "urn:micasaverde-org:device:SerialPort:1", file = "D_SerialPort1.xml"
	},
	SECURITY_SENSOR = {
		type = "urn:schemas-micasaverde-com:device:SecuritySensor:1"
	},
	DOOR_SENSOR = {
		type = "urn:schemas-micasaverde-com:device:DoorSensor:1", file = "D_DoorSensor1.xml",
		category = 4, subCategory = 1,
		parameters = { { "ARMED", "0" }, { "TRIPPED", "0" }, { "TAMPER_ALARM", "0" } }
	},
	MOTION_SENSOR = {
		type = "urn:schemas-micasaverde-com:device:MotionSensor:1", file = "D_MotionSensor1.xml",
		category = 4, subCategory = 3,
		--jsonFile = "D_MotionSensorWithTamper1.json",
		parameters = { { "ARMED", "0" }, { "TRIPPED", "0" }, { "TAMPER_ALARM", "0" } }
	},
	SMOKE_SENSOR = {
		type = "urn:schemas-micasaverde-com:device:SmokeSensor:1", file = "D_SmokeSensor1.xml",
		category = 4, subCategory = 4,
		parameters = { { "ARMED", "0" }, { "TRIPPED", "0" }, { "TAMPER_ALARM", "0" } }
	},
	WIND_SENSOR = {
		type = "urn:schemas-micasaverde-com:device:WindSensor:1", file = "D_WindSensor1.xml",
		parameters = { { "WIND_DIRECTION", "0" }, { "WIND_GUST_SPEED", "0" }, { "WIND_AVERAGE_SPEED", "0" } }
	},
	BAROMETER_SENSOR = {
		type = "urn:schemas-micasaverde-com:device:BarometerSensor:1", file = "D_BarometerSensor1.xml",
		parameters = { { "PRESSURE", "0" }, { "FORECAST", "" } }
	},
	UV_SENSOR = {
		type = "urn:schemas-micasaverde-com:device:UvSensor:1", file = "D_UvSensor.xml",
		parameters = { { "UV", "0" } }
	},
	BINARY_LIGHT = {
		type = "urn:schemas-upnp-org:device:BinaryLight:1", file = "D_BinaryLight1.xml",
		parameters = { { "SWITCH_POWER", "0" } }
	},
	DIMMABLE_LIGHT = {
		type = "urn:schemas-upnp-org:device:DimmableLight:1", file = "D_DimmableLight1.xml",
		parameters = { { "SWITCH_POWER", "0" }, { "DIMMER_LEVEL", "0" } }
	},
	TEMPERATURE_SENSOR = {
		type = "urn:schemas-micasaverde-com:device:TemperatureSensor:1", file = "D_TemperatureSensor1.xml",
		parameters = { { "TEMPERATURE", "0" } }
	},
	HUMIDITY_SENSOR = {
		type = "urn:schemas-micasaverde-com:device:HumiditySensor:1", file = "D_HumiditySensor1.xml",
		parameters = { { "HUMIDITY", "0" } }
	},
	POWER_METER = {
		type = "urn:schemas-micasaverde-com:device:PowerMeter:1", file = "D_PowerMeter1.xml",
		parameters = { { "WATTS", "0" }, { "KWH", "0" } }
	},
	SHUTTER = {
		type = "urn:schemas-micasaverde-com:device:WindowCovering:1", file = "D_WindowCovering1.xml",
		parameters = { { "DIMMER_LEVEL", "0" } }
	},
	PILOT_WIRE = {
		type = "urn:antor-fr:device:PilotWire:1", file = "D_PilotWire1.xml",
		parameters = { { "PILOTWIRE_STATUS", "0" } }
	},
	THERMOSTAT = {
		type = "urn:schemas-upnp-org:device:HVAC_ZoneThermostat:1", file = "D_HVAC_ZoneThermostat1.xml",
		parameters = {
			{ "SWITCH_POWER", "0" }, { "HVAC_MODE_STATE", "Idle" }, { "HVAC_MODE_STATUS", "Off" },
			{ "HVAC_CURRENT_SETPOINT", "15" }, { "HVAC_CURRENT_SETPOINT_HEAT", "15" }, { "HVAC_CURRENT_SETPOINT_COOL", "15" }
		}
	},
	HEATER = {
		type = "urn:schemas-upnp-org:device:Heater:1", file = "D_Heater1.xml",
		parameters = {
			{ "SWITCH_POWER", "0" }, { "HVAC_MODE_STATE", "Idle" }, { "HVAC_MODE_STATUS", "Off" },
			{ "HVAC_CURRENT_SETPOINT", "15" }, { "HVAC_CURRENT_SETPOINT_HEAT", "15" }
		}
	},
	SCENE_CONTROLLER = {
		type = "urn:schemas-micasaverde-com:device:SceneController:1", file = "D_SceneController1.xml",
		parameters = { { "LAST_SCENE_ID", "" } }
	},
	MULTI_SWITCH = {
		-- TODO
		type = "urn:schemas-upnp-org:device:MultiSwitch:1"
	}
}

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
-- ZiBlue equipments
-- **************************************************

-- Equipment types
local EQUIPMENT = {
	[ "0" ] = { -- X10 / DOMIA LITE protocol / PARROT
		name = "Detector/sensor",
		modelings = {
			{
				mappings = {
					{ features = { "state" }, deviceTypes = { "BINARY_LIGHT", "DIMMABLE_LIGHT", "DOOR_SENSOR", "MOTION_SENSOR", "SMOKE_SENSOR" }, settings = { "transmitter" } }
				}
			}
		}
	},
	[ "KD101;1" ] = { -- KD101
		name = "Smoke sensor",
		modelings = {
			{
				mappings = {
					{ features = { "state" }, deviceTypes = { "SMOKE_SENSOR" }, settings = { "transmitter" } }
				}
			}
		}
	},
	[ "1" ] = { -- X10 (24/32 bits ID) / CHACON / BLYSS / JAMMING
		name = "Detector/sensor",
		modelings = {
			{
				mappings = {
					{ features = { "state" }, deviceTypes = { "BINARY_LIGHT", "DOOR_SENSOR", "MOTION_SENSOR", "SMOKE_SENSOR" }, settings = { "transmitter" } }
				}
			}
		}
	},
	[ "2;0" ] = { -- VISONIC detector/sensor (PowerCode device)
		name = "Detector/sensor",
		modelings = {
			{
				mappings = {
					{ features = { "state" } }, -- not used
					{ features = { "tamper", "alarm", "supervisor/alive" }, deviceTypes = { "BINARY_LIGHT", "DOOR_SENSOR", "MOTION_SENSOR", "SMOKE_SENSOR" }, settings = { "transmitter" } }
				}
			}
		}
	},
	[ "2;1" ] = { --  VISONIC remote control (CodeSecure device)
		name = "Remote control",
		modelings = {
			{
				mappings = {
					{ features = { "state" } }, -- not used
					{ features = { "button/command" }, deviceTypes = { "BINARY_LIGHT" }, settings = { "transmitter", "pulse" } },
					{ features = { "button1" }, deviceTypes = { "BINARY_LIGHT" }, settings = { "transmitter", "pulse" } },
					{ features = { "button2" }, deviceTypes = { "BINARY_LIGHT" }, settings = { "transmitter", "pulse" } },
					{ features = { "button3" }, deviceTypes = { "BINARY_LIGHT" }, settings = { "transmitter", "pulse" } },
					{ features = { "button4" }, deviceTypes = { "BINARY_LIGHT" }, settings = { "transmitter", "pulse" } }
				}
			},
			{
				mappings = {
					{ features = { "state" } }, -- not used
					{ features = { "button1", "button2", "button3", "button4" }, deviceTypes = { "MULTI_SWITCH" }, settings = { "transmitter", "pulse" } }
				}
			},
			{
				mappings = {
					{ features = { "state" } }, -- not used
					{ features = { "button1", "button2", "button3", "button4" }, deviceTypes = { "SCENE_CONTROLLER" }, settings = { "transmitter" } }
				}
			}
		}
	},
	[ "3;0" ] = { -- RTS shutter remote control
		name = "Shutter remote control",
		modelings = {
			{
				mappings = {
					{ features = { "state" } }, -- not used
					{ features = { "up/on" }, deviceTypes = { "BINARY_LIGHT" }, settings = { "transmitter", "pulse" }, isUsed = true },
					{ features = { "down/off" }, deviceTypes = { "BINARY_LIGHT" }, settings = { "transmitter", "pulse" }, isUsed = true },
					{ features = { "my" }, deviceTypes = { "BINARY_LIGHT" }, settings = { "transmitter", "pulse" }, isUsed = true }
				}
			},
			{
				mappings = {
					{ features = { "state" } }, -- not used
					{ features = { "up/on", "down/off", "my" }, deviceTypes = { "SHUTTER" }, settings = { "transmitter", "my=50" } }
				}
			}
		}
	},
	[ "3;1" ] = { -- RTS portal remote control
		name = "Portal remote control",
		modelings = {
			{
				mappings = {
					{ features = { "state" } }, -- not used
					{ features = { "button1" }, deviceTypes = { "BINARY_LIGHT" }, settings = { "transmitter", "pulse" } },
					{ features = { "button2" }, deviceTypes = { "BINARY_LIGHT" }, settings = { "transmitter", "pulse" } },
					{ features = { "button3" }, deviceTypes = { "BINARY_LIGHT" }, settings = { "transmitter", "pulse" } },
					{ features = { "button4" }, deviceTypes = { "BINARY_LIGHT" }, settings = { "transmitter", "pulse" } }
				}
			},
			{
				mappings = {
					{ features = { "state" } }, -- not used
					{ features = { "button1", "button2", "button3", "button4" }, deviceTypes = { "MULTI_SWITCH" }, settings = { "transmitter", "pulse" } }
				}
			},
			{
				mappings = {
					{ features = { "state" } }, -- not used
					{ features = { "button1", "button2", "button3", "button4" }, deviceTypes = { "SCENE_CONTROLLER" }, settings = { "transmitter" } }
				}
			}
		}
	},
	[ "4" ] = { -- Scientific Oregon
		name = "Thermo/hygro sensor",
		modelings = {
			{
				mappings = {
					{ features = { "temperature" }, deviceTypes = { "TEMPERATURE_SENSOR" }, settings = { "transmitter" } },
					{ features = { "hygrometry" }, deviceTypes = { "HUMIDITY_SENSOR" }, settings = { "transmitter" } }
				}
			}
		}
	},
	[ "5" ] = { -- Scientific Oregon
		name = "Atmospheric pressure sensor",
		modelings = {
			{
				mappings = {
					{ features = { "temperature" }, deviceTypes = { "TEMPERATURE_SENSOR" }, settings = { "transmitter" } },
					{ features = { "hygrometry" }, deviceTypes = { "HUMIDITY_SENSOR" }, settings = { "transmitter" } },
					{ features = { "pressure" }, deviceTypes = { "BAROMETER_SENSOR" }, settings = { "transmitter" } }
				}
			}
		}
	},
	[ "6" ] = { -- Scientific Oregon
		name = "Wind sensor",
		modelings = {
			{
				mappings = {
					{ features = { "direction", "wind speed" }, deviceTypes = { "WIND_SENSOR" }, settings = { "transmitter" } }
				}
			}
		}
	},
	[ "7" ] = { -- Scientific Oregon
		name = "UV sensor",
		modelings = {
			{
				mappings = {
					{ features = { "uv" }, deviceTypes = { "UV_SENSOR" }, settings = { "transmitter" } }
				}
			}
		}
	},
	[ "8" ] = { -- OWL
		name = "Power meter",
		modelings = {
			{
				mappings = {
					{ features = { "energy", "power" }, deviceTypes = { "POWER_METER" }, settings = { "transmitter" } },
					{ features = { "p1" }, deviceTypes = { "POWER_METER" }, settings = { "transmitter" } },
					{ features = { "p2" }, deviceTypes = { "POWER_METER" }, settings = { "transmitter" } },
					{ features = { "p3" }, deviceTypes = { "POWER_METER" }, settings = { "transmitter" } }
				}
			}
		}
	},
	[ "9" ] = { -- Scientific Oregon
		name = "Rain meter",
		modelings = {
			{
				mappings = {
					{ features = { "total rain", "current rain" }, deviceTypes = { "RAIN_METER" }, settings = { "transmitter" } } -- TODO
				}
			}
		}
	},
	[ "10" ] = { -- X2D Thermostats
		name = "Thermostat",
		modelings = {
			{
				mappings = {
					{ features = { "state" }, deviceTypes = { "HEATER", "THERMOSTAT", "PILOT_WIRE" }, settings = { "transmitter" } }
				}
			}
		}
	},
	[ "11;0" ] = { -- X2D detector/sensor device
		name = "Detector/sensor",
		modelings = {
			{
				mappings = {
					{ features = { "state" } }, -- not used
					{ features = { "tamper", "alarm" }, deviceTypes = { "DOOR_SENSOR", "MOTION_SENSOR", "SMOKE_SENSOR" }, settings = { "transmitter" } }
				}
			}
		}
	},
	[ "11;1" ] = { -- X2D device / shutter remote control
		name = "Shutter remote control",
		modelings = {
			{
				mappings = {
					{ features = { "state" }, deviceTypes = { "BINARY_LIGHT" } }, -- TODO : ???
					{ features = { "on", "off", "stop" }, deviceTypes = { "SHUTTER" }, settings = { "transmitter", "my=50" } }
				}
			}
		}
	}
}

-- Compute feature structure
for _, equipmentInfos in pairs( EQUIPMENT ) do
	for _, modeling in ipairs( equipmentInfos.modelings ) do
		modeling.isUsed = false
		for _, mapping in ipairs( modeling.mappings ) do
			if not ( mapping.isUsed == true ) then
				mapping.isUsed = false
			end
			local features = {}
			for _, featureName in ipairs( mapping.features ) do
				features[ featureName ] = {}
			end
			mapping.features = features
		end
	end
end

do --  Equipments commands/actions translation to Vera devices
	DEVICE.SECURITY_SENSOR.commands = {
		[ "on" ] = function( deviceId )
			Device.setTripped( deviceId, "1" )
		end,
		[ "off" ] = function( deviceId )
			Device.setTripped( deviceId, "0" )
		end,
		[ "alarm" ] = function( deviceId )
			Device.setTripped( deviceId, "1" )
		end,
		[ "tamper" ] = function( deviceId )
			Device.setTamperAlarm( deviceId, "1" )
		end,
		[ "supervisor/alive" ] = function( deviceId )
			-- TODO
		end
	}
	DEVICE.DOOR_SENSOR.commands = DEVICE.SECURITY_SENSOR.commands
	DEVICE.MOTION_SENSOR.commands = DEVICE.SECURITY_SENSOR.commands
	DEVICE.SMOKE_SENSOR.commands = DEVICE.SECURITY_SENSOR.commands
	DEVICE.WIND_SENSOR.commands = {
		[ "wind speed" ] = function( deviceId, data )
			Device.setWindSpeed( deviceId, data )
		end,
		[ "direction" ] = function( deviceId, data )
			Device.setWindDirection( deviceId, data )
		end
	}
	DEVICE.BAROMETER_SENSOR.commands = {
		[ "pressure" ] = function( deviceId, data )
			local pressure = tonumber( data.value )
			Device.setPressure( deviceId, pressure )
		end
	}
	DEVICE.UV_SENSOR.commands = {
		[ "uv" ] = function( deviceId, data )
			local uvLevel = tonumber( data.value )
			Device.setUv( deviceId, uvLevel )
		end
	}
	DEVICE.BINARY_LIGHT.commands = {
		[ "on" ] = function( deviceId )
			Device.setStatus( deviceId, "1", nil, true )
		end,
		[ "off" ] = function( deviceId )
			Device.setStatus( deviceId, "0", nil, true )
		end,
		[ "button/command" ] = function( deviceId )
			Device.setStatus( deviceId, "1", nil, true )
		end
	}
	DEVICE.DIMMABLE_LIGHT.commands = {
		[ "on" ] = DEVICE.BINARY_LIGHT.commands["on"],
		[ "off" ] = DEVICE.BINARY_LIGHT.commands["off"],
		[ "dim" ] = function( deviceId, data )
			local loadLevel = tonumber( data.value )
			Device.setLoadLevel( deviceId, loadLevel, nil, nil, true )
		end
	}
	DEVICE.TEMPERATURE_SENSOR.commands = {
		[ "temperature" ] = function( deviceId, data )
			local temperature = tonumber( data.value ) -- degree celcius
			-- TODO : manage Fahrenheit
			Device.setTemperature( deviceId, temperature )
		end
	}
	DEVICE.HUMIDITY_SENSOR.commands = {
		[ "hygrometry" ] = function( deviceId, data )
			local humidity = tonumber( data.value )
			if ( humidity and humidity ~= 0 ) then
				Device.setHumidity( deviceId, humidity )
			end
		end
	}
	DEVICE.POWER_METER.commands = {
		[ "energy" ] = function( deviceId, data )
			local KWH = tonumber( data.value )
			Device.setKWH( deviceId, KWH )
		end,
		[ "power" ] = function( deviceId, data )
			local watts = tonumber( data.value )
			Device.setWatts( deviceId, watts )
		end
	}
	DEVICE.SHUTTER.commands = {
		[ "on" ] = DEVICE.BINARY_LIGHT.commands["on"],
		[ "off" ] = DEVICE.BINARY_LIGHT.commands["off"],
		[ "up/on" ] = DEVICE.BINARY_LIGHT.commands["on"],
		[ "down/off" ] = DEVICE.BINARY_LIGHT.commands["off"],
		[ "my" ] = function( deviceId )
			-- TODO : get MY value from settings
			Device.setLoadLevel( deviceId, "50", nil, nil, true )
		end
	}
	DEVICE.SCENE_CONTROLLER.commands = {
		[ "button1" ] = function( deviceId )
			Device.setSceneId( deviceId, "1" )
		end,
		[ "button2" ] = function( deviceId )
			Device.setSceneId( deviceId, "2" )
		end,
		[ "button3" ] = function( deviceId )
			Device.setSceneId( deviceId, "3" )
		end,
		[ "button4" ] = function( deviceId )
			Device.setSceneId( deviceId, "4" )
		end
	}
	DEVICE.PILOT_WIRE.commands = {
	}
	DEVICE.THERMOSTAT.commands = {
	}
	DEVICE.HEATER.commands = {
	}
end

local function _getZiBlueInfos( protocol, infoType, subType )
	local ziblueInfos = EQUIPMENT[ tostring(protocol) .. ";" .. tostring(infoType) ]
					or EQUIPMENT[ tostring(infoType) .. ";" .. tostring(subType) ]
					or EQUIPMENT[ tostring(infoType) ]
					or { name = "Unknown", modelings = {} }
	return ziblueInfos
end

local ZIBLUE_SEND_PROTOCOL = {
	VISONIC433 = { name = "Visonic 433Mhz (PowerCode)", deviceSettings = { "receiver" } },
	VISONIC868 = { name = "Visonic 868Mhz (PowerCode)", deviceSettings = { "receiver" } },
	CHACON = {
		name = "Chacon 433Mhz",
		deviceTypes = { "BINARY_LIGHT", "SHUTTER" },
		deviceSettings = { "receiver" }
	},
	DOMIA = { name = "Domia 433Mhz" },
	X10 = {
		name = "X10 433Mhz",
		deviceTypes = { "BINARY_LIGHT", "SHUTTER" },
		deviceSettings = { "receiver" }
	},
	X2D433 = { name = "X2D 433Mhz", deviceSettings = { "receiver" } },
	X2D868 = { name = "X2D 868Mhz", deviceSettings = { "receiver" } },
	X2DSHUTTER = {
		name = "X2D Shutter 868Mhz",
		deviceTypes = { "SHUTTER" },
		deviceSettings = { "receiver" }
	},
	X2DELEC = {
		name = "X2D Elec 868Mhz",
		deviceTypes = { "PILOT_WIRE", "HEATER" },
		deviceSettings = { "receiver" }
	},
	X2DGAS = {
		name = "X2D Gaz 868Mhz",
		deviceTypes = { "THERMOSTAT" },
		deviceSettings = { "receiver" }
	},
	RTS = {
		name = "Somfy RTS 433Mhz",
		deviceTypes = { "BINARY_LIGHT", "SHUTTER;qualifier=0", "SCENE_CONTROLLER;qualifier=1" }, -- TODO Portal
		deviceSettings = { "receiver" },
		protocolSettings = {
			{ variable = "qualifier", name = "Qualifier", type = "string" }
		}
	},
	BLYSS = { name = "Blyss 433Mhz" },
	PARROT = {
		name = "* ZiBlue Parrot",
		--deviceTypes = { "BINARY_LIGHT", "DOOR_SENSOR", "MOTION_SENSOR", "SMOKE_SENSOR" },
		deviceSettings = { "receiver", "transmitter" },
		protocolSettings = {
			{ variable = "comment", name = "Reminder", type = "string" },
			{ variable = "action", name = "Action", type = "select", values = { "ON", "OFF" } }
		}
	},
	KD101 = { name = "KD101 433Mhz", deviceSettings = { "receiver" } }
}

local ZIBLUE_FREQUENCY = {
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

local _settings = {
	plugin = {
		pollInterval = 30
	},
	system = {},
	radio = {}
}

-- **************************************************
-- Number functions
-- **************************************************

do
	-- Formats a number as hex.
	function number_toHex( n )
		if ( type( n ) == "number" ) then
			return string.format( "%02X", n )
		end
		return tostring( n )
	end
end

-- **************************************************
-- Table functions
-- **************************************************

do
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

do
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

	function string_decodeURI( s )
		local hex={}
		for i = 0, 255 do
			hex[ string.format("%0X",i) ] = string.char(i)
		end
		return ( s:gsub( '%%(%x%x)', hex ) )
	end
end


-- **************************************************
-- UI messages
-- **************************************************

UI = {
	show = function( message )
		debug( "Display message: " .. tostring( message ), "UI.show" )
		Variable.set( DEVICE_ID, "LAST_MESSAGE", message )
	end,

	showError = function( message )
		debug( "Display message: " .. tostring( message ), "UI.showError" )
		--message = '<div style="color:red">' .. tostring( message ) .. '</div>'
		message = '<font color="red">' .. tostring( message ) .. '</font>'
		Variable.set( DEVICE_ID, "LAST_MESSAGE", message )
	end,

	clearMessage = function()
		Variable.set( DEVICE_ID, "LAST_MESSAGE", "" )
	end
}


-- **************************************************
-- Variable management
-- **************************************************

local _getVariable = function( name )
	return ( ( type( name ) == "string" ) and VARIABLE[name] or name )
end

Variable = {
	-- Check if variable (service) is supported
	isSupported = function( deviceId, variable )
		deviceId = tonumber(deviceId)
		variable = _getVariable( variable )
		if ( deviceId and variable ) then
			if not luup.device_supports_service( variable[1], deviceId ) then
				warning( "Device #" .. tostring( deviceId ) .. " does not support service " .. variable[1], "Variable.isSupported" )
			else
				return true
			end
		end
		return false
	end,

	-- Get variable timestamp
	getTimestamp = function( deviceId, variable )
		variable = _getVariable( variable )
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
		variable = _getVariable( variable )
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
		end
		variable = _getVariable( variable )
		if ( variable == nil ) then
			error( "Variable is nil", "Variable.get" )
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
		end
		variable = _getVariable( variable )
		if ( variable == nil ) then
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
	end,

	getEncodedValue = function( variable, value )
		variable = _getVariable( variable )
		local encodedParameter = ""
		if variable then
			encodedParameter = variable[1] .. "," .. variable[2] .. "=" .. tostring( value or "" )
		end
		return encodedParameter
	end
}


-- **************************************************
-- Device management
-- **************************************************

local _indexDeviceInfos = {}
for deviceTypeName, deviceInfos in pairs( DEVICE ) do
	deviceInfos.name = deviceTypeName
	_indexDeviceInfos[ deviceInfos.type ] = deviceInfos
end
setmetatable(_indexDeviceInfos, {
	__index = function( t, deviceType )
		warning( "Can not get infos for device type '" .. tostring( deviceType ) .. "'", "Device.getInfos" )
		return {
			type = deviceType
		}
	end
})

Device = {
	-- Get device type infos, by device id, type name or UPnP device id (e.g. "BINARY_LIGHT" or "urn:schemas-upnp-org:device:BinaryLight:1")
	getInfos = function( deviceType )
		if ( type(deviceType) == "number" ) then
			-- Get the device type from the id
			local luDevice = luup.devices[deviceType]
			if luDevice then
				deviceType = luDevice.device_type
			end
		elseif ( deviceType == nil ) then
			deviceType = ""
		end
		-- Get the device infos
		local deviceInfos = DEVICE[ deviceType ]
		if ( deviceInfos == nil ) then
			-- Not known by name, try with UPnP device id
			deviceInfos = _indexDeviceInfos[ deviceType ]
		end
		return deviceInfos
	end,

	getEncodedParameters = function( deviceInfos )
		local encodedParameters = ""
		if ( deviceInfos and deviceInfos.parameters ) then
			for _, param in ipairs( deviceInfos.parameters ) do
				encodedParameters = encodedParameters .. Variable.getEncodedValue( param[1], param[2] ) .. "\n"
			end
		end
		return encodedParameters
	end,

	fileExists = function( deviceInfos )
		local name = deviceInfos.file
		return (
				Tools.fileExists( "/etc/cmh-lu/" .. name .. ".lzo" ) or Tools.fileExists( "/etc/cmh-lu/" .. name )
			or	Tools.fileExists( "/etc/cmh-ludl/" .. name .. ".lzo" ) or Tools.fileExists( "/etc/cmh-ludl/" .. name )
			or	Tools.fileExists( name ) or Tools.fileExists( "../cmh-lu/" .. name )
		)
	end,

	isDimmable = function( deviceId )
		return luup.device_supports_service( VARIABLE.DIMMER_LEVEL[1], deviceId )
	end,

	-- Switch OFF/ON/TOGGLE
	setStatus = function( deviceId, status, isLongPress, noAction )
		if status then
			status = tostring( status )
		end
		local formerStatus = Variable.get( deviceId, "SWITCH_POWER" ) or "0"
		local equipment, features, device = Equipments.getFromDeviceId( deviceId )
		local msg = "Equipment '" .. Tools.getProductInfo( equipment, features ) .. "'"
		if ( device.settings.receiver ) then
			msg = msg .. " (receiver)"
		end

		-- Pulse
		local isPulse = ( device.settings.pulse == true )
		-- Toggle
		local isToggle = ( device.settings.toggle == true )
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
			debug( msg .. " - Status has not changed", "Device.setStatus" )
			return
		end

		-- Update status variable
		local loadLevel
		if ( status == "1" ) then
			msg = msg .. " ON device #" .. tostring( deviceId )
			if Device.isDimmable( deviceId ) then
				loadLevel = Variable.get( deviceId, "DIMMER_LEVEL_OLD" ) or "100"
				if ( loadLevel == "0" ) then
					loadLevel = "100"
				end
				msg = msg .. " at " .. loadLevel .. "%"
			end
		else
			msg = msg .. " OFF device #" .. tostring( deviceId )
			status = "0"
			if Device.isDimmable( deviceId ) then
				msg = msg .. " at 0%"
				loadLevel = 0
			end
		end
		if isLongPress then
			msg = msg .. " (long press)"
		end
		debug( msg, "Device.setStatus" )
		Variable.set( deviceId, "SWITCH_POWER", status )
		if loadLevel then
			if ( loadLevel == 0 ) then
				Variable.set( deviceId, "DIMMER_LEVEL_OLD", Variable.get( deviceId, "DIMMER_LEVEL" ) )
			end
			Variable.set( deviceId, "DIMMER_LEVEL", loadLevel )
		end

		-- Send command if needed
		if ( device.settings.receiver and not ( noAction == true ) ) then
			if ( loadLevel and Device.isDimmable( deviceId ) ) then 
				Equipment.setLoadLevel( equipment, loadLevel, device.settings )
			else
				Equipment.setStatus( equipment, status, device.settings )
			end
		end

		-- Pulse
		if ( isPulse and ( status == "1" ) ) then
			-- TODO : OFF après 200ms : voir multiswitch
			msg = "Equipment '" .. Tools.getProductInfo( equipment, features ) .. "' - Pulse OFF device #" .. tostring( deviceId )
			if Device.isDimmable( deviceId ) then
				debug( msg .. " at 0%", "Device.setStatus" )
				Variable.set( deviceId, "SWITCH_POWER", "0" )
				Variable.set( deviceId, "DIMMER_LEVEL_OLD", Variable.get( deviceId, "DIMMER_LEVEL" ) )
				Variable.set( deviceId, "DIMMER_LEVEL", 0 )
			else
				debug( msg, "Device.setStatus" )
				Variable.set( deviceId, "SWITCH_POWER", "0" )
			end
		end

		-- Association
		Association.propagate( device.association, status, loadLevel, isLongPress )
		if ( isPulse and ( status == "1" ) ) then
			Association.propagate( device.association, "0", nil, isLongPress )
		end

		return status
	end,

	-- Dim OFF/ON/TOGGLE
	setLoadLevel = function( deviceId, loadLevel, direction, isLongPress, noAction )
		loadLevel = tonumber( loadLevel )
		local formerLoadLevel, lastLoadLevelChangeTime = Variable.get( deviceId, "DIMMER_LEVEL" )
		formerLoadLevel = tonumber( formerLoadLevel ) or 0
		local equipment, features, device = Equipments.getFromDeviceId( deviceId )
		local msg = "Dim"

		if ( isLongPress and not Device.isDimmable( deviceId ) ) then
			-- Long press handled by a switch
			return Device.setStatus( deviceId, nil, isLongPress, noAction )

		elseif ( loadLevel == nil ) then
			-- Toggle dim
			loadLevel = formerLoadLevel
			if ( direction == nil ) then
				direction = Variable.getOrInit( deviceId, "DIMMER_DIRECTION", "up" )
				if ( os.difftime( os.time(), lastLoadLevelChangeTime ) > 2 ) then
					-- Toggle direction after 2 seconds of inactivity
					msg = "Toggle dim"
					if ( direction == "down" ) then
						direction = "up"
						Variable.set( deviceId, "DIMMER_DIRECTION", "up" )
					else
						direction = "down"
						Variable.set( deviceId, "DIMMER_DIRECTION", "down" )
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
			debug( msg .. " - Load level has not changed", "Device.setLoadLevel" )
			return
		end

		debug( msg .. " device #" .. tostring( deviceId ) .. " at " .. tostring( loadLevel ) .. "%", "Device.setLoadLevel" )
		Variable.set( deviceId, "DIMMER_LEVEL", loadLevel )
		if ( loadLevel > 0 ) then
			Variable.set( deviceId, "SWITCH_POWER", "1" )
		else
			Variable.set( deviceId, "SWITCH_POWER", "0" )
		end

		-- Send command if needed
		if ( device.settings.receiver and not ( noAction == true ) ) then
			if ( loadLevel > 0 ) then
				if not Device.isDimmable( deviceId ) then
					if ( loadLevel == 100 ) then
						Equipment.setStatus( equipment, "1", device.settings )
					else
						debug( "This device does not support DIM", "Device.setLoadLevel" )
					end
				else
					Equipment.setLoadLevel( equipment, loadLevel, device.settings )
				end
			else
				Equipment.setStatus( equipment, "0", device.settings )
			end
		end

		-- Association
		Association.propagate( device.association, nil, loadLevel, isLongPress )

		return loadLevel
	end,

	-- Set armed
	setArmed = function( deviceId, armed )
		if not Variable.isSupported( deviceId, "ARMED" ) then
			return
		end
		armed = tostring( armed or "0" )
		if ( armed == "1" ) then
			debug( "Arm device #" .. tostring( deviceId ), "Device.setArmed" )
		else
			debug( "Disarm device #" .. tostring( deviceId ), "Device.setArmed" )
		end
		Variable.set( deviceId, "ARMED", armed )
		if ( armed == "0" ) then
			Variable.set( deviceId, "ARMED_TRIPPED", "0" )
		end
	end,

	-- Set tripped
	setTripped = function( deviceId, tripped )
		if not Variable.isSupported( deviceId, "TRIPPED" ) then
			return
		end
		tripped = tostring( tripped or "0" )
		if ( tripped == "1" ) then
			debug( "Device #" .. tostring( deviceId ) .. " is tripped", "Device.setTripped" )
		else
			debug( "Device #" .. tostring( deviceId ) .. " is untripped", "Device.setTripped" )
		end
		Variable.set( deviceId, "TRIPPED", tripped )
		if ( ( tripped == "1" ) and ( Variable.get( deviceId, "ARMED" ) == "1" ) ) then
			Variable.set( deviceId, "ARMED_TRIPPED", "1" )
		else
			Variable.set( deviceId, "ARMED_TRIPPED", "0" )
		end
	end,

	-- Set tamper alarm
	setTamperAlarm  = function( deviceId, alarm )
		if not Variable.isSupported( deviceId, "TAMPER_ALARM" ) then
			return
		end
		debug( "Set device #" .. tostring(deviceId) .. " tamper alarm to '" .. tostring( alarm ) .. "'", "Device.setTamperAlarm" )
		Variable.set( deviceId, "TAMPER_ALARM", alarm )
	end,

	-- Set temperature
	setTemperature = function( deviceId, temperature )
		if not Variable.isSupported( deviceId, "TEMPERATURE" ) then
			return
		end
		debug( "Set device #" .. tostring(deviceId) .. " temperature to " .. tostring( temperature ) .. "°C", "Device.setTemperature" )
		Variable.set( deviceId, "TEMPERATURE", temperature )
	end,

	-- Set humidity
	setHumidity = function( deviceId, humidity )
		if not Variable.isSupported( deviceId, "HUMIDITY" ) then
			return
		end
		local humidity = tonumber( humidity )
		if ( humidity and humidity ~= 0 ) then
			debug( "Set device #" .. tostring(deviceId) .. " humidity to " .. tostring( humidity ) .. "%", "Device.setHygrometry" )
			Variable.set( deviceId, "HUMIDITY", humidity )
		end
	end,

	-- Set watts
	setWatts = function( deviceId, watts )
		if not Variable.isSupported( deviceId, "WATTS" ) then
			return
		end
		debug( "Set device #" .. tostring(deviceId) .. " watts to " .. tostring( watts ) .. "W", "Device.setWatts" )
		Variable.set( deviceId, "WATTS", watts )
	end,

	-- Set KWH
	setKWH = function( deviceId, KWH )
		if not Variable.isSupported( deviceId, "KWH" ) then
			return
		end
		debug( "Set device #" .. tostring(deviceId) .. " watt to " .. tostring( KWH ) .. "Wh", "Device.setKWH" )
		Variable.set( deviceId, "KWH", KWH )
	end,

	-- Set scene id
	setSceneId = function( deviceId, sceneId )
		if not Variable.isSupported( deviceId, "LAST_SCENE_ID" ) then
			return
		end
		debug( "Set device #" .. tostring(deviceId) .. " last scene to '" .. tostring(sceneId) .. "'", "Device.setSceneId" )
		Variable.set( deviceId, "LAST_SCENE_ID", sceneId )
	end,

	-- Set battery level
	setBatteryLevel = function( deviceId, batteryLevel )
		-- TODO : comment identifier un périphérique à pile ?
		--[[
		if not equipment.isBatteryPowered then
			return
		end
		--]]
		local batteryLevel = tonumber(batteryLevel) or 0
		if (batteryLevel < 0) then
			batteryLevel = 0
		elseif (batteryLevel > 100) then
			batteryLevel = 100
		end
		debug("Set device #" .. tostring(deviceId) .. " battery level to " .. tostring(batteryLevel) .. "%", "Device.setBatteryLevel")
		Variable.set( deviceId, "BATTERY_LEVEL", batteryLevel )
	end,

	-- Manage roller shutter
	moveShutter = function( deviceId, direction, noAction )
		debug( "Shutter #" .. tostring(deviceId) .. " direction: " .. tostring(direction), "Device.moveShutter" )
		if ( direction == "up" ) then
			return Device.setStatus( deviceId, "1", nil, noAction )
		elseif ( direction == "down" ) then
			return Device.setStatus( deviceId, "0", nil, noAction )
		elseif ( direction == "stop" ) then
			-- TODO : problème avec sens ?
			local equipment = Equipments.getFromDeviceId( deviceId )
			if ( equipment.protocol == "RTS" ) then
				-- "My" fonction for RTS
				if ( feature.settings.receiver and not ( noAction == true ) ) then
					debug( "RTS 'My' function", "Device.moveShutter" )
					local burst = feature.settings.burst and ( " BURST " .. feature.settings.burst ) or ""
					Network.send( "ZIA++DIM RTS ID " .. equipment.id .. " %4 QUALIFIER 0" .. burst )
				end
			else
				debug( "Stop is not managed for the protocol " .. equipment.protocol, "Device.moveShutter" )
			end
		else
			error( "Shutter #" .. tostring(feature.deviceId) .. " direction: " .. tostring(direction) .. " is not allowed", "Device.moveShutter" )
		end
	end,

	-- Set HVAC Mode Status
	setModeStatus = function( deviceId, newModeStatus, option )
debug( "test", "Device.setModeStatus" )
		local cmd = "ON"
		local param = "7"
		if ( option == "PilotWire" ) then
			if ( newModeStatus == "0" ) then
				-- Shutdown
				cmd = "OFF"
				param = "4"
			elseif ( newModeStatus == "1" ) then
				-- Frost free
				param = "5"
			elseif ( newModeStatus == "2" ) then
				-- Economy
				param = "0"
			elseif ( newModeStatus == "3" ) then
				-- Comfort
				param = "3"
			end
			Variable.set( deviceId, "PILOTWIRE_STATUS", newModeStatus )
		else
			if ( newModeStatus == "Off" ) then
				cmd = "OFF"
				param = "4"
			elseif ( newModeStatus == "HeatOn" ) then
				param = "7"
			end
			Variable.set( deviceId, "HVAC_MODE_STATUS", newModeStatus )
		end
		debug( "Device #" .. tostring( deviceId ) .. " set mode status " .. tostring(newModeStatus), "Device.setModeStatus" )

		-- Send command if needed
		local equipment, feature, device = Equipments.getFromDeviceId( deviceId )
		if device.settings.receiver then
		-- TODO
			Network.send( "ZIA++" .. cmd  .. " " .. equipment.protocol .. " ID " .. equipment.id .. " %" .. param )
		end
	end,

	-- Set HVAC SetPoint
	setSetPoint = function( equipment, feature, newSetpoint, option )
	
	end
}


-- **************************************************
-- Commands
-- **************************************************

local _commandsToProcess = {}
local _isProcessingCommand = false

Command = {

	process = function( source, qualifier, data )
		local header = data.frame.header
		local infos = data.frame.infos
		local protocol = header.protocolMeaning
		local equipmentId = infos.id or infos.adr_channel
		local equipmentInfos = {
			infoType = header.infoType,
			subType = infos.subType,
			frequency = ( ( header.dataFlag ~= "-1 " ) and tostring( ZIBLUE_FREQUENCY[ header.dataFlag ] ) or "" ),
			quality = tonumber( header.rfQuality )
		}
		local isOk = true

		-- Battery
		if ( infos.lowBatt == "1" ) then
			--_addCommand( "lowbatt", "lowbatt" )
			isOk = Command.add( protocol, equipmentId, equipmentInfos, "lowbatt", "lowbatt" ) and isOk
		end
		-- State
		if ( infos.subTypeMeaning ) then
			isOk = Command.add( protocol, equipmentId, equipmentInfos, "state", infos.subTypeMeaning, infos.subTypeMeaning ) and isOk
		end
		-- Measures
		if ( infos.measures ) then
			for _, measure in ipairs( infos.measures ) do
				isOk = Command.add( protocol, equipmentId, equipmentInfos, measure.type, measure.type, measure ) and isOk
			end
		end
		-- Flags (can be "LowBatt")
		if ( infos.qualifierMeaning and infos.qualifierMeaning.flags ) then
			for _, flag in ipairs( infos.qualifierMeaning.flags ) do
				isOk = Command.add( protocol, equipmentId, equipmentInfos, flag, flag ) and isOk
			end
		end

		if ( #_commandsToProcess > 0 ) then
			luup.call_delay( _NAME ..".Command.deferredProcess", 0 )
		end

		return isOk
	end,

	add = function( protocol, equipmentId, equipmentInfos, featureName, commandName, data )
		commandName, featureName = string.lower(commandName or ""), string.lower(featureName or "")
		local id = protocol .. ";" .. equipmentId
		local msg = "Equipment '" .. id .. "'"
		if string_isEmpty(featureName) then
			error( msg .. " : no given feature", "Command.process" )
			return false
		end
		if string_isEmpty(commandName) then
			error( msg .. " : no given command", "Command.process" )
			return false
		end
		local equipment, feature, devices = Equipments.get( protocol, equipmentId, featureName )
		if equipment then
			equipment.frequency = equipmentInfos.frequency
			equipment.quality = equipmentInfos.quality
			if equipment.isNew then
				-- No command on a new equipment (not yet handled by the home automation controller)
				return
			end
			if feature then
				-- Equipment is known for this feature
				if ( type( data ) == "table" ) then
					feature.state = data.value .. " " .. data.unit
				elseif ( data ~= nil ) then
					feature.state = data
				end
				feature.lastUpdate = os.time()
				equipment.lastUpdate = os.time()
				table.insert( _commandsToProcess, { devices, commandName, data } )
			else
				-- Equipment is known (but not for this feature)
				if ( commandName == "lowbatt" ) then
					Device.setBatteryLevel( equipment.mainDeviceId, 10 )
				end
			end
		end

		-- TODO : surement un pb avec la feature status sans devicetype
		if ( ( featureName ~= "lowbatt" ) and ( not equipment or not feature ) ) then
			-- Add this device to the discovered equipments (but not yet known)
			local hasBeenAdded, isFeatureKnown = DiscoveredEquipments.add( protocol, equipmentId, equipmentInfos, featureName, data )
			if hasBeenAdded then
				debug( msg .. ": unknown for feature '" .. featureName .. "'", "Command.process" )
			elseif not isFeatureKnown then
				error( msg .. ": feature '" .. featureName .. "' is not known", "Command.process" )
				return false
			else
				debug( msg .. ": already discovered", "Command.process" )
			end
		end
		return true
	end,

	deferredProcess = function()
		if _isProcessingCommand then
			debug( "Processing is already in progress", "Command.deferredProcess" )
			return
		end
		_isProcessingCommand = true
		while _commandsToProcess[1] do
			local status, err = pcall( Command.protectedProcess )
			if err then
				error( "Error: " .. tostring( err ), "Command.deferredProcess" )
			end
			table.remove( _commandsToProcess, 1 )
		end
		_isProcessingCommand = false
	end,

	protectedProcess = function()
		local devices, commandName, data = unpack( _commandsToProcess[1] )
		for _, device in pairs( devices ) do
			local msg = "Device #" .. tostring(device.id)
			local deviceInfos, deviceType = Device.getInfos( device.id )
			if ( deviceInfos == nil ) then
				error( msg .. " - Type is unknown", "Command.protectedProcess" )
			elseif ( deviceInfos.commands[ commandName ] ~= nil ) then
				if ( type(data) == "table" ) then
					debug( msg .. " - Do command '" .. commandName .. "' with data '" .. json.encode(data) .. "'", "Command.protectedProcess" )
				else
					debug( msg .. " - Do command '" .. commandName .. "' with data '" .. tostring(data) .. "'", "Command.protectedProcess" )
				end
				deviceInfos.commands[ commandName ]( device.id, data )
			else
				warning( msg .. " - Command '" .. commandName .. "' not yet implemented for this device type " .. deviceType, "Command.protectedProcess" )
			end
		end
	end
}


-- **************************************************
-- Network
-- **************************************************

local _messageToSendQueue = {}   -- The outbound message queue
local _isSendingMessage = false
local _lastNetworkReceiveTime = 0
local _lastNetworkSendTime = 0

Network = {

	receive = function( lul_data )
		if lul_data then
			_lastNetworkReceiveTime = os.time()
			local sync = string.sub( lul_data, 1, 2 )
			if ( sync == "ZI" ) then
				local data
				local source = string.sub( lul_data, 3, 3 )
				local qualifier = string.sub( lul_data, 4, 5 )
				local jsonData = string.gsub( string.sub( lul_data, 6 ), '[%c]', '' ) -- Data without the terminator

				if ( string.sub( jsonData, 1, 1 ) == "{" ) then
					local decodeSuccess, data, _, jsonError = pcall( json.decode, jsonData )
					if ( decodeSuccess and data ) then
						debug( source .. " " .. qualifier .. ": " .. json.encode( data ), "Network.receive" )
						if data.systemStatus then
							_settings.system = Tools.extractInfos( data.systemStatus.info )
							-- Special feature : JAMMING
							local filteredSettings = table_filter( _settings.system, function(i, setting) return ( setting.name == "Jamming" ) end )
							if ( ( #filteredSettings > 0 ) and not Equipments.get( "JAMMING", "0") ) then
								local comment = ( tonumber(filteredSettings[1].value or 0) == 0 ) and "Jamming detection feature is not activated" or ""
								DiscoveredEquipments.add( "JAMMING", "0", { infoType = "1" }, "state", "1", comment )
							end
						elseif data.radioStatus then
							_settings.radio = Tools.extractInfos( data.radioStatus.band )
						elseif data.parrotStatus then
							Tools.updateParrotStatus( data.parrotStatus.info )
						elseif not Command.process( source, qualifier, data ) then
							error( "Error with RF frame: " .. tostring(lul_data), "Network.receive" )
						end
					else
						error( "JSON error: " .. tostring( jsonError ), "Network.receive" )
					end
				else
					if ( jsonData == "PONG" ) then
						debug( _NAME .. " is alive", "Network.receive" )
					elseif ( string.sub( jsonData, 1, 7 ) == "Welcome" ) then
						debug( "Welcome: " .. jsonData, "Network.receive" )
					else
						error( "Unkown message: '" .. tostring( jsonData ) .. "'", "Network.receive" )
					end
				end

			else
				debug( "Unkown data: '" .. tostring( lul_data ) .. "'", "Network.receive" )
			end
		end
	end,

	getLastReceiveTime = function()
		return _lastNetworkReceiveTime
	end,

	-- Send a message (add to send queue)
	send = function( message, delay )
		if ( luup.attr_get( "disabled", DEVICE_ID ) == "1" ) then
			warning( "Can not send message: " .. _NAME .. " is disabled", "Network.send" )
			return
		end

		-- Delayed message
		if delay then
			luup.call_delay( _NAME .. ".Network.send", delay, message )
			return
		end

		table.insert( _messageToSendQueue, message )
		if not _isSendingMessage then
			Network.flush()
		end
	end,

	-- Send the packets in the queue to dongle
	flush = function ()
		if ( luup.attr_get( "disabled", DEVICE_ID ) == "1" ) then
			debug( "Can not send message: " .. _NAME .. " is disabled", "Network.send" )
			return
		end
		-- If we don't have any message to send, return.
		if ( #_messageToSendQueue == 0 ) then
			_isSendingMessage = false
			return
		end

		_isSendingMessage = true
		while _messageToSendQueue[1] do
			local message = _messageToSendQueue[1]
			if ( message == "WAIT" ) then
				debug( "Wait 1 second", "Network.flush" )
				table.remove( _messageToSendQueue, 1 )
				luup.call_delay( _NAME .. ".Network.flush", 1 )
				return
			else
				--debug( "Send message: ".. string.formatToHex(_messageToSendQueue[1]), "Network.send" )
				debug( "Send message: " .. message, "Network.send" )
				_lastNetworkSendTime = os.time()
				if not luup.io.write( message ) then
					error( "Failed to send packet", "Network.send" )
					_isSendingMessage = false
					return
				end
				table.remove( _messageToSendQueue, 1 )
			end
		end

		_isSendingMessage = false
	end
}


-- **************************************************
-- Poll engine
-- **************************************************

local _isPollingActivated = false

PollEngine = {
	start = function ()
		log( "Start poll", "PollEngine.start" )
		_isPollingActivated = true
		PollEngine.poll()
	end,

	poll = function ()
		if _isPollingActivated then
			if ( os.difftime( Network.getLastReceiveTime(), os.time() ) > _settings.plugin.pollInterval * 2 ) then
				log( "Last receive is too old : there's a communication problem", "PollEngine.poll" )
				luup.set_failure( 1, DEVICE_ID )
			elseif ( Variable.get( DEVICE_ID, "COMM_FAILURE" ) == "1" ) then
				luup.set_failure( 0, DEVICE_ID )
			end
			debug( "Poll", "PollEngine.poll" )
			Network.send( "ZIA++PING" )
			-- Prepare next polling
			luup.call_delay( _NAME .. ".PollEngine.poll", _settings.plugin.pollInterval )
		end
	end
}


-- **************************************************
-- Tools
-- **************************************************

Tools = {
	fileExists = function( name )
		local f = io.open( name, "r" )
		if ( f ~= nil ) then
			io.close( f )
			return true
		else
			return false
		end
	end,

	getProductInfo = function( equipment, features )
		if features then
			return equipment.protocol .. ";" .. equipment.id .. ";" .. table.concat( table_getKeys( features ), "," )
		else
			return equipment.protocol .. ";" .. equipment.id
		end
	end,

	extractInfos = function( infos )
		local result = {}
		for _, info in ipairs( infos ) do
			if not string_isEmpty( info.n ) then
				local item = {
					name = info.n,
					value = info.v
				}
				if not string_isEmpty( info.unit ) then
					item.unit = info.unit
				end
				if not string_isEmpty( info.c ) then
					item.comment = info.c
				end
				table.insert( result, item )
			elseif info.i then
				table.insert( result, Tools.extractInfos( info.i ) )
			elseif info.p then
				table.insert( result, info.p )
			else
				table.insert( result, info )
			end
		end
		debug( "Result:" .. json.encode( result ), "Tools.extractInfos" )
		return result
	end,

	updateParrotStatus = function( infos )
		local status = Tools.extractInfos( infos )
		if not Equipments.get( "PARROT", status.id ) then
			-- Add the Parrot device to discovered devices
			DiscoveredEquipments.add( "PARROT", status.id, { infoType = "0" }, "state", ( ( status.action == "1" ) and "ON" or "OFF" ), status.reminder )
		end
	end,

	pcall = function( method, ... )
		local isOk, result = pcall( method, unpack(arg) )
		if not isOk then
			error( "Error: " .. tostring( result ), "Tools.pcall" )
		end
		return isOk, result
	end

}


-- **************************************************
-- Association
-- **************************************************

Association = {
	-- Get association from string
	get = function( strAssociation )
		local association = {}
		for _, encodedAssociation in pairs( string_split( strAssociation or "", "," ) ) do
			local linkedId, level, isScene, isEquipment = nil, 1, false, false
			while ( encodedAssociation ) do
				local firstCar = string.sub( encodedAssociation, 1 , 1 )
				if ( firstCar == "*" ) then
					isScene = true
					encodedAssociation = string.sub( encodedAssociation, 2 )
				elseif ( firstCar == "%" ) then
					isEquipment = true
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
						error( "Associated scene #" .. tostring( linkedId ) .. " is unknown", "Association.get" )
					end
				elseif isEquipment then
					if ( luup.devices[ linkedId ] ) then
						if ( association.equipments == nil ) then
							association.equipments = { {}, {} }
						end
						table.insert( association.equipments[ level ], linkedId )
					else
						error( "Associated equipment #" .. tostring( linkedId ) .. " is unknown", "Association.get" )
					end
				else
					if ( luup.devices[ linkedId ] ) then
						if ( association.devices == nil ) then
							association.devices = { {}, {} }
						end
						table.insert( association.devices[ level ], linkedId )
					else
						error( "Associated device #" .. tostring( linkedId ) .. " is unknown", "Association.get" )
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
		if association.equipments then
			table_append( result, _getEncodedAssociations( association.equipments, "%" ) )
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
-- Discovered Equipments
-- **************************************************

local _discoveredEquipments = {}
local _indexDiscoveredEquipmentsById = {}

DiscoveredEquipments = {

	add = function( protocol, equipmentId, equipmentInfos, featureName, data, comment )
		local hasBeenAdded = false
		local id = protocol .. ";" .. equipmentId
		-- Add discovered equipment if not already known
		local discoveredEquipment = _indexDiscoveredEquipmentsById[ id ]
		if ( discoveredEquipment == nil ) then
			local ziblueInfos = _getZiBlueInfos( protocol, equipmentInfos.infoType, equipmentInfos.subType )
			discoveredEquipment = {
				name = ziblueInfos.name,
				protocol = protocol,
				frequency = ( ( dataFlag ~= "-1 " ) and tostring( ZIBLUE_FREQUENCY[ dataFlag ] ) or "" ),
				id = equipmentId,
				comment = comment,
				modelings = table_extend( {}, ziblueInfos.modelings ) -- Clone the modelings
			}
			table.insert( _discoveredEquipments, discoveredEquipment )
			_indexDiscoveredEquipmentsById[ id ] = discoveredEquipment
			hasBeenAdded = true
			debug( "Discovered equipment '" .. id .. "'", "DiscoveredEquipments.add" )
		end
		discoveredEquipment.quality = tonumber( equipmentInfos.quality )
		-- Feature
		local isFeatureKnown = false
		for _, modeling in ipairs( discoveredEquipment.modelings ) do
			for _, mapping in ipairs( modeling.mappings ) do
				local feature = mapping.features[ featureName ]
				if feature then
					-- This mapping contains our feature
					isFeatureKnown = true
					mapping.isUsed = true
					if ( type( data ) == "table" ) then
						feature.state = data.value .. " " .. data.unit
						if ( ( featureName == "hygrometry" ) and ( data.value == "0" ) ) then
							mapping.isUsed = false
						end
					else
						feature.state = data
					end
					if mapping.isUsed then
						modeling.isUsed = true
					end
					-- The features are unique in each modeling
					break
				end
			end
		end
		discoveredEquipment.lastUpdate = os.time()
		if hasBeenAdded then
			Variable.set( DEVICE_ID, "LAST_DISCOVERED", os.time() )
			UI.show( "New equipment discovered" )
		end
		if isFeatureKnown then
			debug( "Discovered equipment '" .. id .. "' and new feature '" .. featureName .. "'", "DiscoveredEquipments.add" )
		end
		return hasBeenAdded, isFeatureKnown
	end,

	get = function( protocol, equipmentId )
		if ( ( protocol ~= nil ) and ( equipmentId ~= nil ) ) then
			local id = protocol .. ";" .. equipmentId
			return _indexDiscoveredEquipmentsById[ id ]
		else
			return _discoveredEquipments
		end
	end,

	remove = function( protocol, equipmentId )
		if ( ( protocol ~= nil ) and ( equipmentId ~= nil ) ) then
			local id = protocol .. ";" .. equipmentId
			local discoveredEquipment = _indexDiscoveredEquipmentsById[ id ]
			for i, device in ipairs( _discoveredEquipments ) do
				if ( device == discoveredEquipment ) then
					table.remove( _discoveredEquipments, i )
					_indexDiscoveredEquipmentsById[ id ] = nil
					break
				end
			end
		end
	end
}


-- **************************************************
-- Equipments
-- **************************************************

local _equipments = {} -- The list of all our child devices
local _indexEquipmentsById = {}
local _indexEquipmentsAndMappingsByDeviceId = {}
local _indexFeaturesAndDevicesByIdAndFeatureName = {}

Equipments = {

	-- Get a list with all our child devices.
	retrieve = function()
		local formerEquipments = _equipments
		local formerFeatures = _indexFeaturesAndDevicesByIdAndFeatureName
		_equipments = {}
		_indexEquipmentsById = {}
		_indexEquipmentsAndMappingsByDeviceId = {}
		_indexFeaturesAndDevicesByIdAndFeatureName = {}
		for deviceId, luDevice in pairs( luup.devices ) do
			if ( luDevice.device_num_parent == DEVICE_ID ) then
				local protocol, equipmentId, deviceNum = unpack( string_split( luDevice.id or "", ";" ) )
				deviceNum = tonumber(deviceNum) or 1
				if ( ( protocol == nil ) or ( equipmentId == nil ) or ( deviceNum == nil ) ) then
					debug( "Found child device #".. tostring( deviceId ) .."(".. luDevice.description .."), but id '" .. tostring( device.id ) .. "' does not match pattern '[0-9]+;[0-9]+;[0-9]+'", "Equipments.retrieve" )
				else
					-- Features
					local featureNames = string_split( Variable.get( deviceId, "FEATURE" ) or "default", "," )
					-- Settings
					local settings = {}
					for _, encodedSetting in ipairs( string_split( Variable.get( deviceId, "SETTING" ) or "", "," ) ) do
						local settingName, value = string.match( encodedSetting, "([^=]*)=?(.*)" )
						if not string_isEmpty( settingName ) then
							settings[ settingName ] = not string_isEmpty( value ) and value or true
						end
					end
					-- Backward compatibility
					if settings.button then
						settings.transmitter = true
						settings.button = nil
					end
					-- Association
					association = Association.get( Variable.get( deviceId, "ASSOCIATION" ) )
					-- Add the device
					Equipments.add( protocol, equipmentId, featureNames, deviceNum, luDevice.device_type, deviceId, luDevice.room_num, settings, association, false )
				end
			end
		end

		-- Retrieve former feature states
		for _, formerEquipment in ipairs( formerEquipments ) do
			local id = formerEquipment.protocol .. ";" .. formerEquipment.id
			local equipment = _indexEquipmentsById[ id ]
			if ( equipment ) then
				for featureName, formerFeatureAndDevices in ipairs(formerFeatures[ id ]) do
					local formerFeature = formerFeatureAndDevices[1]
					local feature = _indexFeaturesAndDevicesByIdAndFeatureName[ id ][ featureName ]
					if ( feature and formerFeature ) then
						feature.state = formerFeature.state
					end
				end
			elseif ( formerEquipment.isNew ) then
				-- Add newly created Equipment (not present in luup.devices until a reload of the luup engine)
				table.insert( _equipments, formerEquipment )
				_indexEquipmentsById[ id ] = formerEquipment
				_indexFeaturesAndDevicesByIdAndFeatureName[ id ] = {}
				-- TODO
				--[[
				for _, feature in ipairs( formerEquipment.features ) do
					_indexFeaturesAndDevicesByIdAndFeatureName[ id ][ feature.name ] = feature 
				end
				--]]
			end
		end
		formerEquipments = nil
		formerFeature = nil
	end,

	-- Add a device
	add = function( protocol, equipmentId, featureNames, deviceNum, deviceType, deviceId, deviceRoomId, settings, association, isNew )
		local id = tostring(protocol) .. ";" .. tostring(equipmentId)
		--local deviceInfos = Device.getInfos( deviceType )
		--local deviceTypeName = deviceInfos and deviceInfos.name or deviceType
		local deviceInfos = Device.getInfos( deviceId )
		local deviceTypeName = deviceInfos and deviceInfos.name or "unknown"
		debug( "Add equipment '" .. id .. "', features " .. json.encode( featureNames or "" ) .. ", device #" .. tostring(deviceId) .. ", type " .. deviceTypeName, "Equipments.add" )
		local device = {
			id = deviceId,
			--type = deviceType,
			settings = settings or {},
			association = association or {}
		}
		local equipment = _indexEquipmentsById[ id ]
		if ( equipment == nil ) then
			equipment = {
				protocol = protocol,
				id = equipmentId,
				frequency = -1,
				quality = -1,
				mappings = {},
				maxDeviceNum = 0
			}
			if isNew then
				equipment.isNew = true
			end
			table.insert( _equipments, equipment )
			_indexEquipmentsById[ id ] = equipment
			_indexFeaturesAndDevicesByIdAndFeatureName[ id ] = {}
		end
		-- Update the device max number
		if ( deviceNum > equipment.maxDeviceNum ) then
			equipment.maxDeviceNum = deviceNum
		end
		-- Main device
		if ( ( deviceNum == 1 ) or not equipment.mainDeviceId ) then
			-- Main device
			equipment.mainDeviceId = deviceId
			equipment.mainRoomId = deviceRoomId
		end
		-- Mapping
		local _, mapping = _indexEquipmentsAndMappingsByDeviceId[ tostring( deviceId ) ]
		if ( mapping == nil ) then
			-- Device not already mapped
			mapping = {
				features = {},
				device = device
			}
			table.insert( equipment.mappings, mapping )
			_indexEquipmentsAndMappingsByDeviceId[ tostring( deviceId ) ] = { equipment, mapping }
		end
		-- Features
		for _, featureName in ipairs( featureNames ) do
			local feature, devices = unpack( _indexFeaturesAndDevicesByIdAndFeatureName[ id ][ featureName ] or {} )
			if ( feature == nil ) then
				feature = {
					name = featureName
				}
				_indexFeaturesAndDevicesByIdAndFeatureName[ id ][ featureName ] = { feature, {} }
			end
			mapping.features[featureName] = feature
			table.insert( _indexFeaturesAndDevicesByIdAndFeatureName[ id ][ featureName ][ 2 ], device )
		end
	end,

	get = function( protocol, equipmentId, featureName )
		if ( ( protocol ~= nil ) and ( equipmentId ~= nil ) ) then
			local id = tostring(protocol) .. ";" .. tostring(equipmentId)
			local equipment = _indexEquipmentsById[ id ]
			if ( equipment ~= nil ) then
				if ( featureName ~= nil ) then
					local feature, devices = unpack( _indexFeaturesAndDevicesByIdAndFeatureName[ id ][ featureName ] or {} )
					if ( feature ~= nil ) then
						return equipment, feature, devices
					end
				end
				return equipment
			end
			return nil
		else
			return _equipments
		end
	end,

	getFromDeviceId = function( deviceId )
		local index = _indexEquipmentsAndMappingsByDeviceId[ tostring( deviceId ) ]
		if index then
			return index[1], index[2].features, index[2].device
		else
			warning( "Equipment with deviceId #" .. tostring( deviceId ) .. "' is unknown", "Equipments.getFromDeviceId" )
		end
		return nil
	end,

	log = function()
		-- TODO : loguer tous les equipements
		local nbEquipments = 0
		local nbDevicesByFeature = {}
		for _, equipment in pairs( _equipments ) do
			nbEquipments = nbEquipments + 1
			for _, mapping in ipairs( equipment.mappings ) do
				for featureName, feature in pairs( mapping.features ) do
					if (nbDevicesByFeature[featureName] == nil) then
						nbDevicesByFeature[featureName] = 1
					else
						nbDevicesByFeature[featureName] = nbDevicesByFeature[featureName] + 1
					end
				end
			end
		end
		log("* Equipments: " .. tostring(nbEquipments), "Equipments.log")
		for featureName, nbDevices in pairs(nbDevicesByFeature) do
			log("*" .. string_lpad(featureName, 20) .. ": " .. tostring(nbDevices), "Equipments.log")
		end
	end
}


-- **************************************************
-- Equipment management
-- **************************************************

Equipment = {
	setStatus = function( equipment, status, parameters )
		parameters = parameters or {}
		local cmd
		if ( tostring(status) == "1" ) then
			cmd = "ON"
		else
			cmd = "OFF"
		end
		local qualifier = parameters.qualifier and ( " QUALIFIER " .. ( ( parameters.qualifier == "1" ) and "1" or "0" ) ) or ""
		local burst = parameters.burst and ( " BURST " .. parameters.burst ) or ""
		Network.send( "ZIA++" .. cmd .. " " .. equipment.protocol .. " ID " .. equipment.id .. qualifier .. burst )
	end,

	setLoadLevel = function( equipment, loadLevel, parameters )
		if ( equipment.protocol == "RTS" ) then
			error( "RTS equipment does not support DIM", "Equipment.setLoadLevel" )
			return false
		end
		parameters = parameters or {}
		local qualifier = parameters.qualifier and ( " QUALIFIER " .. ( ( parameters.qualifier == "1" ) and "1" or "0" ) ) or ""
		local burst = parameters.burst and ( " BURST " .. parameters.burst ) or ""
		Network.send( "ZIA++DIM " .. equipment.protocol .. " ID " .. equipment.id .. " %" .. tostring(loadLevel) .. qualifier .. burst )
	end

	-- TODO : HVAC
}

-- **************************************************
-- Serial connection
-- **************************************************

SerialConnection = {
	-- Check IO connection
	isValid = function()
		if not luup.io.is_connected( DEVICE_ID ) then
			-- Try to connect by ip (openLuup)
			local ip = luup.attr_get( "ip", DEVICE_ID )
			if not string_isEmpty( ip ~= nil ) then
				local ipaddr, port = string.match( ip, "(.-):(.*)" )
				if ( port == nil ) then
					ipaddr = ip
					port = 80
				end
				log( "Open connection on ip " .. ipaddr .. " and port " .. port, "SerialConnection.isValid" )
				luup.io.open( DEVICE_ID, ipaddr, tonumber( port ) )
			end
		end
		if not luup.io.is_connected( DEVICE_ID ) then
			error( "Serial port not connected. First choose the serial port and restart the lua engine.", "SerialConnection.isValid", false )
			UI.showError( "Choose the Serial Port" )
			return false
		else
			local ioDevice = tonumber(( Variable.get( DEVICE_ID, "IO_DEVICE" ) ))
			if ioDevice then
				-- Check serial settings
				local baudRate = Variable.get( ioDevice, "BAUD" ) or "115200"
				if ( baudRate ~= _SERIAL.baudRate ) then
					error( "Incorrect setup of the serial port. Select " .. _SERIAL.baudRate .. " bauds.", "SerialConnection.isValid", false )
					UI.showError( "Select " .. _SERIAL.baudRate .. " bauds for the Serial Port" )
					return false
				end
				log( "Baud rate is " .. _SERIAL.baudRate, "SerialConnection.isValid" )

				-- TODO : Check Parity none / Data bits 8 / Stop bit 1
			end
		end
		log( "Serial port is connected", "SerialConnection.isValid" )
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

	["getEquipmentsInfos"] = function( params, outputFormat )
		result = { equipments = Equipments.get(), discoveredEquipments = DiscoveredEquipments.get() }
		return tostring( json.encode( result ) ), "application/json"
	end,

	["getProtocolsInfos"] = function( params, outputFormat )
		return tostring( json.encode( ZIBLUE_SEND_PROTOCOL ) ), "application/json"
	end,

	["getSettings"] = function( params, outputFormat )
		return tostring( json.encode( _settings ) ), "application/json"
	end,

	["getErrors"] = function( params, outputFormat )
		return tostring( json.encode( g_errors ) ), "application/json"
	end
}
setmetatable( _handlerCommands, {
	__index = function( t, command, outputFormat )
		log( "No handler for command '" ..  tostring(command) .. "'", "handler" )
		return _handlerCommands["default"]
	end
})

local function _handleCommand( lul_request, lul_parameters, lul_outputformat )
	local command = lul_parameters["command"] or "default"
	debug( "Get handler for command '" .. tostring(command) .."'", "handleCommand" )
	return _handlerCommands[command]( lul_parameters, lul_outputformat )
end


-- **************************************************
-- Action implementations for childs
-- **************************************************

Child = {

	setTarget = function( childDeviceId, newTargetValue )
		if not Equipments.getFromDeviceId( childDeviceId ) then
			error( "Device #" .. tostring( childDeviceId ) .. " is not linked to an equipment", "Child.setTarget" )
			return JOB_STATUS.ERROR
		end
		Device.setStatus( childDeviceId, newTargetValue )
		return JOB_STATUS.DONE
	end,

	setLoadLevelTarget = function( childDeviceId, newLoadlevelTarget )
		if not Equipments.getFromDeviceId( childDeviceId ) then
			error( "Device #" .. tostring( childDeviceId ) .. " is not linked to an equipment", "Child.setLoadLevelTarget" )
			return JOB_STATUS.ERROR
		end
		Device.setLoadLevel( childDeviceId, newLoadlevelTarget )
		return JOB_STATUS.DONE
	end,

	setArmed = function( childDeviceId, newArmedValue )
		if not Equipments.getFromDeviceId( childDeviceId ) then
			error( "Device #" .. tostring( childDeviceId ) .. " is not linked to an equipment", "Child.setArmed" )
			return JOB_STATUS.ERROR
		end
		Device.setArmed( childDeviceId, newArmedValue or "0" )
		return JOB_STATUS.DONE
	end,

	moveShutter = function( childDeviceId, direction )
		if not Equipments.getFromDeviceId( childDeviceId ) then
			error( "Device #" .. tostring( childDeviceId ) .. " is not linked to an equipment", "Child.moveShutter" )
			return JOB_STATUS.ERROR
		end
		Device.moveShutter( childDeviceId, direction )
		return JOB_STATUS.DONE
	end,

	setModeStatus = function( childDeviceId, newModeStatus, option )
		if not Equipments.getFromDeviceId( childDeviceId ) then
			error( "Device #" .. tostring( childDeviceId ) .. " is not linked to an equipment", "Child.setModeStatus" )
			return JOB_STATUS.ERROR
		end
		Device.setModeStatus( childDeviceId, newModeStatus, option )
		return JOB_STATUS.DONE
	end,

	setSetPoint = function( childDeviceId, newSetpoint, option )
		if not Equipments.getFromDeviceId( childDeviceId ) then
			error( "Device #" .. tostring( childDeviceId ) .. " is linked to an equipment", "Child.setCurrentSetPoint" )
			return JOB_STATUS.ERROR
		end
		Device.setSetPoint( childDeviceId, newSetpoint, option )
		return JOB_STATUS.DONE
	end

}


-- **************************************************
-- Main action implementations
-- **************************************************

Main = {

	startJob = function( method, ... )
		local isOk = Tools.pcall( method, ... )
		return isOk and JOB_STATUS.DONE or JOB_STATUS.ERROR
	end,

	refresh = function()
		debug( "Refresh equipments", "refresh" )
		Equipments.retrieve()
		Equipments.log()
	end,

	-- Creates devices linked to equipements
	createDevices = function( jsonMappings )
		debug( "Create devices " .. tostring(jsonMappings), "createDevices" )
		local hasBeenCreated = false
		local decodeSuccess, mappings, _, jsonError = pcall( json.decode, string_decodeURI(jsonMappings) )
		local roomId = luup.devices[ DEVICE_ID ].room_num or 0
		for _, mapping in ipairs( mappings ) do
			local id = tostring(mapping.protocol) .. ";" .. tostring(mapping.equipmentId)
			local msg = "Equipment '" .. id .. "'"

			if string_isEmpty( mapping.deviceType ) then
				debug( msg .. " - Mapping does not have a device type", "createDevices" )
			else
				local deviceInfos = Device.getInfos( mapping.deviceType or "BINARY_LIGHT" )
				if not deviceInfos then
					error( msg .. " - Device infos are missing", "createDevices" )
				elseif not Device.fileExists( deviceInfos ) then
					error( msg .. " - Definition file for device type '" .. deviceInfos.name .. "' is missing", "createDevices" )
				else
					-- Compute device number
					local deviceNum = 1
					local equipment = Equipments.get( mapping.protocol, mapping.equipmentId )
					if equipment then
						debug( msg .. " already exists", "createDevices" )
						deviceNum = equipment.maxDeviceNum + 1
					end
					-- Device name
					local deviceName = mapping.deviceName or ( mapping.protocol .. " " .. mapping.equipmentId .. "/" .. tostring(deviceNum) )
					-- Device parameters
					local parameters = Device.getEncodedParameters( deviceInfos )
					parameters = parameters .. Variable.getEncodedValue( "FEATURE", table.concat( mapping.featureNames or {}, "," ) ) .. "\n"
					parameters = parameters .. Variable.getEncodedValue( "ASSOCIATION", "" ) .. "=\n"
					--parameters = parameters .. Variable.getEncodedValue( "SETTING", table.concat( table_append( settings, mapping.settings or {}, true ), "," ) ) .. "\n"
					parameters = parameters .. Variable.getEncodedValue( "SETTING", table.concat( mapping.settings or {}, "," ) ) .. "\n"
					if deviceInfos.category then
						parameters = parameters .. ",category_num=" .. tostring(deviceInfos.category) .. "\n"
					end
					if deviceInfos.subCategory then
						parameters = parameters .. ",subcategory_num=" .. tostring(deviceInfos.subCategory) .. "\n"
					end
					--[[
					if ( mapping.isBatteryPowered ) then -- TODO
						parameters = parameters .. Variable.getEncodedValue( "BATTERY_LEVEL", "" ) .. "=\n"
					end
					--]]
					-- Add new device in the home automation controller
					local internalId = id .. ";" .. tostring(deviceNum)
					debug( msg .. " - Add device '" .. internalId .. "', type '" .. deviceInfos.name .. "', file '" .. deviceInfos.file .. "'", "createDevices" )
					local newDeviceId = luup.create_device(
						'', -- device_type
						internalId,
						deviceName,
						deviceInfos.file,
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
					debug( msg .. " - Device #" .. tostring(newDeviceId) .. "(" .. deviceName .. ") has been created", "createDevices" )
					hasBeenCreated = true

					-- Add or update linked equipment
					--Equipments.add( mapping.protocol, mapping.equipmentId, featureNames, deviceNum, deviceType, newDeviceId, roomId, nil, nil, true )
					Equipments.add( mapping.protocol, mapping.equipmentId, mapping.featureNames, deviceNum, nil, newDeviceId, roomId, nil, nil, true )
					-- Remove from discovered equipments
					DiscoveredEquipments.remove( mapping.protocol, mapping.equipmentId )
				end
			end
		end

		if hasBeenCreated then
			Equipments.retrieve()
			Equipments.log()
			Variable.set( DEVICE_ID, "LAST_UPDATE", os.time() )
		end

	end,

	-- Teach a receiver (or Parrot). This is done on an unknown device (it wil be created)
	teachIn = function( productId, action, comment )
		local protocol, equipmentId = unpack( string_split( productId, ";" ) )
		equipmentId = tonumber(equipmentId)
		if ( ( protocol == nil ) or ( equipmentId == nil ) ) then
			error( "Protocol and equipment id are mandatory", "teachIn" )
			return JOB_STATUS.ERROR
		end
		if ( protocol == "PARROT" ) then
			-- PARROTLEARN
			if ( ( equipmentId < 0 ) or ( equipmentId > 239 ) ) then
				error( "Id of the Parrot device " .. tostring(equipmentId) .. " is not between 0 and 239", "teachIn" )
				return JOB_STATUS.ERROR, nil
			end
			action = ( action == "OFF" ) and "OFF" or "ON"
			debug( "Start Parrot learning for #" .. tostring(equipmentId) .. ", action " .. action .. " and reminder '" .. tostring(comment) .. "'", "teachIn" )
			Network.send( "ZIA++PARROTLEARN ID " .. tostring(equipmentId) .. " " .. action .. ( comment and ( " [" .. tostring(comment) .. "]" ) or "" ) )
		else
			if ( ( equipmentId < 0 ) or ( equipmentId > 255 ) ) then
				error( "Id of the device " .. tostring(equipmentId) .. " is not between 0 and 255", "teachIn" )
				return JOB_STATUS.ERROR, nil
			end
			debug( "Teach in " .. productId, "teachIn" )
			Network.send( "ZIA++ASSOC " .. protocol .. " ID " .. tostring(equipmentId) )
		end
	end,

	setTarget = function( productId, newTargetValue )
		local protocol, equipmentId, qualifier = unpack( string_split( productId, ";" ) )
		if ( ( protocol == nil ) or ( equipmentId == nil ) ) then
			error( "Protocol and equipment id are mandatory", "setTarget" )
			return JOB_STATUS.ERROR
		end
		local cmd = ( newTargetValue == "1" ) and "ON" or "OFF"
		debug( "Set " .. cmd .. " " .. productId, "setTarget" )
		Network.send( "ZIA++" .. cmd .. " ID " .. tostring(equipmentId) .. " " .. tostring(protocol) .. ( qualifier and ( " QUALIFIER " .. tostring(qualifier) ) or "" ) )
	end,

	-- Simulate a jamming
	simulateJamming = function( delay )
		local delay = tostring(delay or 5)
		debug( "Simulate jamming during " .. delay .. " seconds", "simulateJamming")
		Network.send( "ZIA++JAMMING SIMULATE " .. delay )
	end,

	-- DEBUG METHOD
	sendMessage = function( message )
		debug( "Send message: " .. tostring(message), "sendMessage" )
		Network.send( message )
	end

}


-- **************************************************
-- Startup
-- **************************************************

-- Init plugin instance
local function _initPluginInstance()
	log( "Init", "initPluginInstance" )

	-- Update the Debug Mode
	debugMode = ( Variable.getOrInit( DEVICE_ID, "DEBUG_MODE", "0" ) == "1" ) and true or false
	if debugMode then
		log( "DebugMode is enabled", "init" )
		debug = log
	else
		log( "DebugMode is disabled", "init" )
		debug = function() end
	end

	Variable.set( DEVICE_ID, "PLUGIN_VERSION", _VERSION )
	Variable.set( DEVICE_ID, "LAST_UPDATE", os.time() )
	Variable.set( DEVICE_ID, "LAST_MESSAGE", "" )
	Variable.getOrInit( DEVICE_ID, "LAST_DISCOVERED", "" )
end

-- Register with ALTUI once it is ready
local function _registerWithALTUI()
	for deviceId, luDevice in pairs( luup.devices ) do
		if ( luDevice.device_type == "urn:schemas-upnp-org:device:altui:1" ) then
			if luup.is_ready( deviceId ) then
				log( "Register with ALTUI main device #" .. tostring( deviceId ), "registerWithALTUI" )
				luup.call_action(
					"urn:upnp-org:serviceId:altui1",
					"RegisterPlugin",
					{
						newDeviceType = "urn:schemas-upnp-org:device:" .. _NAME .. ":1",
						newScriptFile = "J_" .. _NAME .. "1.js",
						newDeviceDrawFunc = _NAME .. ".ALTUI_drawDevice"
					},
					deviceId
				)
			else
				log( "ALTUI main device #" .. tostring( deviceId ) .. " is not yet ready, retry to register in 10 seconds...", "registerWithALTUI" )
				luup.call_delay( _NAME .. ".registerWithALTUI", 10 )
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

	--if ( type( json ) == "string" ) then
	if not hasJson then
		UI.showError( "No JSON decoder" )
	elseif SerialConnection.isValid() then
		-- Get the list of the child devices
		math.randomseed( os.time() )
		Equipments.retrieve()
		Equipments.log()

		-- Open the connection with the RFP1000
		Network.send( "ZIA++HELLO" )
		Network.send( "ZIA++FORMAT JSON" )

		-- Get the system statuses
		Network.send( "ZIA++STATUS SYSTEM JSON" )
		Network.send( "ZIA++STATUS RADIO JSON" )
		--Network.send( "WAIT" )
		Network.send( "ZIA++STATUS PARROT JSON" )

		-- Start polling engine
		PollEngine.start()
	end

	-- Watch setting changes
	Variable.watch( DEVICE_ID, VARIABLE.DEBUG_MODE, _NAME .. ".initPluginInstance" )

	-- HTTP Handlers
	log( "Register handler " .. _NAME, "init" )
	luup.register_handler( _NAME .. ".handleCommand", _NAME )

	-- Register with ALTUI
	luup.call_delay( _NAME .. ".registerWithALTUI", 10 )

	if ( luup.version_major >= 7 ) then
		luup.set_failure( 0, DEVICE_ID )
	end

	log( "Startup successful", "init" )
	return true, "Startup successful", _NAME
end


-- Promote the functions used by Vera's luup.xxx functions to the global name space
_G[_NAME .. ".handleCommand"] = _handleCommand
_G[_NAME .. ".Command.deferredProcess"] = Command.deferredProcess
_G[_NAME .. ".Network.send"] = Network.send
_G[_NAME .. ".Network.flush"] = Network.flush
_G[_NAME .. ".PollEngine.poll"] = PollEngine.poll

_G[_NAME .. ".initPluginInstance"] = _initPluginInstance
_G[_NAME .. ".registerWithALTUI"] = _registerWithALTUI
