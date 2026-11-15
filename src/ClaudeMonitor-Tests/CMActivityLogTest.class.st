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
