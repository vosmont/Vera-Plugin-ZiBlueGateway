Utils.initTokens( {
	"ziblue_donate": "This plugin is free but if you install and find it useful, then a donation to support further development is greatly appreciated.",
	"ziblue_loading": "Loading...",
	"ziblue_reload_has_to_be_done": "The changes made won't be visible until a reload of the Luup engine. You can decide to continue without reloading.",

	"ziblue_help": "Help",
	"ziblue_refresh": "Refresh",
	"ziblue_add": "Add",
	"ziblue_learn": "Learn",
	"ziblue_cancel": "Cancel",
	"ziblue_confirm": "Confirm",
	"ziblue_room": "Room",
	"ziblue_protocol": "Protocol",
	"ziblue_select_protocol": "Select a protocol",
	"ziblue_signal_quality": "Signal<br/>quality",
	"ziblue_feature": "Feature",
	"ziblue_equipment": "Equipment",
	"ziblue_equipment_name": "Equipment's name",
	"ziblue_enter_name": "Enter the name",
	"ziblue_id": "Id",
	"ziblue_enter_id": "Enter the id [0-255]",
	"ziblue_device": "Linked device",
	"ziblue_device_type": "Linked device type",
	"ziblue_select_device_type": "Select a device type",
	"ziblue_association": "Association",
	"ziblue_param": "Settings",
	"ziblue_action": "Action",
	"ziblue_last_update": "Last update",
	"ziblue_communication_error": "Communication error",

	// Settings
	"ziblue_tab_settings": "ZiBlue Settings",
	"ziblue_explanation_plugin_settings": "This tab displays the ZiBlue dongle settings, read-only.<br/><br/>\
	To be able to modify them, you have 2 possibilities :<br/>\
	<ul>\
	<li>Use the ZiBlue's <a href=\"http://rfplayer.com/en/download\">configurator</a></li>\
	<li>Use the \"SendMessage\" command of the plugin and send a command to the ZiBLue dongle. You will need to know what commands are available by contacting ZiBlue.</li>\
	</ul>",
	"ziblue_plugin_settings": "ZiBlue Settings",

	// New equipment
	"ziblue_tab_new_equipment": "New equipment",
	"ziblue_add_new_equipment": "Add a new equipment",
	"ziblue_add_new_equipment_step": "Step {0}",
	"ziblue_add_new_equipment_settings_title": "Settings",
	"ziblue_add_new_equipment_teach_title": "Teach",
	"ziblue_add_new_dequipment_teach_explanation": "Depending on the receiver/actuator, the 'teach in' process can differ. First, put the receiver in learning mode, then click on the button 'Teach' (you may have just 10 seconds).",
	"ziblue_add_new_equipment_teach_parrot_explanation": "Press the button 'Teach' to make the dongle enters into 'capture mode'. Place the transmitter to learn at 2-3m and force it to emit frames.<br/>Decrease gradually the distance if no effect. Too near device will give bad results.<br/>The frame must be captured 2 times (1: Low frequency blue blinking then 2: High frequency blue blinking ; Good comparison: PINK Lighting, bad comparison: RED lighting).",
	"ziblue_add_new_equipment_test_title": "Test",
	"ziblue_add_new_equipment_test_explanation": "You can use 'ON' and 'OFF' buttons to test that the learning is correct.",
	"ziblue_add_new_equipment_validate_title": "Validate",
	"ziblue_add_new_equipment_validate_explanation": "If everything is OK, you can validate by creating the new device (virtual emitter).",
	"ziblue_warning_teach_in_not_done": "The teaching in of the receiver has not been done. Do you want to continue to create the new device ?",
	"ziblue_teach": "Teach",
	"ziblue_create": "Create",
	"ziblue_device_has_been_created": "The device has been created.",

	// Managed equipments
	"ziblue_tab_managed_equipments": "Managed equipments",
	"ziblue_managed_equipments": "Managed equipments",
	"ziblue_explanation_known_equipments": "This tab displays the ZiBlue equipments, known to the home automation system, and their associated devices.<br/><br/>\
	Each associated device is managed directly by the home automation system as a standard device : for any standard action (like adding to scenarios, renaming, or even deleting), you can find it on the standard user interface.<br/><br/>\
	You can access the specific parameters/actions by clicking on the dedicated button <i class=\"fa fa-caret-down fa-lg\" aria-hidden=\"true\"></i>.",
	"ziblue_no_equipment": "There's no equipment.",
	"ziblue_explanation_association": "This panel displays the associations between the device associated with the equipment and devices or scenarios on the home automation system.<br/>\
	It is a facility proposed by the plugin, which allows you to simply perform actions in response to a device state change, without having to create a scenario.<br/><br/>\
	For example, the activation of a remote control can turn on an outlet managed by the home automation system.",
	"ziblue_explanation_param": "This panel displays the parameters (specific to the plugin) of the device associated with an equipment.<br/><br/>\
	<b>Transmitter:</b> Checked if the device represents a transmitter equipment (e.g. a remote).<br/>\
	The behavior of the linked device can be adjusted with the parameters \"Pulse\" or \"Toggle\"<br/><br/>\
	<b>Receiver:</b> Checked if the device represents a receiver/actuator equipment (e.g. an outlet).<br/>\
	In this case the device is seen as a virtual transmitter equipment and must be associated with the receiver equipment to be able to control it.<br/>\
	Normally this action was done when creating the device from the \"New equipment\" tab, otherwise it can be done from the functions button in the \"Managed equipments\" tab.<br/>\
	For more information on \"Qualify\" or \"Burst\" parameters, refer to the ZiBlue dongle manual.",
	"ziblue_confirmation_teach_in_receiver": "Please put the receiver/actuator equipment in learning mode so that you can associate your virtual equipment with it.",

	// Discovered equipments
	"ziblue_tab_discovered_equipments": "Discovered equipments",
	"ziblue_discovered_equipments": "Discovered equipments",
	"ziblue_explanation_discovered_equipments": "This tab displays the equipments exposed by the ZiBlue dongle and not yet known from the home automation system.<br/><br\>\
	<b>Equipment:</b> a device exposed by the ZiBlue dongle. For example, a 433 MHz temperature probe.<br\>\
	<b>Device:</b> a device managed by the home automation system. For example, a Zwave motion detector.<br\><br\>\
	To be able to use the equipments on the home automation system, you have to :<br/>\
	<ul>\
	<li>select a modeling (definition of the relationships between equipment and devices, by features).</li>\
	<li>the type of device can sometimes be chosen: this will not change the functionality but its representation in the user interface.</li>\
	<li>have the system learn this modeling.</li>\
	</ul>\
	For example, an equipment measuring temperature and humidity will be associated with 2 devices on the system: a temperature sensor and a humidity sensor.",
	"ziblue_no_discovered_equipment": "There's no discovered equipment.",
	"ziblue_select_equipment": "You have to select the equipment(s) you want to learn.",
	"ziblue_confirmation_learning_equipments": "Confirmation for learning the equipments.",
	"ziblue_devices_have_been_created": "The devices have been created.",

	// Errors
	"ziblue_tab_errors": "Errors",
	"ziblue_errors": "Errors",
	"ziblue_explanation_errors": "This tab displays the last errors encountered by the plugin.",
	"ziblue_no_error": "There's no error.",

	// Device types
	"urn:antor-fr:device:PilotWire:1": "Pilot wire",
	"urn:schemas-micasaverde-com:device:BarometerSensor:1": "Barometer sensor",
	"urn:schemas-micasaverde-com:device:DoorSensor:1": "Door Sensor",
	"urn:schemas-micasaverde-com:device:HumiditySensor:1": "Humidity sensor",
	"urn:schemas-micasaverde-com:device:LightSensor:1": "Light sensor",
	"urn:schemas-micasaverde-com:device:MotionSensor:1": "Motion Sensor",
	"urn:schemas-micasaverde-com:device:PowerMeter:1": "Power meter",
	"urn:schemas-micasaverde-com:device:SceneController:1": "Scene Controller",
	"urn:schemas-micasaverde-com:device:TemperatureSensor:1": "Temperature sensor",
	"urn:schemas-micasaverde-com:device:WindowCovering:1": "Window covering",
	"urn:schemas-upnp-org:device:BinaryLight:1": "On/Off Switch",
	"urn:schemas-upnp-org:device:DimmableLight:1": "Dimmable Switch",
	"urn:schemas-upnp-org:device:DimmableRGBLight:1": "Dimmable RGB",
	"urn:schemas-upnp-org:device:Heater:1": "Heater",
	"urn:schemas-upnp-org:device:HVAC_ZoneThermostat:1": "Thermostat"
} );