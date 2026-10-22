class_name PlayerSlot
extends RefCounted
## One player's seat in the game: whether they are playing, on what, and with which car.

var active := false
var device := -1       # joypad id, or -1 when not on a gamepad
var kb := false        # plays on the keyboard (using this slot's keyboard keys)
var color := 0         # index into Game.COLORS
var easy := false      # auto-steer mode
var ready := false     # confirmed on the car screen
