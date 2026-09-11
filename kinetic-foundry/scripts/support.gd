extends StaticBody3D

var frame: StructuralFrame

func machine_hit(amount: float, direction: Vector3) -> void:
    if frame == null:
        return
    var index := int(get_meta("support_index", -1))
    frame.damage_support(index, amount, direction)
