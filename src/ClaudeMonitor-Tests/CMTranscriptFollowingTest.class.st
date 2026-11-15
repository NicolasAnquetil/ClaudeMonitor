"
I check that a CMActivityLog turns what Claude Code writes in a session transcript into activities: messages, readable thinking, and the steps of plans and to-do lists.
"
Class {
	#name : 'CMTranscriptFollowingTest',
	#superclass : 'TestCase',
	#instVars : [
		'log',
		'fileSystem',
		'transcript'
	],
	#category : 'ClaudeMonitor-Tests',
	#package : 'ClaudeMonitor-Tests'
}

{ #category : 'helpers' }
CMTranscriptFollowingTest >> append: aCollectionOfLines [

	| contents |
	contents := transcript contents.
	transcript writeStreamDo: [ :stream |
			stream nextPutAll: contents.
			aCollectionOfLines do: [ :line |
					stream
						nextPutAll: line;
						lf ] ]
]

{ #category : 'helpers' }
CMTranscriptFollowingTest >> assistantLine: anUuid type: aType text: aString [

	| field |
	field := aType = 'thinking'
		         ifTrue: [ 'thinking' ]
		         ifFalse: [ 'text' ].
	^ '{"type":"assistant","uuid":"' , anUuid , '","timestamp":"2026-11-15T12:00:00.000Z","message":{"content":[{"type":"' , aType
	  , '","' , field , '":"' , aString , '"}]}}'
]

{ #category : 'helpers' }
CMTranscriptFollowingTest >> event: aName [

	^ Dictionary new
		  at: 'hook_event_name' put: aName;
		  at: 'session_id' put: 's1';
		  at: 'transcript_path' put: transcript fullName;
		  yourself
]

{ #category : 'helpers' }
CMTranscriptFollowingTest >> pre: anId [

	^ self pre: anId tool: 'Bash' input: (Dictionary with: 'command' -> 'ls')
]

{ #category : 'helpers' }
CMTranscriptFollowingTest >> pre: anId tool: aToolName input: aDictionary [

	^ (self event: 'PreToolUse')
		  at: 'tool_use_id' put: anId;
		  at: 'tool_name' put: aToolName;
		  at: 'tool_input' put: aDictionary;
		  at: 'prompt_id' put: 'p1';
		  yourself
]

{ #category : 'helpers' }
CMTranscriptFollowingTest >> prompt: aPromptId [

	^ (self event: 'UserPromptSubmit')
		  at: 'prompt_id' put: aPromptId;
		  at: 'prompt' put: 'do it';
		  yourself
]

{ #category : 'running' }
CMTranscriptFollowingTest >> setUp [

	super setUp.
	fileSystem := FileSystem memory.
	transcript := fileSystem / 'session.jsonl'.
	transcript writeStreamDo: [ :stream |  ].
	log := CMActivityLog new.
	log fileSystem: fileSystem
]

{ #category : 'tests' }
CMTranscriptFollowingTest >> testATodoListHasOneStepPerTodo [

	| todos tool |
	todos := {
		         (Dictionary new
			          at: 'content' put: 'Write the tests';
			          at: 'status' put: 'completed';
			          yourself).
		         (Dictionary new
			          at: 'content' put: 'Make them pass';
			          at: 'status' put: 'in_progress';
			          yourself) }.
	tool := log handleHookEvent: (self pre: 't1' tool: 'TodoWrite' input: (Dictionary with: 'todos' -> todos)).
	self assert: (tool children collect: [ :each | each text ]) asArray equals: #( 'Write the tests' 'Make them pass' ).
	self assert: (tool children collect: [ :each | each stepState ]) asArray equals: #( 'completed' 'in_progress' ).
	self assert: (tool children allSatisfy: [ :each | each isStep and: [ each isRunning not ] ])
]

{ #category : 'tests' }
CMTranscriptFollowingTest >> testEmptyThinkingAndSubagentEntriesAreSkipped [

	| prompt |
	self append: { (self userLine: 'p1') }.
	prompt := log handleHookEvent: (self prompt: 'p1').
	self append: {
			(self assistantLine: 'a1' type: 'thinking' text: '').
			'{"type":"assistant","isSidechain":true,"uuid":"a2","message":{"content":[{"type":"text","text":"from a subagent"}]}}' }.
	log handleHookEvent: (self event: 'Stop').
	self assert: prompt children isEmpty
]

{ #category : 'tests' }
CMTranscriptFollowingTest >> testEntriesOfPromptsNotMonitoredAreSkipped [

	self append: {
			(self userLine: 'p0').
			(self assistantLine: 'a1' type: 'text' text: 'Before the monitor.') }.
	log handleHookEvent: (self prompt: 'p1').
	self assert: (log activities noneSatisfy: [ :each | each isMessage ])
]

{ #category : 'tests' }
CMTranscriptFollowingTest >> testMessagesAndThinkingComeBeforeTheToolCallUnderTheirPrompt [

	| prompt tool |
	self append: { (self userLine: 'p1') }.
	prompt := log handleHookEvent: (self prompt: 'p1').
	self append: {
			(self assistantLine: 'a1' type: 'thinking' text: 'I should look first').
			(self assistantLine: 'a2' type: 'text' text: 'First I look.') }.
	tool := log handleHookEvent: (self pre: 't1').
	self assert: (prompt children collect: [ :each | each kind ]) asArray equals: #( #thinking #message #tool ).
	self assert: prompt children first text equals: 'I should look first'.
	self assert: prompt children second text equals: 'First I look.'.
	self assert: prompt children second summary equals: 'First I look.'.
	self assert: prompt children last identicalTo: tool
]

{ #category : 'tests' }
CMTranscriptFollowingTest >> testThePlanOfPlanModeHasOneStepPerItem [

	| plan tool |
	plan := '# Plan

Some context.

1. Read the transcript
2. Show the entries
- Test it'.
	tool := log handleHookEvent: (self pre: 't1' tool: 'ExitPlanMode' input: (Dictionary with: 'plan' -> plan)).
	self
		assert: (tool children collect: [ :each | each text ]) asArray
		equals: #( 'Plan' 'Read the transcript' 'Show the entries' 'Test it' )
]

{ #category : 'tests' }
CMTranscriptFollowingTest >> testTheTranscriptIsReadOnce [

	| prompt |
	self append: { (self userLine: 'p1') }.
	prompt := log handleHookEvent: (self prompt: 'p1').
	self append: { (self assistantLine: 'a1' type: 'text' text: 'One.') }.
	log handleHookEvent: (self event: 'Stop').
	log handleHookEvent: (self event: 'Stop').
	self assert: prompt children size equals: 1.
	self append: { (self assistantLine: 'a2' type: 'text' text: 'Two.') }.
	log handleHookEvent: (self event: 'Stop').
	self assert: (prompt children collect: [ :each | each text ]) asArray equals: #( 'One.' 'Two.' )
]

{ #category : 'tests' }
CMTranscriptFollowingTest >> testTranscriptTimesAreLocal [

	| prompt message |
	self append: { (self userLine: 'p1') }.
	prompt := log handleHookEvent: (self prompt: 'p1').
	self append: { (self assistantLine: 'a1' type: 'text' text: 'Hello.') }.
	log handleHookEvent: (self event: 'Stop').
	message := prompt children first.
	self assert: message startedAt equals: (DateAndTime fromString: '2026-11-15T12:00:00.000Z').
	self assert: message startedAt offset equals: DateAndTime now offset
]

{ #category : 'helpers' }
CMTranscriptFollowingTest >> userLine: aPromptId [

	^ '{"type":"user","promptId":"' , aPromptId , '","message":{"role":"user","content":"do it"}}'
]
