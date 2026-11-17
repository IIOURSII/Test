class_name DummyController
extends RefCounted
## Mannequin d'entraînement : ne bouge pas, se tourne juste vers sa cible.
## L'IA (étape 6) suivra exactement le même principe : elle produit des InputFrame.


func poll(world: SimWorld, self_index: int, target_index: int) -> InputFrame:
	var me := world.fighters[self_index]
	var target := world.fighters[target_index]
	var d := target.pos - me.pos
	var yaw := me.yaw
	if Vector2(d.x, d.z).length_squared() > 0.0001:
		yaw = InputFrame.yaw_to_int(atan2(-d.x, -d.z))
	return InputFrame.new(0, yaw, 0)
