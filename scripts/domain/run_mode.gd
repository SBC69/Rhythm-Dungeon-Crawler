# scripts/domain/run_mode.gd
class_name RunMode
extends RefCounted

enum Mode {
	NONE = 0,
	TIMED_100 = 1,
	ENDLESS = 2
}

enum Outcome {
	NONE = 0,
	SUCCESS = 1,
	DEATH = 2,
	RETIRED = 3
}

static func mode_to_string(mode: Mode) -> String:
	match mode:
		Mode.TIMED_100:
			return "TIMED_100"
		Mode.ENDLESS:
			return "ENDLESS"
	return "NONE"

static func mode_from_string(val: String) -> Mode:
	match val:
		"TIMED_100":
			return Mode.TIMED_100
		"ENDLESS":
			return Mode.ENDLESS
	return Mode.NONE

static func outcome_to_string(outcome: Outcome) -> String:
	match outcome:
		Outcome.SUCCESS:
			return "SUCCESS"
		Outcome.DEATH:
			return "DEATH"
		Outcome.RETIRED:
			return "RETIRED"
	return "NONE"

static func outcome_from_string(val: String) -> Outcome:
	match val:
		"SUCCESS":
			return Outcome.SUCCESS
		"DEATH":
			return Outcome.DEATH
		"RETIRED":
			return Outcome.RETIRED
	return Outcome.NONE
