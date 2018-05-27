Utils.initTokens( {
	"ziblue_donate": "Ce plugin est gratuit mais si vous l'installez et le trouvez utile, alors un don pour aider aux futurs développements serait grandement apprécié.",
	"ziblue_loading": "En cours de chargement...",
	"ziblue_reload_has_to_be_done": "Les changements effectués ne seront visibles qu'après un redémarrage du moteur Luup. Vous pouvez décider de continuer sans redémarrer.",

	"ziblue_help": "Aide",
	"ziblue_refresh": "Rafraîchir",
	"ziblue_add": "Ajouter",
	"ziblue_learn": "Apprendre",
	"ziblue_cancel": "Annuler",
	"ziblue_confirm": "Confirmer",
	"ziblue_room": "Pièce",
	"ziblue_protocol": "Protocole",
	"ziblue_select_protocol": "Choisissez un protocole",
	"ziblue_signal_quality": "Qualité<br/>signal",
	"ziblue_feature": "Fonction",
	"ziblue_equipment": "Equipement",
	"ziblue_equipment_name": "Nom de l'équipement",
	"ziblue_enter_name": "Entrez le nom",
	"ziblue_id": "Id",
	"ziblue_enter_id": "Entrez l'id [0-255]",
	"ziblue_device": "Module lié",
	"ziblue_device_type": "Type du module lié",
	"ziblue_select_device_type": "Sélectionnez un type",
	"ziblue_association": "Association",
	"ziblue_param": "Paramétrage",
	"ziblue_action": "Action",
	"ziblue_last_update": "Dernière modification",

	// Settings
	"ziblue_tab_settings": "Paramètres ZiBlue",
	"ziblue_explanation_plugin_settings": "Cet onglet affiche les paramètres du dongle ZiBlue, en lecture seule.<br/><br/>\
	Pour pouvoir les modifier, vous avez 2 possibilités :<br/>\
	<ul>\
	<li>Utiliser le <a href=\"http://rfplayer.com/telechargement\">configurateur</a> de ZiBlue</li>\
	<li>Utiliser la commande \"SendMessage\" du plugin et envoyer une commande au dongle ZiBLue. Il vous faudra connaître les commandes disponibles en contactant la société ZiBlue.</li>\
	</ul>",
	"ziblue_plugin_settings": "Paramètres ZiBlue",

	// New equipment
	"ziblue_tab_new_equipment": "Nouvel équipement",
	"ziblue_add_new_equipment": "Ajout d'un nouvel équipement",
	"ziblue_add_new_equipment_step": "Etape {0}",
	"ziblue_add_new_equipment_settings_title": "Paramétrage",
	"ziblue_add_new_equipment_teach_title": "Apprentissage",
	"ziblue_add_new_equipment_teach_explanation": "En fonction de l'équipement récepteur/actionneur, l'apprentissage peut être différent. Tout d'abord, positionnez le récepteur en mode apprentissage, puis cliquez sur le bouton 'Enseigner' (vous n'aurez peut-être que 10 secondes).",
	"ziblue_add_new_equipment_teach_parrot_explanation": "Pressez le bouton 'Enseigner' pour positionner le dongle en mode capture. Placez l'émetteur à apprendre à 2-3m et faites le émettre des trames.<br/>Diminuez graduellement la distance s'il n'y a pas de résultat. Un équipement trop près donnera des résultats décevants.<br/>La trame doit être capturée 2 fois (1: Lent clignotement bleu puis 2: Clignotement rapide bleu ; Apprentissage réussi: lumière ROSE, apprentissage raté: lumière ROUGE).",
	"ziblue_add_new_equipment_test_title": "Test",
	"ziblue_add_new_equipment_test_explanation": "Vous pouvez utiliser les boutons 'ON' et 'OFF' pour vérifier que l'apprentissage est correctement effectué.",
	"ziblue_add_new_equipment_validate_title": "Validation",
	"ziblue_add_new_equipment_validate_explanation": "Si tout est OK, vous pouvez valider et créer le nouveau module associé à l'équipement (émetteur virtuel).",
	"ziblue_warning_teach_in_not_done": "L'apprentissage du récepteur n'a pas été fait. Voulez vous continuer à créer le nouveau module ?",
	"ziblue_teach": "Enseigner",
	"ziblue_create": "Créer",
	"ziblue_device_has_been_created": "Le module a été créé.",

	// Managed equipments
	"ziblue_tab_managed_equipments": "Equipements gérés",
	"ziblue_managed_equipments": "Equipements gérés",
	"ziblue_explanation_known_equipments": "Cet onglet affiche les équipements ZiBlue, connus de la Vera, et leurs modules associés sur la Vera.<br/><br/>\
	Chaque module associé est géré directement par le contrôleur domotique comme un module standard : pour toute action standard (comme ajouter à des scénarios, renommer, voire supprimer), vous le retrouvez sur l'interface utilisateur standard.<br/><br/>\
	Vous pouvez accéder aux paramétrages/actions spécifiques en cliquant sur le bouton dédié : <i class=\"fa fa-caret-down fa-lg\" aria-hidden=\"true\"></i>.",
	"ziblue_no_equipment": "Il n'y a pas d'équipement.",
	"ziblue_explanation_association": "Ce panneau affiche les associations entre le module associé à l'équipement et des modules ou des scénarios sur la centrale domotique.<br/>\
	C'est une facilité proposée par le plugin, qui vous permet d'effectuer simplement des actions en réponse à un changement d'état du module, sans devoir créer un scénario.<br/><br/>\
	Par exemple, l'activation d'une télécommande peut allumer une prise gérée par la centrale domotique.",
	"ziblue_explanation_param": "Ce panneau affiche les paramètres (spécifiques au plugin), du module associé à un équipement.<br/><br/>\
	<b>Button:</b> Coché si le module dit se comporter comme un bouton, éventuellement en mode \"Pulse\" ou \"Toggle\"<br/><br/>\
	<b>Receiver:</b> Coché si le module représente un équipement récepteur/actionneur. Dans ce cas le module est vu comme un équipement émetteur virtuel et doit être associé à l'équipement récepteur pour pouvoir le contrôler.<br/>\
	Normalement cette action a été faite lors de la création du module depuis l'onglet \"Nouvel équipement\", sinon elle peut être faite depuis le bouton de fonctions dans l'onglet \"Equipements gérés\".<br/>\
	Pour plus d'information sur les paramètres \"Qualifier\" ou \"Burst\", référez-vous au manuel du dongle ZiBlue.",
	"ziblue_confirmation_teach_in_receiver": "Veuillez mettre l'équipement récepteur/actionneur en mode apprentissage, afin de pouvoir y associer votre équipement virtuel.",

	// Discovered equipments
	"ziblue_tab_discovered_equipments": "Equipements découverts",
	"ziblue_discovered_equipments": "Equipements découverts",
	"ziblue_explanation_discovered_equipments": "Cet onglet affiche les équipements exposés par le dongle ZiBlue et non encore connus de la centrale domotique.<br/><br\>\
	<b>Equipement:</b> un appareil exposé par le dongle ZiBlue. Par exemple, une sonde de température en 433Mhz.<br\>\
	<b>Module:</b> un appareil géré par la centrale domotique. Par exemple, un détecteur de mouvement Zwave.<br\><br\>\
	Pour pouvoir utiliser les équipements sur la centrale domotique, il faut d'abord les faire apprendre à la centrale, et définir les modules qui seront associés à cet équipement.<br/>\
	Par exemple, un équipement relevant la température et l'hygrométrie sera associé à 2 modules sur la centrale : un capteur de température et un capteur d'humidité.<br/><br\>\
	Le type du module peut parfois être choisi : cela ne changera pas la fonctionnalité mais sa représentation dans l'interface utilisateur.",
	"ziblue_no_discovered_equipment": "Il n'y a pas d'équipement découvert.",
	"ziblue_select_equipment": "Vous devez sélectionner le(s) équipement(s) que vous voulez apprendre.",
	"ziblue_confirmation_learning_equipments": "Veuillez confirmer les équipements à apprendre.",
	"ziblue_devices_have_been_created": "Les modules associés ont été créés.",

	// Errors
	"ziblue_tab_errors": "Erreurs",
	"ziblue_errors": "Erreurs",
	"ziblue_explanation_errors": "Cet onglet affiche les dernières erreurs rencontrées par le plugin.",
	"ziblue_no_error": "Il n'y a pas d'erreur.",

	// Device types
	"urn:antor-fr:device:PilotWire:1": "Fil pilote",
	"urn:schemas-micasaverde-com:device:BarometerSensor:1": "Baromètre",
	"urn:schemas-micasaverde-com:device:DoorSensor:1": "Capteur d'ouverture",
	"urn:schemas-micasaverde-com:device:HumiditySensor:1": "Capteur d'humidité",
	"urn:schemas-micasaverde-com:device:LightSensor:1": "Capteur de luminosité",
	"urn:schemas-micasaverde-com:device:MotionSensor:1": "Capteur de mouvement",
	"urn:schemas-micasaverde-com:device:PowerMeter:1": "Compteur électrique",
	"urn:schemas-micasaverde-com:device:SceneController:1": "Controlleur de scène",
	"urn:schemas-micasaverde-com:device:TemperatureSensor:1": "Capteur de température",
	"urn:schemas-micasaverde-com:device:WindowCovering:1": "Volet",
	"urn:schemas-upnp-org:device:BinaryLight:1": "Interrupteur On/Off",
	"urn:schemas-upnp-org:device:DimmableLight:1": "Variateur",
	"urn:schemas-upnp-org:device:DimmableRGBLight:1": "Variateur RGB",
	"urn:schemas-upnp-org:device:Heater:1": "Radiateur",
	"urn:schemas-upnp-org:device:HVAC_ZoneThermostat:1": "Thermostat",
	"urn:schemas-upnp-org:device:JammingSensor:1": "Détecteur de brouillage"
} );