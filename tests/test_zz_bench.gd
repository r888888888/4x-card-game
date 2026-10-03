extends "res://tests/lib/test_case.gd"

func _ms(t0: int) -> String:
	return "%.2f" % [(Time.get_ticks_usec() - t0) / 1000.0]

func test_bench() -> void:
	var t0 := Time.get_ticks_usec()
	for i in 20: GameTheme.build()
	print("GameTheme.build: %.2f ms" % [(Time.get_ticks_usec() - t0) / 1000.0 / 20])
	var scene: PackedScene = load("res://ui/main.tscn")
	for k in 4:
		t0 = Time.get_ticks_usec()
		var main: Node = scene.instantiate()
		var t_inst := _ms(t0)
		t0 = Time.get_ticks_usec()
		(Engine.get_main_loop() as SceneTree).root.add_child(main)
		var t_add := _ms(t0)
		t0 = Time.get_ticks_usec()
		main.start_game(1)
		var t_start := _ms(t0)
		t0 = Time.get_ticks_usec()
		await wait_frames(1)
		var t_f1 := _ms(t0)
		t0 = Time.get_ticks_usec()
		await wait_frames(1)
		var t_f2 := _ms(t0)
		t0 = Time.get_ticks_usec()
		await wait_frames(10)
		var t_f10 := _ms(t0)
		t0 = Time.get_ticks_usec()
		close_main(main)
		print("ms: inst %s add %s start %s frame1 %s frame2 %s next10 %s free %s" % [t_inst, t_add, t_start, t_f1, t_f2, t_f10, _ms(t0)])
	check(true, "ran")
