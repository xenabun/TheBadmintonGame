extends Node

func look_vector(node):
	return -node.get_global_transform().basis.z.normalized()
