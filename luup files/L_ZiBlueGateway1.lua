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
local hasBit, bit = pcall( require , "bit" )


--https://apps.mios.com/plugin.php?id=1648


-- **************************************************
-- Plugin constants
-- **************************************************

_NAME = "ZiBlueGateway"
_DESCRIPTION = "ZiBlue gateway for the Vera"
_VERSION = "1.3.5"
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

local _errors = {}
local function error( msg, methodName, notifyOnUI )
	table.insert( _errors, { os.time(), methodName or "", tostring( msg ) } )
	if ( #_errors > 100 ) then
		table.remove( _errors, 1 )
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
-- 4) variable that is used for the timestamp, for active value
-- 5) variable that is used for the timestamp, for inactive value
local VARIABLE = {
	-- Sensors
	TEMPERATURE = { "urn:upnp-org:serviceId:TemperatureSensor1", "CurrentTemperature", true },
	HUMIDITY = { "urn:micasaverde-com:serviceId:HumiditySensor1", "CurrentLevel", true },
	LIGHT_LEVEL = { "urn:micasaverde-com:serviceId:LightSensor1", "CurrentLevel", true },
	PRESSURE = { "urn:upnp-org:serviceId:BarometerSensor1", "CurrentPressure", true },
	FORECAST = { "urn:upnp-org:serviceId:BarometerSensor1", "Forecast", true },
	WIND_DIRECTION = { "urn:upnp-org:serviceId:WindSensor1", "Direction", true },
	WIND_GUST_SPEED = { "urn:upnp-org:serviceId:WindSensor1", "GustSpeed", true },
	WIND_AVERAGE_SPEED = { "urn:upnp-org:serviceId:WindSensor1", "AvgSpeed", true },
	RAIN_TOTAL = { "urn:upnp-org:serviceId:RainSensor1", "CurrentTRain", true },
	RAIN = { "urn:upnp-org:serviceId:RainSensor1", "CurrentRain", true },
	UV_LEVEL = { "urn:upnp-org:serviceId:UvSensor1", "CurrentLevel", true },
	-- Switches
	SWITCH_POWER = { "urn:upnp-org:serviceId:SwitchPower1", "Status", true },
	DIMMER_LEVEL = { "urn:upnp-org:serviceId:Dimming1", "LoadLevelStatus", true },
	DIMMER_LEVEL_TARGET = { "urn:upnp-org:serviceId:Dimming1", "LoadLevelTarget", true },
	DIMMER_LEVEL_OLD = { "urn:upnp-org:serviceId:ZiBlueDevice1", "LoadLevelStatus", true },
	DIMMER_DIRECTION = { "urn:upnp-org:serviceId:ZiBlueDevice1", "LoadLevelDirection", true },
	DIMMER_STEP = { "urn:upnp-org:serviceId:ZiBlueDevice1", "DimmingStep", true },
	-- Scene controller
	LAST_SCENE_ID = { "urn:micasaverde-com:serviceId:SceneController1", "LastSceneID", true, "LAST_SCENE_DATE" },
	LAST_SCENE_DATE = { "urn:micasaverde-com:serviceId:SceneController1", "LastSceneTime", true },
	-- Security
	ARMED = { "urn:micasaverde-com:serviceId:SecuritySensor1", "Armed", true },
	TRIPPED = { "urn:micasaverde-com:serviceId:SecuritySensor1", "Tripped", true, "LAST_TRIP", "LAST_UNTRIP" },
	ARMED_TRIPPED = { "urn:micasaverde-com:serviceId:SecuritySensor1", "ArmedTripped", true, "LAST_TRIP" },
	LAST_TRIP = { "urn:micasaverde-com:serviceId:SecuritySensor1", "LastTrip", true },
	LAST_UNTRIP = { "urn:micasaverde-com:serviceId:SecuritySensor1", "LastTrip", true },
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
	MAC_ADDRESS = { "urn:upnp-org:serviceId:ZiBlueGateway1", "MacAdress", true },
	DEBUG_MODE = { "urn:upnp-org:serviceId:ZiBlueGateway1", "DebugMode", true },
	LAST_DISCOVERED = { "urn:upnp-org:serviceId:ZiBlueGateway1", "LastDiscovered", true },
	LAST_UPDATE = { "urn:upnp-org:serviceId:ZiBlueGateway1", "LastUpdate", true },
	LAST_MESSAGE = { "urn:upnp-org:serviceId:ZiBlueGateway1", "LastMessage", true },
	-- Equipment
	ADDRESS = { "urn:upnp-org:serviceId:ZiBlueDevice1", "Address", true },
	ENDPOINT = { "urn:upnp-org:serviceId:ZiBlueDevice1", "Endpoint", true },
	FEATURE = { "urn:upnp-org:serviceId:ZiBlueDevice1", "Feature", true },
	ASSOCIATION = { "urn:upnp-org:serviceId:ZiBlueDevice1", "Association", true },
	SETTING = { "urn:upnp-org:serviceId:ZiBlueDevice1", "Setting", true },
	CAPABILITIES = { "urn:upnp-org:serviceId:ZiBlueDevice1", "Capabilities", true },
	LAST_INFO = { "urn:upnp-org:serviceId:ZiBlueDevice1", "LastInfo", true },
	NEXT_SCHEDULE = { "urn:upnp-org:serviceId:ZiBlueDevice1", "NextSchedule", true }
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
		parameters = { { "UV_LEVEL", "0" } }
	},
	RAIN_METER = {
		type = "urn:schemas-micasaverde-com:device:RainSensor:1", file = "D_RainSensor1.xml",
		parameters = { { "RAIN", "0" }, { "RAIN_TOTAL", "0" } }
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

-- Equipment types (capabilities)
local EQUIPMENT = {
	[ "PARROT;0" ] = { -- PARROT
		name = "PARROT",
		modelings = {
			{
				mappings = {
					{ features = { "state" }, deviceTypes = { "BINARY_LIGHT" }, settings = { "receiver", "transmitter" } }
				}
			}
		}
	},
	[ "0" ] = { -- X10 / DOMIA LITE protocol
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
					{ features = { "state", "assoc" } }, -- not used
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
					{ features = { "total rain", "current rain" }, deviceTypes = { "RAIN_METER" }, settings = { "transmitter" } }
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
	},
	[ "15|1" ] = { -- Edisio buttons (ETC1/ETC4/EBP8)
		name = "Button",
		modelings = {
			{
				mappings = {
					{ features = { "state" }, deviceTypes = { "BINARY_LIGHT", "DIMMABLE_LIGHT" }, settings = { "transmitter" } }
				}
			}
		}
	},
	[ "15|8" ] = { -- Edisio temperature (ETS-100)
		name = "Thermo sensor",
		modelings = {
			{
				mappings = {
					{ features = { "temperature" }, deviceTypes = { "TEMPERATURE_SENSOR" }, settings = { "transmitter" } }
				}
			}
		}
	},
	[ "15|9" ] = { -- Edisio temperature (EDS-100)
		name = "Door sensor",
		modelings = {
			{
				mappings = {
					{ features = { "state" }, deviceTypes = { "DOOR_SENSOR" }, settings = { "transmitter" } }
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
			mapping.isUsed = ( mapping.isUsed == true )
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
		[ "state" ] = function( deviceId, state )
			state = string.lower(state or "")
			if ( ( state == "on" ) or ( state == "alarm" ) ) then
				Device.setTripped( deviceId, "1" )
			elseif ( state == "off" ) then
				Device.setTripped( deviceId, "0" )
			elseif ( state == "tamper" ) then
				Device.setVariable( deviceId, "TAMPER_ALARM", "1" )
			elseif ( state == "supervisor/alive" ) then
				-- TODO
			end
		end
	}
	DEVICE.DOOR_SENSOR.commands = DEVICE.SECURITY_SENSOR.commands
	DEVICE.MOTION_SENSOR.commands = DEVICE.SECURITY_SENSOR.commands
	DEVICE.SMOKE_SENSOR.commands = DEVICE.SECURITY_SENSOR.commands
	DEVICE.WIND_SENSOR.commands = {
		[ "wind speed" ] = function( deviceId, windSpeed )
			Device.setVariable( deviceId, "WIND_AVERAGE_SPEED", windSpeed, "m/s" )
		end,
		[ "direction" ] = function( deviceId, windDirection )
			Device.setVariable( deviceId, "WIND_DIRECTION", windDirection )
		end
	}
	DEVICE.BAROMETER_SENSOR.commands = {
		[ "pressure" ] = function( deviceId, pressure )
			Device.setPressure( deviceId, pressure )
		end
	}
	DEVICE.UV_SENSOR.commands = {
		[ "uv" ] = function( deviceId, uvLevel )
			Device.setVariable( deviceId, "UV_LEVEL", uvLevel )
		end
	}
	DEVICE.RAIN_METER.commands = {
		[ "total rain" ] = function( deviceId, totalRain )
			Device.setVariable( deviceId, "RAIN_TOTAL", totalRain )
		end,
		[ "current rain" ] = function( deviceId, currentRain )
			Device.setVariable( deviceId, "RAIN", currentRain )
		end
	}
	DEVICE.BINARY_LIGHT.commands = {
		[ "state" ] = function( deviceId, state, params )
			state = string.lower(state or "")
			if ( ( state == "on" ) or ( state == "button/command" ) ) then
				Device.setStatus( deviceId, "1", table_extend( { noAction = true }, params ) )
			elseif ( state == "off" ) then
				Device.setStatus( deviceId, "0", table_extend( { noAction = true }, params ) )
			elseif ( state == "toggle" ) then
				Device.setStatus( deviceId, nil, table_extend( { noAction = true }, params ) )
			end
		end
	}
	DEVICE.DIMMABLE_LIGHT.commands = {
		[ "state" ] = DEVICE.BINARY_LIGHT.commands["state"],
		[ "dim" ] = function( deviceId, loadLevel )
			Device.setLoadLevel( deviceId, loadLevel, nil, nil, true )
		end,
		[ "dim-up" ] = function( deviceId )
			Device.setLoadLevel( deviceId, nil, "up", nil, true )
		end,
		[ "dim-down" ] = function( deviceId )
			Device.setLoadLevel( deviceId, nil, "down", nil, true )
		end,
		[ "dim-a" ] = function( deviceId, data )
			Device.setLoadLevel( deviceId, nil, nil, true, true )
		end,
		[ "dim-stop" ] = function( deviceId, data )
			-- TODO ?
		end
	}
	DEVICE.TEMPERATURE_SENSOR.commands = {
		[ "temperature" ] = function( deviceId, temperature )
			-- degree celcius
			-- TODO : manage Fahrenheit
			Device.setVariable( deviceId, "TEMPERATURE", temperature, "°C" )
		end
	}
	DEVICE.HUMIDITY_SENSOR.commands = {
		[ "hygrometry" ] = function( deviceId, humidity )
			Device.setVariable( deviceId, "HUMIDITY", humidity, "%" )
		end
	}
	DEVICE.POWER_METER.commands = {
		[ "energy" ] = function( deviceId, KWH )
			Device.setVariable( deviceId, "KWH", KWH, "KWH" )
		end,
		[ "power" ] = function( deviceId, watts )
			Device.setVariable( deviceId, "WATTS", watts, "W" )
		end
	}
	DEVICE.SHUTTER.commands = {
		[ "state" ] = DEVICE.BINARY_LIGHT.commands["state"],
		[ "up/on" ] = function( deviceId )
			Device.moveShutter( deviceId, "up" )
		end,
		[ "down/off" ] = function( deviceId )
			Device.moveShutter( deviceId, "down" )
		end,
		[ "my" ] = function( deviceId )
			Device.moveShutter( deviceId, "stop" )
		end
	}
	DEVICE.SCENE_CONTROLLER.commands = {
		[ "scene" ] = function( deviceId, sceneId )
			Device.setVariable( deviceId, "LAST_SCENE_ID", sceneId )
		end,
		[ "button1" ] = function( deviceId )
			Device.setVariable( deviceId, "LAST_SCENE_ID", "1" )
		end,
		[ "button2" ] = function( deviceId )
			Device.setVariable( deviceId, "LAST_SCENE_ID", "2" )
		end,
		[ "button3" ] = function( deviceId )
			Device.setVariable( deviceId, "LAST_SCENE_ID", "3" )
		end,
		[ "button4" ] = function( deviceId )
			Device.setVariable( deviceId, "LAST_SCENE_ID", "4" )
		end
	}
	DEVICE.PILOT_WIRE.commands = {
		-- TODO
	}
	DEVICE.THERMOSTAT.commands = {
		-- TODO
	}
	DEVICE.HEATER.commands = {
		-- TODO
	}
end

local function _getEquipmentInfos( protocol, infoType, subType, modelId )
	local equipmentInfos = EQUIPMENT[ tostring(protocol) .. ";" .. tostring(infoType) ]
					or ( modelId and EQUIPMENT[ tostring(infoType) .. "|" .. tostring(modelId) ] )
					or EQUIPMENT[ tostring(infoType) .. ";" .. tostring(subType) ]
					or EQUIPMENT[ tostring(infoType) ]
					or { name = "Unknown", modelings = {} }
	return equipmentInfos
end

-- Virtual equipment types (by protocol)
local VIRTUAL_EQUIPMENT = {
	VISONIC433 = { name = "Visonic 433Mhz (PowerCode)" },
	VISONIC868 = { name = "Visonic 868Mhz (PowerCode)" },
	CHACON = { name = "Chacon 433Mhz", deviceTypes = { "BINARY_LIGHT", "SHUTTER" } },
	DOMIA = { name = "Domia 433Mhz" },
	X10 = { name = "X10 433Mhz", deviceTypes = { "BINARY_LIGHT", "SHUTTER" } },
	X2D433 = { name = "X2D 433Mhz" },
	X2D868 = { name = "X2D 868Mhz" },
	X2DSHUTTER = { name = "X2D Shutter 868Mhz", deviceTypes = { "SHUTTER" } },
	X2DELEC = { name = "X2D Elec 868Mhz", deviceTypes = { "PILOT_WIRE", "HEATER" } },
	X2DGAS = { name = "X2D Gaz 868Mhz", deviceTypes = { "THERMOSTAT" } },
	RTS = {
		name = "Somfy RTS 433Mhz",
		deviceTypes = { "SHUTTER;qualifier=0", "SCENE_CONTROLLER;qualifier=1" }, -- TODO Portal
		deviceSettings = { "receiver", "my=50" },
		-- deviceTypes = { "SHUTTER;qualifier=0", "PORTAL;qualifier=1" },
		protocolSettings = {
			{ variable = "qualifier", name = "qualifier", type = "string" }
		}
	},
	BLYSS = { name = "Blyss 433Mhz" },
	PARROT = {
		name = "* ZiBlue Parrot",
		--deviceTypes = { "BINARY_LIGHT", "DOOR_SENSOR", "MOTION_SENSOR", "SMOKE_SENSOR" },
		deviceSettings = { "receiver", "transmitter" },
		protocolSettings = {
			{ variable = "comment", name = "reminder", type = "string" },
			{ variable = "action", name = "action", type = "select", values = { "ON", "OFF" } }
		}
	},
	KD101 = { name = "KD101 433Mhz" }, -- TODO Alarm with scene or button
	EDISIO = {
		name = "Edisio 868Mhz",
		deviceTypes = { "BINARY_LIGHT", "DIMMABLE_LIGHT" },
		protocolSettings = {
			{ variable = "qualifier", name = "channel", type = "string" }
		}
	}
}
for _, virtualEquipmentInfos in pairs( VIRTUAL_EQUIPMENT ) do
	virtualEquipmentInfos.features = { "virtual" }
	if not virtualEquipmentInfos.deviceTypes then
		virtualEquipmentInfos.deviceTypes = { "BINARY_LIGHT" }
	end
	if not virtualEquipmentInfos.deviceSettings then
		virtualEquipmentInfos.deviceSettings = { "receiver" }
	end
end

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

local SETTINGS = {
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

	function number_toBytes( num, endian, signed )
		if ( ( num < 0 ) and not signed ) then
			num = -num
		end
		local res = {}
		local n = math.ceil( select( 2, math.frexp(num) ) / 8 ) -- number of bytes to be used.
		if ( signed and num < 0 ) then
			num = num + 2^n
		end
		for k = n, 1, -1 do -- 256 = 2^8 bits per char.
			local mul = 2^(8*(k-1))
			res[k] = math.floor( num / mul )
			num = num - res[k] * mul
		end
		assert( num == 0 )
		if endian == "big" then
			local t={}
			for k = 1, n do
				t[k] = res[n-k+1]
			end
			res = t
		end
		return string.char(unpack(res))
	end

end

-- **************************************************
-- Table functions
-- **************************************************

do
	-- Merges (deeply) the contents of one table (t2) into another (t1)
	function table_extend( t1, t2, excludedKeys )
		if ( ( type(t1) == "table" ) and ( type(t2) == "table" ) ) then
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

	function string_fromHex( s )
		return ( s:gsub( '..', function( cc )
			return string.char( tonumber(cc, 16) )
		end ))
	end

	function string_toHex( s )
		return ( s:gsub( '.', function( c )
			return string.format( '%02X', string.byte(c) )
		end ))
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
		if string_isEmpty( s ) then
			return ""
		end
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
	getTimestamp = function( deviceId, variable, isActive )
		variable = _getVariable( variable )
		local pos = isActive and 4 or 5
		if ( ( type( variable ) == "table" ) and ( type( variable[pos] ) == "string" ) ) then
			local variableTimestamp = VARIABLE[ variable[pos] ]
			if ( variableTimestamp ~= nil ) then
				return tonumber( ( luup.variable_get( variableTimestamp[1], variableTimestamp[2], deviceId ) ) )
			end
		end
		return nil
	end,

	-- Set variable timestamp
	setTimestamp = function( deviceId, variable, timestamp, isActive )
		variable = _getVariable( variable )
		local pos = isActive and 4 or 5
		if ( variable[pos] ~= nil ) then
			local variableTimestamp = VARIABLE[ variable[pos] ]
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
		timestamp = Variable.getTimestamp( deviceId, variable, ( value ~= "0" ) ) or timestamp
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
		if ( ( currentValue == value ) and ( ( variable[3] == true ) or ( value == "0" ) ) ) then
			-- Variable is not updated when the value is unchanged
			doChange = false
		end

		if doChange then
			luup.variable_set( variable[1], variable[2], value, deviceId )
		end

		-- Updates linked variable for timestamp
		Variable.setTimestamp( deviceId, variable, os.time(), ( value ~= "0" ) )
	end,

	-- Get variable value and init if value is nil or empty
	getOrInit = function( deviceId, variable, defaultValue )
		local value, timestamp = Variable.get( deviceId, variable )
		if ( ( value == nil ) or (  value == "" ) ) then
			value = defaultValue
			Variable.set( deviceId, variable, value )
			timestamp = os.time()
			Variable.setTimestamp( deviceId, variable, timestamp, true )
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
		local name = deviceInfos.file or ""
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
	setStatus = function( deviceId, status, params )
		if status then
			status = tostring( status )
		end
		local params = params or {}
		local formerStatus = Variable.get( deviceId, "SWITCH_POWER" ) or "0"
		local equipment, mapping = Equipments.getFromDeviceId( deviceId )
		local msg = "Equipment '" .. Tools.getEquipmentSummary( equipment, mapping ) .. "'"
		if ( mapping.device.settings.receiver ) then
			msg = msg .. " (receiver)"
		elseif ( mapping.device.settings.transmitter ) then
			msg = msg .. " (transmitter)"
		end

		-- Momentary
		local isMomentary = ( mapping.device.settings.momentary == true )
		if ( isMomentary and ( status == "0" ) and not params.isAfterTimeout ) then
			debug( msg .. " - Begin of momentary state", "Device.setStatus" )
			return
		end

		-- Toggle
		local isToggle = ( mapping.device.settings.toggle == true )
		if ( isToggle or ( status == nil ) or ( status == "" ) ) then
			if ( status == "0" ) then
				debug( msg .. " - Toggle : ignore OFF state", "Device.setStatus" )
				return
			elseif isMomentary then
				-- Always ON in momentary and toggle mode
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

		-- Long press (works at least for Xiaomi button)
		local isLongPress = false
		local timeForLongPress = tonumber(mapping.device.settings.timeForLongPress) or 0
		if ( isMomentary and ( timeForLongPress > 0 ) and ( status == "1" ) and ( params.lastData == "off" ) and ( params.elapsedTime >= timeForLongPress ) ) then
			isLongPress = true
		end

		-- Has status changed ?
		if ( not isMomentary and ( status == formerStatus ) ) then
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
				-- Store the current load level
				Variable.set( deviceId, "DIMMER_LEVEL_OLD", Variable.get( deviceId, "DIMMER_LEVEL" ) )
			end
			Variable.set( deviceId, "DIMMER_LEVEL", loadLevel )
		end

		-- Send command to the linked equipment if needed
		if ( mapping.device.settings.receiver and not params.noAction ) then
			if ( loadLevel and Device.isDimmable( deviceId ) ) then 
				Equipment.setLoadLevel( equipment, loadLevel, mapping )
			else
				Equipment.setStatus( equipment, status, mapping )
			end
		end

		-- Propagate to associated devices
		if not params.noPropagation then
			Association.propagate( mapping.device.association, status, loadLevel, isLongPress )
		end

		-- Momentary
		if ( isMomentary and ( status == "1" ) ) then
			local timeout = mapping.device.settings.timeout or 0
			if ( timeout > 0 ) then
				debug( "Device #" .. tostring( deviceId ) .. " will be switch OFF in " .. tostring(timeout) .. "s", "Device.setStatus" )
				luup.call_delay( _NAME .. ".Device.setStatusAfterTimeout", timeout, deviceId )
			else
				status = "0"
				Device.setStatus( deviceId, status, { noAction = true, noPropagation = true, isAfterTimeout = true } )
			end
		end

		return status
	end,

	setStatusAfterTimeout = function( deviceId )
		deviceId = tonumber( deviceId )
		local equipment, mapping = Equipments.getFromDeviceId( deviceId )
		local timeout = tonumber(mapping.device.settings.timeout) or 0
		if ( ( timeout > 0 ) and ( Variable.get( deviceId, VARIABLE.SWITCH_POWER ) == "1" ) ) then 
			local elapsedTime = os.difftime( os.time(), Variable.getTimestamp( deviceId, VARIABLE.SWITCH_POWER ) or 0 )
			if ( elapsedTime >= timeout ) then
				Device.setStatus( deviceId, "0", { isAfterTimeout = true } )
			end
		end
	end,

	-- Dim OFF/ON/TOGGLE
	setLoadLevel = function( deviceId, loadLevel, params )
		local params = params or {}
		loadLevel = tonumber( loadLevel )
		local formerLoadLevel, lastLoadLevelChangeTime = Variable.get( deviceId, "DIMMER_LEVEL" )
		formerLoadLevel = tonumber( formerLoadLevel ) or 0
		local equipment, mapping = Equipments.getFromDeviceId( deviceId )
		local dimmingStep = tonumber(mapping.device.settings.dimmingStep) or 3
		local msg = "Dim"

		if ( params.isLongPress and not Device.isDimmable( deviceId ) ) then
			-- Long press handled by a switch
			return Device.setStatus( deviceId, nil, params )

		elseif ( loadLevel == nil ) then
			-- Toggle dim
			loadLevel = formerLoadLevel
			if ( params.direction == nil ) then
				params.direction = Variable.getOrInit( deviceId, "DIMMER_DIRECTION", "up" )
				if ( os.difftime( os.time(), lastLoadLevelChangeTime ) > 2 ) then
					-- Toggle direction after 2 seconds of inactivity
					msg = "Toggle dim"
					if ( params.direction == "down" ) then
						params.direction = "up"
						Variable.set( deviceId, "DIMMER_DIRECTION", "up" )
					else
						params.direction = "down"
						Variable.set( deviceId, "DIMMER_DIRECTION", "down" )
					end
				end
			end
			if ( params.direction == "down" ) then
				loadLevel = loadLevel - dimmingStep
				msg = msg .. "-" .. tostring(dimmingStep)
			else
				loadLevel = loadLevel + dimmingStep
				msg = msg .. "+" .. tostring(dimmingStep)
			end
		end

		-- Update load level variable
		if ( loadLevel < dimmingStep ) then
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
		Variable.set( deviceId, "DIMMER_LEVEL_TARGET", loadLevel )
		Variable.set( deviceId, "DIMMER_LEVEL", loadLevel )
		if ( loadLevel > 0 ) then
			Variable.set( deviceId, "SWITCH_POWER", "1" )
		else
			Variable.set( deviceId, "SWITCH_POWER", "0" )
		end

		-- Send command to the linked equipment if needed
		if ( mapping.device.settings.receiver and not ( params.noAction == true ) ) then
			if ( loadLevel > 0 ) then
				if not Device.isDimmable( deviceId ) then
					if ( loadLevel == 100 ) then
						Equipment.setStatus( equipment, "1", mapping )
					else
						debug( "This device does not support DIM", "Device.setLoadLevel" )
					end
				else
					Equipment.setLoadLevel( equipment, loadLevel, mapping )
				end
			else
				Equipment.setStatus( equipment, "0", mapping )
			end
		end

		-- Propagate to associated devices
		Association.propagate( mapping.device.association, nil, loadLevel, params.isLongPress )

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
		local formerTripped = Variable.get( deviceId, "TRIPPED" ) or "0"
		local equipment, mapping = Equipments.getFromDeviceId( deviceId )
		if ( tripped ~= formerTripped ) then
			debug( "Device #" .. tostring( deviceId ) .. " is " .. ( ( tripped == "1" ) and "tripped" or "untripped" ), "Device.setTripped" )
			Variable.set( deviceId, "TRIPPED", tripped )
			if ( ( tripped == "1" ) and ( Variable.get( deviceId, "ARMED" ) == "1" ) ) then
				Variable.set( deviceId, "ARMED_TRIPPED", "1" )
			else
				Variable.set( deviceId, "ARMED_TRIPPED", "0" )
			end
			-- Propagate to associated devices
			Association.propagate( mapping.device.association, tripped )
		end

		-- Momentary
		local isMomentary = ( mapping.device.settings.momentary == true )
		if ( isMomentary and ( tripped == "1" ) ) then
			local timeout = tonumber(mapping.device.settings.timeout) or 0
			if ( timeout > 0 ) then
				debug( "Device #" .. tostring( deviceId ) .. " will be untripped in " .. tostring(timeout) .. "s", "Device.setTripped" )
				Variable.set( deviceId, "NEXT_SCHEDULE", os.time() + timeout )
				luup.call_delay( _NAME .. ".Device.setTrippedAfterTimeout", timeout, deviceId )
			end
		end
	end,

	setTrippedAfterTimeout = function( deviceId )
		deviceId = tonumber( deviceId )
		local nextSchedule = tonumber((Variable.get( deviceId, "NEXT_SCHEDULE" ))) or 0
		if ( os.time() >= nextSchedule ) then
			Device.setTripped( deviceId, "0" )
		end
	end,

	-- Set a variable value
	setVariable = function( deviceId, variableName, value, unit )
		if not Variable.isSupported( deviceId, variableName ) then
			return
		end
		debug( "Set device #" .. tostring(deviceId) .. " " .. variableName .. " to " .. tostring( value ) .. ( unit or "" ), "Device.setVariable" )
		Variable.set( deviceId, variableName, value )
	end,

	-- Set atmospheric pressure
	setPressure = function( deviceId, pressure )
		--[[if not Variable.isSupported( deviceId, "PRESSURE" ) then
			return
		end--]]
		local pressure = tonumber( pressure )
		local forecast = "TODO" -- TODO
		--[[
		"sunny"
		"partly cloudy"
		"cloudy"
		"rain"
		--]]
		debug( "Set device #" .. tostring(deviceId) .. " pressure to " .. tostring( pressure ) .. "hPa and forecast to " .. forecast, "Device.setPressure" )
		Variable.set( deviceId, "PRESSURE", pressure )
		Variable.set( deviceId, "FORECAST", forecast )
	end,

	-- Set battery level
	setBatteryLevel = function( deviceId, batteryLevel )
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
	moveShutter = function( deviceId, direction, params )
		local params = params or {}
		debug( "Shutter #" .. tostring(deviceId) .. " direction: " .. tostring(direction), "Device.moveShutter" )
		if ( direction == "up" ) then
			return Device.setStatus( deviceId, "1", nil, params )
		elseif ( direction == "down" ) then
			return Device.setStatus( deviceId, "0", nil, params )
		elseif ( direction == "stop" ) then
			-- TODO : problème avec sens ?
			local equipment, mapping = Equipments.getFromDeviceId( deviceId )
			if ( equipment.protocol == "RTS" ) then
				-- "My" fonction for RTS
				if ( mapping.device.settings.receiver and not ( params.noAction == true ) ) then
					debug( "RTS 'My' function", "Device.moveShutter" )
					local loadLevel = mapping.device.settings.my or "50"
					Device.setLoadLevel( deviceId, loadLevel, { noAction = true } )
					local burst = mapping.device.settings.burst and ( " BURST " .. mapping.device.settings.burst ) or ""
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
		-- TODO
	end
}


-- **************************************************
-- Commands
-- **************************************************

local _commandsToProcess = {}
local _isProcessingCommand = false

Commands = {

	process = function()
		if ( #_commandsToProcess > 0 ) then
			luup.call_delay( _NAME .. ".Commands.deferredProcess", 0 )
		end
	end,

	add = function( protocol, equipmentId, address, endpointId, infos, cmd )
		cmd.name = string.lower(cmd.name or "")
		local msg = "Equipment " .. Tools.getEquipmentInfo( protocol, equipmentId, address, endpointId )
		if string_isEmpty(cmd.name) then
			error( msg .. " : no given command", "Commands.add" )
			return false
		end
		local equipment, feature, devices = Equipments.get( protocol, equipmentId, address, ( cmd.broadcast == true and "all" or endpointId ), cmd.name ) -- cmd.name = feature
		if equipment then
			equipment.frequency = infos.frequency
			equipment.quality = infos.quality
			if equipment.isNew then
				-- No command on a new equipment (not yet handled by the home automation controller)
				debug( msg .. " is new : do nothing", "Commands.add" )
				return true
			end
			if feature then
				-- Equipment is known for this feature
				cmd.elapsedTime = os.difftime( os.time(), feature.lastUpdate or os.time() )
				cmd.lastData = feature.data
				feature.data = cmd.data
				feature.unit = cmd.unit
				feature.lastUpdate = os.time()
				equipment.lastUpdate = os.time()
				table.insert( _commandsToProcess, { devices, cmd } )
			else
				-- Equipment is known (but not for this feature)
				if ( cmd.name == "battery" ) then
					Device.setBatteryLevel( equipment.mainDeviceId, cmd.data )
				end
			end
		end

		if ( not cmd.broadcast and ( cmd.name ~= "battery" ) and ( not equipment or not feature ) ) then
			-- Add this equipment or feature to the discovered equipments (but not yet known)
			local hasBeenAdded, isFeatureKnown = DiscoveredEquipments.add( protocol, equipmentId, address, endpointId, infos, cmd.name, cmd.data, cmd.unit )
			if hasBeenAdded then
				debug( msg .. " is unknown for command '" .. cmd.name .. "'", "Commands.add" )
			elseif not isFeatureKnown then
				error( msg .. ": feature '" .. cmd.name .. "' is not known", "Commands.add" )
				return false
			else
				debug( msg .. " is already discovered for command '" .. cmd.name .. "'", "Commands.add" )
			end
		end
		return true
	end,

	deferredProcess = function()
		if _isProcessingCommand then
			debug( "Processing is already in progress", "Commands.deferredProcess" )
			return
		end
		_isProcessingCommand = true
		while _commandsToProcess[1] do
			local status, err = pcall( Commands.protectedProcess )
			if err then
				error( "Error: " .. tostring( err ), "Commands.deferredProcess" )
			end
			table.remove( _commandsToProcess, 1 )
		end
		_isProcessingCommand = false
	end,

	protectedProcess = function()
		local devices, cmd = unpack( _commandsToProcess[1] )
		for _, device in pairs( devices ) do
			local msg = "Device #" .. tostring(device.id)
			local deviceInfos = Device.getInfos( device.id )
			if ( deviceInfos == nil ) then
				error( msg .. " - Type is unknown", "Commands.protectedProcess" )
			elseif ( deviceInfos.commands[ cmd.name ] ~= nil ) then
				if ( type(cmd.data) == "table" ) then
					debug( msg .. " - Do command '" .. cmd.name .. "' with data '" .. json.encode(cmd.data) .. "'", "Commands.protectedProcess" )
				else
					debug( msg .. " - Do command '" .. cmd.name .. "' with data '" .. tostring(cmd.data) .. "'", "Commands.protectedProcess" )
				end
				deviceInfos.commands[ cmd.name ]( device.id, cmd.data, { unit = cmd.unit, lastData = cmd.lastData, elapsedTime = cmd.elapsedTime } )
				if cmd.info then
					Variable.set( device.id, "LAST_INFO", cmd.info )
				end
			else
				warning( msg .. " - Command '" .. cmd.name .. "' not yet implemented for this device type " .. tostring(deviceInfos.type), "Commands.protectedProcess" )
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

local _isMeasureValid = function( measure )
	if ( ( measure.type == "hygrometry" ) and ( measure.value == "0" ) ) then
		return false
	end
	if ( ( measure.type == "temperature" ) and ( measure.value == "-0.0" ) ) then
		return false
	end
	return true
end

Network = {

	receive = function( lul_data )
		if lul_data then
			_lastNetworkReceiveTime = os.time()
			local sync = string.sub( lul_data, 1, 2 )
			if ( sync == "ZI" ) then
				local source = string.sub( lul_data, 3, 3 )
				local qualifier = string.sub( lul_data, 4, 5 )
				local data = string.gsub( string.sub( lul_data, 6 ), '[%c]', '' ) -- Data without the terminator

				if ( ( qualifier == "33" ) or ( ( qualifier == "--" ) and ( string.sub( data, 1, 1 ) == "{" ) ) ) then
					-- JSON
					local decodeSuccess, data, _, jsonError = pcall( json.decode, data )
					if ( decodeSuccess and data ) then
						debug( source .. " " .. qualifier .. ": " .. json.encode( data ), "Network.receive" )
						if data.systemStatus then
							SETTINGS.system = Tools.extractInfos( data.systemStatus.info )
							-- Special feature : JAMMING
							local filteredSettings = table_filter( SETTINGS.system, function(i, setting) return ( setting.name == "Jamming" ) end )
							if ( ( #filteredSettings > 0 ) and not Equipments.get( "JAMMING", "0" ) ) then
								local comment = ( tonumber(filteredSettings[1].value or 0) == 0 ) and "Jamming detection feature is not activated" or ""
								DiscoveredEquipments.add( "JAMMING", "0", nil, nil, { infoType = "1" }, "state", "1", nil, comment )
							end
						elseif data.radioStatus then
							SETTINGS.radio = Tools.extractInfos( data.radioStatus.band )
						elseif data.parrotStatus then
							Tools.updateParrotStatus( data.parrotStatus.info )
						elseif not Network.processFrame( source, qualifier, data ) then
						--elseif not Tools.pcall( Network.processFrame, source, qualifier, data )
							error( "Error with RF frame: " .. tostring(lul_data), "Network.receive" )
						else
							Commands.process()
						end
					else
						error( "JSON error: " .. tostring( jsonError ), "Network.receive" )
					end
				elseif ( qualifier == "66" ) then
					-- EDISIOFRAME
					-- TODO
					data = string.sub( data, 14 )
					debug( "Edisio frame: '" .. tostring( data ) .. "'", "Network.receive" )
				else
					if ( data == "PONG" ) then
						debug( _NAME .. " is alive", "Network.receive" )
					elseif ( string.sub( data, 1, 7 ) == "Welcome" ) then
						debug( "Welcome: " .. data, "Network.receive" )
					else
						error( "Unkown message: " .. qualifier .. "'" .. tostring( data ) .. "'", "Network.receive" )
					end
				end

			else
				debug( "Unkown data: '" .. tostring( lul_data ) .. "'", "Network.receive" )
			end
		end
	end,

	processFrame = function( source, qualifier, data )
		local frameHeader = data.frame.header
		local frameInfos = data.frame.infos
		local protocol = frameHeader.protocolMeaning
		local infoType = frameHeader.infoType
		local equipmentId = frameInfos.id or frameInfos.adr_channel
		if string_isEmpty(equipmentId) then
			warning( "equipmentId can not be empty", "Network.processFrame" )
			return true
		end
		if ( ( protocol ~= "JAMMING" ) and ( protocol ~= "PARROT" ) and ( tonumber(equipmentId) == 0 ) ) then
			warning( "equipmentId has to be greater than 0", "Network.processFrame" )
			return true
		end
		local infos = {
			infoType = frameHeader.infoType,
			subType = frameInfos.subType,
			frequency = ( ( frameHeader.dataFlag ~= "-1 " ) and tostring( ZIBLUE_FREQUENCY[ frameHeader.dataFlag ] ) or "" ),
			quality = tonumber( frameHeader.rfQuality )
		}
		local endpointId
		local isOk = true

		if ( protocol == "EDISIO" ) then
			equipmentId = string_toHex( number_toBytes( tonumber(equipmentId), "little", false ) )
			endpointId = string_lpad( frameInfos.qualifier or "01", 2, "0" ) -- Edisio channel
			debug( "modelId : " .. frameInfos.info, "Network.processFrame" )
			local info = tonumber(frameInfos.info) or 0
			infos.modelId = bit.band( info, 0xFF )
			debug( "modelId : " .. number_toHex( infos.modelId ), "Network.process" )
			if ( frameInfos.subTypeMeaning == "SET_TEMPERATURE" ) then
				frameInfos.measures = {
					{
						type = "temperature",
						value = ( tonumber(frameInfos.add0) or 0 ) / 100,
						unit = "Celsius"
					}
				}
				frameInfos.subTypeMeaning = nil
			end
			--  3.6V is 100%, 2.6V is 0%
			local batteryLevel = math.ceil((math.floor(info / 254) - 26) * 10)
			debug( "batteryLevel : " .. number_toHex( batteryLevel ), "Network.process" )
			isOk = Commands.add( protocol, equipmentId, nil, endpointId, infos, { name = "battery", data = batteryLevel, unit = "%" } ) and isOk
		end

		local equipInfos = _getEquipmentInfos( protocol, infos.infoType, infos.subType, infos.modelId )
		infos.capability = { name = equipInfos.name, modelings = equipInfos.modelings }
		debug( "capability : " .. json.encode( infos.capability ), "Network.process" )


		-- Battery
		if ( frameInfos.lowBatt == "1" ) then
			isOk = Commands.add( protocol, equipmentId, nil, endpointId, infos, { name = "battery", data = 10, unit = "%" } ) and isOk
		end

		if ( infoType == "10" ) then
		--[[
			frameInfos.functionMeaning
			stateMeaning
			infos.modelName = frameInfos.subTypeMeaning
		--]]
		elseif ( frameInfos.subTypeMeaning ) then
			-- State
			isOk = Commands.add( protocol, equipmentId, nil, endpointId, infos, { name = "state", data = frameInfos.subTypeMeaning } ) and isOk
		end

		-- Measures
		if ( frameInfos.measures ) then
			for _, measure in ipairs( frameInfos.measures ) do
				if _isMeasureValid( measure ) then
					isOk = Commands.add( protocol, equipmentId, nil, endpointId, infos, { name = measure.type, data = measure.value, unit = measure.unit } ) and isOk
				end
			end
		end

		-- Flags (can be "LowBatt")
		if ( frameInfos.qualifierMeaning and frameInfos.qualifierMeaning.flags ) then
			for _, flag in ipairs( frameInfos.qualifierMeaning.flags ) do
				if ( flag == "LowBatt") then
					isOk = Commands.add( protocol, equipmentId, nil, endpointId, infos, { name = "battery", data = 10, unit = "%" } ) and isOk
				else
					isOk = Commands.add( protocol, equipmentId, nil, endpointId, infos, { name = flag } ) and isOk
				end
			end
		end

		return isOk
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
	start = function()
		log( "Start poll", "PollEngine.start" )
		_isPollingActivated = true
		luup.call_delay( _NAME .. ".PollEngine.poll", SETTINGS.plugin.pollInterval )
	end,

	poll = function()
		if _isPollingActivated then
		-- TODO : check if it works
			if ( os.difftime( Network.getLastReceiveTime(), os.time() ) > SETTINGS.plugin.pollInterval * 2 ) then
				log( "Last receive is too old : there's a communication problem", "PollEngine.poll" )
				luup.set_failure( 1, DEVICE_ID )
			elseif ( Variable.get( DEVICE_ID, "COMM_FAILURE" ) == "1" ) then
				luup.set_failure( 0, DEVICE_ID )
			end
			debug( "Poll", "PollEngine.poll" )
			Network.send( "ZIA++PING" )
			-- Prepare next polling
			luup.call_delay( _NAME .. ".PollEngine.poll", SETTINGS.plugin.pollInterval )
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

	getEquipmentInfo = function( protocol, equipmentId, address, endpointId, featureNames, deviceId )
		local info = "(protocol:" .. protocol .. "),(id:" .. tostring(equipmentId) ..")"
		if not string_isEmpty(address) then
			info = info .. ",(address:" .. tostring(address) .. ")"
		end
		if not string_isEmpty(endpointId) then
			info = info .. ",(endpointId:" .. tostring(endpointId) .. ")"
		end
		if ( type(featureNames) == "table" ) then
			info = info .. ",(features:" .. table.concat( featureNames, "," ) .. ")"
		end
		if deviceId then
			info = info .. ",(deviceId:" .. tostring( deviceId ) .. ")"
		end
		return info
	end,

	getEquipmentSummary = function( equipment, mapping )
		local info
		if mapping then
			info = Tools.getEquipmentInfo( equipment.protocol, equipment.id, equipment.address, mapping.endpointId, table_getKeys( mapping.features ), mapping.device.id )
		else
			info = Tools.getEquipmentInfo( equipment.protocol, equipment.id, equipment.address )
		end
		return info
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
				if ( item.name == "Jamming" ) then
					item.action = "SetParam"
					item.variable = "jamming"
					item.type = "select"
					item.values = { "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10" }
					item.comment = "(0=OFF, 1=most sensitive -> 10=least sensitive)"
				end
			elseif info.i then
				table.insert( result, Tools.extractInfos( info.i ) )
			elseif info.p then
				table.insert( result, info.p )
			elseif info.transmitter then
				table.insert( result, { name = "transmitter-available", value = table.concat( info.transmitter.available.p, "," ) } )
			elseif info.receiver then
				if info.receiver.available then
					table.insert( result, { name = "receiver-available", value = table.concat( info.receiver.available.p, "," ) } )
				elseif info.receiver.enabled then
					table.insert( result, { name = "receiver-enabled", value = table.concat( info.receiver.enabled.p, "," ) } )
				end
			elseif info.repeater then
				if info.repeater.available then
					table.insert( result, { name = "repeater-available", value = table.concat( info.repeater.available.p, "," ) } )
				elseif info.repeater.enabled then
					table.insert( result, { name = "repeater-enabled", value = table.concat( info.repeater.enabled.p, "," ) } )
				end
			else
				table.insert( result )
			end
		end
		debug( "Result:" .. json.encode( result ), "Tools.extractInfos" )
		return result
	end,

	updateParrotStatus = function( infos )
		local status = Tools.extractInfos( infos )
		-- TODO
		--[[
		if not Equipments.get( "PARROT", status.id ) then
			-- Add the Parrot device to discovered devices
			DiscoveredEquipments.add( "PARROT", status.id, nil, nil, { infoType = "0" }, "state", ( ( status.action == "1" ) and "ON" or "OFF" ), nil, status.reminder )
		end
		--]]
	end,

	pcall = function( method, ... )
		local isOk, result = pcall( method, unpack(arg) )
		if not isOk then
			error( "Error: " .. tostring( result ), "Tools.pcall" )
		end
		return isOk, result
	end,

	getSettings = function( encodedSettings )
		local settings = {}
		for _, encodedSetting in ipairs( string_split( encodedSettings or "", "," ) ) do
			local settingName, operator, value = string.match( encodedSetting, "([^=]*)(=?)(.*)" )
			if not string_isEmpty( settingName ) then
				-- Backward compatibility
				if ( settingName == "pulse" ) then
					settingName = "momentary"
				end
				if ( operator == "=" ) then
					value = tonumber(value) or value or ""
				else
					value = true
				end
				settings[ settingName ] = value
			end
		end
		return settings
	end

}


-- **************************************************
-- Association
-- **************************************************

Association = {
	-- Get association of a device
	get = function( deviceId )
		local association = {}
		local encodedAssociations = string_split( Variable.get( deviceId, "ASSOCIATION" ) or "", "," )
		for _, encodedAssociation in pairs( encodedAssociations ) do
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
					if luup.scenes[ linkedId ] then
						if ( association.scenes == nil ) then
							association.scenes = { {}, {} }
						end
						table.insert( association.scenes[ level ], linkedId )
					else
						error( "Associated scene #" .. tostring( linkedId ) .. " is unknown for device #" .. tostring(deviceId), "Association.get" )
					end
				elseif isEquipment then
					if luup.devices[ linkedId ] then
						if ( association.equipments == nil ) then
							association.equipments = { {}, {} }
						end
						table.insert( association.equipments[ level ], linkedId )
					else
						error( "Associated equipment #" .. tostring( linkedId ) .. " is unknown for device #" .. tostring(deviceId), "Association.get" )
					end
				else
					if luup.devices[ linkedId ] then
						if ( association.devices == nil ) then
							association.devices = { {}, {} }
						end
						table.insert( association.devices[ level ], linkedId )
					else
						error( "Associated device #" .. tostring( linkedId ) .. " is unknown for device #" .. tostring(deviceId), "Association.get" )
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
local _indexDiscoveredEquipmentsByProtocolEquipmentId = {}
local _indexDiscoveredEquipmentsByProtocolAddress = {}

DiscoveredEquipments = {

	add = function( protocol, equipmentId, address, endpointId, infos, featureName, data, unit, comment )
		local hasBeenAdded = false
		if ( string_isEmpty(equipmentId) and string_isEmpty(address) ) then
			error( "equipmentId or address has to be set", "DiscoveredEquipments.add" )
			return false
		end
		local discoveredEquipment
		if not string_isEmpty(equipmentId) then
			discoveredEquipment = _indexDiscoveredEquipmentsByProtocolEquipmentId[ protocol .. ";" .. equipmentId ]
		elseif not string_isEmpty(address) then
			discoveredEquipment = _indexDiscoveredEquipmentsByProtocolAddress[ protocol .. ";" .. address ]
		end
		-- Add discovered equipment if not already known
		if ( discoveredEquipment == nil ) then
			discoveredEquipment = {
				protocol = protocol,
				frequency = infos.frequency,
				comment = comment,
				capabilities = {}
			}
			table.insert( _discoveredEquipments, discoveredEquipment )
			if not string_isEmpty(equipmentId) then
				discoveredEquipment.id = equipmentId
				_indexDiscoveredEquipmentsByProtocolEquipmentId[ protocol .. ";" .. equipmentId ] = discoveredEquipment
			end
			if not string_isEmpty(address) then
				discoveredEquipment.address = address
				_indexDiscoveredEquipmentsByProtocolAddress[ protocol .. ";" .. address ] = discoveredEquipment
			end
			hasBeenAdded = true
			debug( "New discovered equipment " .. Tools.getEquipmentSummary(discoveredEquipment), "DiscoveredEquipments.add" )
		end
		discoveredEquipment.quality = tonumber( infos.quality )

		-- Capability
		local isFeatureKnown, hasCapabilityBeenAdded = false, false
		if infos.capability then
			local capabilityName = ( not string_isEmpty(endpointId) and ( endpointId .. "-" ) or "" ) .. ( infos.capability.name or "Unknown" )
			local capability = discoveredEquipment.capabilities[ capabilityName ]
			if ( capability == nil ) then
				capability = {
					name = capabilityName,
					endpointId = endpointId,
					modelings = table_extend( {}, infos.capability.modelings ) -- Clone the modelings
				}
				discoveredEquipment.capabilities[ capabilityName ] = capability
				hasCapabilityBeenAdded = true
			end

			-- Feature
			for _, modeling in ipairs( capability.modelings ) do
				for _, mapping in ipairs( modeling.mappings ) do
					local feature = mapping.features[ featureName ]
					if feature then
						-- This mapping contains our feature
						isFeatureKnown = true
						if mapping.deviceTypes then
							mapping.isUsed = true
							feature.data = data
							feature.unit = unit
							modeling.isUsed = true
						end
						-- The features are unique in each modeling
						break
					end
				end
			end
		end

		discoveredEquipment.lastUpdate = os.time()
		if hasBeenAdded then
			Variable.set( DEVICE_ID, "LAST_DISCOVERED", os.time() )
			UI.show( "New equipment discovered" )
		end
		if ( isFeatureKnown and hasCapabilityBeenAdded ) then
			debug( "Discovered equipment " .. Tools.getEquipmentSummary(discoveredEquipment) .. " has a new feature '" .. featureName .. "'", "DiscoveredEquipments.add" )
		end
		return hasBeenAdded, isFeatureKnown
	end,

	get = function( protocol, equipmentId )
		if ( not string_isEmpty(protocol) and not string_isEmpty(equipmentId) ) then
			local key = protocol .. ";" .. equipmentId
			return _indexDiscoveredEquipmentsByProtocolEquipmentId[ key ]
		else
			return _discoveredEquipments
		end
	end,

	remove = function( protocol, equipmentId )
		if ( ( protocol ~= nil ) and ( equipmentId ~= nil ) ) then
			local key = protocol .. ";" .. equipmentId
			local discoveredEquipment = _indexDiscoveredEquipmentsByProtocolEquipmentId[ key ]
			for i, equipment in ipairs( _discoveredEquipments ) do
				if ( equipment == discoveredEquipment ) then
					local address = equipment.address
					table.remove( _discoveredEquipments, i )
					_indexDiscoveredEquipmentsByProtocolEquipmentId[ key ] = nil
					if address then
						_indexDiscoveredEquipmentsByProtocolAddress[ protocol .. ";" .. address ] = nil
					end
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
local _indexEquipmentsByProtocolEquipmentId = {}
local _indexEquipmentsByProtocolAddress = {}
local _indexEquipmentsAndMappingsByDeviceId = {}
local _indexFeaturesAndDevicesByProtocolEquipmentIdAndFeatureEndpoint = {}
-- TODO : list device sinon crash

Equipments = {

	-- Get a list with all our child devices.
	retrieve = function()
		local formerEquipments = _equipments
		_equipments = {}
		Equipments.clearIndexes()
		for deviceId, luDevice in pairs( luup.devices ) do
			if ( luDevice.device_num_parent == DEVICE_ID ) then
				local protocol, equipmentId, deviceNum = unpack( string_split( luDevice.id or "", ";" ) )
				deviceNum = tonumber(deviceNum) or 1
				if ( ( protocol == nil ) or ( equipmentId == nil ) or ( deviceNum == nil ) ) then
					debug( "Found child device #".. tostring( deviceId ) .."(".. luDevice.description .."), but id '" .. tostring( luDevice.id ) .. "' does not match pattern '[0-9]+;[0-9]+;[0-9]+'", "Equipments.retrieve" )
				else
					-- Address
					local address = Variable.get( deviceId, "ADDRESS" )
					-- Endpoint
					local endpointId = Variable.get( deviceId, "ENDPOINT" )
					-- Features
					local featureNames = string_split( Variable.get( deviceId, "FEATURE" ) or "default", "," )
					-- Settings
					local settings = Tools.getSettings( Variable.get( deviceId, "SETTING" ) )
					-- Backward compatibility
					if settings.button then
						settings.transmitter = true
						settings.button = nil
					end
					-- Association
					association = Association.get( deviceId )
					-- Add the device
					Equipments.add( protocol, equipmentId, address, endpointId, featureNames, deviceNum, luDevice.device_type, deviceId, luDevice.room_num, settings, association, false )
				end
			end
		end

		-- Retrieve former data
		for _, formerEquipment in ipairs( formerEquipments ) do
			local equipment = Equipments.get( formerEquipment.protocol, formerEquipment.id, formerEquipment.address )
			if ( equipment ) then
				-- This former equipment has been retrieved
				formerEquipment.lastUpdate = equipment.lastUpdate
				for _, formerMapping in ipairs( formerEquipment.mappings ) do
					for _, formerFeature in ipairs( formerMapping.features ) do
						local _, feature, devices = Equipments.get( formerEquipment.protocol, formerEquipment.id, formerEquipment.address, formerMapping.endpointId, formerFeature.featureName )
						if feature then
							feature.data = formerFeature.data
							feature.lastUpdate = formerFeature.lastUpdate
						end
					end
				end
			elseif ( formerEquipment.isNew ) then
				-- Add newly created Equipment (not present in luup.devices until a reload of the luup engine)
				table.insert( _equipments, formerEquipment )
				-- Add to indexes
				Equipments.addToIndexes( formerEquipment )
			end
		end
		formerEquipments = nil

		log("Found " .. tostring(#_equipments) .. " equipment(s)", "Equipments.retrieve")
	end,

	-- Add a device
	add = function( protocol, equipmentId, address, endpointId, featureNames, deviceNum, deviceType, deviceId, deviceRoomId, settings, association, isNew )
		local key = tostring(protocol) .. ";" .. tostring(equipmentId)
		local deviceInfos = Device.getInfos( deviceId )
		local deviceTypeName = deviceInfos and deviceInfos.name or "unknown"
		debug( "Add equipment " .. Tools.getEquipmentInfo( protocol, equipmentId, address, endpointId, featureNames, deviceId ) .. ",(deviceNum:" .. tostring(deviceNum) .. ",(type:" .. deviceTypeName .. ")", "Equipments.add" )
		local device = {
			id = deviceId,
			settings = settings or {},
			association = association or {}
		}
		local equipment = _indexEquipmentsByProtocolEquipmentId[ key ]
		if ( equipment == nil ) then
			equipment = {
				protocol = protocol,
				id = equipmentId,
				address = address,
				frequency = -1,
				quality = -1,
				mappings = {},
				maxDeviceNum = 0
			}
			if isNew then
				equipment.isNew = true
			end
			table.insert( _equipments, equipment )
		end
		-- TODO : control num
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
		local _, mapping = Equipments.getFromDeviceId( deviceId, true )
		if ( mapping == nil ) then
			-- Device not already mapped
			mapping = {
				endpointId = endpointId,
				features = {},
				device = device
			}
			table.insert( equipment.mappings, mapping )
		end
		-- Features
		for _, featureName in ipairs( featureNames ) do
			local _, feature = Equipments.get( protocol, equipmentId, address, endpointId, featureName )
			if ( feature == nil ) then
				feature = {
					name = featureName
				}
			end
			mapping.features[featureName] = feature
		end
		-- Add to indexes
		Equipments.addToIndexes( equipment )
	end,

	clearIndexes = function()
		_indexEquipmentsByProtocolEquipmentId = {}
		_indexEquipmentsByProtocolAddress = {}
		_indexEquipmentsAndMappingsByDeviceId = {}
		_indexFeaturesAndDevicesByProtocolEquipmentIdAndFeatureEndpoint = {}
	end,

	addToIndexes = function( equipment )
		local key = tostring(equipment.protocol) .. ";" .. tostring(equipment.id)
		if ( _indexEquipmentsByProtocolEquipmentId[ key ] == nil ) then
			_indexEquipmentsByProtocolEquipmentId[ key ] = equipment
		end
		if ( equipment.address and ( _indexEquipmentsByProtocolAddress[ tostring(equipment.protocol) .. ";" .. tostring(equipment.address) ] == nil ) ) then
			_indexEquipmentsByProtocolAddress[ tostring(equipment.protocol) .. ";" .. tostring(equipment.address) ] = equipment
		end
		if ( _indexFeaturesAndDevicesByProtocolEquipmentIdAndFeatureEndpoint[ key ] == nil ) then
			_indexFeaturesAndDevicesByProtocolEquipmentIdAndFeatureEndpoint[ key ] = {}
		end
		for _, mapping in ipairs( equipment.mappings ) do
			if ( _indexEquipmentsAndMappingsByDeviceId[ tostring( mapping.device.id ) ] == nil ) then
				for featureName, feature in pairs( mapping.features ) do
					local _indexFeaturesAndDevicesFromIdAndFeatureByEndpoint = _indexFeaturesAndDevicesByProtocolEquipmentIdAndFeatureEndpoint[ key ][ featureName ]
					if ( _indexFeaturesAndDevicesFromIdAndFeatureByEndpoint == nil ) then
						_indexFeaturesAndDevicesByProtocolEquipmentIdAndFeatureEndpoint[ key ][ featureName ] = {}
						_indexFeaturesAndDevicesFromIdAndFeatureByEndpoint = _indexFeaturesAndDevicesByProtocolEquipmentIdAndFeatureEndpoint[ key ][ featureName ]
					end
					local endpointId = string_isEmpty(mapping.endpointId) and "none" or mapping.endpointId
					if ( _indexFeaturesAndDevicesFromIdAndFeatureByEndpoint[ endpointId ] == nil ) then
						_indexFeaturesAndDevicesFromIdAndFeatureByEndpoint[ endpointId ] = { feature, {} }
					end
					table.insert( _indexFeaturesAndDevicesFromIdAndFeatureByEndpoint[ endpointId ][ 2 ], mapping.device )
				end
				_indexEquipmentsAndMappingsByDeviceId[ tostring( mapping.device.id ) ] = { equipment, mapping }
			end
		end
	end,

	get = function( protocol, equipmentId, address, endpointId, featureName )
		if not string_isEmpty(protocol) then
			local equipment
			if not string_isEmpty(equipmentId) then
				equipment = _indexEquipmentsByProtocolEquipmentId[ protocol .. ";" .. equipmentId ]
			elseif not string_isEmpty(address) then
				equipment = _indexEquipmentsByProtocolAddress[ protocol .. ";" .. address ]
			end
			if ( ( equipment ~= nil ) and featureName ) then
				local key = tostring(protocol) .. ";" .. tostring(equipment.id)
				local _indexFeaturesAndDevicesFromIdAndFeatureByEndpoint = _indexFeaturesAndDevicesByProtocolEquipmentIdAndFeatureEndpoint[ key ][ tostring(featureName) ]
				if _indexFeaturesAndDevicesFromIdAndFeatureByEndpoint then
					local feature, devices
					if ( endpointId == "all" ) then
						-- Used during broadcast
						-- TODO : get all the endpoints and not just the first for this feature name
						for endpointId, featureAndDevices in pairs(_indexFeaturesAndDevicesFromIdAndFeatureByEndpoint) do
							feature, devices = unpack( featureAndDevices )
							break
						end
					else
						endpointId = string_isEmpty(endpointId) and "none" or endpointId
						feature, devices = unpack( _indexFeaturesAndDevicesFromIdAndFeatureByEndpoint[ endpointId ] or {} )
					end
					if ( feature ~= nil ) then
						return equipment, feature, devices
					end
				end
			end
			return equipment
		else
			return _equipments
		end
	end,

	getFromDeviceId = function( deviceId, noWarningIfUnknown )
		local equipment, mapping = unpack( _indexEquipmentsAndMappingsByDeviceId[ tostring( deviceId ) ] or {} )
		if mapping then
			return equipment, mapping
		elseif ( noWarningIfUnknown ~= true ) then
			warning( "Equipment with deviceId #" .. tostring( deviceId ) .. "' is unknown", "Equipments.getFromDeviceId" )
		end
		return nil
	end,

	changeAddress = function( equipment, newAddress )
		local formerAddress = equipment.address
		debug( "Change address of " .. Tools.getEquipmentSummary(equipment) .. " to " .. tostring(newAddress), "Equipments.changeAddress" )
		for _, mapping in ipairs( equipment.mappings ) do
			Variable.set( mapping.device.id, "ADDRESS", newAddress )
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
		local loadLevel = tonumber(loadLevel) or 0
		if ( equipment.protocol == "RTS" ) then
			if ( loadLevel == 0 ) then
				Equipment.setStatus( equipment, "0", parameters )
				return true
			elseif ( loadLevel == 100 ) then
				Equipment.setStatus( equipment, "1", parameters )
				return true
			else
				error( "RTS equipment does not support DIM", "Equipment.setLoadLevel" )
				return false
			end
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
				local baudRate = Variable.get( ioDevice, "BAUD" ) or "9600"
				log( "Baud rate is " .. baudRate, "SerialConnection.isValid" )
				if ( baudRate ~= _SERIAL.baudRate ) then
					error( "Incorrect setup of the serial port. Select " .. _SERIAL.baudRate .. " bauds.", "SerialConnection.isValid", false )
					UI.showError( "Select " .. _SERIAL.baudRate .. " bauds for the Serial Port" )
					return false
				end
				

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

local REQUEST_TYPE = {
	["default"] = function( params, outputFormat )
		return "Unknown command '" .. tostring( params["command"] ) .. "'", "text/plain"
	end,

	["getEquipmentsInfos"] = function( params, outputFormat )
		result = { equipments = Equipments.get(), discoveredEquipments = DiscoveredEquipments.get() }
		return tostring( json.encode( result ) ), "application/json"
	end,

	["getProtocolsInfos"] = function( params, outputFormat )
		return tostring( json.encode( VIRTUAL_EQUIPMENT ) ), "application/json"
	end,

	["getSettings"] = function( params, outputFormat )
		return tostring( json.encode( SETTINGS ) ), "application/json"
	end,

	["getErrors"] = function( params, outputFormat )
		return tostring( json.encode( _errors ) ), "application/json"
	end
}
setmetatable( REQUEST_TYPE, {
	__index = function( t, command, outputFormat )
		log( "No handler for command '" ..  tostring(command) .. "'", "handler" )
		return REQUEST_TYPE["default"]
	end
})

local function _handleRequest( lul_request, lul_parameters, lul_outputformat )
	local command = lul_parameters["command"] or "default"
	--debug( "Get handler for command '" .. tostring(command) .."'", "handleRequest" )
	return REQUEST_TYPE[command]( lul_parameters, lul_outputformat )
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
		debug( "Refresh equipments", "Main.refresh" )
		Equipments.retrieve()
	end,

	-- Creates devices linked to equipements
	createDevices = function( jsonMappings )
		local decodeSuccess, mappings, _, jsonError = pcall( json.decode, string_decodeURI(jsonMappings) )
		if ( decodeSuccess and mappings ) then
			debug( "Create devices " .. json.encode(mappings), "Main.createDevices" )
		else
			error( "JSON error: " .. tostring( jsonError ), "Main.createDevices" )
			return
		end
		local hasBeenCreated = false
		local roomId = luup.devices[ DEVICE_ID ].room_num or 0
		for _, mapping in ipairs( mappings ) do
			if ( string_isEmpty( mapping.protocol ) or string_isEmpty( mapping.equipmentId ) or string_isEmpty( mapping.deviceType ) ) then
				error( "'protocol', 'equipmentId' or 'deviceType' can not be empty in " .. json.encode(mapping), "Main.createDevices" )
			else
				local msg = "Equipment " .. Tools.getEquipmentInfo( mapping.protocol, mapping.equipmentId, mapping.address, mapping.endpointId, mapping.featureNames )
				local deviceInfos = Device.getInfos( mapping.deviceType or "BINARY_LIGHT" )
				if not deviceInfos then
					error( msg .. " - Device infos are missing", "Main.createDevices" )
				elseif not Device.fileExists( deviceInfos ) then
					error( msg .. " - Definition file for device type '" .. deviceInfos.name .. "' is missing", "Main.createDevices" )
				else
					-- Compute device number (critical)
					local deviceNum = 1
					local equipment = Equipments.get( mapping.protocol, mapping.equipmentId )
					if equipment then
						debug( msg .. " already exists", "Main.createDevices" )
						deviceNum = equipment.maxDeviceNum + 1
					end
					-- Device name
					local deviceName = mapping.deviceName or ( mapping.protocol .. "-" .. mapping.equipmentId .. "/" .. tostring(deviceNum) )
					-- Device parameters
					local parameters = Device.getEncodedParameters( deviceInfos )
					parameters = parameters .. Variable.getEncodedValue( "ADDRESS", mapping.address ) .. "\n"
					parameters = parameters .. Variable.getEncodedValue( "ENDPOINT", mapping.endpointId ) .. "\n"
					parameters = parameters .. Variable.getEncodedValue( "FEATURE", table.concat( mapping.featureNames or {}, "," ) ) .. "\n"
					parameters = parameters .. Variable.getEncodedValue( "ASSOCIATION", "" ) .. "\n"
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
					local internalId = mapping.protocol .. ";" .. mapping.equipmentId .. ";" .. tostring(deviceNum)
					debug( msg .. " - Add device '" .. internalId .. "', type '" .. deviceInfos.name .. "', file '" .. deviceInfos.file .. "'", "Main.createDevices" )
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
					debug( msg .. " - Device #" .. tostring(newDeviceId) .. "(" .. deviceName .. ") has been created", "Main.createDevices" )
					hasBeenCreated = true

					-- Add or update linked equipment
					Equipments.add( mapping.protocol, mapping.equipmentId, mapping.address, mapping.endpointId, mapping.featureNames or {}, deviceNum, nil, newDeviceId, roomId, nil, nil, true )
					-- Remove from discovered equipments
					DiscoveredEquipments.remove( mapping.protocol, mapping.equipmentId )
				end
			end
		end

		if hasBeenCreated then
			Equipments.retrieve()
			Variable.set( DEVICE_ID, "LAST_UPDATE", os.time() )
		end

	end,

	-- Teach a receiver (or Parrot). This is done on an unknown device (it will be created)
	teachIn = function( protocol, equipmentId, settings, action, comment )
		equipmentId = tonumber(equipmentId)
		if ( ( protocol == nil ) or ( equipmentId == nil ) ) then
			error( "Protocol and equipment id are mandatory", "Main.teachIn" )
			return JOB_STATUS.ERROR
		end
		settings = Tools.getSettings( string_decodeURI( settings ) )
		if ( protocol == "PARROT" ) then
			-- PARROTLEARN
			if ( ( equipmentId < 0 ) or ( equipmentId > 239 ) ) then
				error( "Id of the Parrot device " .. tostring(equipmentId) .. " is not between 0 and 239", "Main.teachIn" )
				return JOB_STATUS.ERROR, nil
			end
			action = ( action == "OFF" ) and "OFF" or "ON"
			debug( "Start Parrot learning for #" .. tostring(equipmentId) .. ", action " .. action .. " and reminder '" .. tostring(comment) .. "'", "Main.teachIn" )
			Network.send( "ZIA++PARROTLEARN ID " .. tostring(equipmentId) .. " " .. action .. ( comment and ( " [" .. tostring(comment) .. "]" ) or "" ) )
		elseif ( protocol == "EDISIO" ) then
			
		else
			if ( ( equipmentId < 0 ) or ( equipmentId > 255 ) ) then
				error( "Id of the device " .. tostring(equipmentId) .. " is not between 0 and 255", "Main.teachIn" )
				return JOB_STATUS.ERROR, nil
			end
			debug( "Teach in " .. protocol .. ";" .. equipmentId .. " with " .. json.encode(settings), "Main.teachIn" )
			Network.send( "ZIA++ASSOC ID " .. tostring(equipmentId) .. " " .. protocol .. ( settings.qualifier and ( " QUALIFIER " .. tostring(settings.qualifier) ) or "" ) )
		end
	end,

	setTarget = function( protocol, equipmentId, settings, newTargetValue )
		if ( ( protocol == nil ) or ( equipmentId == nil ) ) then
			error( "Protocol and equipment id are mandatory", "Main.setTarget" )
			return JOB_STATUS.ERROR
		end
		settings = Tools.getSettings( string_decodeURI( settings ) )
		local cmd = ( newTargetValue == "1" ) and "ON" or "OFF"
		debug( "Set " .. cmd .. " for " .. protocol .. ";" .. equipmentId .. " with " .. json.encode(settings), "Main.setTarget" )
		Network.send( "ZIA++" .. cmd .. " ID " .. tostring(equipmentId) .. " " .. tostring(protocol) .. ( settings.qualifier and ( " QUALIFIER " .. tostring(settings.qualifier) ) or "" ) )
	end,

	setParam = function( paramName, paramValue )
		debug( "Set param '" .. tostring(paramName) .. "' to '" .. tostring(paramValue) .. "'", "Main.setParam" )
		if ( paramName == "system.jamming" ) then
			Network.send( "ZIA++JAMMING " .. tostring(paramValue) )
			Network.send( "ZIA++STATUS SYSTEM JSON" )
		end
	end,

	-- Simulate a jamming
	simulateJamming = function( delay )
		local delay = tostring(delay or 5)
		debug( "Simulate jamming during " .. delay .. " seconds", "Main.simulateJamming")
		Network.send( "ZIA++JAMMING SIMULATE " .. delay )
	end,

	-- DEBUG METHOD
	sendMessage = function( message )
		debug( "Send message: " .. tostring(message), "Main.sendMessage" )
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
		Equipments.retrieve()

		-- Open the connection with the RFP1000
		Network.send( "ZIA++HELLO" )
		Network.send( "ZIA++FORMAT JSON" )

		-- Get the system statuses
		Network.send( "ZIA++STATUS SYSTEM JSON" )
		Network.send( "ZIA++STATUS RADIO JSON" )
		--Network.send( "WAIT" )
		Network.send( "ZIA++STATUS PARROT JSON" )

		--Network.send( "ZIA++EDISIOFRAME" )

		-- Start polling engine
		PollEngine.start()
	end

	-- Watch setting changes
	Variable.watch( DEVICE_ID, VARIABLE.DEBUG_MODE, _NAME .. ".initPluginInstance" )

	-- HTTP requests handler
	log( "Register handler " .. _NAME, "init" )
	luup.register_handler( _NAME .. ".handleRequest", _NAME )

	-- Register with ALTUI
	luup.call_delay( _NAME .. ".registerWithALTUI", 10 )

	if ( luup.version_major >= 7 ) then
		luup.set_failure( 0, DEVICE_ID )
	end

	log( "Startup successful", "init" )
	return true, "Startup successful", _NAME
end


-- Promote the functions used by Vera's luup.xxx functions to the global name space
_G[_NAME .. ".handleRequest"] = _handleRequest
_G[_NAME .. ".Commands.deferredProcess"] = Commands.deferredProcess
_G[_NAME .. ".Device.setStatusAfterTimeout"] = Device.setStatusAfterTimeout
_G[_NAME .. ".Device.setTrippedAfterTimeout"] = Device.setTrippedAfterTimeout
_G[_NAME .. ".Network.send"] = Network.send
_G[_NAME .. ".Network.flush"] = Network.flush
_G[_NAME .. ".PollEngine.poll"] = PollEngine.poll

_G[_NAME .. ".initPluginInstance"] = _initPluginInstance
_G[_NAME .. ".registerWithALTUI"] = _registerWithALTUI
