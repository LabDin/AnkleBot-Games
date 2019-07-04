extends Node

signal configs_listed
signal config_received
signal state_changed
signal socket_connected

var interface = null

var axes_number = 0
var positions = [ 0 ]
var forces = [ 0 ]
var position_setpoints = [ 0 ]
var force_setpoints = [ 0 ]

var previous_request = 0
var previous_reply = 0

var configuration = "" setget _set_configuration
var user_name = "" setget _set_user

func _init( input_interface ):
	interface = input_interface
	set_process( false )

func request_available_configurations():
	interface.set_request( InputManager.Request.LIST_CONFIGS )

func _set_configuration( value ):
	interface.set_request( InputManager.Request.SET_CONFIG, value )

func _set_user( value ):
	interface.set_request( InputManager.Request.SET_USER, value )

func request_state_change( state_request ):
	if state_request != previous_request:
		interface.set_request( state_request )
	previous_request = state_request

func get_axis_position( axis_index ):
	return interface.get_axis_position( axis_index ) if axis_index < axes_number else 0.0

func get_axis_force( axis_index ):
	return interface.get_axis_force( axis_index ) if axis_index < axes_number else 0.0

func set_axis_setpoint( axis_index, position, force ):
	if axis_index >= position_setpoints.size(): return
	position_setpoints[ axis_index ] = position
	force_setpoints[ axis_index ] = force

func _reset_axes( axes_list ):
	position_setpoints = []
	force_setpoints = []
	axes_number = axes_list.size()
	for axis_index in range( axes_number ):
		position_setpoints.append( 0.0 )
		force_setpoints.append( 0.0 )

func _get_state_reply():
	var reply_code = interface.get_reply()
	if reply_code != previous_reply:
		match reply_code:
			InputManager.Reply.CONFIGS_LISTED:
				var available_configurations = interface.get_available_devices()
				emit_signal( "configs_listed", available_configurations )
			InputManager.Reply.CONFIG_SET:
				interface.set_request( InputManager.Request.GET_CONFIG )
			InputManager.Reply.GOT_CONFIG:
				var device_info = interface.get_device_info()
				var string_id = device_info[ "id" ]
				var axes_list = device_info[ "axes" ]
				_reset_axes( axes_list )
				emit_signal( "config_received", string_id, axes_list )
			InputManager.Reply.USER_SET: pass
			_: emit_signal( "state_changed", reply_code )
		print( "reply received: " + str(reply_code) )
	previous_reply = reply_code

func _physics_process( delta ):
	interface.set_axis_setpoints( position_setpoints, force_setpoints )
	positions = interface.get_axis_positions()
	forces = interface.get_axis_forces()
	_get_state_reply()

func connect_socket( host ):
	if interface != null:
		if interface.connect_socket( host ):
			print( "connected to " + host )
			set_process( true )
			emit_signal( "socket_connected" )

func disconnect_socket():
	set_process( false )
	interface.disconnect_socket()

func _notification( what ):
	if what == NOTIFICATION_PREDELETE: 
		disconnect_socket()