"
Tests for ClaudeMonitor, using hook payloads shaped like the ones Claude Code sends.
"
Class {
	#name : 'CMActivityLogTest',
	#superclass : 'TestCase',
	#instVars : [
		'log'
	],
	#category : 'ClaudeMonitor-Tests',
	#package : 'ClaudeMonitor-Tests'
}

{ #category : 'running' }
CMActivityLogTest >> post: anId [

	^ Dictionary new
		  at: 'hook_event_name' put: 'PostToolUse';
		  at: 'session_id' put: 's1';
		  at: 'tool_name' put: 'Bash';
		  at: 'tool_use_id' put: anId;
		  at: 'duration_ms' put: 44;
		  at: 'tool_input' put: (Dictionary new
				   at: 'command' put: 'ls -l';
				   at: 'description' put: 'List files';
				   yourself);
		  at: 'tool_response' put: (Dictionary new
			   at: 'stdout' put: 'a b';
			   yourself);
		  yourself
]

{ #category : 'running' }
CMActivityLogTest >> pre: anId [

	^ Dictionary new
		  at: 'hook_event_name' put: 'PreToolUse';
		  at: 'session_id' put: 's1';
		  at: 'tool_name' put: 'Bash';
		  at: 'tool_use_id' put: anId;
		  at: 'tool_input' put: (Dictionary new
				   at: 'command' put: 'ls -l';
				   at: 'description' put: 'List files';
				   yourself);
		  yourself
]

{ #category : 'tests' }
CMActivityLogTest >> prompt: aPromptId [

	^ Dictionary new
		  at: 'hook_event_name' put: 'UserPromptSubmit';
		  at: 'session_id' put: 's1';
		  at: 'prompt_id' put: aPromptId;
		  at: 'prompt' put: 'do ' , aPromptId;
		  yourself
]

{ #category : 'running' }
CMActivityLogTest >> setUp [

	super setUp.
	log := CMActivityLog new
]

{ #category : 'tests - removing' }
CMActivityLogTest >> testANewPromptAfterARemovedOneIsShown [

	| p2 t2 |
	log remove: (log handleHookEvent: (self prompt: 'p1')).
	p2 := log handleHookEvent: (self prompt: 'p2').
	t2 := log handleHookEvent: (self pre: 't2').
	self assert: t2 parent identicalTo: p2.
	self assert: log size equals: 2
]

{ #category : 'tests' }
CMActivityLogTest >> testChangesAreAnnounced [

	| announced |
	announced := OrderedCollection new.
	log announcer when: CMActivityAnnouncement do: [ :ann | announced add: ann class ] for: self.
	log handleHookEvent: (self pre: 't1').
	log handleHookEvent: (self post: 't1').
	self assert: announced asArray equals: {
			CMActivityAdded.
			CMActivityChanged }
]

{ #category : 'tests' }
CMActivityLogTest >> testEventsGiveTheirSession [

	| session |
	log handleHookEvent: (self pre: 't1').
	log handleHookEvent: (self post: 't1').
	self assert: log sessions size equals: 1.
	session := log sessionWithId: 's1'.
	self assert: session id equals: 's1'.
	self assert: session startedAt isNotNil.
	self assert: session displayTitle equals: 'Session s1'
]

{ #category : 'tests' }
CMActivityLogTest >> testFailureMarksTheActivityFailed [

	| failure |
	log handleHookEvent: (self pre: 't1').
	failure := (self pre: 't1')
		           at: 'hook_event_name' put: 'PostToolUseFailure';
		           at: 'error' put: 'command not found';
		           yourself.
	log handleHookEvent: failure.
	self assert: (log activityWithId: 't1') isFailed.
	self assert: (log activityWithId: 't1') response equals: 'command not found'
]

{ #category : 'tests - removing' }
CMActivityLogTest >> testLateEventsOfARemovedPromptAreDropped [

	| p1 t1 |
	p1 := log handleHookEvent: (self prompt: 'p1').
	t1 := log handleHookEvent: ((self pre: 't1')
			       at: 'prompt_id' put: 'p1';
			       yourself).
	log remove: p1.
	self assert: (log handleHookEvent: ((self post: 't1')
				  at: 'prompt_id' put: 'p1';
				  yourself)) isNil.
	self assert: (log handleHookEvent: ((self pre: 't2')
				  at: 'prompt_id' put: 'p1';
				  yourself)) isNil.
	self assert: (log handleHookEvent: (self pre: 't3')) isNil.
	self assert: log size equals: 0
]

{ #category : 'tests' }
CMActivityLogTest >> testPostBeforePreGivesOneCompletedActivity [

	| activity |
	log handleHookEvent: (self post: 't1').
	log handleHookEvent: (self pre: 't1').
	self assert: log size equals: 1.
	activity := log activityWithId: 't1'.
	self assert: activity status equals: #ok.
	self assert: activity why equals: 'List files'
]

{ #category : 'tests' }
CMActivityLogTest >> testPostToolUseCompletesTheActivity [

	| activity |
	log handleHookEvent: (self pre: 't1').
	log handleHookEvent: (self post: 't1').
	self assert: log size equals: 1.
	activity := log activityWithId: 't1'.
	self assert: activity status equals: #ok.
	self assert: activity durationMilliseconds equals: 44.
	self assert: (activity response includesSubstring: 'a b')
]

{ #category : 'tests' }
CMActivityLogTest >> testPreToolUseStartsARunningActivity [

	| activity |
	activity := log handleHookEvent: (self pre: 't1').
	self assert: log size equals: 1.
	self assert: activity isRunning.
	self assert: activity toolName equals: 'Bash'.
	self assert: activity why equals: 'List files'.
	self assert: activity subject equals: 'ls -l'.
	self assert: activity summary equals: 'List files'
]

{ #category : 'tests' }
CMActivityLogTest >> testPromptIsRecorded [

	| activity |
	activity := log handleHookEvent: (Dictionary new
			             at: 'hook_event_name' put: 'UserPromptSubmit';
			             at: 'prompt' put: 'restart the client';
			             yourself).
	self assert: activity isPrompt.
	self assert: activity summary equals: 'restart the client'.
	self assert: activity shortToolName equals: 'prompt'
]

{ #category : 'tests - removing' }
CMActivityLogTest >> testRemovalIsAnnounced [

	| p1 t1 announced |
	p1 := log handleHookEvent: (self prompt: 'p1').
	t1 := log handleHookEvent: ((self pre: 't1')
			       at: 'prompt_id' put: 'p1';
			       yourself).
	log announcer when: CMActivitiesRemoved do: [ :ann | announced := ann ] for: self.
	log remove: p1.
	self assert: announced activities asSet equals: {
			p1.
			t1 } asSet.
	self assert: announced session isNil
]

{ #category : 'tests - removing' }
CMActivityLogTest >> testRemovingAPromptRemovesWhatIsUnderIt [

	| p1 t1 p2 |
	p1 := log handleHookEvent: (self prompt: 'p1').
	t1 := log handleHookEvent: ((self pre: 't1')
			       at: 'prompt_id' put: 'p1';
			       yourself).
	p2 := log handleHookEvent: (self prompt: 'p2').
	log remove: p1.
	self assert: log activities asArray equals: { p2 }.
	self assert: (log activityWithId: t1 id) isNil.
	self assert: p1 isRemoved.
	self assert: t1 isRemoved
]

{ #category : 'tests - removing' }
CMActivityLogTest >> testRemovingASessionLeavesACurrentSession [

	log handleHookEvent: (self prompt: 'p1').
	self assert: log currentSession isNil.
	log remove: (log sessionWithId: 's1').
	self assert: log currentSession isNotNil
]

{ #category : 'tests - removing' }
CMActivityLogTest >> testRemovingASessionRemovesItsActivities [

	| session other p2 |
	log handleHookEvent: (self prompt: 'p1').
	session := log sessionWithId: 's1'.
	other := log startSessionNamed: 'Other'.
	p2 := log handleHookEvent: (self prompt: 'p2').
	log remove: session.
	self assert: (log sessionWithId: 's1') isNil.
	self assert: log activities asArray equals: { p2 }.
	self assert: log currentSession identicalTo: other
]

{ #category : 'tests - removing' }
CMActivityLogTest >> testRemovingAToolDetachesItFromItsPrompt [

	| p1 t1 |
	p1 := log handleHookEvent: (self prompt: 'p1').
	t1 := log handleHookEvent: ((self pre: 't1')
			       at: 'prompt_id' put: 'p1';
			       yourself).
	log remove: t1.
	self assert: p1 children isEmpty.
	self assert: log activities asArray equals: { p1 }
]

{ #category : 'tests - removing' }
CMActivityLogTest >> testRemovingTheCurrentSessionMakesTheLatestCurrent [

	| older newer |
	older := log startSessionNamed: 'Older'.
	older startedAt: DateAndTime now - 1 hour.
	newer := log startSessionNamed: 'Newer'.
	log makeCurrent: older.
	log remove: older.
	self assert: log currentSession identicalTo: newer
]

{ #category : 'tests - removing' }
CMActivityLogTest >> testRemovingTheLastSessionStartsANewOne [

	| only |
	only := log startSessionNamed: 'Only'.
	log remove: only.
	self assert: log currentSession notNil.
	self deny: log currentSession identicalTo: only.
	self assert: (log sessions includes: log currentSession)
]

{ #category : 'tests' }
CMActivityLogTest >> testSessionDateString [

	| session |
	session := CMSession new
		           startedAt: (DateAndTime
				            year: 2026
				            month: 11
				            day: 15
				            hour: 11
				            minute: 27
				            second: 34);
		           yourself.
	self assert: session dateString equals: 'Sun 15 Nov 2026, 11:27'
]

{ #category : 'tests' }
CMActivityLogTest >> testShortToolNameOfAnMCPTool [

	| activity |
	activity := CMActivity new toolName: 'mcp__pharo__image_evaluate'.
	self assert: activity shortToolName equals: 'pharo image_evaluate'.
	self assert: activity isPharoTool
]

{ #category : 'tests' }
CMActivityLogTest >> testSubjectOfAMethodCompile [

	| activity |
	activity := CMActivity new
		            toolName: 'mcp__pharo__method_compile';
		            input: (Dictionary new
				             at: 'class' put: 'Foo';
				             at: 'side' put: 'class';
				             at: 'source' put: {
						             ('bar: x' , String cr , '	^ x').
						             ('baz' , String lf , '	^ 1') };
				             yourself);
		            yourself.
	self assert: activity subject equals: 'Foo class>>bar:, baz'
]

{ #category : 'tests' }
CMActivityLogTest >> testSubjectOfCodeSkipsTemporaries [

	| activity |
	activity := CMActivity new
		            toolName: 'mcp__pharo__image_evaluate';
		            input: (Dictionary new
				             at: 'code' put: '| a b |
"setup"
a := CMMonitor default.
b := 3';
				             yourself);
		            yourself.
	self assert: activity subject equals: 'a := CMMonitor default.'
]

{ #category : 'tests' }
CMActivityLogTest >> testToolCallBeforeAnyPromptHasNoParent [

	self assert: (log handleHookEvent: (self pre: 't1')) parent isNil
]

{ #category : 'tests' }
CMActivityLogTest >> testToolCallsHangUnderTheirPrompt [

	| p1 p2 t1 t2 |
	p1 := log handleHookEvent: (self prompt: 'p1').
	t1 := log handleHookEvent: ((self pre: 't1')
			       at: 'prompt_id' put: 'p1';
			       yourself).
	p2 := log handleHookEvent: (self prompt: 'p2').
	t2 := log handleHookEvent: ((self pre: 't2')
			       at: 'prompt_id' put: 'p2';
			       yourself).
	self assert: t1 parent identicalTo: p1.
	self assert: t2 parent identicalTo: p2.
	self assert: p1 children asArray equals: { t1 }.
	self assert: p1 parent isNil.
	self assert: t1 depth equals: 1
]

{ #category : 'tests' }
CMActivityLogTest >> testUnknownEventIsIgnored [

	self assert: (log handleHookEvent: (Dictionary with: 'hook_event_name' -> 'Stop')) isNil.
	self assert: log size equals: 0
]

{ #category : 'tests' }
CMActivityLogTest >> testWithoutPromptIdTheLastPromptOfTheSessionIsTheParent [

	| p1 t1 |
	p1 := log handleHookEvent: (self prompt: 'p1').
	t1 := log handleHookEvent: (self pre: 't1').
	self assert: t1 parent identicalTo: p1
]
