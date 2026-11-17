extends RefCounted
## Base class for tests. Name files test_*.gd and methods test_*().

var failures: Array[String] = []
var _current := ""

func assert_true(cond: bool, msg := "") -> void:
	if not cond:
		failures.append("%s: expected true. %s" % [_current, msg])

func assert_false(cond: bool, msg := "") -> void:
	assert_true(not cond, msg)

func assert_eq(actual: Variant, expected: Variant, msg := "") -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s. %s" % [_current, str(expected), str(actual), msg])

func assert_near(actual: float, expected: float, eps := 0.001, msg := "") -> void:
	if absf(actual - expected) > eps:
		failures.append("%s: expected ~%s, got %s. %s" % [_current, expected, actual, msg])
