extends Control

signal restart()
signal exit()

func _on_restart_button_pressed():
	restart.emit()


func _on_exit_button_pressed():
	exit.emit()
