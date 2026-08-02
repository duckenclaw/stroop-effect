extends Control

signal resume()
signal restart()

func _on_resume_button_pressed():
	resume.emit()


func _on_restart_button_pressed():
	restart.emit()
