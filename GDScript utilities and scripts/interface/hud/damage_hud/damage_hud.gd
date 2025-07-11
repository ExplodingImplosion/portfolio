extends Control

const OwnerID = preload("res://gameplay/owner_id.gd")
const DamageNumber = preload("res://interface/hud/damage_hud/damage_number.gd")

func display_damage_number(damage: float, color: Color) -> void:
	pass

func damage_profile_to_display(profile: DamageProfile, distance: float, max_color: Color, min_color: Color) -> DamageNumber.DisplayProfile:
	var display := DamageNumber.DisplayProfile.new()
	
	if !profile.falloff:
		display.color = max_color
		return display
	
	display.color = max_color.lerp(min_color,profile.get_normalized(distance))
	
	return display
