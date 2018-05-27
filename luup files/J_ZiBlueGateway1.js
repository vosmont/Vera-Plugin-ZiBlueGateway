//# sourceURL=J_ZiBlueGateway1.js

/**
 * This file is part of the plugin ZiBlueGateway.
 * https://github.com/vosmont/Vera-Plugin-ZiBlueGateway
 * Copyright (c) 2018 Vincent OSMONT
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
					var result;
					try {
						result = JSON.parse( response.responseText );
					} catch( err ) {
					}
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
					Utils.logError( "[Utils.performActionOnDevice] ERROR(" + response.status + "): " + response.responseText );
					d.reject();
				}
			} );
		} catch( err ) {
			Utils.logError( "[Utils.performActionOnDevice] ERROR: " + JSON.parse( err ) );
			d.reject();
		}
		return d.promise();
	};
	Utils.setDeviceStateVariablePersistent = function( deviceId, service, variable, value ) {
		var d = $.Deferred();
		api.setDeviceStateVariablePersistent( deviceId, service, variable, value, {
			onSuccess: function() {
				d.resolve();
			},
			onFailure: function() {
				Utils.logError( "[Utils.setDeviceStateVariablePersistent] ERROR" );
				d.reject();
			}
		});
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
			$.each( tokens, function( key, value ) {
				if ( !window.langJson.Tokens[ key ] ) {
					window.langJson.Tokens[ key ] = value;
				}
			});
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
			var parts = fileName.split(";");
			var name = parts[0].trim();
			var fileName = ( parts[1] ? parts[1] : parts[0] ).trim();
			if ( fileName.indexOf( "/" ) !== 0 ) {
				// Local file on the Vera
				fileName = api.getDataRequestURL().replace( "/data_request", "/" ) + fileName;
			}
			if ( !_resourceLoaded[ name ] ) {
				var parts = name.split(".");
				switch( parts.pop() ) {
					case 'css':
						var cssLink = $( "<link rel='stylesheet' type='text/css' href='" + fileName + "'>" );
						$( "head" ).append( cssLink );
						_resourceLoaded[ name ] = true;
						break;
					case 'js':
						loaders.push(
							$.ajax( {
								url: fileName,
								dataType: "script",
								beforeSend: function( jqXHR, settings ) {
									jqXHR.name = name;
								}
							} )
						);
				}
			}
		} );
		// Execute loaders
		$.when.apply( $, loaders )
			.done( function( xml, textStatus, jqxhr ) {
				if (loaders.length === 1) {
					_resourceLoaded[ jqxhr.name ] = true;
				} else if (loaders.length > 1) {
					// arguments : [ [ xml, textStatus, jqxhr ], ... ]
					for (var i = 0; i < arguments.length; i++) {
						jqxhr = arguments[ i ][ 2 ];
						_resourceLoaded[ jqxhr.name ] = true;
					}
				}
				d.resolve();
			} )
			.fail( function( jqxhr, textStatus, errorThrown  ) {
				Utils.logError( 'Load "' + jqxhr.name + '" : ' + textStatus + ' - ' + errorThrown );
				d.reject();
			} );
		return d.promise();
	};

	Utils.getLangStringFormat = function() {
		var content = Utils.getLangString( arguments[0] );
		for ( var i=1; i < arguments.length; i++ ) {
			var replacement = new RegExp( '\\{' + (i-1) + '\\}', 'g' );
			content = content.replace( replacement, arguments[i] );
		}
		return content;
	};

} ) ( jQuery );


/**
 * ALTUI fixes
 */
( function( $ ) {
	if ( window.Localization ) {
		Utils.getLangString = function( token, defaultValue ) { return _T(token) || defaultValue; };
	}
} ) ( jQuery );


/**
 * Plugin
 */
var ZiBlueGateway = ( function( api, $ ) {
	var _prefix = "ziblue";
	var _pluginName = "ZiBlueGateway";
	var _uuid = "51d7cd82-355e-4dad-b5c9-100a74133220";
	var PLUGIN_SID = "urn:upnp-org:serviceId:ZiBlueGateway1";
	var PLUGIN_CHILD_SID = "urn:upnp-org:serviceId:ZiBlueDevice1";
	var _deviceId = null;
	var _lastUpdate = 0;
	var _indexMappings = {};
	var _selectedDeviceId = "";
	var _formerScrollTopPosition = 0;
	var _equipmentsTimeout, _discoveredEquipmentsTimeout;
	var _equipmentsLastRefresh = 0, _discoveredEquipmentsLastRefresh = 0;

	// *************************************************************************************************
	// Tools
	// *************************************************************************************************

	/**
	 * Resources
	 */
	function _loadResourcesAsync() {
		var resources = [ 'J_' + _pluginName + '1.css' ];
		if ( $( 'link[rel="stylesheet"][href*="font-awesome"]' ).length === 0 ) {
			resources.push( 'font-awesome.css;//maxcdn.bootstrapcdn.com/font-awesome/4.7.0/css/font-awesome.min.css' );
		}
		return Utils.loadResourcesAsync( resources )
	}

	/**
	 * Localization
	 */
	function _loadLocalizationAsync() {
		var d = $.Deferred();
		Utils.loadResourcesAsync( 'J_' + _pluginName + '1_loc_' + Utils.getLanguage() + '.js' )
			.done( function() {
				d.resolve();
			})
			.fail( function() {
				if ( Utils.getLanguage() !== 'en' ) {
					// Fallback
					Utils.loadResourcesAsync( 'J_' + _pluginName + '1_loc_en.js' )
						.done( function() {
							d.resolve();
						});
				} else {
					d.reject();
				}
			});
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

	function _showReload( message, onSuccess ) {
		var html = '<div id="' + _prefix + '-reload">'
			+			( message ? '<div>' + message + '</div>' : '' )
			+			'<div>' + Utils.getLangString( _prefix + "_reload_has_to_be_done" ) + '</div>'
			+			'<div>'
			+				'<button type="button" class="' + _prefix + '-reload">Reload Luup engine</button>'
			+			'</div>'
			+		'</div>';
		api.ui.showMessagePopup( html, 0, 0, { onSuccess: onSuccess } );

		$( "#" + _prefix + "-reload" ).click( function() {
			$.when( api.luReload() )
				.done( function() {
					$( "#" + _prefix + "-reload" ).css({ "display": "none" });
				});
			$( this ).prop( "disabled", true );
		});
	}

	/**
	 * Settings
	 */
	function _getSettingHtml( setting ) {
		var className = _prefix + "-setting-value" + ( setting.className ? " " + setting.className : "" );
		var html = '<div class="' + _prefix + '-setting ui-widget-content ui-corner-all">'
			+			'<span>' + setting.name + '</span>';
		if ( setting.type == "checkbox" ) {
			html += '<input type="checkbox"'
				+		( ( setting.value === true ) ? ' checked="checked"' : '' )
				+		( ( setting.isReadOnly === true ) ? ' disabled="disabled"' : '' )
				+		' class="' + className + '" data-setting="' + setting.variable  + '">';
		} else if ( setting.type == "string" ) {
			var value = ( setting.value ? setting.value : ( setting.defaultValue ? setting.defaultValue : '' ) );
			html +=	'<input type="text" value="' + value + '" class="' + className + '" data-setting="' + setting.variable  + '">';
		} else if ( setting.type == "select" ) {
			html +=	'<select class="' + className + '" data-setting="' + setting.variable + '">';
			$.each( setting.values, function( i, value ) {
				var isSelected = false;
				if ( typeof setting.value === "string" ) {
					if ( value === setting.value ) {
						isSelected = true;
					}
				} else if ( i === 0 ) {
					isSelected = true;
				}
				html +=	'<option value="' + value + '"' + ( isSelected ? ' selected' : '' ) + '>' + value + '</option>';
			} );
			html +=	'</select>';
		}
		if ( setting.comment ) {
			html +=	'<span class="' + _prefix + '-setting-comment">' + setting.comment + '</span>';
		}
		html +=	'</div>';
		return html;
	}

	// *************************************************************************************************
	// Plugin settings
	// *************************************************************************************************

	/**
	 * Get settings
	 */
	function _getSettingsAsync() {
		var d = $.Deferred();
		api.showLoadingOverlay();
		$.ajax( {
			url: Utils.getDataRequestURL() + "id=lr_" + _pluginName + "&command=getSettings&output_format=json#",
			dataType: "json"
		} )
		.done( function( settings ) {
			api.hideLoadingOverlay();
			if ( $.isPlainObject( settings ) ) {
				d.resolve( settings );
			} else {
				Utils.logError( "No setting" );
				d.reject();
			}
		} )
		.fail( function( jqxhr, textStatus, errorThrown ) {
			api.hideLoadingOverlay();
			Utils.logError( "Get " + _pluginName + " settings infos error : " + errorThrown );
			d.reject();
		} );
		return d.promise();
	}

	/**
	 * Show settings
	 */
	function _showSettings( deviceId ) {
		if ( deviceId ) {
			_deviceId = deviceId;
		}
		try {
			$.when( _getSettingsAsync(), _loadResourcesAsync(), _loadLocalizationAsync() ).then( function( settings ) {
				var html = '<div id="' + _prefix + '-plugin-settings" class="' + _prefix + '-panel">'
					+		'<h1>' + Utils.getLangString( _prefix + "_plugin_settings" ) + '</h1>'
					+		'<div class="scenes_section_delimiter"></div>'
					+		'<div class="' + _prefix + '-toolbar">'
					+			'<button type="button" class="' + _prefix + '-help"><i class="fa fa-question fa-lg text-info" aria-hidden="true"></i>&nbsp;' + Utils.getLangString( _prefix + "_help" ) + '</button>'
					+		'</div>'
					+		'<div class="' + _prefix + '-explanation ' + _prefix + '-hidden">'
					+			Utils.getLangString( _prefix + "_explanation_plugin_settings" )
					+		'</div>'
					+		'<div>'
					+			'<h3>System</h3>';
				$.each( settings.system, function( i, setting ) {
					html += _getSettingHtml({
						type: "string",
						variable: setting.name,
						name: setting.name,
						value: setting.value,
						comment: setting.comment
					});
				});
				html += 	'<div>'
					+			'<h3>Radio Low</h3>';
				$.each( settings.radio[0], function( i, setting ) {
					html += _getSettingHtml({
						type: "string",
						variable: setting.name,
						name: setting.name,
						value: setting.value,
						comment: ( setting.unit ? setting.unit : '' ) + ( setting.unit && setting.comment ? ' - ' : '' ) + ( setting.comment ? setting.comment : '' )
					});
				});
				html += 	'<div>'
					+			'<h3>Radio High</h3>';
				$.each( settings.radio[1], function( i, setting ) {
					html += _getSettingHtml({
						type: "string",
						variable: setting.name,
						name: setting.name,
						value: setting.value,
						comment: ( setting.unit ? setting.unit : '' ) + ( setting.unit && setting.comment ? ' - ' : '' ) + ( setting.comment ? setting.comment : '' )
					});
				});
				html +=		'</div>'
					+	'</div>'
				api.setCpanelContent( html );

				// Manage UI events
				$( "#" + _prefix + "-plugin-settings" )
					.on( "click", "." + _prefix + "-help", function() {
						$( this ).parent().next( "." + _prefix + "-explanation" ).toggleClass( _prefix + "-hidden" );
					} )
			});
		} catch (err) {
			Utils.logError( "Error in " + _pluginName + ".showSettings(): " + err );
		}
	}

	// *************************************************************************************************
	// Equipments
	// *************************************************************************************************

	/**
	 * Get informations on equipments
	 */
	function _getEquipmentsInfosAsync() {
		var d = $.Deferred();
		$.ajax( {
			url: Utils.getDataRequestURL() + "id=lr_" + _pluginName + "&command=getEquipmentsInfos&output_format=json#",
			dataType: "json",
			timeout: 1000
		} )
		.done( function( infos ) {
			if ( $.isPlainObject( infos ) ) {
				d.resolve( infos );
			} else {
				Utils.logError( "No equipments infos" );
				d.reject();
			}
		} )
		.fail( function( jqxhr, textStatus, errorThrown ) {
			Utils.logError( "Get " + _pluginName + " equipments infos error : " + errorThrown );
			d.reject();
		} );
		return d.promise();
	}

	function _stopEquipmentsRefresh() {
		if ( _equipmentsTimeout ) {
			window.clearTimeout( _equipmentsTimeout );
		}
		_equipmentsTimeout = null;
	}
	function _resumeEquipmentsRefresh() {
		if ( _equipmentsTimeout == null ) {
			var timeout = 3000 - ( Date.now() - _equipmentsLastRefresh );
			if ( timeout < 0 ) {
				timeout = 0;
			}
			_equipmentsTimeout = window.setTimeout( _drawEquipmentsList, timeout );
		}
	}

	function _getAssociationHtml( associationType, association, level ) {
		if ( association && ( association[ level ].length > 0 ) ) {
			var pressType = "short";
			if ( level === 1 ) {
				pressType = "long";
			}
			return	'<span class="' + _prefix + '-association ' + _prefix + '-association-' + associationType + '" title="' + associationType + ' associated with ' + pressType + ' press">'
				+		'<span class="' + _prefix + '-' + pressType + '-press">'
				+			association[ level ].join( "," )
				+		'</span>'
				+	'</span>';
		}
		return "";
	}

	/**
	 * Draw and manage equipments list
	 */
	function _drawEquipmentsList() {
		_stopEquipmentsRefresh();
		if ( $( "#" + _prefix + "-known-equipments" ).length === 0 ) {
			// The panel is no more here
			return;
		}
		if ( !$( "#" + _prefix + "-known-equipments" ).is( ":visible" ) ) {
			// The panel is hidden
			_equipmentsLastRefresh = Date.now();
			_resumeEquipmentsRefresh();
			return;
		}
		_indexMappings = {};
		$.when( _getEquipmentsInfosAsync() )
			.done( function( infos ) {
				if ( infos.equipments.length > 0 ) {
					$.each( infos.equipments, function( i, equipment ) {
						var haRoom = api.getRoomObject( equipment.mainRoomId );
						equipment.roomName = haRoom ? haRoom.name : 'unknown';
					});
					// Sort the equipments by room / name
					infos.equipments.sort( function( e1, e2 ) {
						if ( e1.protocol === e2.protocol ) {
							var x = e1.roomName.toLowerCase(), y = e2.roomName.toLowerCase(); // TODO ????
							return x < y ? -1 : x > y ? 1 : 0;
						}
						return e1.protocol < e2.protocol ? -1 : e1.protocol > e2.protocol ? 1 : 0;
					});
					
					var html =	'<table><tr>'
						+			'<th>' + Utils.getLangString( _prefix + "_room" ) + '</th>'
						+			'<th>' + Utils.getLangString( _prefix + "_protocol" ) + '</th>'
						+			'<th>' + Utils.getLangString( _prefix + "_id" ) + '</th>'
						+			'<th>' + Utils.getLangString( _prefix + "_signal_quality" ) + '</th>'
						+			'<th>' + Utils.getLangString( _prefix + "_last_update" ) + '</th>'
						+			'<th>' + Utils.getLangString( _prefix + "_feature" ) + '</th>'
						+		'</tr>';
					$.each( infos.equipments, function( i, equipment ) {
						html += '<tr class="' + _prefix + '-known-equipment">'
							+		'<td class="' + _prefix + '-room-name">' + equipment.roomName + '</td>'
							+		'<td class="' + _prefix + '-protocol-name">' + equipment.protocol + '</td>'
							+		'<td class="' + _prefix + '-protocol-id">' + equipment.id + ( equipment.isNew ? ' <span style="color:red">NEW</span>' : '' ) + '</td>'
							+		'<td>' + ( equipment.quality >= 0 ? equipment.quality : '' ) + '</td>'
							+		'<td>' + _convertTimestampToLocaleString( equipment.lastUpdate ) + '</td>'
							+		'<td>'
/*
						// Sort features of the equipment by linked device names
						equipment.features.sort( function( e1, e2 ) {
							var nameA = api.getDeviceObject( e1.deviceId ).name.toLowerCase();
							var nameB = api.getDeviceObject( e2.deviceId ).name.toLowerCase();
							if ( nameA < nameB ) {
								return -1;
							} else if ( nameA > nameB ) {
								return 1;
							}
							return 0;
						});
*/
						html +=			'<div class="' + _prefix + '-equipment-mappings">';
						$.each( equipment.mappings, function( i, mapping ) {
							html +=			'<div class="' + _prefix + '-equipment-mapping">';

							html +=				'<div class="' + _prefix + '-features">';
							$.each( mapping.features, function( featureName, feature ) {
								html +=				'<div class="' + _prefix + '-feature">'
									+					'<span class="' + _prefix + '-feature-name">' + featureName + '</span>'
									+					( feature.state ? '<span class="' + _prefix + '-feature-state">' + feature.state + '</span>' : '' )
									+					( feature.comment ? '<div class="' + _prefix + '-feature-comment">' + feature.comment + '</div>' : '' )
									+				'</div>';
							});
							html +=				'</div>';

							var device = mapping.device;
							_indexMappings[ device.id.toString() ] = [ equipment, mapping ];
							var haDevice = api.getDeviceObject( device.id );
							html +=				'<i class="' + _prefix + '-device-actions fa fa-caret-down fa-lg" aria-hidden="true" data-device-id="' + device.id + '"></i>'
								+				'<div class="' + _prefix + '-device-type">'
								+					'<div><span class="' + _prefix + '-device-name">' + haDevice.name + '</span> (#' + device.id + ')</div>'
								+					'<div>'
								+						Utils.getLangString( haDevice.device_type )
								+						( device.settings.pulse ? ' PULSE' : '' )
								+						( device.settings.toggle ? ' TOGGLE' : '' )
								+					'</div>'
								+					'<div class="' + _prefix + '-device-association">'
								+						_getAssociationHtml( "device", device.association.devices, 0 )
								//+						_getAssociationHtml( "device", device.association.devices, 1 )
								+						_getAssociationHtml( "scene", device.association.scenes, 0 )
								//+						_getAssociationHtml( "scene", device.association.scenes, 1 )
								+						_getAssociationHtml( "equipment", device.association.equipments, 0 )
								+					'</div>'
								+				'</div>'
								+			'</div>';
						});
						html +=			'</div>'
							+		'</td>'
							+	'</tr>';
					});
					html += '</table>';
					$("#" + _prefix + "-known-equipments").html( html );
				} else {
					$("#" + _prefix + "-known-equipments").html( Utils.getLangString( _prefix + "_no_equipment" ) );
				}
				_equipmentsLastRefresh = Date.now();
				_resumeEquipmentsRefresh();
			} );
	}

	/**
	 * Show the actions that can be done on an equipment
	 */
	function _showEquipmentActions( position, equipment, mapping ) {
		_stopEquipmentsRefresh();
		var settings = mapping.device.settings;
		var html = '<table>'
				+		'<tr>'
				+			'<td>'
				+				( settings.transmitter ?
								'<button type="button" class="' + _prefix + '-show-association">Associate</button>'
								: '')
				+				'<button type="button" class="' + _prefix + '-show-params">Params</button>'
				+			'</td>';
		if ( settings.receiver ) {
			html +=			'<td bgcolor="#FF0000">'
				+				'<button type="button" class="' + _prefix + '-teach">Teach in</button>'
				//+				'<button type="button" class="' + _prefix + '-clear">Clear</button>'
				+			'</td>';
		}
		html +=			'</tr>'
			+		'</table>';
		var $actions = $( "#" + _prefix + "-equipments-actions" );
		$actions
			.html( html )
			.data( "equipment", equipment )
			.data( "mapping", mapping )
			.css({ "display": "block" });
		position.left -= $actions.outerWidth() + 5;
		position.top -= $actions.outerHeight() / 2;
		$actions.offset( position );
	}

	/**
	 * Show all devices and scene that can be associated and manage associations
	 */
	function _showEquipmentAssociation( equipment, mapping ) {
		_stopEquipmentsRefresh();
		var html = '<h1>' + Utils.getLangString( _prefix + "_association" ) + '</h1>'
				+	'<h3>' + equipment.protocol + ' - ' + equipment.id + " - " + Object.keys( mapping.features ).join( "," ) + ' (#' + mapping.device.id + ')</h3>'
				+	'<div class="scenes_section_delimiter"></div>'
				+	'<div class="' + _prefix + '-toolbar">'
				+		'<button type="button" class="' + _prefix + '-help"><i class="fa fa-question fa-lg text-info" aria-hidden="true"></i>&nbsp;' + Utils.getLangString( _prefix + "_help" ) + '</button>'
				+	'</div>'
				+	'<div class="' + _prefix + '-explanation ' + _prefix + '-hidden">'
				+		Utils.getLangString( _prefix + "_explanation_association" )
				+	'</div>';

		// Get compatible devices in the HA controller
		var devices = [];
		$.each( api.getListOfDevices(), function( i, luDevice ) {
			if ( luDevice.id == mapping.device.id ) {
				return;
			}
			// Check if device is an equipment with same protocol
			var isEquipment = false;
			if ( luDevice.id_parent === _deviceId ) {
				var index = _indexMappings[ luDevice.id.toString() ];
				if ( index && ( index[0].protocol == equipment.protocol ) ) {
					isEquipment = true;
				}
			}
			// Check if device is compatible
			var isCompatible = false;
			for ( var j = 0; j < luDevice.states.length; j++ ) {
				if ( ( luDevice.states[j].service === SWP_SID ) || ( luDevice.states[j].service === SWD_SID ) ) {
					// Device can be switched or dimmed
					isCompatible = true;
					break;
				}
			}
			if ( !isEquipment && !isCompatible ) {
				return;
			}
			
			var room = ( luDevice.room ? api.getRoomObject( luDevice.room ) : null );
			if ( isEquipment ) {
				devices.push( {
					"id": luDevice.id,
					"roomName": ( room ? room.name : "_No room" ),
					"name": "(" + _prefix + ") " + luDevice.name,
					"type": 3,
					"isEquipment": isEquipment
				} );
			} else {
				devices.push( {
					"id": luDevice.id,
					"roomName": ( room ? room.name : "_No room" ),
					"name": luDevice.name,
					"type": 2,
					"isEquipment": isEquipment
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
			return	'<span class="' + _prefix + '-' + pressType + '-press" title="' + pressType + ' press">'
				+		'<input type="checkbox"' + ( association && ( $.inArray( parseInt( deviceId, 10 ), association[level] ) > -1 ) ? ' checked="checked"' : '' ) + '>'
				+	'</span>';
		}

		var currentRoomName = "";
		$.each( devices, function( i, device ) {
			if ( device.roomName !== currentRoomName ) {
				currentRoomName = device.roomName;
				html += '<div class="' + _prefix + '-association-room">' +  device.roomName + '</div>';
			}
			if ( device.type === 1 ) {
				// Scene
				html += '<div class="' + _prefix + '-association ' + _prefix + '-association-scene" data-scene-id="' + device.id + '">'
					+		'<label>'
					+			_getCheckboxHtml( device.id, mapping.device.association.scenes, 0 )
					//+			_getCheckboxHtml( device.id, mapping.device.association.scenes, 1 )
					+			'&nbsp;' + device.name + ' (#' + device.id + ')'
					+		'</label>'
					+	'</div>';
			} else if ( device.type === 3 ) {
				// Declared association between equipments
				html += '<div class="' + _prefix + '-association ' + _prefix + '-association-equipment" data-device-id="' + device.id + '">'
					+		'<label>'
					+			_getCheckboxHtml( device.id, mapping.device.association.equipments, 0 )
					+			'&nbsp;' + device.name + ' (#' + device.id + ')'
					+		'</label>'
					+	'</div>';
			} else {
				// Classic device (e.g. Z-wave)
				html += '<div class="' + _prefix + '-association ' + _prefix + '-association-device" data-device-id="' + device.id + '">'
					+		'<label>'
					+			_getCheckboxHtml( device.id, mapping.device.association.devices, 0 )
					//+			_getCheckboxHtml( device.id, mapping.device.association.devices, 1 )
					+			'&nbsp;' + device.name + ' (#' + device.id + ')'
					+		'</label>'
					+	'</div>';
			}
		} );

		html += '<div class="' + _prefix + '-toolbar">'
			+		'<button type="button" class="' + _prefix + '-cancel"><i class="fa fa-times fa-lg text-danger" aria-hidden="true"></i>&nbsp;'  + Utils.getLangString( _prefix + "_cancel" ) + '</button>'
			+		'<button type="button" class="' + _prefix + '-associate"><i class="fa fa-check fa-lg text-success" aria-hidden="true"></i>&nbsp;'  + Utils.getLangString( _prefix + "_confirm" ) + '</button>'
			+	'</div>';

		$( "#" + _prefix + "-equipments-association" )
			.html( html )
			.css( {
				"display": "block"
			} );

		_formerScrollTopPosition = $( window ).scrollTop();
		$( window ).scrollTop( $( "#" + _prefix + "-known-panel" ).offset().top - 150 );
	}
	function _hideEquipmentAssociation() {
		$( "#" + _prefix + "-equipments-association" )
			.css( {
				"display": "none",
				"min-height": $( "#" + _prefix + "-known-panel" ).height()
			} );
		if ( _formerScrollTopPosition > 0 ) {
			$( window ).scrollTop( _formerScrollTopPosition );
		}
	}
	function _setEquipmentAssociation() {
		function _getEncodedAssociation() {
			var associations = [];
			// Classic device
			$("#" + _prefix + "-equipments-association ." + _prefix + "-association-device input:checked").each( function() {
				var deviceId = $( this ).parents( "." + _prefix + "-association-device" ).data( "device-id" );
				if ( $( this ).parent().hasClass( _prefix + "-long-press" ) ) {
					associations.push( "+" + deviceId );
				} else {
					associations.push( deviceId );
				}
			});
			// Scene
			$("#" + _prefix + "-equipments-association ." + _prefix + "-association-scene input:checked").each( function() {
				var sceneId = $( this ).parents( "." + _prefix + "-association-scene" ).data( "scene-id" );
				if ( $( this ).parent().hasClass( _prefix + "-long-press" ) ) {
					associations.push( "+*" + sceneId );
				} else {
					associations.push( "*" + sceneId );
				}
			});
			// Device linked to an equipment
			$("#" + _prefix + "-equipments-association ." + _prefix + "-association-equipment input:checked").each( function() {
				var deviceId = $( this ).parents( "." + _prefix + "-association-equipment" ).data( "device-id" );
				associations.push( "%" + deviceId );
			});
			return associations.join( "," );
		}

		var mapping = $( "#" + _prefix + "-equipments-actions" ).data( "mapping" );
		$.when(
			Utils.setDeviceStateVariablePersistent( mapping.device.id, PLUGIN_CHILD_SID, "Association", _getEncodedAssociation() ),
			_performActionRefresh()
		)
			.done( function() {
				_resumeEquipmentsRefresh();
				_hideEquipmentAssociation();
			});
	}

	/**
	 * Show parameters for an equipment
	 */
	function _showEquipmentParams( equipment, mapping ) {
		_stopEquipmentsRefresh();
		var settings = mapping.device.settings;
		var html = '<h1>' + Utils.getLangString( _prefix + "_param" ) + '</h1>'
				+	'<h3>' + equipment.protocol + ' - ' + equipment.id + " - " + Object.keys( mapping.features ).join( "," ) + ' (#' + mapping.device.id + ')</h3>'
				+	'<div class="scenes_section_delimiter"></div>'
				+	'<div class="' + _prefix + '-toolbar">'
				+		'<button type="button" class="' + _prefix + '-help"><i class="fa fa-question fa-lg text-info" aria-hidden="true"></i>&nbsp;' + Utils.getLangString( _prefix + "_help" ) + '</button>'
				+	'</div>'
				+	'<div class="' + _prefix + '-explanation ' + _prefix + '-hidden">'
				+		Utils.getLangString( _prefix + "_explanation_param" )
				+	'</div>';

		// Button
		html += '<h3>'
			+		_getSettingHtml({
						type: "checkbox",
						className: _prefix + "-hider",
						variable: "transmitter",
						name: "Transmitter",
						value: settings.transmitter
					})
			+	'</h3>'
			+	'<div class="' + _prefix + '-hideable"' + ( !settings.transmitter ? ' style="display: none;"' : '' ) + '>';
		$.each( [ [ 'pulse', 'Pulse' ], [ 'toggle', 'Toggle' ] ], function( i, param ) {
			html += _getSettingHtml({
				type: "checkbox",
				variable: param[0],
				name: param[1],
				value: settings[ param[0] ]
			});
		});
		html += '</div>';

		// Receiver
		html += '<h3>'
			+		_getSettingHtml({
						type: "checkbox",
						className: _prefix + "-hider",
						variable: "receiver",
						name: "Receiver",
						value: settings.receiver
					})
			+	'</h3>'
			+	'<div class="' + _prefix + '-hideable"' + ( !settings.receiver ? ' style="display: none;"' : '' ) + '>';
		$.each( [ [ 'qualifier', 'Qualifier' ], [ 'burst', 'Burst' ] ], function( i, param ) {
			html += _getSettingHtml({
				type: "string",
				variable: param[0],
				name: param[1],
				value: settings[ param[0] ]
			});
		});
		html += '</div>';

		// Specific
		var specificHtml = '';
		$.each( settings, function( paramName, paramValue ) {
			if ( $.inArray( paramName, [ 'transmitter', 'pulse', 'toggle', 'receiver', 'qualifier', 'burst' ] ) === -1 ) {
				specificHtml += _getSettingHtml({
					type: ( ( typeof paramValue == "boolean" ) ? "checkbox" : "string" ),
					isReadOnly: true,
					variable: paramName,
					name: paramName,
					value: paramValue
				});
			}
		});
		if ( specificHtml != '' ) {
			html += '<h3>'
			+			'<div class="' + _prefix + '-setting ui-widget-content ui-corner-all">'
			+				'Specific'
			+			'</div>'
			+		'</h3>'
			+		specificHtml;
		}

		html += '<div class="' + _prefix + '-toolbar">'
			+		'<button type="button" class="' + _prefix + '-cancel"><i class="fa fa-times fa-lg text-danger" aria-hidden="true"></i>&nbsp;' + Utils.getLangString( _prefix + "_cancel" ) + '</button>'
			+		'<button type="button" class="' + _prefix + '-set"><i class="fa fa-check fa-lg text-success" aria-hidden="true"></i>&nbsp;'  + Utils.getLangString( _prefix + "_confirm" ) + '</button>'
			+	'</div>';

		$( "#" + _prefix + "-equipments-params" )
			.html( html )
			.data( 'device', mapping.device )
			.css( {
				"display": "block",
				"min-height": $( "#" + _prefix + "-known-panel" ).height()
			} )
			.on( "change", "." + _prefix + "-hider", function() {
				var hasToBeVisible = $( this ).is( ':checkbox' ) ? $( this ).is( ':checked' ) : true;
				$( this ).parent().parent()
					.next( "." + _prefix + "-hideable" )
						.css({ 'display': ( hasToBeVisible ? "block": "none" ) });
			});

		_formerScrollTopPosition = $( window ).scrollTop();
		$( window ).scrollTop( $( "#" + _prefix + "-known-panel" ).offset().top - 150 );
	}
	function _hideEquipmentParams() {
		$( "#" + _prefix + "-equipments-params" )
			.css( {
				"display": "none"
			} );
		if ( _formerScrollTopPosition > 0 ) {
			$( window ).scrollTop( _formerScrollTopPosition );
		}
	}
	function _setEquipmentParams() {
		var device = $( "#" + _prefix + "-equipments-params" ).data( "device" );
		device.settings = {};
		$( "#" + _prefix + "-equipments-params ." + _prefix + "-setting-value:visible" ).each( function() {
			var settingName = $( this ).data( "setting" );
			var settingValue = $( this ).is( ":checkbox" ) ? $( this ).is( ":checked" ) : $( this ).val();
			if ( settingName && ( settingValue !== "" ) ) {
				device.settings[ settingName ] = settingValue;
			}
		});
		var setting = $.map( device.settings, function( value, key ) {
			if ( typeof value == "boolean" ) {
				return ( value === true ) ? key : null;
			} else {
				return key + "=" + value;
			}
		});
		$.when(
			Utils.setDeviceStateVariablePersistent( device.id, PLUGIN_CHILD_SID, "Setting", setting.join( "," ) ),
			_performActionRefresh()
		)
			.done( function() {
				_resumeEquipmentsRefresh();
				_hideEquipmentParams();
			});
	}

	/**
	 * Show equipments
	 */
	function _showEquipments( deviceId ) {
		if ( deviceId ) {
			_deviceId = deviceId;
		}
		try {
			$.when( _loadResourcesAsync(), _loadLocalizationAsync() ).then( function() {
				api.setCpanelContent(
						'<div id="' + _prefix + '-known-panel" class="' + _prefix + '-panel">'
					+		'<h1>' + Utils.getLangString( _prefix + "_managed_equipments" ) + '</h1>'
					+		'<div class="scenes_section_delimiter"></div>'
					+		'<div class="' + _prefix + '-toolbar">'
					+			'<button type="button" class="' + _prefix + '-help"><i class="fa fa-question fa-lg text-info" aria-hidden="true"></i>&nbsp;' + Utils.getLangString( _prefix + "_help" ) + '</button>'
					//+			'<button type="button" class="' + _prefix + '-add"><i class="fa fa-plus fa-lg text-info" aria-hidden="true"></i>&nbsp;' + Utils.getLangString( _prefix + "_add" ) + '</button>'
					+			'<button type="button" class="' + _prefix + '-refresh"><i class="fa fa-refresh fa-lg" aria-hidden="true"></i>&nbsp;' + Utils.getLangString( _prefix + "_refresh" ) + '</button>'
					+		'</div>'
					+		'<div class="' + _prefix + '-explanation ' + _prefix + '-hidden">'
					+			Utils.getLangString( _prefix + "_explanation_known_equipments" )
					+		'</div>'
					+		'<div id="' + _prefix + '-known-equipments" class="' + _prefix + '-equipments">'
					+			Utils.getLangString( _prefix + "_loading" )
					+		'</div>'
					+		'<div id="' + _prefix + '-equipments-actions" style="display: none;"></div>'
					+		'<div id="' + _prefix + '-equipments-association" style="display: none;"></div>'
					+		'<div id="' + _prefix + '-equipments-params" style="display: none;"></div>'
					+	'</div>'
				);

				// Manage UI events
				$( "#" + _prefix + "-known-panel" )
					.on( "click", "." + _prefix + "-help", function() {
						$( this ).parent().next( "." + _prefix + "-explanation" ).toggleClass( _prefix + "-hidden" );
					} )
					.on( "click", "." + _prefix + "-refresh", function() {
						$.when( _performActionRefresh() )
							.done( function() {
								_drawEquipmentsList();
							});
					} )
					//.on( "click", "." + _prefix + "-add", function() { _showAddEquipment(); } )
					.click( function() {
						$( "#" + _prefix + "-equipments-actions" ).css( "display", "none" );
					} )
					.on( "click", "." + _prefix + "-device-actions", function( e ) {
						var position = $( this ).offset();
						position.left += $( this ).outerWidth() / 2;
						position.top += $( this ).outerHeight() / 2;
						_selectedDeviceId = $( this ).data( "device-id" );
						var index = _indexMappings[ _selectedDeviceId ];
						if ( index ) {
							var equipment = index[0];
							var mapping   = index[1];
							_showEquipmentActions( position, equipment, mapping );
						}
						e.stopPropagation();
					} )
					.on( "click", "." + _prefix + "-show-association", function() {
						var $actions = $( this ).parents( "#" + _prefix + "-equipments-actions" );
						_showEquipmentAssociation( $actions.data( "equipment" ), $actions.data( "mapping" ) );
					} )
					.on( "click", "." + _prefix + "-show-params", function() {
						var $actions = $( this ).parents( "#" + _prefix + "-equipments-actions" );
						_showEquipmentParams( $actions.data( "equipment" ), $actions.data( "mapping" ) );
					} )
					.on( "click", "." + _prefix + "-cancel", function() {
						_hideEquipmentAssociation();
						_hideEquipmentParams();
						_resumeEquipmentsRefresh();
					} )
					// Association event
					.on( "click", "." + _prefix + "-associate", _setEquipmentAssociation )
					// Parameters event
					.on( "click", "." + _prefix + "-set", _setEquipmentParams )
					// Teach (receiver) event
					.on( "click", "." + _prefix + "-teach", function() {
						var $actions = $( this ).parents( "#" + _prefix + "-equipments-actions" );
						var equipment = $actions.data( "equipment" );
						api.ui.showMessagePopup( Utils.getLangString( _prefix + "_confirmation_teach_in_receiver" ), 4, 0, {
							onSuccess: function() {
								_performActionTeachIn( equipment.protocol + ";" + equipment.id, "ON", "" );
								return true;
							}
						});
					} )
					// Clear (receiver) event
					.on( "click", "." + _prefix + "-clear", function() {
						var $actions = $( this ).parents( "#" + _prefix + "-equipments-actions" );
						var equipment = $actions.data( "equipment" );
						api.ui.showMessagePopup( Utils.getLangString( _prefix + "_confirmation_clearing_receiver" ), 4, 0, {
							onSuccess: function() {
								_performActionClear( equipment.protocol + ";" + equipment.id );
								return true;
							}
						});
					} );

				// Show equipments infos
				_drawEquipmentsList();
			});
		} catch (err) {
			Utils.logError( "Error in " + _pluginName + ".showEquipments(): " + err );
		}
	}

	// *************************************************************************************************
	// Add equipment
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
	 * Draw and manage add equipment
	 */
	function _drawAddEquipment() {
		$.when( _getProtocolsInfosAsync() )
			.done( function( protocolsInfos ) {
				var html = 	'<h3>' + Utils.getLangStringFormat( _prefix + "_add_new_equipment_step", 1 ) + ': ' + Utils.getLangString( _prefix + "_add_new_equipment_settings_title" ) + '</h3>'
					+		'<div class="' + _prefix + '-setting ui-widget-content ui-corner-all">'
					+			'<span>' + Utils.getLangString( _prefix + "_protocol" ) + '</span>'
					+			'<select id="' + _prefix + '-setting-protocol" class="' + _prefix + '-setting-value" data-variable="protocol">'
					+				'<option value="">-- ' + Utils.getLangString( _prefix + "_protocol" ) + ' --</option>';
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
					+		'<div class="' + _prefix + '-setting ui-widget-content ui-corner-all">'
					+			'<span>' + Utils.getLangString( _prefix + "_equipment_name" ) + '</span>'
					+			'<input type="text" class="' + _prefix + '-setting-value" data-variable="deviceName" placeholder="' + Utils.getLangString( _prefix + "_enter_name" ) + '">'
					+		'</div>'
					+		'<div class="' + _prefix + '-setting ui-widget-content ui-corner-all">'
					+			'<span>Id</span>'
					+			'<input type="text" id="' + _prefix + '-setting-equipment-id" class="' + _prefix + '-setting-value" data-variable="equipmentId" placeholder="' + Utils.getLangString( _prefix + "_enter_id" ) + '">'
					+			'&nbsp;'
					+			'<select id="' + _prefix + '-setting-equipment-group">'
					+				'<option value=""></option>'
					+			'</select>'
					+			'<select id="' + _prefix + '-setting-equipment-unit">'
					+				'<option value=""></option>'
					+			'</select>'
					+		'</div>'
					+		'<div id="' + _prefix + '-protocol-settings"></div>'
					+		'<div id="' + _prefix + '-protocol-validation"></div>';
				$( "#" + _prefix + "-add-equipment" ).html( html );

				for ( var i = 65; i < 81; i++) { 
					$( "#" + _prefix + "-setting-equipment-group" ).append( $( "<option>", {
						value: String.fromCharCode( i ),
						text : String.fromCharCode( i )
					}));
				}
				for ( var i = 1; i < 17; i++) { 
					$( "#" + _prefix + "-setting-equipment-unit" ).append( $( "<option>", {
						value: i,
						text : i
					}));
				}

				$( "#" +_prefix + "-setting-protocol" ).change( function() {
					var protocolName = $(this).val();
					var protocolInfos = protocolsInfos[ protocolName ];
					if ( typeof protocolInfos != "undefined") {
						_drawProtocolSettings( protocolInfos.deviceTypes || [], protocolInfos.deviceSettings || [], protocolInfos.protocolSettings || {} );
					}
					_drawProtocolValidation( protocolName );
				});
				$( "#" + _prefix + "-setting-equipment-id" ).change( function() {
					var id = parseInt( $( this ).val(), 10 );
					$( "#" + _prefix + "-setting-equipment-group" ).val( String.fromCharCode( Math.floor( id / 16) + 65 ) );
					$( "#" + _prefix + "-setting-equipment-unit" ).val( (id % 16 + 1).toString() );
				});
				$( "#" + _prefix + "-setting-equipment-group" ).change( function() {
					var group = $( this ).val().charCodeAt( 0 ) - 65;
					var unit = parseInt( $( "#" + _prefix + "-setting-equipment-unit" ).val(), 10 );
					if ( ( group >= 0 ) && unit ) {
						$( "#" + _prefix + "-setting-equipment-id" ).val( group * 16  + ( unit - 1 ) );
					}
				});
				$( "#" + _prefix + "-setting-equipment-unit" ).change( function() {
					var group = $( "#" + _prefix + "-setting-equipment-group" ).val().charCodeAt( 0 ) - 65;
					var unit = parseInt( $( this ).val(), 10 );
					if ( ( group >= 0 ) && unit ) {
						$( "#" + _prefix + "-setting-equipment-id" ).val( group * 16  + ( unit - 1 ) );
					}
				});
			} );
	}

	/**
	 * Draw and manage the protocol settings
	 */
	function _drawProtocolSettings( deviceTypes, deviceSettings, protocolSettings ) {
		var html = '';

		// Linked device type
		var deviceTypeParams = {};
		if ( ( deviceTypes == undefined ) || ( deviceTypes.length === 0 ) ) {
			deviceTypes = [ "BINARY_LIGHT" ];
		}
		html +=	'<div class="' + _prefix + '-setting ui-widget-content ui-corner-all">'
			+		'<span>' + Utils.getLangString( _prefix + "_device_type" ) + '</span>'
			+		'<select id="' + _prefix + '-setting-device-type" class="' + _prefix + '-setting-value" data-variable="deviceType">'
			+			'<option value="">-- ' + Utils.getLangString( _prefix + "_select_device_type" ) + ' --</option>';
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
			+	'<div style="display:none" class="' + _prefix + '-setting-value" data-settings="' + deviceSettings.join(",") + '"></div>'
			+ '</div>';

		// Protocol settings
		$.each( protocolSettings, function( i, setting ) {
			html += _getSettingHtml( setting );
		} );

		$("#" + _prefix + "-protocol-settings").html( html );

		$( '#' + _prefix + '-setting-device-type' ).change( function() {
			var deviceType = $(this).val();
			$.each( deviceTypeParams[ deviceType ], function( key, value ) {
				$( '#' + _prefix + '-add-equipment-panel .' + _prefix + '-setting-value[data-setting="' + key + '"]' ).val( value );
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
			html = '<h3>' + Utils.getLangStringFormat( _prefix + "_add_new_equipment_step", step ) + ': ' + Utils.getLangString( _prefix + "_add_new_equipment_teach_title" ) + '</h3>'
				+		'<div>'
				+		( protocolName === "PARROT" ? Utils.getLangString( _prefix + "_add_new_equipment_teach_parrot_explanation" ) : Utils.getLangString( _prefix + "_add_new_equipment_teach_explanation" ) )
				+		'</div>'
				+		'<div>'
				+			'<button type="button" class="' + _prefix + '-teach">' + Utils.getLangString( _prefix + "_teach" ) + '</button>'
				+		'</div>';
			if ( protocolName !== "PARROT" ) {
				step = 3;
				html +=	'<h3>' + Utils.getLangStringFormat( _prefix + "_add_new_equipment_step", step ) + ': ' + Utils.getLangString( _prefix + "_add_new_equipment_test_title" ) + '</h3>'
					+	'<div>' + Utils.getLangString( _prefix + "_add_new_equipment_test_explanation" ) + '</div>'
					+	'<div>'
					+		'<button type="button" class="' + _prefix + '-test-on">ON</button>'
					+		'<button type="button" class="' + _prefix + '-test-off">OFF</button>'
					+	'</div>';
			}
			step++;
			html +=		'<h3>' + Utils.getLangStringFormat( _prefix + "_add_new_equipment_step", step ) + ': ' + Utils.getLangString( _prefix + "_add_new_equipment_validate_title" ) + '</h3>'
				+		'<div>' + Utils.getLangString( _prefix + "_add_new_equipment_validate_explanation" ) + '</div>'
				+		'<div>'
				+			'<button type="button" class="' + _prefix + '-create">' + Utils.getLangString( _prefix + "_create" ) + '</button>'
				+		'</div>';
		}
		$("#" + _prefix + "-protocol-validation").html( html );
	}

	/**
	 *
	 */
	function _getSettings() {
		var settings = { settings: [] };
		$( '#' + _prefix + '-add-equipment-panel .' + _prefix + '-setting-value' ).each( function() {
			var variableName = $( this ).data( 'variable' );
			if ( variableName ) {
				settings[ variableName ] = $( this ).val();
			}
			var settingName = $( this ).data( 'setting' );
			if ( settingName ) {
				settings.settings.push( settingName + "=" + $( this ).val() );
			}
			var settingsName = $( this ).data( 'settings' );
			if ( settingsName ) {
				$.extend( settings.settings, settingsName.split( "," ) );
			}
		});
		settings.settings = settings.settings.join( "," );
		if ( !settings.protocol ) {
			api.ui.showMessagePopup( "You have to choose a protocol.", 2, 0 );
			return false;
		} else if ( !settings.equipmentId ) {
			api.ui.showMessagePopup( "You have to set the equipment id.", 2, 0 );
			return false;
		} else if ( !settings.deviceName ) {
			api.ui.showMessagePopup( "You have to set the linked device name.", 2, 0 );
			return false;
		} else if ( !settings.deviceType ) {
			api.ui.showMessagePopup( "You have to choose the linked device type.", 2, 0 );
			return false;
		}
		return settings;
	}

	/**
	 * Show add equipment
	 */
	function _showAddEquipment( deviceId ) {
		if ( deviceId ) {
			_deviceId = deviceId;
		}
		try {
			$.when( _loadResourcesAsync(), _loadLocalizationAsync() ).then( function() {
				var hasTeachingBeenDone = false;
				api.setCpanelContent(
						'<div id="' + _prefix + '-add-equipment-panel" class="' + _prefix + '-panel">'
					+		'<h1>' + Utils.getLangString( _prefix + "_add_new_equipment" ) + '</h1>'
					+		'<div class="scenes_section_delimiter"></div>'
					+		'<div id="' + _prefix + '-add-equipment">'
					+			Utils.getLangString( _prefix + "_loading" )
					+		'</div>'
					+	'</div>'
				);

				$( "#" + _prefix + "-add-equipment-panel" )
					.on( "click", "." + _prefix + "-teach", function() {
						var settings = _getSettings();
						if ( settings ) {
							var $that = $( this ).addClass( "highlighted" );
							$.when( _performActionTeachIn( settings.protocol + ";" + settings.equipmentId, settings.action, settings.message ) )
								.done( function() { hasTeachingBeenDone = true; } )
								.then( function() { $that.removeClass( "highlighted" ); } );
						}
					})
					.on( "click", "." + _prefix + "-test-on", function() {
						var settings = _getSettings();
						if ( settings ) {
							var $that = $( this ).addClass( "highlighted" );
							$.when( _performActionSetTarget( settings.protocol + ";" + settings.equipmentId + ( settings.qualifier ? ";" + settings.qualifier : "" ), "1" ) )
								.then( function() { $that.removeClass( "highlighted" ); } );
						}
					})
					.on( "click", "." + _prefix + "-test-off", function() {
						var settings = _getSettings();
						if ( settings ) {
							var $that = $( this ).addClass( "highlighted" );
							$.when( _performActionSetTarget( settings.protocol + ";" + settings.equipmentId + ( settings.qualifier ? ";" + settings.qualifier : "" ), "0" ) )
								.then( function() { $that.removeClass( "highlighted" ); } );
						}
					})
					.on( "click", "." + _prefix + "-create", function() {
						var $that = $( this );
						var d = $.Deferred();
						var settings = _getSettings();
						if ( !hasTeachingBeenDone ) {
							api.ui.showMessagePopup( Utils.getLangString( _prefix + "_warning_teach_in_not_done" ), 4, 0, {
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
								// Create linked device
								$that.addClass( "highlighted" );
								$.when( _performActionCreateDevices( [ settings ] ) )
									.done( function() {
										$that.removeClass( "highlighted" );
										_showReload( Utils.getLangString( _prefix + "_device_has_been_created" ), function() {
											_showEquipments();
										});
									});
							});
					});

				_drawAddEquipment();
			});
		} catch (err) {
			Utils.logError('Error in ' + _pluginName + '.showAddEquipment(): ' + err);
		}
	}

	// *************************************************************************************************
	// Discovered equipments
	// *************************************************************************************************

	function _stopDiscoveredEquipmentsRefresh() {
		if ( _discoveredEquipmentsTimeout ) {
			window.clearTimeout( _discoveredEquipmentsTimeout );
		}
		_discoveredEquipmentsTimeout = null;
	}
	function _resumeDiscoveredEquipmentsRefresh() {
		if ( _discoveredEquipmentsTimeout == null ) {
			var timeout = 3000 - ( Date.now() - _discoveredEquipmentsLastRefresh );
			if ( timeout < 0 ) {
				timeout = 0;
			}
			_discoveredEquipmentsTimeout = window.setTimeout( _drawDiscoveredEquipmentsList, timeout );
		}
	}

	/**
	 * Draw and manage discovered equipments list
	 */
	function _drawDiscoveredEquipmentsList() {
		_stopDiscoveredEquipmentsRefresh();
		if ( $( "#" + _prefix + "-discovered-equipments" ).length === 0 ) {
			// The panel is no more here
			return;
		}
		if ( !$( "#" + _prefix + "-discovered-equipments" ).is( ":visible" ) ) {
			// The panel is hidden
			_discoveredEquipmentsLastRefresh = Date.now();
			_resumeDiscoveredEquipmentsRefresh();
			return;
		}
		$.when( _getEquipmentsInfosAsync() )
			.done( function( infos ) {
				if ( infos.discoveredEquipments.length > 0 ) {
					// Sort the discovered equipments by last update
					infos.discoveredEquipments.sort( function( e1, e2 ) {
						return e2.lastUpdate - e1.lastUpdate;
					});
					var html =	'<table><tr>'
						+			'<th>' + Utils.getLangString( _prefix + "_protocol" ) + '</th>'
						+			'<th>' + Utils.getLangString( _prefix + "_id" ) + '</th>' // TODO : Frequency ?
						+			'<th>' + Utils.getLangString( _prefix + "_signal_quality" ) + '</th>'
						+			'<th>' + Utils.getLangString( _prefix + "_last_update" ) + '</th>'
						+			'<th>' + Utils.getLangString( _prefix + "_feature" ) + '</th>'
						+		'</tr>';
					$.each( infos.discoveredEquipments, function( i, discoveredEquipment ) {
						html += '<tr class="' + _prefix + '-discovered-equipment">'
							+		'<td class="' + _prefix + '-protocol-name">' + discoveredEquipment.protocol + '</td>'
							+		'<td class="' + _prefix + '-protocol-id">' + discoveredEquipment.id + '</td>'
							+		'<td>' + ( discoveredEquipment.quality >= 0 ? discoveredEquipment.quality : '' ) + '</td>'
							+		'<td>' + _convertTimestampToLocaleString( discoveredEquipment.lastUpdate ) + '</td>'
							+		'<td>'
							+			'<div class="font-weight-bold">' + discoveredEquipment.name + '</div>';
						if ( discoveredEquipment.comment ) {
							html +=		'<div>' + discoveredEquipment.comment + '</div>';
						}
						$.each( discoveredEquipment.modelings, function( j, modeling ) {
							if ( modeling.isUsed === false ) {
								return;
							}
							html +=		'<div class="' + _prefix + '-equipment-modeling" data-protocol="' + discoveredEquipment.protocol + '" data-equipment-id="' + discoveredEquipment.id + '">'
								+			'<div class="' + _prefix + '-modeling-select">'
								+				'<input type="checkbox">'
								+			'</div>'
								+			'<div class="' + _prefix + '-equipment-mappings">';
							$.each( modeling.mappings, function( j, mapping ) {
								if ( mapping.isUsed === false ) {
									return;
								}
								var featureNames = [];
								html +=			'<div class="' + _prefix + '-equipment-mapping">'
									+				'<div class="' + _prefix + '-features">';
								$.each( mapping.features, function( featureName, feature ) {
									if ( feature.isUsed === false ) {
										return;
									}
									featureNames.push( featureName );
									html +=				'<div class="' + _prefix + '-feature">'
										+					'<span class="' + _prefix + '-feature-name">' + featureName + '</span>'
										+					( feature.state ? '<span class="' + _prefix + '-feature-state">' + feature.state + '</span>' : '' )
										+				'</div>';
								});
								html +=				'</div>'
									+				'<div class="' + _prefix + '-device-type" data-feature-names="' + featureNames.join(",") + '" data-settings="' + ( mapping.settings ? mapping.settings.join(",") : "" ) + '">';
								if ( mapping.deviceTypes ) {
									if ( mapping.deviceTypes.length > 1 ) {
										html +=			'<select>';
										$.each( mapping.deviceTypes, function( k, deviceType ) {
											html +=			'<option value="' + deviceType + '">' + deviceType + '</option>';
										} );
										html +=			'</select>';
									} else {
										html +=	mapping.deviceTypes[0];
									}
								}
								html +=				'</div>'
									+			'</div>';
							});
							html +=			'</div>'
								+		'</div>';
						});
						html +=		'</td>'
							+	'</tr>';
					});
					html += '</table>';
					$("#" + _prefix + "-discovered-equipments").html( html );
				} else {
					$("#" + _prefix + "-discovered-equipments").html( Utils.getLangString( _prefix + "_no_discovered_equipment" ) );
				}
				_discoveredEquipmentsLastRefresh = Date.now();
				_resumeDiscoveredEquipmentsRefresh();
			} );
	}

	/**
	 * Show discovered equipments
	 */
	function _showDiscoveredEquipments( deviceId ) {
		if ( deviceId ) {
			_deviceId = deviceId;
		}
		try {
			$.when( _loadResourcesAsync(), _loadLocalizationAsync() ).then( function() {
				api.setCpanelContent(
						'<div id="' + _prefix + '-discovered-panel" class="' + _prefix + '-panel">'
					+		'<h1>' + Utils.getLangString( _prefix + "_discovered_equipments" ) + '</h1>'
					+		'<div class="scenes_section_delimiter"></div>'
					+		'<div class="' + _prefix + '-toolbar">'
					+			'<button type="button" class="' + _prefix + '-help"><i class="fa fa-question fa-lg text-info" aria-hidden="true"></i>&nbsp;' + Utils.getLangString( _prefix + "_help" ) + '</button>'
					//+			'<button type="button" class="' + _prefix + '-ignore"><span class="icon icon-ignore"></span>' + Utils.getLangString( _prefix + "_ignore" ) + '</button>'
					+			'<button type="button" class="' + _prefix + '-refresh" style="display: none"><span class="icon icon-refresh"></span>' + Utils.getLangString( _prefix + "_refresh" ) + '</button>'
					+			'<button type="button" class="' + _prefix + '-learn"><i class="fa fa-plus fa-lg" aria-hidden="true"></i>&nbsp;' + Utils.getLangString( _prefix + "_learn" ) + '</button>'
					+		'</div>'
					+		'<div class="' + _prefix + '-explanation ' + _prefix + '-hidden">'
					+			Utils.getLangString( _prefix + "_explanation_discovered_equipments" )
					+		'</div>'
					+		'<div id="' + _prefix + '-discovered-equipments" class="' + _prefix + '-equipments">'
					+			Utils.getLangString( _prefix + "_loading" )
					+		'</div>'
					+	'</div>'
				);

				function _getSelectedMappings() {
					var mappings = [];
					$( "#" + _prefix + "-discovered-equipments input:checked:visible" ).each( function() {
						var $modeling = $( this ).parents( "." + _prefix + "-equipment-modeling" );
						var protocol = $modeling.data( "protocol" );
						var equipmentId = $modeling.data( "equipment-id" );
						$modeling.find( "." + _prefix + "-device-type" )
							.each( function( index ) {
								var $select = $( this ).find( "select" );
								mappings.push({
									protocol: protocol,
									equipmentId: equipmentId,
									deviceType: ( ( $select.length > 0 ) ? $select.val() : $( this ).text() ),
									featureNames: $( this ).data( "feature-names" ).split( "," ),
									settings: $( this ).data( "settings" ).split( "," )
								});
							});
					});
					return mappings;
				}

				// Manage UI events
				$( "#" + _prefix + "-discovered-panel" )
					.on( "click", "." + _prefix + "-help", function() {
						$( "." + _prefix + "-explanation" ).toggleClass( _prefix + "-hidden" );
					} )
					.on( "click", "." + _prefix + "-learn", function( e ) {
						var mappings = _getSelectedMappings();
						if ( mappings.length === 0 ) {
							api.ui.showMessagePopup( Utils.getLangString( _prefix + "_select_equipment" ), 1 );
						} else {
							api.ui.showMessagePopup( Utils.getLangString( _prefix + "_confirmation_learning_equipments" ) + " <pre>" + JSON.stringify( mappings, undefined, 2 ) + "</pre>", 4, 0, {
								onSuccess: function() {
									$.when( _performActionCreateDevices( mappings ) )
										.done( function() {
											_showReload( Utils.getLangString( _prefix + "_devices_have_been_created" ), function() {
												_showEquipments();
											});
										});
									return true;
								}
							});
						}
					} )
					.on( "click", "." + _prefix + "-ignore", function( e ) {
						alert( "TODO" );
					})
					.on( "focus", "select", function( e ) {
						_stopDiscoveredEquipmentsRefresh();
					})
					.on( "blur", "select", function( e ) {
						if ( $( "#" + _prefix + "-discovered-panel input:checked" ).length === 0 ) {
							_resumeDiscoveredEquipmentsRefresh();
						}
					})
					.on( "change", "select", function( e ) {
						if ( $( "#" + _prefix + "-discovered-panel input:checked" ).length === 0 ) {
							_resumeDiscoveredEquipmentsRefresh();
						}
					})
					.on( "change", "input:checkbox", function( e ) {
						if ( $( "#" + _prefix + "-discovered-panel input:checked" ).length > 0 ) {
							_stopDiscoveredEquipmentsRefresh();
						} else {
							_resumeDiscoveredEquipmentsRefresh();
						}
					})
					;

				// Show discovered equipments infos
				_drawDiscoveredEquipmentsList();
			});
		} catch (err) {
			Utils.logError( "Error in " + _pluginName + ".showDiscoveredEquipments(): " + err );
		}
	}

	// *************************************************************************************************
	// Actions
	// *************************************************************************************************

	/**
	 * 
	 */
	function _performActionRefresh() {
		Utils.logDebug( "[" + _pluginName + ".performActionRefresh] Refresh the list of equipments" );
		return Utils.performActionOnDevice(
			_deviceId, PLUGIN_SID, "Refresh", {
				output_format: "json"
			}
		);
	}

	/**
	 * Create devices linked to an equipment
	 */
	function _performActionCreateDevices( mappings ) {
		var jsonMappings = JSON.stringify( mappings );
		Utils.logDebug( "[" + _pluginName + ".performActionCreateDevices] Create devices '" + jsonMappings + "'" );
		return Utils.performActionOnDevice(
			_deviceId, PLUGIN_SID, "CreateDevices", {
				output_format: "json",
				mappings: encodeURIComponent( jsonMappings )
			}
		);
	}

	/**
	 * 
	 */
	function _performActionTeachIn( productId, action, comment ) {
		Utils.logDebug( "[" + _pluginName + ".performActionTeachIn] Teach in equipment '" + productId + "', action: " + action + ", comment: " + comment );
		return Utils.performActionOnDevice(
			_deviceId, PLUGIN_SID, "TeachIn", {
				output_format: "json",
				productId: productId,
				action: action,
				comment: encodeURIComponent( comment )
			}
		);
	}

	/**
	 * Associate equipment to Vera devices
	 */
	function _performActionAssociate( productId, featureName, encodedAssociation ) {
		Utils.logDebug( "[" + _pluginName + ".performActionAssociate] Associate equipment product/feature '" + productId + "/" + featureName + "' with " + encodedAssociation );
		return Utils.performActionOnDevice(
			_deviceId, PLUGIN_SID, "Associate", {
				output_format: "json",
				productId: productId,
				feature: featureName,
				association: encodeURIComponent( encodedAssociation )
			}
		);
	}

	/**
	 * Test ON/OFF on newly created equipment (before validating)
	 */
	function _performActionSetTarget( productId, targetValue ) {
		Utils.logDebug( "[" + _pluginName + "._performActionSetTarget] Set target for equipment '" + productId + " to " + targetValue );
		return Utils.performActionOnDevice(
			_deviceId, PLUGIN_SID, "SetTarget", {
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
			url: Utils.getDataRequestURL() + "id=lr_" + _pluginName + "&command=getErrors&output_format=json#",
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
		if ( $( "#" + _prefix + "-errors" ).length === 0 ) {
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
					$( "#" + _prefix + "-errors" ).html( html );
				} else {
					$( "#" + _prefix + "-errors" ).html( Utils.getLangString( _prefix + "_no_error" ) );
				}
			} );
	}

	/**
	 * Show errors tab
	 */
	function _showErrors( deviceId ) {
		_deviceId = deviceId;
		try {
			$.when( _loadResourcesAsync(), _loadLocalizationAsync() ).then( function() {
				api.setCpanelContent(
						'<div id="' + _prefix + '-errors-panel" class="' + _prefix + '-panel">'
					+		'<h1>' + Utils.getLangString( _prefix + "_errors" ) + '</h1>'
					+		'<div class="scenes_section_delimiter"></div>'
					+		'<div class="' + _prefix + '-toolbar">'
					+			'<button type="button" class="' + _prefix + '-help"><i class="fa fa-question fa-lg text-info" aria-hidden="true"></i>&nbsp;' + Utils.getLangString( _prefix + "_help" ) + '</button>'
					+		'</div>'
					+		'<div class="' + _prefix + '-explanation ' + _prefix + '-hidden">'
					+			Utils.getLangString( _prefix + "_explanation_errors" )
					+		'</div>'
					+		'<div id="' + _prefix + '-errors">'
					+			Utils.getLangString( _prefix + "_loading" )
					+		'</div>'
					+	'</div>'
				);
				// Manage UI events
				$( "#" + _prefix + "-errors-panel" )
					.on( "click", "." + _prefix + "-help" , function() {
						$( "." + _prefix + "-explanation" ).toggleClass( _prefix + "-hidden" );
					} );
				// Display the errors
				_drawErrorsList();
			});
		} catch ( err ) {
			Utils.logError( "Error in " + _pluginName + ".showErrors(): " + err );
		}
	}

	// *************************************************************************************************
	// Donate
	// *************************************************************************************************

	function _showDonate( deviceId ) {
		var donateHtml = '\
<form action="https://www.paypal.com/cgi-bin/webscr" method="post" target="_blank">\
<input type="hidden" name="cmd" value="_s-xclick">\
<input type="hidden" name="encrypted" value="-----BEGIN PKCS7-----MIIHTwYJKoZIhvcNAQcEoIIHQDCCBzwCAQExggEwMIIBLAIBADCBlDCBjjELMAkGA1UEBhMCVVMxCzAJBgNVBAgTAkNBMRYwFAYDVQQHEw1Nb3VudGFpbiBWaWV3MRQwEgYDVQQKEwtQYXlQYWwgSW5jLjETMBEGA1UECxQKbGl2ZV9jZXJ0czERMA8GA1UEAxQIbGl2ZV9hcGkxHDAaBgkqhkiG9w0BCQEWDXJlQHBheXBhbC5jb20CAQAwDQYJKoZIhvcNAQEBBQAEgYCigjq4i0t0zXMdULAXk7WPx1vVEU3xxwi6USOGwZQuDuFF1d6pAkLb/4aXN/yDBlQ6yzEvhSMQfsDDQIwE+OVcI91zhRi2GqR0L0c16KfVYEjK52VHQ23JgLsWG2Sb77K3VEm7sv2hNF9J8esQJ4JYIc+hTU/LFUIC4nmTo1zNwTELMAkGBSsOAwIaBQAwgcwGCSqGSIb3DQEHATAUBggqhkiG9w0DBwQIuRwucTVfzraAgahE8C5njLNiEQlFYV7cJrKKmXhMywmNLwqG/QlEj9cppo9tS3zH4E1AcghGVbPAqHf6E3ks54FuY2HcUQAuHdHKWT+VM32HKnzUu0ZTZsC4Tx1lR/NHGu0HCOnqggWnWNKlJeXig13ZyMauURiSfF/hx8j81qo+/K/qIzmZqN+kWNsKF6JiZQ/u5IkiBXNF1wNQ0t7XArNxrmcEKwJSQlvwfCQvvBxrrTagggOHMIIDgzCCAuygAwIBAgIBADANBgkqhkiG9w0BAQUFADCBjjELMAkGA1UEBhMCVVMxCzAJBgNVBAgTAkNBMRYwFAYDVQQHEw1Nb3VudGFpbiBWaWV3MRQwEgYDVQQKEwtQYXlQYWwgSW5jLjETMBEGA1UECxQKbGl2ZV9jZXJ0czERMA8GA1UEAxQIbGl2ZV9hcGkxHDAaBgkqhkiG9w0BCQEWDXJlQHBheXBhbC5jb20wHhcNMDQwMjEzMTAxMzE1WhcNMzUwMjEzMTAxMzE1WjCBjjELMAkGA1UEBhMCVVMxCzAJBgNVBAgTAkNBMRYwFAYDVQQHEw1Nb3VudGFpbiBWaWV3MRQwEgYDVQQKEwtQYXlQYWwgSW5jLjETMBEGA1UECxQKbGl2ZV9jZXJ0czERMA8GA1UEAxQIbGl2ZV9hcGkxHDAaBgkqhkiG9w0BCQEWDXJlQHBheXBhbC5jb20wgZ8wDQYJKoZIhvcNAQEBBQADgY0AMIGJAoGBAMFHTt38RMxLXJyO2SmS+Ndl72T7oKJ4u4uw+6awntALWh03PewmIJuzbALScsTS4sZoS1fKciBGoh11gIfHzylvkdNe/hJl66/RGqrj5rFb08sAABNTzDTiqqNpJeBsYs/c2aiGozptX2RlnBktH+SUNpAajW724Nv2Wvhif6sFAgMBAAGjge4wgeswHQYDVR0OBBYEFJaffLvGbxe9WT9S1wob7BDWZJRrMIG7BgNVHSMEgbMwgbCAFJaffLvGbxe9WT9S1wob7BDWZJRroYGUpIGRMIGOMQswCQYDVQQGEwJVUzELMAkGA1UECBMCQ0ExFjAUBgNVBAcTDU1vdW50YWluIFZpZXcxFDASBgNVBAoTC1BheVBhbCBJbmMuMRMwEQYDVQQLFApsaXZlX2NlcnRzMREwDwYDVQQDFAhsaXZlX2FwaTEcMBoGCSqGSIb3DQEJARYNcmVAcGF5cGFsLmNvbYIBADAMBgNVHRMEBTADAQH/MA0GCSqGSIb3DQEBBQUAA4GBAIFfOlaagFrl71+jq6OKidbWFSE+Q4FqROvdgIONth+8kSK//Y/4ihuE4Ymvzn5ceE3S/iBSQQMjyvb+s2TWbQYDwcp129OPIbD9epdr4tJOUNiSojw7BHwYRiPh58S1xGlFgHFXwrEBb3dgNbMUa+u4qectsMAXpVHnD9wIyfmHMYIBmjCCAZYCAQEwgZQwgY4xCzAJBgNVBAYTAlVTMQswCQYDVQQIEwJDQTEWMBQGA1UEBxMNTW91bnRhaW4gVmlldzEUMBIGA1UEChMLUGF5UGFsIEluYy4xEzARBgNVBAsUCmxpdmVfY2VydHMxETAPBgNVBAMUCGxpdmVfYXBpMRwwGgYJKoZIhvcNAQkBFg1yZUBwYXlwYWwuY29tAgEAMAkGBSsOAwIaBQCgXTAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0xNzAxMzEyMDU3MDFaMCMGCSqGSIb3DQEJBDEWBBRhRll+6MI5J97l2p5RAz1OII992jANBgkqhkiG9w0BAQEFAASBgHn1oHpNDr20Cy7DUpBa5SyoJbQV6UrGO6+lcCUb8g1HH2cnGoc3qtFroXXINgSNCzWGha+EIXl+UG5NlKGthCXBjaRVTDzmFxjBmx/6me/G67jqbYo0Ah/4kQEv7X2K/Amqt9Ed+rf/fIWALF/rmBRRAYuk2dt9hDk7Tr2QVAqB-----END PKCS7-----">\
<input type="image" src="https://www.paypalobjects.com/en_US/FR/i/btn/btn_donateCC_LG.gif" border="0" name="submit" alt="PayPal - The safer, easier way to pay online!">\
<img alt="" border="0" src="https://www.paypalobjects.com/fr_FR/i/scr/pixel.gif" width="1" height="1">\
</form>';
		$.when( _loadResourcesAsync(), _loadLocalizationAsync() ).then( function() {
			api.setCpanelContent(
					'<div id="' + _prefix + '-donate-panel" class="' + _prefix + '-panel">'
				+		'<div id="' + _prefix + '-donate">'
				+			'<span>' + Utils.getLangString( _prefix + "_donate" ) + '</span>'
				+			donateHtml
				+		'</div>'
				+	'</div>'
			);
		});
	}

	// *************************************************************************************************
	// Main
	// *************************************************************************************************

	myModule = {
		uuid: _uuid,
		showSettings: _showSettings,
		showAddEquipment: _showAddEquipment,
		showEquipments: _showEquipments,
		showDiscoveredEquipments: _showDiscoveredEquipments,
		showErrors: _showErrors,
		showDonate: _showDonate,

		ALTUI_drawDevice: function( device ) {
			var version = MultiBox.getStatus( device, PLUGIN_SID, "PluginVersion" );
			return '<div class="panel-content">'
				+		'<div class="btn-group" role="group" aria-label="...">'
				+			'v' + version
				+		'</div>'
				+	'</div>';
		}
	};

	return myModule;

})( api, jQuery );
