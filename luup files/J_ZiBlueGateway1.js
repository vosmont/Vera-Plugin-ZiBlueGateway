//# sourceURL=J_ZiBlueGateway1.js

/**
 * This file is part of the plugin ZiBlueGateway.
 * https://github.com/vosmont/Vera-Plugin-ZiBlueGateway
 * Copyright (c) 2017 Vincent OSMONT
 * This code is released under the MIT License, see LICENSE.
 */


/**
 * UI7 enhancement
 */
( function( $ ) {
	// UI7 fix
	Utils.getDataRequestURL = function() {
		var dataRequestURL = api.getDataRequestURL();
		if ( dataRequestURL.indexOf( "?" ) === -1 ) {
			dataRequestURL += "?";
		}
		return dataRequestURL;
	};
	// Custom CSS injection
	Utils.injectCustomCSS = function( nameSpace, css ) {
		if ( $( "#custom-css-" + nameSpace ).size() === 0 ) {
			Utils.logDebug( "Injects custom CSS for " + nameSpace );
			var pluginStyle = $( '<style id="custom-css-' + nameSpace + '">' );
			pluginStyle
				.text( css )
				.appendTo( "head" );
		} else {
			Utils.logDebug( "Injection of custom CSS has already been done for " + nameSpace );
		}
	};
	Utils.performActionOnDevice = function( deviceId, service, action, actionArguments ) {
		var d = $.Deferred();
		try {
			if ( $.isPlainObject( actionArguments ) ) {
				$.each( actionArguments, function( key, value ) {
					if ( !value ) {
						delete actionArguments[ key ];
					}
				});
			}
			api.performActionOnDevice( deviceId, service, action, {
				actionArguments: actionArguments,
				onSuccess: function( response ) {
					var result = JSON.parse( response.responseText );
					if ( !$.isPlainObject( result )
						|| !$.isPlainObject( result[ "u:" + action + "Response" ] )
						|| (
							( result[ "u:" + action + "Response" ].OK !== "OK" )
							&& ( typeof( result[ "u:" + action + "Response" ].JobID ) === "undefined" )
						)
					) {
						Utils.logError( "[Utils.performActionOnDevice] ERROR on action '" + action + "': " + response.responseText );
						d.reject();
					} else {
						d.resolve();
					}
				},
				onFailure: function( response ) {
					Utils.logDebug( "[Utils.performActionOnDevice] ERROR(" + response.status + "): " + response.responseText );
					d.reject();
				}
			} );
		} catch( err ) {
			Utils.logError( "[Utils.performActionOnDevice] ERROR: " + JSON.parse( err ) );
			d.reject();
		}
		return d.promise();
	};

	function getQueryStringValue( key ) {  
		return unescape(window.location.search.replace(new RegExp("^(?:.*[&\\?]" + escape(key).replace(/[\.\+\*]/g, "\\$&") + "(?:\\=([^&]*))?)?.*$", "i"), "$1"));  
	}
	Utils.getLanguage = function() {
		var language = getQueryStringValue( "lang_code" ) || getQueryStringValue( "lang" ) || window.navigator.userLanguage || window.navigator.language;
		return language.substring( 0, 2 );
	};

	Utils.initTokens = function( tokens ) {
		if ( window.Localization ) {
			window.Localization.init( tokens );
		} else if ( window.langJson ) {
			window.langJson.Tokens = $.extend( window.langJson.Tokens, tokens );
		}
	};

	var _resourceLoaded = {};
	Utils.loadResourcesAsync = function( fileNames ) {
		var d = $.Deferred();
		if ( typeof fileNames === 'string' ) {
			fileNames = [ fileNames ];
		}
		if ( !$.isArray( fileNames ) ) {
			return;
		}
		// Prepare loaders
		var loaders = [];
		$.each( fileNames, function( index, fileName ) {
			if ( !_resourceLoaded[ fileName ] ) {
				loaders.push(
					$.ajax( {
						url: (fileName.indexOf( "http" ) === 0 ? fileName: api.getDataRequestURL().replace( "/data_request", "" ) + '/' + fileName),
						dataType: "script",
						beforeSend: function( jqXHR, settings ) {
							jqXHR.fileName = fileName;
						}
					} )
				);
			}
		} );
		// Execute loaders
		$.when.apply( $, loaders )
			.done( function( xml, textStatus, jqxhr ) {
				if (loaders.length === 1) {
					_resourceLoaded[ jqxhr.fileName ] = true;
				} else if (loaders.length > 1) {
					// arguments : [ [ xml, textStatus, jqxhr ], ... ]
					for (var i = 0; i < arguments.length; i++) {
						jqxhr = arguments[ i ][ 2 ];
						_resourceLoaded[ jqxhr.fileName ] = true;
					}
				}
				d.resolve();
			} )
			.fail( function( jqxhr, textStatus, errorThrown  ) {
				Utils.logError( 'Load "' + jqxhr.fileName + '" : ' + textStatus + ' - ' + errorThrown );
				d.reject();
			} );
		return d.promise();
	};

	if ( !String.prototype.format ) {
		String.prototype.format = function() {
			var content = this;
			for (var i=0; i < arguments.length; i++) {
				var replacement = new RegExp('\\{' + i + '\\}', 'g');
				content = content.replace(replacement, arguments[i]);  
			}
			return content;
		};
	}

} ) ( jQuery );


/**
 * ALTUI fixes
 */
( function( $ ) {
	if ( window.Localization ) {
		Utils.getLangString = function( token, defaultValue ) { return _T(token) || defaultValue; };

		Utils.initTokens( {
			"ui7_device_type_temperature_sensor": "Temperature sensor",
			"ui7_device_type_humidity_sensor": "Hygrometry sensor",
			"ui7_device_type_barometer_sensor": "Barometer sensor",
			"ui7_device_type_power_meter": "Power Meter",
			"ui7_device_type_motion_sensor":  "Motion sensor",
			"ui7_device_type_door_sensor": "Door sensor",
			"ui7_device_type_smoke_sensor": "Smoke sensor",
			"ui7_device_type_binary_light": "Switch",
			"ui7_device_type_dimmable_light": "Dimmable Switch",
			"ui7_device_type_window_covering": "Window Covering"
		} );
	}
} ) ( jQuery );


/**
 * Localization
 */
( function( $ ) {
	Utils.loadResourcesAsync( 'J_ZiBlueGateway_loc_' + Utils.getLanguage() + '.js' )
		.fail( function() {
			Utils.loadResourcesAsync( 'J_ZiBlueGateway_loc_en.js' );
		});
} ) ( jQuery );


/**
 * Custom CSS
 * http://www.utf8icons.com/
 */
Utils.injectCustomCSS( "zibluegateway", '\
.zibluegateway-panel { position: relative; padding: 5px; }\
.zibluegateway-panel table { width: 100%; }\
.zibluegateway-panel th { text-align: center; background-color: #ccc; }\
.zibluegateway-panel td { padding: 5px; border: 1px solid #ccc; }\
.zibluegateway-panel label { font-weight: normal }\
.zibluegateway-panel button { display: inline-block; }\
.zibluegateway-panel button.highlighted { background: #006d46; color: #fff; }\
.zibluegateway-panel .icon { vertical-align: middle; }\
.zibluegateway-panel .icon.big { vertical-align: sub; }\
.zibluegateway-panel .icon:before { font-size: 15px; }\
.zibluegateway-panel .icon.big:before { font-size: 30px; }\
.zibluegateway-panel .icon-menu:before { content: "\\25BE"; }\
.zibluegateway-panel .icon-ok:before { content: "\\2713"; }\
.zibluegateway-panel .icon-help:before { content: "\\2753"; }\
.zibluegateway-panel .icon-cancel:before { content: "\\2718"; }\
.zibluegateway-panel .icon-teach:before { content: "\\270D"; }\
.zibluegateway-panel .icon-ignore:before { content: "\\2718"; }\
.zibluegateway-panel .icon-refresh:before { content: "\\267B"; }\
.zibluegateway-panel .icon-add:before { content: "\\271A"; }\
.zibluegateway-panel .icon-temperature:before { content: "\\2103"; }\
.zibluegateway-panel .icon-motion:before { content: "\\2103"; }\
.zibluegateway-panel .icon-door:before { content: "\\25AF"; }\
.zibluegateway-panel .icon-button:before { content: "\\25A3"; }\
.zibluegateway-panel .icon-light:before { content: "\\25CF"; }\
.zibluegateway-panel .icon-dimmable:before { content: "\\25D0"; }\
.zibluegateway-panel .icon-shutter:before { content: "\\25A4"; }\
.zibluegateway-hidden { display: none; }\
.zibluegateway-error { color:red; }\
.zibluegateway-header { margin: 10px; font-size: 1.1em; font-weight: bold; }\
.zibluegateway-explanation { margin: 5px; padding: 5px; border: 1px solid; background: #FFFF88}\
.zibluegateway-toolbar { height: 25px; text-align: right; margin: 5px; }\
.zibluegateway-association-room { font-weight: bold; width: 100%; background: #ccc; }\
div.zibluegateway-association { padding-left: 20px; }\
div.zibluegateway-association label span { padding: 4px 0 0 2px; }\
span.zibluegateway-association { margin-right: 5px; }\
span.zibluegateway-association span { padding: 1px; }\
.zibluegateway-association-device .ziblue-short-press { color: white; background: orange; border: 1px solid orange; }\
.zibluegateway-association-device .ziblue-long-press  { color: white; background: red; border: 1px solid red; }\
.zibluegateway-association-scene .ziblue-short-press  { color: white; background: blue; border: 1px solid blue; }\
.zibluegateway-association-scene .ziblue-long-press   { color: white; background: green; border: 1px solid green; }\
.zibluegateway-association-zibluedevice .ziblue-short-press  { color: white; background: purple; border: 1px solid purple; }\
.ziblue-short-press {}\
.ziblue-long-press { border: red; }\
.zibluegateway-device-channels { margin-left: 10px; }\
.zibluegateway-device-channel { padding-right: 5px; white-space: nowrap; }\
#zibluegateway-device-actions { position: absolute; background: #FFF; border: 2px solid #AAA; white-space: nowrap; }\
#zibluegateway-device-actions td { padding: 5px; }\
#zibluegateway-device-actions button { margin: 2px; }\
#zibluegateway-device-association {\
	position: absolute; top: 0px; left: 0px;\
	width: 100%;\
	background: #FFF; border: 2px solid #AAA;\
}\
#zibluegateway-device-params {\
	position: absolute; top: 0px; left: 0px;\
	width: 100%;\
	background: #FFF; border: 2px solid #AAA;\
}\
#zibluegateway-donate { text-align: center; width: 70%; margin: auto; }\
#zibluegateway-donate form { height: 50px; }\
.zibluegateway-feature-group td { border: 0 }\
.zibluegateway-setting { margin-top: 10px; border-radius: 25px; padding: 1px 25px; text-align: left; }\
.zibluegateway-setting span { display: inline-block; width: 30%; }');



var ZiBlueGateway = ( function( api, $ ) {
	var _uuid = "f3737884-38bd-4d9b-983d-3fafac1ce9b4";
	var ZIBLUEGATEWAY_SID = "urn:upnp-org:serviceId:ZiBlueGateway1";
	var ZIBLUEDEVICE_SID = "urn:upnp-org:serviceId:ZiBlueDevice1";
	var _deviceId = null;
	var _registerIsDone = false;
	var _lastUpdate = 0;
	var _indexFeatures = {};
	var _selectedProductId = "";
	var _selectedFeatureName = "";
	var _formerScrollTopPosition = 0;

	/**
	 * Get informations on ZiBlue devices
	 */
	function _getDevicesInfosAsync() {
		var d = $.Deferred();
		api.showLoadingOverlay();
		$.ajax( {
			url: Utils.getDataRequestURL() + "id=lr_ZiBlueGateway&command=getDevicesInfos&output_format=json#",
			dataType: "json"
		} )
		.done( function( devicesInfos ) {
			api.hideLoadingOverlay();
			if ( $.isPlainObject( devicesInfos ) ) {
				d.resolve( devicesInfos );
			} else {
				Utils.logError( "No devices infos" );
				d.reject();
			}
		} )
		.fail( function( jqxhr, textStatus, errorThrown ) {
			api.hideLoadingOverlay();
			Utils.logError( "Get ZiBlue devices infos error : " + errorThrown );
			d.reject();
		} );
		return d.promise();
	}

	/**
	 * Convert timestamp to locale string
	 */
	function _convertTimestampToLocaleString( timestamp ) {
		if ( typeof( timestamp ) === "undefined" ) {
			return "";
		}
		var t = new Date( parseInt( timestamp, 10 ) * 1000 );
		var localeString = t.toLocaleString();
		return localeString;
	}

	/**
	 * Callback on change in Vera devices
	 */
	function _onDeviceStatusChanged( deviceObjectFromLuStatus ) {
		if ( deviceObjectFromLuStatus.id == _deviceId ) {
			for ( i = 0; i < deviceObjectFromLuStatus.states.length; i++ ) {
				if ( deviceObjectFromLuStatus.states[i].variable == "LastUpdate" ) {
					if ( _lastUpdate !== deviceObjectFromLuStatus.states[ i ].value ) {
						_lastUpdate = deviceObjectFromLuStatus.states[ i ].value;
						_drawDevicesList();
						_drawDiscoveredDevicesList();
					}
				} else if ( deviceObjectFromLuStatus.states[i].variable == "LastDiscovered" ) {
					// Show refresh button on the panel of discovered devices
					$( "#zibluegateway-discovered-panel .zibluegateway-refresh" ).css({ 'display': '' });
				}
			}
		}
	}

	function _showReload( message, onSuccess ) {
		var html = '<div id="zibluegateway-reload">'
			+			( message ? '<div>' + message + '</div>' : '' )
			+			'<div>' + Utils.getLangString( "ziblue_reload_has_to_be_done" ) + '</div>'
			+			'<div>'
			+				'<button type="button" class="zibluegateway-reload">Reload Luup engine</button>'
			+			'</div>'
			+		'</div>';
		api.ui.showMessagePopup( html, 0, 0, { onSuccess: onSuccess } );

		$( "#zibluegateway-reload" ).click( function() {
			$.when( api.luReload() )
				.done( function() {
					$( "#zibluegateway-reload" ).css({ "display": "none" });
				});
			$( this ).prop( "disabled", true );
		});
	}

	// *************************************************************************************************
	// ZiBlue devices
	// *************************************************************************************************

	/**
	 * Draw and manage ZiBlue device list
	 */
	function _drawDevicesList() {
		if ( $( "#zibluegateway-known-devices" ).length === 0 ) {
			return;
		}
		function _getAssociationHtml( associationType, association, level ) {
			if ( association && ( association[ level ].length > 0 ) ) {
				var pressType = "short";
				if ( level === 1 ) {
					pressType = "long";
				}
				return	'<span class="zibluegateway-association zibluegateway-association-' + associationType + '" title="' + associationType + ' associated with ' + pressType + ' press">'
					+		'<span class="ziblue-' + pressType + '-press">'
					+			association[ level ].join( "," )
					+		'</span>'
					+	'</span>';
			}
			return "";
		}
		_indexFeatures = {};
		$.when( _getDevicesInfosAsync() )
			.done( function( devicesInfos ) {
				if ( devicesInfos.devices.length > 0 ) {
					var html =	'<table><tr><th>Protocol</th><th>Id</th><th>Signal<br/>Quality</th><th>Feature</th><th>Device</th><th>Association</th><th>Action</th></tr>';
					$.each( devicesInfos.devices, function( i, device ) {
						var rowSpan = ( device.features.length > 1 ? ' rowspan="' + device.features.length + '"' : '' );
						html += '<tr>'
							+		'<td' + rowSpan + '>' + device.protocol + '</td>'
							+		'<td' + rowSpan + '>' + device.protocolDeviceId + '</td>'
							+		'<td' + rowSpan + '>' + ( device.rfQuality >= 0 ? device.rfQuality : '' ) + '</td>';
						var isFirstRow = true;

						device.features.sort( function( a, b ) {
							if ( a.deviceName < b.deviceName ) {
								return -1;
							} else if ( a.deviceName > b.deviceName ) {
								return 1;
							}
							return 0;
						} );

						var countDevices = {};
						$.each( device.features, function( i, feature ) {
							countDevices[ feature.deviceId.toString() ] = countDevices[ feature.deviceId.toString() ]  != null ? countDevices[ feature.deviceId.toString() ] + 1 : 1;
						} );

						var lastDeviceId = -1;
						var deviceRowSpan = '1';
						$.each( device.features, function( i, feature ) {
							var productId = device.protocol + ';' + device.protocolDeviceId;
							_indexFeatures[ productId + ';' + feature.name ] = feature;
							feature.settings = {};
							$.each( ( api.getDeviceStateVariable( feature.deviceId, "urn:upnp-org:serviceId:ZiBlueDevice1", "Setting", { dynamic: false } ) || "" ).split( "," ), function( i, settingName ) {
								feature.settings[ settingName ] = true;
							} );
							if ( !isFirstRow ) {
								html += '<tr>';
							}
							html +=	'<td>'
								//+		'<div class="zibluegateway-device-channel">'
								//
								+		'<div>' + feature.name + '</div>'
								+		( feature.comment ? '<div>' + feature.comment + '</div>' : '' )
								+		( feature.state ? '<div>' + feature.state + '</div>' : '' )
								+	'</td>';

							if ( feature.deviceId != lastDeviceId ) {
								lastDeviceId = feature.deviceId;
								deviceRowSpan = ' rowspan="' + countDevices[ feature.deviceId.toString() ] + '"';
								html +=	'<td' + deviceRowSpan +'>'
									//+			'<div class="zibluegateway-device-type">'
									+		'<div>' + feature.deviceName + ' (#' + feature.deviceId + ')</div>'
									+		'<div>'
									+				Utils.getLangString( feature.deviceTypeName )
									+				( device.isNew ? ' <span style="color:red">NEW</span>' : '' )
									+				( feature.settings['pulse'] ? ' PULSE' : '' )
									+				( feature.settings['toggle'] ? ' TOGGLE' : '' )
									+		'</div>'
									//+		'</div>'
									+	'</td>'
									+	'<td' + deviceRowSpan +'>'
									+		_getAssociationHtml( "device", feature.association.devices, 0 )
									//+		_getAssociationHtml( "device", feature.association.devices, 1 )
									+		_getAssociationHtml( "scene", feature.association.scenes, 0 )
									//+		_getAssociationHtml( "scene", feature.association.scenes, 1 )
									+	'</td' + deviceRowSpan +'>'
									+	'<td' + deviceRowSpan +' align="center">'
									+		( !device.isNew && ( feature.settings['button'] || feature.settings['receiver'] ) ?
												'<span class="zibluegateway-actions icon big icon-menu" data-product-id="' + productId + '" data-feature-name="' + feature.name + '"></span>' 
												: '' )
									+	'</td>';
							}

							html +=	'</tr>';
							isFirstRow = false;
						} );
					});
					html += '</table>';
					$("#zibluegateway-known-devices").html( html );
				} else {
					$("#zibluegateway-known-devices").html( Utils.getLangString( "ziblue_no_device" ) );
				}
			} );
	}

	/**
	 * Show the actions that can be done on a ZiBlue device
	 */
	function _showDeviceActions( position, settings ) {
		var html = '<table>'
				+		'<tr>'
				+			'<td>'
				+				( settings['button'] ?
								'<button type="button" class="zibluegateway-show-association">Associate</button>'
								: '')
				+				( settings['button'] || settings['receiver'] ?
								'<button type="button" class="zibluegateway-show-params">Params</button>'
								: '')
				+			'</td>';
		if ( settings['receiver'] ) {
			html +=			'<td bgcolor="#FF0000">'
				+				'<button type="button" class="zibluegateway-teach">Teach in</button>'
				//+				'<button type="button" class="zibluegateway-clear">Clear</button>'
				+			'</td>';
		}
		html +=			'</tr>'
			+		'</table>';
		var $actions = $( "#zibluegateway-device-actions" );
		$actions
			.html( html )
			.css( {
				"display": "block",
				"left": ( position.left - $actions.width() + 5 ),
				"top": ( position.top - $actions.height() / 2 )
			} );
	}

	/**
	 * Show all devices and scene that can be associated and manage associations
	 */
	function _showDeviceAssociation( productId, feature ) {
		var html = '<div class="zibluegateway-header">'
				+		'Association for ' + productId + ' - ' + feature.name + ' - ' + feature.deviceName + ' (#' + feature.deviceId + ')'
				+	'</div>'
				+	'<div class="zibluegateway-toolbar">'
				+		'<button type="button" class="zibluegateway-help"><span class="icon icon-help"></span>Help</button>'
				+	'</div>'
				+	'<div class="zibluegateway-explanation zibluegateway-hidden">'
				+		Utils.getLangString( "ziblue_explanation_association" )
				+	'</div>';

		// Get compatible devices
		var devices = [];
		$.each( api.getListOfDevices(), function( i, device ) {
			if ( device.id == feature.deviceId ) {
				return;
			}
			// Check if device is compatible
			var isCompatible = false;
			for ( var j = 0; j < device.states.length; j++ ) {
				if ( ( device.states[j].service === SWP_SID ) || ( device.states[j].service === SWD_SID ) ) {
					// Device can be switched or dimmed
					isCompatible = true;
					break;
				}
			}
			if ( !isCompatible ) {
				return;
			}
			// Check if device is an ziblue device
			var isZiBlue = false;
			for ( var j = 0; j < device.states.length; j++ ) {
				if ( device.states[j].service === ZIBLUEDEVICE_SID ) {
					isZiBlue = true;
					break;
				}
			}
			var room = ( device.room ? api.getRoomObject( device.room ) : null );
			if ( isZiBlue ) {
				devices.push( {
					"id": device.id,
					"roomName": ( room ? room.name : "_No room" ),
					"name": "(ZiBlue) " + device.name,
					"type": 3,
					"isZiBlue": isZiBlue
				} );
			} else {
				devices.push( {
					"id": device.id,
					"roomName": ( room ? room.name : "_No room" ),
					"name": device.name,
					"type": 2,
					"isZiBlue": isZiBlue
				} );
			}
		} );
		// Get scenes
		$.each( jsonp.ud.scenes, function( i, scene ) {
			var room = ( scene.room ? api.getRoomObject( scene.room ) : null );
			devices.push( {
				"id": scene.id,
				"roomName": ( room ? room.name : "_No room" ),
				"name": "(Scene) " + scene.name,
				"type": 1
			} );
		} );

		// Sort devices/scenes by Room/Type/name
		devices.sort( function( d1, d2 ) {
			var r1 = d1.roomName.toLowerCase();
			var r2 = d2.roomName.toLowerCase();
			if (r1 < r2) return -1;
			if (r1 > r2) return 1;
			var n1 = d1.name.toLowerCase();
			var n2 = d2.name.toLowerCase();
			if (n1 < n2) return -1;
			if (n1 > n2) return 1;
			return 0;
		} );

		function _getCheckboxHtml( deviceId, association, level ) {
			var pressType = "short";
			if ( level === 1 ) {
				pressType = "long";
			}
			return	'<span class="ziblue-' + pressType + '-press" title="' + pressType + ' press">'
				+		'<input type="checkbox"' + ( association && ( $.inArray( parseInt( deviceId, 10 ), association[level] ) > -1 ) ? ' checked="checked"' : '' ) + '>'
				+	'</span>';
		}

		var currentRoomName = "";
		$.each( devices, function( i, device ) {
			if ( device.roomName !== currentRoomName ) {
				currentRoomName = device.roomName;
				html += '<div class="zibluegateway-association-room">' +  device.roomName + '</div>';
			}
			if ( device.type === 1 ) {
				// Scene
				html += '<div class="zibluegateway-association zibluegateway-association-scene" data-scene-id="' + device.id + '">'
					+		'<label>'
					+			_getCheckboxHtml( device.id, feature.association.scenes, 0 )
					//+			_getCheckboxHtml( device.id, feature.association.scenes, 1 )
					+			'&nbsp;' + device.name + ' (#' + device.id + ')'
					+		'</label>'
					+	'</div>';
			} else if ( device.type === 3 ) {
				// ZiBlue : direct association (TODO)
				/*
				html += '<div class="zibluegateway-association zibluegateway-association-zibluedevice" data-device-id="' + device.id + '">'
					+		'<label>'
					+			_getCheckboxHtml( device.id, feature.association.devices, 0 )
					+			'&nbsp;' + device.name + ' (#' + device.id + ')'
					+		'</label>'
					+	'</div>';
				*/
			} else {
				// Classic device (e.g. Z-wave)
				html += '<div class="zibluegateway-association zibluegateway-association-device" data-device-id="' + device.id + '">'
					+		'<label>'
					+			_getCheckboxHtml( device.id, feature.association.devices, 0 )
					//+			_getCheckboxHtml( device.id, feature.association.devices, 1 )
					+			'&nbsp;' + device.name + ' (#' + device.id + ')'
					+		'</label>'
					+	'</div>';
			}
		} );

		html += '<div class="zibluegateway-toolbar">'
			+		'<button type="button" class="zibluegateway-cancel"><span class="icon icon-cancel"></span>Cancel</button>'
			+		'<button type="button" class="zibluegateway-associate"><span class="icon icon-ok"></span>Associate</button>'
			+	'</div>';

		$( "#zibluegateway-device-association" )
			.html( html )
			.css( {
				"display": "block"
			} );

		_formerScrollTopPosition = $( window ).scrollTop();
		$( window ).scrollTop( $( "#zibluegateway-known-panel" ).offset().top - 150 );
	}
	function _hideDeviceAssociation() {
		$( "#zibluegateway-device-association" )
			.css( {
				"display": "none",
				"height": $( "#zibluegateway-known-panel" ).height()
			} );
		if ( _formerScrollTopPosition > 0 ) {
			$( window ).scrollTop( _formerScrollTopPosition );
		}
	}
	function _setDeviceAssociation() {
		function _getEncodedAssociation() {
			var associations = [];
			$("#zibluegateway-device-association .zibluegateway-association-device input:checked").each( function() {
				var deviceId = $( this ).parents( ".zibluegateway-association-device" ).data( "device-id" );
				if ( $( this ).parent().hasClass( "ziblue-long-press" ) ) {
					associations.push( "+" + deviceId );
				} else {
					associations.push( deviceId );
				}
			});
			$("#zibluegateway-device-association .zibluegateway-association-scene input:checked").each( function() {
				var sceneId = $( this ).parents( ".zibluegateway-association-scene" ).data( "scene-id" );
				if ( $( this ).parent().hasClass( "ziblue-long-press" ) ) {
					associations.push( "+*" + sceneId );
				} else {
					associations.push( "*" + sceneId );
				}
			});
			$("#zibluegateway-device-association .zibluegateway-association-zibluedevice input:checked").each( function() {
				var deviceId = $( this ).parents( ".zibluegateway-association-zibluedevice" ).data( "device-id" );
				associations.push( "%" + deviceId );
			});
			return associations.join( "," );
		}

		$.when( _performActionAssociate( _selectedProductId, _selectedFeatureName, _getEncodedAssociation() ) )
			.done( function() {
				_drawDevicesList();
				_hideDeviceAssociation();
			});
	}

	/**
	 * Show parameters for a ZiBlue device
	 */
	function _showDeviceParams( productId, feature ) {
		var html = '<div class="zibluegateway-header">'
				+		'Params for ' + productId + ' - ' + feature.deviceName + ' (#' + feature.deviceId + ')'
				+	'</div>'
				+	'<div class="zibluegateway-toolbar">'
				+		'<button type="button" class="zibluegateway-help"><span class="icon icon-help"></span>Help</button>'
				+	'</div>'
				+	'<div class="zibluegateway-explanation zibluegateway-hidden">'
				+		Utils.getLangString( "ziblue_explanation_params" )
				+	'</div>';

		if ( feature.settings['button'] ) {
			html += '<h3>Button</h3>';
			$.each( [ [ 'pulse', 'Pulse' ], [ 'toggle', 'Toggle' ] ], function( i, param ) {
				html += '<div class="zibluegateway-param zibluegateway-param-' + param[0] + '">'
					+		'<input type="checkbox"' + ( feature.settings[ param[0] ] ? ' checked="checked"' : '' ) + '>'
					+		' ' + param[1]
					+	'</div>';
			} );
		}

		if ( feature.settings['receiver'] ) {
			html += '<h3>Receiver</h3>';
			html += 'TODO';
		}

		html += '<div class="zibluegateway-toolbar">'
			+		'<button type="button" class="zibluegateway-cancel"><span class="icon icon-cancel"></span>Cancel</button>'
			+		'<button type="button" class="zibluegateway-set"><span class="icon icon-ok"></span>Set</button>'
			+	'</div>';

		$( "#zibluegateway-device-params" )
			.html( html )
			.data( 'feature', feature )
			.css( {
				"display": "block",
				"height": $( "#zibluegateway-known-panel" ).height()
			} );

		_formerScrollTopPosition = $( window ).scrollTop();
		$( window ).scrollTop( $( "#zibluegateway-known-panel" ).offset().top - 150 );
	}
	function _hideDeviceParams() {
		$( "#zibluegateway-device-params" )
			.css( {
				"display": "none"
			} );
		if ( _formerScrollTopPosition > 0 ) {
			$( window ).scrollTop( _formerScrollTopPosition );
		}
	}
	function _setDeviceParams() {
		var feature = $( '#zibluegateway-device-params' ).data( 'feature' );
		$.each( [ 'pulse', 'toggle' ], function( i, param ) {
			feature.settings[ param ] = ( $('#zibluegateway-device-params .zibluegateway-param-' + param + ' input:checked').length > 0 );
		} );
		var setting = $.map( feature.settings, function( value, key ) {
			if ( value ) {
				return key;
			}
		} );
		api.setDeviceStateVariable( feature.deviceId, "urn:upnp-org:serviceId:ZiBlueDevice1", "Setting", setting.join( "," ), { dynamic: false } );
		$.when( _performActionRefresh() )
			.done( function() {
				_drawDevicesList();
				_hideDeviceParams();
			});
	}

	/**
	 * Show ZiBlue devices
	 */
	function _showDevices( deviceId ) {
		if ( deviceId ) {
			_deviceId = deviceId;
		}
		try {
			api.setCpanelContent(
					'<div id="zibluegateway-known-panel" class="zibluegateway-panel">'
				+		'<h1>Managed devices</h1>'
				+		'<div class="scenes_section_delimiter"></div>'
				+		'<div class="zibluegateway-toolbar">'
				+			'<button type="button" class="zibluegateway-help"><span class="icon icon-help"></span>Help</button>'
				+			'<button type="button" class="zibluegateway-refresh"><span class="icon icon-refresh"></span>Refresh</button>'
				+			'<button type="button" class="zibluegateway-add"><span class="icon icon-add"></span>Add</button>'
				+		'</div>'
				+		'<div class="zibluegateway-explanation zibluegateway-hidden">'
				+			Utils.getLangString( "ziblue_explanation_known_devices" )
				+		'</div>'
				+		'<div id="zibluegateway-known-devices" class="zibluegateway-devices">'
				+			Utils.getLangString( "ziblue_loading" )
				+		'</div>'
				+		'<div id="zibluegateway-device-actions" style="display: none;"></div>'
				+		'<div id="zibluegateway-device-association" style="display: none;"></div>'
				+		'<div id="zibluegateway-device-params" style="display: none;"></div>'
				+	'</div>'
			);

			// Manage UI events
			$( "#zibluegateway-known-panel" )
				.on( "click", ".zibluegateway-help", function() {
					$( this ).parent().next( ".zibluegateway-explanation" ).toggleClass( "zibluegateway-hidden" );
				} )
				.on( "click", ".zibluegateway-refresh", function() {
					$.when( _performActionRefresh() )
						.done( function() {
							_drawDevicesList();
						});
				} )
				.on( "click", ".zibluegateway-add", _showAddDevice )
				.click( function() {
					$( "#zibluegateway-device-actions" ).css( "display", "none" );
				} )
				.on( "click", ".zibluegateway-actions", function( e ) {
					var position = $( this ).position();
					position.left = position.left + $( this ).outerWidth();
					_selectedProductId = $( this ).data( "product-id" );
					_selectedFeatureName = $( this ).data( "feature-name" );
					var selectedFeature = _indexFeatures[ _selectedProductId + ";" + _selectedFeatureName ];
					_showDeviceActions( position, selectedFeature.settings );
					e.stopPropagation();
				} )
				.on( "click", ".zibluegateway-show-association", function() {
					_showDeviceAssociation( _selectedProductId, _indexFeatures[ _selectedProductId + ";" + _selectedFeatureName ] );
				} )
				.on( "click", ".zibluegateway-show-params", function() {
					_showDeviceParams( _selectedProductId, _indexFeatures[ _selectedProductId + ";" + _selectedFeatureName ] );
				} )
				.on( "click", ".zibluegateway-cancel", function() {
					_hideDeviceAssociation();
					_hideDeviceParams();
				} )
				// Association event
				.on( "click", ".zibluegateway-associate", _setDeviceAssociation )
				// Parameters event
				.on( "click", ".zibluegateway-set", _setDeviceParams )
				// Teach (receiver) event
				.on( "click", ".zibluegateway-teach", function() {
					api.ui.showMessagePopup( Utils.getLangString( "ziblue_confirmation_teach_in_receiver" ), 4, 0, {
						onSuccess: function() {
							_performActionTeachIn( _selectedProductId, "ON", "" );
							return true;
						}
					});
				} )
				// Clear (receiver) event
				.on( "click", ".zibluegateway-clear", function() {
					api.ui.showMessagePopup( Utils.getLangString( "ziblue_confirmation_clearing_receiver" ), 4, 0, {
						onSuccess: function() {
							_performActionClear( _selectedProductId );
							return true;
						}
					});
				} );

			// Show devices infos
			_drawDevicesList();

		} catch (err) {
			Utils.logError('Error in ZiBlueGateway.showDevices(): ' + err);
		}
	}

	// *************************************************************************************************
	// Add ZiBlue device
	// *************************************************************************************************

	/**
	 * Get informations on ZiBlue protocols
	 */
	function _getProtocolsInfosAsync() {
		var d = $.Deferred();
		api.showLoadingOverlay();
		$.ajax( {
			url: Utils.getDataRequestURL() + "id=lr_ZiBlueGateway&command=getProtocolsInfos&output_format=json#",
			dataType: "json"
		} )
		.done( function( protocolsInfos ) {
			api.hideLoadingOverlay();
			if ( $.isPlainObject( protocolsInfos ) ) {
				d.resolve( protocolsInfos );
			} else {
				Utils.logError( "No protocol infos" );
				d.reject();
			}
		} )
		.fail( function( jqxhr, textStatus, errorThrown ) {
			api.hideLoadingOverlay();
			Utils.logError( "Get ZiBlue protocols infos error : " + errorThrown );
			d.reject();
		} );
		return d.promise();
	}

	/**
	 * Draw and manage ZiBlue add device
	 */
	function _drawAddDevice() {
		$.when( _getProtocolsInfosAsync() )
			.done( function( protocolsInfos ) {
				var html = 	'<h3>' + Utils.getLangString( "ziblue_add_new_device_step", "" ).format( 1 ) + ': ' + Utils.getLangString( "ziblue_add_new_device_settings_title" ) + '</h3>'
					+		'<div class="zibluegateway-setting ui-widget-content ui-corner-all">'
					+			'<span>Protocol</span>'
					+			'<select id="zibluegateway-setting-protocol" class="zibluegateway-setting-value" data-variable="protocol">'
					+				'<option value="">-- Select a protocol --</option>';
				var protocols = [];
				$.each( protocolsInfos, function( protocolName, protocolInfos ) {
					protocols.push( [ protocolName, protocolInfos.name ] );
				});
				protocols.sort( function( p1, p2 ) {
					if ( p2[1] < p1[1] ) {
						return 1;
					} else if ( p2[1] > p1[1] ) {
						return -1;
					}
					return 0;
				});
				$.each( protocols, function( i, protocol ) {
					html +=			'<option value="' + protocol[0] + '">' + protocol[1]  + '</option>';
				});
				html +=			'</select>'
					+		'</div>'
					+		'<div class="zibluegateway-setting ui-widget-content ui-corner-all">'
					+			'<span>Device name</span>'
					+			'<input type="text" class="zibluegateway-setting-value" data-variable="deviceName" placeholder="Enter the name">'
					+		'</div>'
					+		'<div class="zibluegateway-setting ui-widget-content ui-corner-all">'
					+			'<span>Id</span>'
					+			'<input type="text" id="zibluegateway-setting-device-id" class="zibluegateway-setting-value" data-variable="deviceId" placeholder="Enter the id [0-255]">'
					+			'&nbsp;'
					+			'<select id="zibluegateway-setting-device-group">'
					+				'<option value=""></option>'
					+			'</select>'
					+			'<select id="zibluegateway-setting-device-unit">'
					+				'<option value=""></option>'
					+			'</select>'
					+		'</div>'
					+		'<div id="zibluegateway-protocol-settings"></div>'
					+		'<div id="zibluegateway-protocol-validation"></div>';
				$( "#zibluegateway-add-device" ).html( html );

				for ( var i = 65; i < 81; i++) { 
					$( "#zibluegateway-setting-device-group" ).append( $( "<option>", {
						value: String.fromCharCode( i ),
						text : String.fromCharCode( i )
					}));
				}
				for ( var i = 1; i < 17; i++) { 
					$( "#zibluegateway-setting-device-unit" ).append( $( "<option>", {
						value: i,
						text : i
					}));
				}

				$( "#zibluegateway-setting-protocol" ).change( function() {
					var protocolName = $(this).val();
					var protocolInfos = protocolsInfos[ protocolName ];
					if ( typeof protocolInfos != "undefined") {
						_drawProtocolSettings( protocolInfos.deviceTypes || [], protocolInfos.settings || {} );
					}
					_drawProtocolValidation( protocolName );
				});
				$( "#zibluegateway-setting-device-id" ).change( function() {
					var id = parseInt( $( this ).val(), 10 );
					$( "#zibluegateway-setting-device-group" ).val( String.fromCharCode( Math.floor( id / 16) + 65 ) );
					$( "#zibluegateway-setting-device-unit" ).val( (id % 16 + 1).toString() );
				});
				$( "#zibluegateway-setting-device-group" ).change( function() {
					var group = $( this ).val().charCodeAt( 0 );
					var unit = parseInt( $( "#zibluegateway-setting-device-unit" ).val(), 10 );
					$( "#zibluegateway-setting-device-id" ).val( ( group - 65 ) * 16  + ( unit - 1 ) );
				});
				$( "#zibluegateway-setting-device-unit" ).change( function() {
					var group = $( "#zibluegateway-setting-device-group" ).val().charCodeAt( 0 );
					var unit = parseInt( $( this ).val(), 10 );
					$( "#zibluegateway-setting-device-id" ).val( ( group - 65 ) * 16  + ( unit - 1 ) );
				});
			} );
	}

	/**
	 * Draw and manage the protocol settings
	 */
	function _drawProtocolSettings( deviceTypes, settings ) {
		var html = '';

		// Device type
		var deviceTypeParams = {};
		if ( ( deviceTypes == undefined ) || ( deviceTypes.length === 0 ) ) {
			deviceTypes = [ "BINARY_LIGHT" ];
		}
		html +=	'<div class="zibluegateway-setting ui-widget-content ui-corner-all">'
			+		'<span>Device type</span>'
			+		'<select id="zibluegateway-setting-device-type" class="zibluegateway-setting-value" data-variable="deviceType">'
			+			'<option value="">-- Select a device type --</option>';
		$.each( deviceTypes, function( i, encodedType ) {
			encodedType = encodedType.split( ';' );
			var deviceType = encodedType[0];
			deviceTypeParams[ deviceType ] = {};
			if ( encodedType[1] ) {
				$.each( encodedType[1].split( ',' ), function( i, encodedParam ) {
					encodedParam = encodedParam.split( '=' );
					deviceTypeParams[ deviceType ][ encodedParam[0] ] = encodedParam[1] || '';
				});
			}
			html +=	'<option value="' + deviceType + '"' + ( ( i === 0 ) && ( deviceTypes.length === 1 ) ? ' selected' : '' ) + '>' + deviceType + '</option>';
		} );
		html +=	'</select>'
			+ '</div>';

		// Settings
		$.each( settings, function( i, setting ) {
			html +=	'<div class="zibluegateway-setting ui-widget-content ui-corner-all">'
				+		'<span>' + setting.name + '</span>';
			if ( setting.type == "string" ) {
				html +=	'<input type="text" value="' + ( typeof setting.defaultValue === "string" ? setting.defaultValue : '' ) + '" class="zibluegateway-setting-value" data-setting="' + setting.variable  + '">';
			} else if ( setting.type == "select" ) {
				html +=	'<select class="zibluegateway-setting-value" data-setting="' + setting.variable  + '">';
				$.each( setting.values, function( i, value ) {
					html +=	'<option value="' + value + '"' + ( i === 0 ? ' selected' : '' ) + '>' + value + '</option>';
				} );
				html +=	'</select>';
			}
			html +=	'</div>';
		} );

		$("#zibluegateway-protocol-settings").html( html );

		$( '#zibluegateway-setting-device-type' ).change( function() {
			var deviceType = $(this).val();
			$.each( deviceTypeParams[ deviceType ], function( key, value ) {
				$( '#zibluegateway-add-device-panel .zibluegateway-setting-value[data-setting="' + key + '"]' ).val( value );
			});
		});
	}

	/**
	 * Draw protocol validation (explanations and buttons)
	 */
	function _drawProtocolValidation( protocolName ) {
		var html = '';
		if ( protocolName != "" ) {
			var step = 2;
			html = '<h3>' + Utils.getLangString( "ziblue_add_new_device_step", "" ).format( step ) + ': ' + Utils.getLangString( "ziblue_add_new_device_teach_title" ) + '</h3>'
				+		'<div>'
				+		( protocolName === "PARROT" ? Utils.getLangString( "ziblue_add_new_device_teach_parrot_explanation" ) : Utils.getLangString( "ziblue_add_new_device_teach_explanation" ) )
				+		'</div>'
				+		'<div>'
				+			'<button type="button" class="zibluegateway-teach">Teach</button>'
				+		'</div>';
			if ( protocolName !== "PARROT" ) {
				step = 3;
				html +=	'<h3>' + Utils.getLangString( "ziblue_add_new_device_step", "" ).format( step ) + ': ' + Utils.getLangString( "ziblue_add_new_device_test_title" ) + '</h3>'
					+	'<div>' + Utils.getLangString( "ziblue_add_new_device_test_explanation" ) + '</div>'
					+	'<div>'
					+		'<button type="button" class="zibluegateway-test-on">ON</button>'
					+		'<button type="button" class="zibluegateway-test-off">OFF</button>'
					+	'</div>';
			}
			step++;
			html +=		'<h3>' + Utils.getLangString( "ziblue_add_new_device_step", "" ).format( step ) + ': ' + Utils.getLangString( "ziblue_add_new_device_validate_title" ) + '</h3>'
				+		'<div>' + Utils.getLangString( "ziblue_add_new_device_validate_explanation" ) + '</div>'
				+		'<div>'
				+			'<button type="button" class="zibluegateway-create">Create</button>'
				+		'</div>';
		}
		$("#zibluegateway-protocol-validation").html( html );
	}

	/**
	 *
	 */
	function _getSettings() {
		var settings = { settings: [] };
		$( '#zibluegateway-add-device-panel .zibluegateway-setting-value' ).each( function() {
			settings[ $( this ).data( 'variable' ) ] = $( this ).val();
			settings.settings.push( $( this ).data( 'setting' ) + "=" + $( this ).val() );
		});
		settings.settings = settings.settings.join( "," );
		if ( !settings.protocol ) {
			api.ui.showMessagePopup( "You have to choose a protocol.", 2, 0 );
			return false;
		} else if ( !settings.deviceId ) {
			api.ui.showMessagePopup( "You have to set the device id.", 2, 0 );
			return false;
		} else if ( !settings.deviceName ) {
			api.ui.showMessagePopup( "You have to set the device name.", 2, 0 );
			return false;
		} else if ( !settings.deviceType ) {
			api.ui.showMessagePopup( "You have to choose the device type.", 2, 0 );
			return false;
		}
		return settings;
	}

	/**
	 * Show add device
	 */
	function _showAddDevice( deviceId ) {
		if ( deviceId ) {
			_deviceId = deviceId;
		}
		try {
			var hasTeachingBeenDone = false;
			api.setCpanelContent(
					'<div id="zibluegateway-add-device-panel" class="zibluegateway-panel">'
				+		'<h1>Add a new device</h1>'
				+		'<div class="scenes_section_delimiter"></div>'
				+		'<div id="zibluegateway-add-device">'
				+			Utils.getLangString( "ziblue_loading" )
				+		'</div>'
				+	'</div>'
			);

			$( "#zibluegateway-add-device-panel" )
				.on( "click", ".zibluegateway-teach", function() {
					var settings = _getSettings();
					if ( settings ) {
						var $that = $( this ).addClass( "highlighted" );
						$.when( _performActionTeachIn( settings.protocol + ";" + settings.deviceId, settings.action, settings.message ) )
							.done( function() { hasTeachingBeenDone = true; } )
							.then( function() { $that.removeClass( "highlighted" ); } );
					}
				})
				.on( "click", ".zibluegateway-test-on", function() {
					var settings = _getSettings();
					if ( settings ) {
						var $that = $( this ).addClass( "highlighted" );
						$.when( _performActionSetTarget( settings.protocol + ";" + settings.deviceId + ( settings.qualifier ? ";" + settings.qualifier : "" ), "1" ) )
							.then( function() { $that.removeClass( "highlighted" ); } );
					}
				})
				.on( "click", ".zibluegateway-test-off", function() {
					var settings = _getSettings();
					if ( settings ) {
						var $that = $( this ).addClass( "highlighted" );
						$.when( _performActionSetTarget( settings.protocol + ";" + settings.deviceId + ( settings.qualifier ? ";" + settings.qualifier : "" ), "0" ) )
							.then( function() { $that.removeClass( "highlighted" ); } );
					}
				})
				.on( "click", ".zibluegateway-create", function() {
					var $that = $( this );
					var d = $.Deferred();
					var settings = _getSettings();
					if ( !hasTeachingBeenDone ) {
						api.ui.showMessagePopup( Utils.getLangString( "ziblue_warning_teach_in_not_done" ), 4, 0, {
							onSuccess: function() {
								d.resolve();
							},
							onFailure: function() {
								d.reject();
							}
						});
					} else {
						d.resolve();
					}
					$.when( d, settings )
						.done( function() {
							// create device
							$that.addClass( "highlighted" );
							var encodedProductId = settings.protocol + ";" + settings.deviceId + ";" + settings.deviceType + ";" + settings.settings + ";" + settings.deviceName;
							$.when( _performActionCreateDevices( [ encodedProductId ] ) )
								.done( function() {
									$that.removeClass( "highlighted" );
									_showReload( Utils.getLangString( "ziblue_device_has_been_created" ), function() {
										_showDevices();
									});
								});
						});
				});

			_drawAddDevice();
		} catch (err) {
			Utils.logError('Error in ZiBlueGateway.showAddDevice(): ' + err);
		}
	}

	// *************************************************************************************************
	// Discovered ZiBlue devices
	// *************************************************************************************************

	/**
	 * Draw and manage discovered ziblue device list
	 */
	function _drawDiscoveredDevicesList() {
		if ( $( "#zibluegateway-discovered-devices" ).length === 0 ) {
			return;
		}
		$.when( _getDevicesInfosAsync() )
			.done( function( devicesInfos ) {
				if ( devicesInfos.discoveredDevices.length > 0 ) {
					// Sort the discovered ziblue devices by last update
					devicesInfos.discoveredDevices.sort( function( d1, d2 ) {
						return d2.lastUpdate - d1.lastUpdate;
					});
					var html =	'<table><tr><th>Protocol</th><th>Id</th><th>Signal<br/>Quality</th><th>Last view</th><th>Feature</th><th></th></tr>';
					$.each( devicesInfos.discoveredDevices, function( i, discoveredDevice ) {
						var productId = discoveredDevice.protocol + ';' + discoveredDevice.protocolDeviceId;
						html += '<tr class="zibluegateway-discovered-device" data-product-id="' + productId + '">'
							+		'<td>' + discoveredDevice.protocol + '</td>'
							+		'<td>' + discoveredDevice.protocolDeviceId + '</td>'
							+		'<td>' + ( discoveredDevice.rfQuality >= 0 ? discoveredDevice.rfQuality : '' ) + '</td>'
							+		'<td>' + _convertTimestampToLocaleString( discoveredDevice.lastUpdate ) + '</td>'
							+		'<td>'
							+			'<table class="zibluegateway-feature-group">';
						$.each( discoveredDevice.featureGroups, function( j, group ) {
							if ( group.isUsed === false ) {
								return;
							}
							html +=			'<tr>'
								+				'<td>';
							$.each( group.features, function( featureName, feature ) {
								if ( feature.isUsed === false ) {
									return;
								}
								html +=				'<div>' + featureName + '</div>'
									+				( feature.comment ? '<div>' + feature.comment + '</div>' : '' )
									+				( feature.state ? '<div>' + feature.state + '</div>' : '' );
							});
							html +=				'</td><td class="zibluegateway-device-type" width="40%">';
							if ( group.deviceTypes.length > 1 ) {
								html +=				'<select>';
								$.each( group.deviceTypes, function( k, deviceType ) {
									html +=				'<option value="' + deviceType + '">' + deviceType + '</option>';
								} );
								html +=				'</select>';
							} else {
								html +=	group.deviceTypes[0];
							}
							html +=				'</td>'
								+			'</tr>';
						} );
						html +=			'</table>'
							+		'</td>'
							+		'<td>'
							+			'<input type="checkbox">'
							+		'</td>'
							+	'</tr>';
					});
					html += '</table>';
					$("#zibluegateway-discovered-devices").html( html );
				} else {
					$("#zibluegateway-discovered-devices").html( Utils.getLangString( "ziblue_no_discovered_device" ) );
				}
			} );
	}

	/**
	 * Show ziblue discovered devices
	 */
	function _showDiscoveredDevices( deviceId ) {
		if ( deviceId ) {
			_deviceId = deviceId;
		}
		try {
			// TODO : add room ?
			api.setCpanelContent(
					'<div id="zibluegateway-discovered-panel" class="zibluegateway-panel">'
				+		'<h1>Discovered devices</h1>'
				+		'<div class="scenes_section_delimiter"></div>'
				+		'<div class="zibluegateway-toolbar">'
				+			'<button type="button" class="zibluegateway-help"><span class="icon icon-help"></span>Help</button>'
				//+			'<button type="button" class="zibluegateway-ignore"><span class="icon icon-ignore"></span>Ignore</button>'
				+			'<button type="button" class="zibluegateway-refresh" style="display: none"><span class="icon icon-refresh"></span>Refresh</button>'
				+			'<button type="button" class="zibluegateway-learn"><span class="icon icon-ok"></span>Learn</button>'
				+		'</div>'
				+		'<div class="zibluegateway-explanation zibluegateway-hidden">'
				+			Utils.getLangString( "ziblue_explanation_discovered_devices" )
				+		'</div>'
				+		'<div id="zibluegateway-discovered-devices" class="zibluegateway-devices">'
				+			Utils.getLangString( "ziblue_loading" )
				+		'</div>'
				+	'</div>'
			);

			function _getSelectedProductIds() {
				var items = [];
				$("#zibluegateway-discovered-devices input:checked:visible").each( function() {
					var $device = $( this ).parents( ".zibluegateway-discovered-device" );
					var productId = $device.data( "product-id" );
					var deviceTypes = [];
					$device.find( ".zibluegateway-device-type" )
						.each( function( index ) {
							var $select = $( this ).find( "select" );
							if ( $select.length > 0 ) {
								deviceTypes.push( $select.val() );
							} else {
								deviceTypes.push( $( this ).text() );
							}
						});
					items.push( productId + ';' + deviceTypes.join( ',' ) + ';' );
				});
				return items;
			}

			// Manage UI events
			$( "#zibluegateway-discovered-panel" )
				.on( "click", ".zibluegateway-help", function() {
					$( ".zibluegateway-explanation" ).toggleClass( "zibluegateway-hidden" );
				} )
				.on( "click", ".zibluegateway-refresh", function() {
					$( "#zibluegateway-discovered-panel .zibluegateway-refresh" ).css({ 'display': 'none' });
						_drawDiscoveredDevicesList();
				} )
				.on( "click", ".zibluegateway-learn", function( e ) {
					var productIds = _getSelectedProductIds();
					if ( productIds.length === 0 ) {
						api.ui.showMessagePopup( Utils.getLangString( "ziblue_select_device" ), 1 );
					} else {
						api.ui.showMessagePopup( Utils.getLangString( "ziblue_confirmation_learning_devices" ) + " " + productIds, 4, 0, {
							onSuccess: function() {
								$.when( _performActionCreateDevices( productIds ) )
									.done( function() {
										_showReload( Utils.getLangString( "ziblue_device_has_been_created" ), function() {
											_showDevices();
										});
									});
								return true;
							}
						});
					}
				} )
				.on( "click", ".zibluegateway-ignore", function( e ) {
					alert( "TODO" );
				});

			// Show discovered devices infos
			_drawDiscoveredDevicesList();

		} catch (err) {
			Utils.logError('Error in ZiBlueGateway.showDevices(): ' + err);
		}
	}

	// *************************************************************************************************
	// Actions
	// *************************************************************************************************

	/**
	 * 
	 */
	function _performActionRefresh() {
		Utils.logDebug( "[ZiBlueGateway.performActionRefresh] Refresh the list of ZiBlue devices" );
		return Utils.performActionOnDevice(
			_deviceId, ZIBLUEGATEWAY_SID, "Refresh", {
				output_format: "json"
			}
		);
	}

	/**
	 * 
	 */
	function _performActionCreateDevices( encodedProductIds ) {
		Utils.logDebug( "[ZiBlueGateway.performActionCreateDevices] Create ZiBlue product/features '" + encodedProductIds + "'" );
		return Utils.performActionOnDevice(
			_deviceId, ZIBLUEGATEWAY_SID, "CreateDevices", {
				output_format: "json",
				productIds: encodeURIComponent( encodedProductIds.join( "|" ) )
			}
		);
	}

	/**
	 * 
	 */
	function _performActionTeachIn( productId, action, comment ) {
		Utils.logDebug( "[ZiBlueGateway.performActionTeachIn] Teach in ZiBlue product '" + productId + "', action: " + action + ", comment: " + comment );
		return Utils.performActionOnDevice(
			_deviceId, ZIBLUEGATEWAY_SID, "TeachIn", {
				output_format: "json",
				productId: productId,
				action: action,
				comment: encodeURIComponent( comment )
			}
		);
	}

	/**
	 * Associate ZiBlue device to Vera devices
	 */
	function _performActionAssociate( productId, featureName, encodedAssociation ) {
		Utils.logDebug( "[ZiBlueGateway.performActionAssociate] Associate ZiBlue product/feature '" + productId + "/" + featureName + "' with " + encodedAssociation );
		return Utils.performActionOnDevice(
			_deviceId, ZIBLUEGATEWAY_SID, "Associate", {
				output_format: "json",
				productId: productId,
				feature: featureName,
				association: encodeURIComponent( encodedAssociation )
			}
		);
	}

	/**
	 * Test ON/OFF on newly created device (before validating)
	 */
	function _performActionSetTarget( productId, targetValue ) {
		Utils.logDebug( "[ZiBlueGateway._performActionSetTarget] Set target for ZiBlue product '" + productId + " to " + targetValue );
		return Utils.performActionOnDevice(
			_deviceId, ZIBLUEGATEWAY_SID, "SetTarget", {
				output_format: "json",
				productId: productId,
				newTargetValue: targetValue
			}
		);
	}

	// *************************************************************************************************
	// Errors
	// *************************************************************************************************

	/**
	 * Get errors
	 */
	function _getErrorsAsync() {
		var d = $.Deferred();
		api.showLoadingOverlay();
		$.ajax( {
			url: Utils.getDataRequestURL() + "id=lr_ZiBlueGateway&command=getErrors&output_format=json#",
			dataType: "json"
		} )
		.done( function( errors ) {
			api.hideLoadingOverlay();
			if ( $.isArray( errors ) ) {
				d.resolve( errors );
			} else {
				Utils.logError( "No errors" );
				d.reject();
			}
		} )
		.fail( function( jqxhr, textStatus, errorThrown ) {
			api.hideLoadingOverlay();
			Utils.logError( "Get errors error : " + errorThrown );
			d.reject();
		} );
		return d.promise();
	}

	/**
	 * Draw errors list
	 */
	function _drawErrorsList() {
		if ( $( "#zibluegateway-errors" ).length === 0 ) {
			return;
		}
		$.when( _getErrorsAsync() )
			.done( function( errors ) {
				if ( errors.length > 0 ) {
					var html = '<table><tr><th>Date</th><th>Method<th>Error</th></tr>';
					$.each( errors, function( i, error ) {
						html += '<tr>'
							+		'<td>' + _convertTimestampToLocaleString( error[0] ) + '</td>'
							+		'<td>' + error[1] + '</td>'
							+		'<td>' + error[2] + '</td>'
							+	'</tr>';
					} );
					html += '</table>';
					$( "#zibluegateway-errors" ).html( html );
				} else {
					$( "#zibluegateway-errors" ).html( Utils.getLangString( "ziblue_no_error" ) );
				}
			} );
	}

	/**
	 * Show errors tab
	 */
	function _showErrors( deviceId ) {
		_deviceId = deviceId;
		try {
			api.setCpanelContent(
					'<div id="zibluegateway-errors-panel" class="zibluegateway-panel">'
				/*+		'<div class="zibluegateway-toolbar">'
				+			'<button type="button" class="zibluegateway-help"><span class="icon icon-help"></span>Help</button>'
				+		'</div>'
				+		'<div class="zibluegateway-explanation zibluegateway-hidden">'
				+			Utils.getLangString( "ziblue_explanation_errors" )
				+		'</div>'*/
				+		'<div id="zibluegateway-errors">'
				+			Utils.getLangString( "ziblue_loading" )
				+		'</div>'
				+	'</div>'
			);
			// Manage UI events
			/*$( "#zibluegateway-errors-panel" )
				.on( "click", ".zibluegateway-help" , function() {
					$( ".zibluegateway-explanation" ).toggleClass( "zibluegateway-hidden" );
				} );*/
			// Display the errors
			_drawErrorsList();
		} catch ( err ) {
			Utils.logError( "Error in ZiBlueGateway.showErrors(): " + err );
		}
	}

	// *************************************************************************************************
	// Donate
	// *************************************************************************************************

	function _showDonate( deviceId ) {
		var donateHtml = '\
<form action="https://www.paypal.com/cgi-bin/webscr" method="post" target="_blank">\
<input type="hidden" name="cmd" value="_s-xclick">\
<input type="hidden" name="encrypted" value="-----BEGIN PKCS7-----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-----END PKCS7-----">\
<input type="image" src="https://www.paypalobjects.com/en_US/FR/i/btn/btn_donateCC_LG.gif" border="0" name="submit" alt="PayPal - The safer, easier way to pay online!">\
<img alt="" border="0" src="https://www.paypalobjects.com/fr_FR/i/scr/pixel.gif" width="1" height="1">\
</form>';

		api.setCpanelContent(
				'<div id="zibluegateway-donate-panel" class="zibluegateway-panel">'
			+		'<div id="zibluegateway-donate">'
			+			'<span>This plugin is free but if you install and find it useful then a donation to support further development is greatly appreciated</span>'
			+			donateHtml
			+		'</div>'
			+	'</div>'
		);
	}

	// *************************************************************************************************
	// Main
	// *************************************************************************************************

	myModule = {
		uuid: _uuid,
		onDeviceStatusChanged: _onDeviceStatusChanged,
		showAddDevice: _showAddDevice,
		showDevices: _showDevices,
		showDiscoveredDevices: _showDiscoveredDevices,
		showErrors: _showErrors,
		showDonate: _showDonate,

		ALTUI_drawDevice: function( device ) {
			//var status = parseInt( MultiBox.getStatus( device, "urn:upnp-org:serviceId:SwitchPower1", "Status" ), 10 );
			var version = MultiBox.getStatus( device, "urn:upnp-org:serviceId:ZiBlueGateway1", "PluginVersion" );
			return '<div class="panel-content">'
				//+		ALTUI_PluginDisplays.createOnOffButton( status, "altui-zibluegateway-" + device.altuiid, _T( "OFF,ON" ), "pull-right" )
				+		'<div class="btn-group" role="group" aria-label="...">'
				+			'v' + version
				+		'</div>'
				+	'</div>';
				//+	'<script type="text/javascript">'
				//+		'$("div#altui-zibluegateway-{0}").on("click touchend", function() { ALTUI_PluginDisplays.toggleOnOffButton("{0}", "div#altui-zibluegateway-{0}"); } );'.format( device.altuiid )
				//+	'</script>';
		}
	};

	// Register
	if ( !_registerIsDone ) {
		api.registerEventHandler( "on_ui_deviceStatusChanged", myModule, "onDeviceStatusChanged" );
		_registerIsDone = true;
	}

	return myModule;

})( api, jQuery );
