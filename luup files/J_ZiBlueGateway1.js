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
	// Custom CSS injection
	Utils.injectCustomCSS = function( nameSpace, css ) {
		if ( $( "#custom-css-" + nameSpace ).length === 0 ) {
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
	Utils.setDeviceStateVariablePersistent = function( deviceId, service, variable, value ) {
		var d = $.Deferred();
		api.setDeviceStateVariablePersistent( deviceId, service, variable, value, {
			onSuccess: function() {
				d.resolve();
			},
			onFailure: function() {
				Utils.logDebug( "[Utils.setDeviceStateVariablePersistent] ERROR" );
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
	var _indexFeatures = {}, _indexDevices = {};
	var _selectedProductId = "";
	var _selectedFeatureName = "";
	var _formerScrollTopPosition = 0;
	var _devicesTimeout, _discoveredDevicesTimeout;
	var _devicesLastRefresh = 0, _discoveredDevicesLastRefresh = 0;

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
	 * Get informations on external devices
	 */
	function _getDevicesInfosAsync() {
		var d = $.Deferred();
		$.ajax( {
			url: Utils.getDataRequestURL() + "id=lr_" + _pluginName + "&command=getDevicesInfos&output_format=json#",
			dataType: "json"
		} )
		.done( function( devicesInfos ) {
			if ( $.isPlainObject( devicesInfos ) ) {
				d.resolve( devicesInfos );
			} else {
				Utils.logError( "No devices infos" );
				d.reject();
			}
		} )
		.fail( function( jqxhr, textStatus, errorThrown ) {
			Utils.logError( "Get " + _pluginName + " devices infos error : " + errorThrown );
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

	// *************************************************************************************************
	// External devices
	// *************************************************************************************************

	function _stopDevicesRefresh() {
		if ( _devicesTimeout ) {
			window.clearTimeout( _devicesTimeout );
		}
		_devicesTimeout = null;
	}
	function _resumeDevicesRefresh() {
		if ( _devicesTimeout == null ) {
			var timeout = 3000 - ( Date.now() - _devicesLastRefresh );
			if ( timeout < 0 ) {
				timeout = 0;
			}
			_devicesTimeout = window.setTimeout( _drawDevicesList, timeout );
		}
	}

	function _getAssociationHtml( associationType, association, level ) {
		if ( association && ( association[ level ].length > 0 ) ) {
			var pressType = "short";
			if ( level === 1 ) {
				pressType = "long";
			}
			return	'<span class="' + _prefix + '-association ' + _prefix + '-association-' + associationType + '" title="' + associationType + ' associated with ' + pressType + ' press">'
				+		'<span class="ziblue-' + pressType + '-press">'
				+			association[ level ].join( "," )
				+		'</span>'
				+	'</span>';
		}
		return "";
	}

	/**
	 * Draw and manage external device list
	 */
	function _drawDevicesList() {
		_stopDevicesRefresh();
		if ( $( "#" + _prefix + "-known-devices" ).length === 0 ) {
			return;
		}
		_indexFeatures = {}; _indexDevices = {};
		$.when( _getDevicesInfosAsync() )
			.done( function( devicesInfos ) {
				if ( devicesInfos.devices.length > 0 ) {
					$.each( devicesInfos.devices, function( i, device ) {
						var room = api.getRoomObject( device.mainRoomId );
						device.roomName = room ? room.name : 'unknown';
					});
					// Sort the devices by room / name
					devicesInfos.devices.sort( function( a, b ) {
						if ( a.protocol === b.protocol ) {
							var x = a.roomName.toLowerCase(), y = b.roomName.toLowerCase();
							return x < y ? -1 : x > y ? 1 : 0;
						}
						return a.protocol < b.protocol ? -1 : a.protocol > b.protocol ? 1 : 0;
					});
					
					var html =	'<table><tr>'
						+			'<th>' + Utils.getLangString( _prefix + "_room" ) + '</th>'
						+			'<th>' + Utils.getLangString( _prefix + "_protocol" ) + '</th>'
						+			'<th>' + Utils.getLangString( _prefix + "_id" ) + '</th>'
						+			'<th>' + Utils.getLangString( _prefix + "_signal_quality" ) + '</th>'
						+			'<th>' + Utils.getLangString( _prefix + "_last_update" ) + '</th>'
						+			'<th>' + Utils.getLangString( _prefix + "_feature" ) + '</th>'
						+			'<th>' + Utils.getLangString( _prefix + "_device" ) + '</th>'
						+			'<th>' + Utils.getLangString( _prefix + "_association" ) + '</th>'
						+			'<th>' + Utils.getLangString( _prefix + "_action" ) + '</th>'
						+		'</tr>';
					$.each( devicesInfos.devices, function( i, device ) {
						var rowSpan = ( device.features.length > 1 ? ' rowspan="' + device.features.length + '"' : '' );
						html += '<tr>'
							+		'<td class="' + _prefix + '-room-name"' + rowSpan + '>' + device.roomName + '</td>'
							+		'<td class="' + _prefix + '-protocol-name"' + rowSpan + '>' + device.protocol + '</td>'
							+		'<td class="' + _prefix + '-protocol-id"' + rowSpan + '>' + device.protocolDeviceId + '</td>'
							+		'<td' + rowSpan + '>' + ( device.rfQuality >= 0 ? device.rfQuality : '' ) + '</td>'
							+		'<td' + rowSpan + '>' + _convertTimestampToLocaleString( device.lastUpdate ) + '</td>';
						var isFirstRow = true;

						device.features.sort( function( a, b ) {
							if ( a.deviceName < b.deviceName ) {
								return -1;
							} else if ( a.deviceName > b.deviceName ) {
								return 1;
							}
							return 0;
						});

						var countDevices = {};
						$.each( device.features, function( i, feature ) {
							countDevices[ feature.deviceId.toString() ] = countDevices[ feature.deviceId.toString() ]  != null ? countDevices[ feature.deviceId.toString() ] + 1 : 1;
						});

						var lastDeviceId = -1;
						var deviceRowSpan = '1';
						$.each( device.features, function( i, feature ) {
							var productId = device.protocol + ';' + device.protocolDeviceId;
							_indexFeatures[ productId + ';' + feature.name ] = feature;
							_indexDevices[ feature.deviceId.toString() ] = device.protocol;
							if ( !feature.settings ) {
								feature.settings = {};
							}
							/*feature.settings = {};
							$.each( ( api.getDeviceStateVariable( feature.deviceId, PLUGIN_CHILD_SID, "Setting", { dynamic: false } ) || "" ).split( "," ), function( i, settingName ) {
								feature.settings[ settingName ] = true;
							} );*/
							if ( !isFirstRow ) {
								html += '<tr>';
							}
							html +=	'<td>'
								//+		'<div class="' + _prefix + '-device-channel">'
								//
								+		'<div class="' + _prefix + '-feature-name">' + feature.name + '</div>'
								+		( feature.comment ? '<div class="' + _prefix + '-feature-state">' + feature.comment + '</div>' : '' )
								+		( feature.state ? '<div class="' + _prefix + '-feature-state">' + feature.state + '</div>' : '' )
								+	'</td>';

							if ( feature.deviceId != lastDeviceId ) {
								lastDeviceId = feature.deviceId;
								deviceRowSpan = ' rowspan="' + countDevices[ feature.deviceId.toString() ] + '"';
								html +=	'<td' + deviceRowSpan +'>'
									//+			'<div class="' + _prefix + '-device-type">'
									+		'<div><span class="' + _prefix + '-device-name">' + feature.deviceName + '</span> (#' + feature.deviceId + ')</div>'
									+		'<div>'
									+				Utils.getLangString( feature.deviceTypeName )
									+				( device.isNew ? ' <span style="color:red">NEW</span>' : '' )
									+				( feature.settings.pulse ? ' PULSE' : '' )
									+				( feature.settings.toggle ? ' TOGGLE' : '' )
									+		'</div>'
									//+		'</div>'
									+	'</td>'
									+	'<td' + deviceRowSpan +'>'
									+		_getAssociationHtml( "device", feature.association.devices, 0 )
									//+		_getAssociationHtml( "device", feature.association.devices, 1 )
									+		_getAssociationHtml( "scene", feature.association.scenes, 0 )
									//+		_getAssociationHtml( "scene", feature.association.scenes, 1 )
									+		_getAssociationHtml( "ziblue-device", feature.association.ziBlueDevices, 0 )
									+	'</td' + deviceRowSpan +'>'
									+	'<td' + deviceRowSpan +' align="center">'
									//+		( !device.isNew && ( feature.settings.button || feature.settings.receiver ) ?
									+		( !device.isNew ?
												'<i class="' + _prefix + '-actions fa fa-caret-down fa-lg" aria-hidden="true" data-product-id="' + productId + '" data-feature-name="' + feature.name + '"></i>'
												: '' )
									+	'</td>';
							}
							html +=	'</tr>';
							isFirstRow = false;
						} );
					});
					html += '</table>';
					$("#" + _prefix + "-known-devices").html( html );
				} else {
					$("#" + _prefix + "-known-devices").html( Utils.getLangString( _prefix + "_no_device" ) );
				}
				_devicesLastRefresh = Date.now();
				_resumeDevicesRefresh();
			} );
	}

	/**
	 * Show the actions that can be done on an external device
	 */
	function _showDeviceActions( position, settings ) {
		_stopDevicesRefresh();
		var html = '<table>'
				+		'<tr>'
				+			'<td>'
				+				( settings.button ?
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
		var $actions = $( "#" + _prefix + "-device-actions" );
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
		_stopDevicesRefresh();
		var html = '<h1>' + Utils.getLangString( _prefix + "_association" ) + '</h1>'
				+	'<h3>' + productId + ' - ' + feature.name + ' - ' + feature.deviceName + ' (#' + feature.deviceId + ')</h3>'
				+	'<div class="scenes_section_delimiter"></div>'
				+	'<div class="' + _prefix + '-toolbar">'
				+		'<button type="button" class="' + _prefix + '-help"><i class="fa fa-question fa-lg text-info" aria-hidden="true"></i>&nbsp;' + Utils.getLangString( _prefix + "_help" ) + '</button>'
				+	'</div>'
				+	'<div class="' + _prefix + '-explanation ' + _prefix + '-hidden">'
				+		Utils.getLangString( _prefix + "_explanation_association" )
				+	'</div>';

		// Get compatible devices
		var protocol = _indexDevices[ feature.deviceId.toString() ];
		var devices = [];
		$.each( api.getListOfDevices(), function( i, device ) {
			if ( device.id == feature.deviceId ) {
				return;
			}
			// Check if device is an external device with same protocol
			var isExternal = false;
			if ( device.id_parent === _deviceId ) {
				if ( _indexDevices[ device.id.toString() ] == protocol ) {
					isExternal = true;
				}
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
			if ( !isExternal && !isCompatible ) {
				return;
			}
			
			var room = ( device.room ? api.getRoomObject( device.room ) : null );
			if ( isExternal ) {
				devices.push( {
					"id": device.id,
					"roomName": ( room ? room.name : "_No room" ),
					"name": "(ZiBlue) " + device.name,
					"type": 3,
					"isExternal": isExternal
				} );
			} else {
				devices.push( {
					"id": device.id,
					"roomName": ( room ? room.name : "_No room" ),
					"name": device.name,
					"type": 2,
					"isExternal": isExternal
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
				html += '<div class="' + _prefix + '-association-room">' +  device.roomName + '</div>';
			}
			if ( device.type === 1 ) {
				// Scene
				html += '<div class="' + _prefix + '-association ' + _prefix + '-association-scene" data-scene-id="' + device.id + '">'
					+		'<label>'
					+			_getCheckboxHtml( device.id, feature.association.scenes, 0 )
					//+			_getCheckboxHtml( device.id, feature.association.scenes, 1 )
					+			'&nbsp;' + device.name + ' (#' + device.id + ')'
					+		'</label>'
					+	'</div>';
			} else if ( device.type === 3 ) {
				// ZiBlue : declared association
				html += '<div class="ziblue-association ziblue-association-zibluedevice" data-device-id="' + device.id + '">'
					+		'<label>'
					+			_getCheckboxHtml( device.id, feature.association.ziBlueDevices, 0 )
					+			'&nbsp;' + device.name + ' (#' + device.id + ')'
					+		'</label>'
					+	'</div>';
			} else {
				// Classic device (e.g. Z-wave)
				html += '<div class="' + _prefix + '-association ' + _prefix + '-association-device" data-device-id="' + device.id + '">'
					+		'<label>'
					+			_getCheckboxHtml( device.id, feature.association.devices, 0 )
					//+			_getCheckboxHtml( device.id, feature.association.devices, 1 )
					+			'&nbsp;' + device.name + ' (#' + device.id + ')'
					+		'</label>'
					+	'</div>';
			}
		} );

		html += '<div class="' + _prefix + '-toolbar">'
			+		'<button type="button" class="' + _prefix + '-cancel"><i class="fa fa-times fa-lg text-danger" aria-hidden="true"></i>&nbsp;'  + Utils.getLangString( _prefix + "_cancel" ) + '</button>'
			+		'<button type="button" class="' + _prefix + '-associate"><i class="fa fa-check fa-lg text-success" aria-hidden="true"></i>&nbsp;'  + Utils.getLangString( _prefix + "_confirm" ) + '</button>'
			+	'</div>';

		$( "#" + _prefix + "-device-association" )
			.html( html )
			.css( {
				"display": "block"
			} );

		_formerScrollTopPosition = $( window ).scrollTop();
		$( window ).scrollTop( $( "#" + _prefix + "-known-panel" ).offset().top - 150 );
	}
	function _hideDeviceAssociation() {
		$( "#" + _prefix + "-device-association" )
			.css( {
				"display": "none",
				"min-height": $( "#" + _prefix + "-known-panel" ).height()
			} );
		if ( _formerScrollTopPosition > 0 ) {
			$( window ).scrollTop( _formerScrollTopPosition );
		}
	}
	function _setDeviceAssociation() {
		function _getEncodedAssociation() {
			var associations = [];
			$("#" + _prefix + "-device-association ." + _prefix + "-association-device input:checked").each( function() {
				var deviceId = $( this ).parents( "." + _prefix + "-association-device" ).data( "device-id" );
				if ( $( this ).parent().hasClass( "ziblue-long-press" ) ) {
					associations.push( "+" + deviceId );
				} else {
					associations.push( deviceId );
				}
			});
			$("#" + _prefix + "-device-association ." + _prefix + "-association-scene input:checked").each( function() {
				var sceneId = $( this ).parents( "." + _prefix + "-association-scene" ).data( "scene-id" );
				if ( $( this ).parent().hasClass( "ziblue-long-press" ) ) {
					associations.push( "+*" + sceneId );
				} else {
					associations.push( "*" + sceneId );
				}
			});
			$("#" + _prefix + "-device-association ." + _prefix + "-association-zibluedevice input:checked").each( function() {
				var deviceId = $( this ).parents( "." + _prefix + "-association-zibluedevice" ).data( "device-id" );
				associations.push( "%" + deviceId );
			});
			return associations.join( "," );
		}

		$.when( _performActionAssociate( _selectedProductId, _selectedFeatureName, _getEncodedAssociation() ) )
			.done( function() {
				_resumeDevicesRefresh();
				_hideDeviceAssociation();
			});
	}

	/**
	 * Show parameters for an external device
	 */
	function _showDeviceParams( productId, feature ) {
		_stopDevicesRefresh();
		var html = '<h1>' + Utils.getLangString( _prefix + "_param" ) + '</h1>'
				+	'<h3>' + productId + ' - ' + feature.deviceName + ' (#' + feature.deviceId + ')</h3>'
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
						variable: "button",
						name: "Button",
						value: feature.settings.button
					})
			+	'</h3>'
			+	'<div class="' + _prefix + '-hideable"' + ( !feature.settings.button ? ' style="display: none;"' : '' ) + '>';
		$.each( [ [ 'pulse', 'Pulse' ], [ 'toggle', 'Toggle' ] ], function( i, param ) {
			html += _getSettingHtml({
				type: "checkbox",
				variable: param[0],
				name: param[1],
				value: feature.settings[ param[0] ]
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
						value: feature.settings.receiver
					})
			+	'</h3>'
			+	'<div class="' + _prefix + '-hideable"' + ( !feature.settings.receiver ? ' style="display: none;"' : '' ) + '>';
		$.each( [ [ 'qualifier', 'Qualifier' ], [ 'burst', 'Burst' ] ], function( i, param ) {
			html += _getSettingHtml({
				type: "string",
				variable: param[0],
				name: param[1],
				value: feature.settings[ param[0] ]
			});
		});
		html += '</div>';

		// Specific
		var specificHtml = '';
		$.each( feature.settings, function( paramName, paramValue ) {
			if ( $.inArray( paramName, [ 'button', 'pulse', 'toggle', 'receiver', 'qualifier', 'burst' ] ) === -1 ) {
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

		$( "#" + _prefix + "-device-params" )
			.html( html )
			.data( 'feature', feature )
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
	function _hideDeviceParams() {
		$( "#" + _prefix + "-device-params" )
			.css( {
				"display": "none"
			} );
		if ( _formerScrollTopPosition > 0 ) {
			$( window ).scrollTop( _formerScrollTopPosition );
		}
	}
	function _setDeviceParams() {
		var feature = $( "#" + _prefix + "-device-params" ).data( "feature" );
		feature.settings = {};
		$( "#" + _prefix + "-device-params ." + _prefix + "-setting-value:visible" ).each( function() {
			var settingName = $( this ).data( "setting" );
			var settingValue = $( this ).is( ":checkbox" ) ? $( this ).is( ":checked" ) : $( this ).val();
			if ( settingName && ( settingValue !== "" ) ) {
				feature.settings[ settingName ] = settingValue;
			}
		});
		var setting = $.map( feature.settings, function( value, key ) {
			if ( typeof value == "boolean" ) {
				return ( value === true ) ? key : null;
			} else {
				return key + "=" + value;
			}
		});
		$.when(
			Utils.setDeviceStateVariablePersistent( feature.deviceId, PLUGIN_CHILD_SID, "Setting", setting.join( "," ) ),
			_performActionRefresh()
		)
			.done( function() {
				_resumeDevicesRefresh();
				_hideDeviceParams();
			});
	}

	/**
	 * Show external devices
	 */
	function _showDevices( deviceId ) {
		if ( deviceId ) {
			_deviceId = deviceId;
		}
		try {
			$.when( _loadResourcesAsync(), _loadLocalizationAsync() ).then( function() {
				api.setCpanelContent(
						'<div id="' + _prefix + '-known-panel" class="' + _prefix + '-panel">'
					+		'<h1>' + Utils.getLangString( _prefix + "_managed_devices" ) + '</h1>'
					+		'<div class="scenes_section_delimiter"></div>'
					+		'<div class="' + _prefix + '-toolbar">'
					+			'<button type="button" class="' + _prefix + '-help"><i class="fa fa-question fa-lg text-info" aria-hidden="true"></i>&nbsp;' + Utils.getLangString( _prefix + "_help" ) + '</button>'
					+			'<button type="button" class="' + _prefix + '-refresh"><i class="fa fa-refresh fa-lg" aria-hidden="true"></i>&nbsp;' + Utils.getLangString( _prefix + "_refresh" ) + '</button>'
					+		'</div>'
					+		'<div class="' + _prefix + '-explanation ' + _prefix + '-hidden">'
					+			Utils.getLangString( _prefix + "_explanation_known_devices" )
					+		'</div>'
					+		'<div id="' + _prefix + '-known-devices" class="' + _prefix + '-devices">'
					+			Utils.getLangString( _prefix + "_loading" )
					+		'</div>'
					+		'<div id="' + _prefix + '-device-actions" style="display: none;"></div>'
					+		'<div id="' + _prefix + '-device-association" style="display: none;"></div>'
					+		'<div id="' + _prefix + '-device-params" style="display: none;"></div>'
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
								_drawDevicesList();
							});
					} )
					.on( "click", "." + _prefix + "-add", function() { _showAddDevice(); } )
					.click( function() {
						$( "#" + _prefix + "-device-actions" ).css( "display", "none" );
					} )
					.on( "click", "." + _prefix + "-actions", function( e ) {
						var position = $( this ).position();
						position.left = position.left + $( this ).outerWidth();
						_selectedProductId = $( this ).data( "product-id" );
						_selectedFeatureName = $( this ).data( "feature-name" );
						var selectedFeature = _indexFeatures[ _selectedProductId + ";" + _selectedFeatureName ];
						if ( selectedFeature ) {
							_showDeviceActions( position, selectedFeature.settings );
						}
						e.stopPropagation();
					} )
					.on( "click", "." + _prefix + "-show-association", function() {
						_showDeviceAssociation( _selectedProductId, _indexFeatures[ _selectedProductId + ";" + _selectedFeatureName ] );
					} )
					.on( "click", "." + _prefix + "-show-params", function() {
						_showDeviceParams( _selectedProductId, _indexFeatures[ _selectedProductId + ";" + _selectedFeatureName ] );
					} )
					.on( "click", "." + _prefix + "-cancel", function() {
						_hideDeviceAssociation();
						_hideDeviceParams();
						_resumeDevicesRefresh();
					} )
					// Association event
					.on( "click", "." + _prefix + "-associate", _setDeviceAssociation )
					// Parameters event
					.on( "click", "." + _prefix + "-set", _setDeviceParams )
					// Teach (receiver) event
					.on( "click", "." + _prefix + "-teach", function() {
						api.ui.showMessagePopup( Utils.getLangString( _prefix + "_confirmation_teach_in_receiver" ), 4, 0, {
							onSuccess: function() {
								_performActionTeachIn( _selectedProductId, "ON", "" );
								return true;
							}
						});
					} )
					// Clear (receiver) event
					.on( "click", "." + _prefix + "-clear", function() {
						api.ui.showMessagePopup( Utils.getLangString( _prefix + "_confirmation_clearing_receiver" ), 4, 0, {
							onSuccess: function() {
								_performActionClear( _selectedProductId );
								return true;
							}
						});
					} );

				// Show devices infos
				_drawDevicesList();
			});
		} catch (err) {
			Utils.logError( "Error in " + _pluginName + ".showDevices(): " + err );
		}
	}

	// *************************************************************************************************
	// Add external device
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
					+			'<span>' + Utils.getLangString( "ziblue_protocol" ) + '</span>'
					+			'<select id="zibluegateway-setting-protocol" class="zibluegateway-setting-value" data-variable="protocol">'
					+				'<option value="">-- ' + Utils.getLangString( "ziblue_protocol" ) + ' --</option>';
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
					+			'<span>' + Utils.getLangString( "ziblue_device_name" ) + '</span>'
					+			'<input type="text" class="zibluegateway-setting-value" data-variable="deviceName" placeholder="' + Utils.getLangString( "ziblue_enter_name" ) + '">'
					+		'</div>'
					+		'<div class="zibluegateway-setting ui-widget-content ui-corner-all">'
					+			'<span>Id</span>'
					+			'<input type="text" id="zibluegateway-setting-device-id" class="zibluegateway-setting-value" data-variable="deviceId" placeholder="' + Utils.getLangString( "ziblue_enter_id" ) + '">'
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
					var group = $( this ).val().charCodeAt( 0 ) - 65;
					var unit = parseInt( $( "#zibluegateway-setting-device-unit" ).val(), 10 );
					if ( ( group >= 0 ) && unit ) {
						$( "#zibluegateway-setting-device-id" ).val( group * 16  + ( unit - 1 ) );
					}
				});
				$( "#zibluegateway-setting-device-unit" ).change( function() {
					var group = $( "#zibluegateway-setting-device-group" ).val().charCodeAt( 0 ) - 65;
					var unit = parseInt( $( this ).val(), 10 );
					if ( ( group >= 0 ) && unit ) {
						$( "#zibluegateway-setting-device-id" ).val( group * 16  + ( unit - 1 ) );
					}
				});
			} );
	}

	function _getSettingHtml( setting ) {
		var className = "zibluegateway-setting-value" + ( setting.className ? " " + setting.className : "" );
		var html = '<div class="zibluegateway-setting ui-widget-content ui-corner-all">'
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
		html +=	'</div>';
		return html;
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
			+		'<span>' + Utils.getLangString( "ziblue_device_type" ) + '</span>'
			+		'<select id="zibluegateway-setting-device-type" class="zibluegateway-setting-value" data-variable="deviceType">'
			+			'<option value="">-- ' + Utils.getLangString( "ziblue_select_device_type" ) + ' --</option>';
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
			html += _getSettingHtml( setting );
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
				+			'<button type="button" class="zibluegateway-teach">' + Utils.getLangString( "ziblue_teach" ) + '</button>'
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
				+			'<button type="button" class="zibluegateway-create">' + Utils.getLangString( "ziblue_create" ) + '</button>'
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
			var variableName = $( this ).data( 'variable' );
			if ( variableName ) {
				settings[ variableName ] = $( this ).val();
			}
			var settingName = $( this ).data( 'setting' );
			if ( settingName ) {
				settings.settings.push( settingName + "=" + $( this ).val() );
			}
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
			$.when( _loadResourcesAsync(), _loadLocalizationAsync() ).then( function() {
				var hasTeachingBeenDone = false;
				api.setCpanelContent(
						'<div id="zibluegateway-add-device-panel" class="zibluegateway-panel">'
					+		'<h1>' + Utils.getLangString( "ziblue_add_new_device" ) + '</h1>'
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
			});
		} catch (err) {
			Utils.logError('Error in ZiBlueGateway.showAddDevice(): ' + err);
		}
	}

	// *************************************************************************************************
	// Discovered external devices
	// *************************************************************************************************

	function _stopDiscoveredDevicesRefresh() {
		if ( _discoveredDevicesTimeout ) {
			window.clearTimeout( _discoveredDevicesTimeout );
		}
		_discoveredDevicesTimeout = null;
	}
	function _resumeDiscoveredDevicesRefresh() {
		if ( _discoveredDevicesTimeout == null ) {
			var timeout = 3000 - ( Date.now() - _discoveredDevicesLastRefresh );
			if ( timeout < 0 ) {
				timeout = 0;
			}
			_discoveredDevicesTimeout = window.setTimeout( _drawDiscoveredDevicesList, timeout );
		}
	}

	/**
	 * Draw and manage discovered ziblue device list
	 */
	function _drawDiscoveredDevicesList() {
		_stopDiscoveredDevicesRefresh();
		if ( $( "#" + _prefix + "-discovered-devices" ).length === 0 ) {
			return;
		}
		$.when( _getDevicesInfosAsync() )
			.done( function( devicesInfos ) {
				if ( devicesInfos.discoveredDevices.length > 0 ) {
					// Sort the discovered ziblue devices by last update
					devicesInfos.discoveredDevices.sort( function( d1, d2 ) {
						return d2.lastUpdate - d1.lastUpdate;
					});
					var html =	'<table><tr>'
						+			'<th>' + Utils.getLangString( _prefix + "_protocol" ) + '</th>'
						+			'<th>' + Utils.getLangString( _prefix + "_id" ) + '</th>'
						+			'<th>' + Utils.getLangString( _prefix + "_signal_quality" ) + '</th>'
						+			'<th>' + Utils.getLangString( _prefix + "_last_update" ) + '</th>'
						+			'<th>' + Utils.getLangString( _prefix + "_feature" ) + '</th>'
						+			'<th></th>'
						+		'</tr>';
					$.each( devicesInfos.discoveredDevices, function( i, discoveredDevice ) {
						var productId = discoveredDevice.protocol + ';' + discoveredDevice.protocolDeviceId;
						html += '<tr class="' + _prefix + '-discovered-device" data-product-id="' + productId + '">'
							+		'<td>' + discoveredDevice.protocol + '</td>'
							+		'<td>' + discoveredDevice.protocolDeviceId + '</td>'
							+		'<td>' + ( discoveredDevice.rfQuality >= 0 ? discoveredDevice.rfQuality : '' ) + '</td>'
							+		'<td>' + _convertTimestampToLocaleString( discoveredDevice.lastUpdate ) + '</td>'
							+		'<td>'
							+			'<div class="font-weight-bold">' + discoveredDevice.name + '</div>'
							+			'<table class="' + _prefix + '-feature-group">';
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
								html +=				'<div class="ziblue-feature-name">' + featureName + '</div>'
									+				( feature.comment ? '<div>' + feature.comment + '</div>' : '' )
									+				( feature.state ? '<div class="ziblue-feature-state">' + feature.state + '</div>' : '' );
							});
							html +=				'</td><td class="ziblue-device-type" width="40%">';
							if ( group.deviceTypes ) {
								if ( group.deviceTypes.length > 1 ) {
									html +=				'<select>';
									$.each( group.deviceTypes, function( k, deviceType ) {
										html +=				'<option value="' + deviceType + '">' + deviceType + '</option>';
									} );
									html +=				'</select>';
								} else {
									html +=	group.deviceTypes[0];
								}
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
					$("#" + _prefix + "-discovered-devices").html( html );
				} else {
					$("#" + _prefix + "-discovered-devices").html( Utils.getLangString( "zigate_no_discovered_device" ) );
				}
				_discoveredDevicesLastRefresh = Date.now();
				_resumeDiscoveredDevicesRefresh();
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
			$.when( _loadResourcesAsync(), _loadLocalizationAsync() ).then( function() {
				api.setCpanelContent(
						'<div id="' + _prefix + '-discovered-panel" class="' + _prefix + '-panel">'
					+		'<h1>' + Utils.getLangString( _prefix + "_discovered_devices" ) + '</h1>'
					+		'<div class="scenes_section_delimiter"></div>'
					+		'<div class="' + _prefix + '-toolbar">'
					+			'<button type="button" class="' + _prefix + '-help"><i class="fa fa-question fa-lg text-info" aria-hidden="true"></i>&nbsp;' + Utils.getLangString( _prefix + "_help" ) + '</button>'
					//+			'<button type="button" class="' + _prefix + '-ignore"><span class="icon icon-ignore"></span>' + Utils.getLangString( _prefix + "_ignore" ) + '</button>'
					+			'<button type="button" class="' + _prefix + '-refresh" style="display: none"><span class="icon icon-refresh"></span>' + Utils.getLangString( _prefix + "_refresh" ) + '</button>'
					+			'<button type="button" class="' + _prefix + '-learn"><i class="fa fa-plus fa-lg" aria-hidden="true"></i>&nbsp;' + Utils.getLangString( _prefix + "_learn" ) + '</button>'
					+		'</div>'
					+		'<div class="' + _prefix + '-explanation ' + _prefix + '-hidden">'
					+			Utils.getLangString( _prefix + "_explanation_discovered_devices" )
					+		'</div>'
					+		'<div id="' + _prefix + '-discovered-devices" class="' + _prefix + '-devices">'
					+			Utils.getLangString( _prefix + "_loading" )
					+		'</div>'
					+	'</div>'
				);

				function _getSelectedProductIds() {
					var items = [];
					$( "#" + _prefix + "-discovered-devices input:checked:visible" ).each( function() {
						var $device = $( this ).parents( "." + _prefix + "-discovered-device" );
						var productId = $device.data( "product-id" );
						var deviceTypes = [];
						$device.find( "." + _prefix + "-device-type" )
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
				$( "#" + _prefix + "-discovered-panel" )
					.on( "click", "." + _prefix + "-help", function() {
						$( "." + _prefix + "-explanation" ).toggleClass( _prefix + "-hidden" );
					} )
					.on( "click", "." + _prefix + "-learn", function( e ) {
						var productIds = _getSelectedProductIds();
						if ( productIds.length === 0 ) {
							api.ui.showMessagePopup( Utils.getLangString( _prefix + "_select_device" ), 1 );
						} else {
							api.ui.showMessagePopup( Utils.getLangString( _prefix + "_confirmation_learning_devices" ) + " " + productIds.join( "<br/>" ), 4, 0, {
								onSuccess: function() {
									$.when( _performActionCreateDevices( productIds ) )
										.done( function() {
											_showReload( Utils.getLangString( _prefix + "_devices_have_been_created" ), function() {
												_showDevices();
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
						_stopDiscoveredDevicesRefresh();
					})
					.on( "blur", "select", function( e ) {
						if ( $( "#" + _prefix + "-discovered-panel input:checked" ).length === 0 ) {
							_resumeDiscoveredDevicesRefresh();
						}
					})
					.on( "change", "select", function( e ) {
						if ( $( "#" + _prefix + "-discovered-panel input:checked" ).length === 0 ) {
							_resumeDiscoveredDevicesRefresh();
						}
					})
					.on( "change", "input:checkbox", function( e ) {
						if ( $( "#" + _prefix + "-discovered-panel input:checked" ).length > 0 ) {
							_stopDiscoveredDevicesRefresh();
						} else {
							_resumeDiscoveredDevicesRefresh();
						}
					})
					;

				// Show discovered devices infos
				_drawDiscoveredDevicesList();
			});
		} catch (err) {
			Utils.logError( "Error in " + _pluginName + ".showDevices(): " + err );
		}
	}

	// *************************************************************************************************
	// Actions
	// *************************************************************************************************

	/**
	 * 
	 */
	function _performActionRefresh() {
		Utils.logDebug( "[" + _pluginName + ".performActionRefresh] Refresh the list of external devices" );
		return Utils.performActionOnDevice(
			_deviceId, PLUGIN_SID, "Refresh", {
				output_format: "json"
			}
		);
	}

	/**
	 * 
	 */
	function _performActionCreateDevices( encodedProductIds ) {
		Utils.logDebug( "[" + _pluginName + ".performActionCreateDevices] Create external product/features '" + encodedProductIds + "'" );
		return Utils.performActionOnDevice(
			_deviceId, PLUGIN_SID, "CreateDevices", {
				output_format: "json",
				productIds: encodeURIComponent( encodedProductIds.join( "|" ) )
			}
		);
	}

	/**
	 * 
	 */
	function _performActionTeachIn( productId, action, comment ) {
		Utils.logDebug( "[" + _pluginName + ".performActionTeachIn] Teach in ZiBlue product '" + productId + "', action: " + action + ", comment: " + comment );
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
	 * Associate external device to Vera devices
	 */
	function _performActionAssociate( productId, featureName, encodedAssociation ) {
		Utils.logDebug( "[" + _pluginName + ".performActionAssociate] Associate external product/feature '" + productId + "/" + featureName + "' with " + encodedAssociation );
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
	 * Test ON/OFF on newly created device (before validating)
	 */
	function _performActionSetTarget( productId, targetValue ) {
		Utils.logDebug( "[" + _pluginName + "._performActionSetTarget] Set target for ZiBlue product '" + productId + " to " + targetValue );
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
					/*+		'<div class="' + _prefix + '-toolbar">'
					+			'<button type="button" class="' + _prefix + '-help"><i class="fa fa-question fa-lg text-info" aria-hidden="true"></i>&nbsp;' + Utils.getLangString( _prefix + "_help" ) + '</button>'
					+		'</div>'
					+		'<div class="' + _prefix + '-explanation ' + _prefix + '-hidden">'
					+			Utils.getLangString( _prefix + "_explanation_errors" )
					+		'</div>'*/
					+		'<div id="' + _prefix + '-errors">'
					+			Utils.getLangString( _prefix + "_loading" )
					+		'</div>'
					+	'</div>'
				);
				// Manage UI events
				/*$( "#" + _prefix + "-errors-panel" )
					.on( "click", "." + _prefix + "-help" , function() {
						$( "." + _prefix + "-explanation" ).toggleClass( _prefix + "-hidden" );
					} );*/
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
		showAddDevice: _showAddDevice,
		showDevices: _showDevices,
		showDiscoveredDevices: _showDiscoveredDevices,
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
