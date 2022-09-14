dofile( "$GAME_DATA/Scripts/game/BasePlayer.lua" )

Player = class( BasePlayer )

function Player.server_onCreate( self )
	print("Player.server_onCreate")
	BasePlayer.server_onCreate()
end