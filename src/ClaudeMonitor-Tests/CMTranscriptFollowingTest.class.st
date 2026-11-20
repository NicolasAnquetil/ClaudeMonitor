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
CMTranscriptFollowingTest >> callLine: anUuid call: aMessageId block: aBlockJson output: anOutput thinking: aThinking [
	"An assistant entry of the model call aMessageId, with its usage"

	^ '{"type":"assistant","uuid":"' , anUuid , '","timestamp":"2026-11-15T12:00:00.000Z","message":{"id":"' , aMessageId
	  , '","content":[' , aBlockJson
	  , '],"usage":{"input_tokens":2,"cache_creation_input_tokens":100,"cache_read_input_tokens":1000,"output_tokens":'
	  , anOutput printString , ',"output_tokens_details":{"thinking_tokens":' , aThinking printString , '}}}}'
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
	log fileSystem: fileSystem.
	log laterReadDelays: #(  )
]

{ #category : 'tests' }
CMTranscriptFollowingTest >> testAMessageReadLateTakesTheToolCallsAfterIt [

	| prompt early late message |
	self append: { (self userLine: 'p1') }.
	prompt := log handleHookEvent: (self prompt: 'p1').
	early := log handleHookEvent: (self pre: 't0').
	early startedAt: (DateAndTime fromString: '2026-11-15T11:00:00.000Z').
	late := log handleHookEvent: (self pre: 't1').
	late startedAt: (DateAndTime fromString: '2026-11-15T13:00:00.000Z').
	"The message, at 12:00, is read only now"
	self append: { (self assistantLine: 'a1' type: 'text' text: 'Then I fix.') }.
	log handleHookEvent: (self event: 'Stop').
	message := log activityWithId: 'a1#1'.
	self assert: early parent identicalTo: prompt.
	self assert: late parent identicalTo: message.
	self assert: (prompt children includes: late) not.
	self assert: message children asArray equals: { late }
]

{ #category : 'tests - tokens' }
CMTranscriptFollowingTest >> testASingleBlockCallIsExact [

	| message |
	self append: { (self userLine: 'p1') }.
	log handleHookEvent: (self prompt: 'p1').
	self append: { (self
			 callLine: 'a1'
			 call: 'm1'
			 block: (self textBlock: 'Done.')
			 output: 50
			 thinking: 0) }.
	log handleHookEvent: (self event: 'Stop').
	message := log activityWithId: 'a1#1'.
	self assert: message outputTokens equals: 50.
	self deny: message isTokenEstimate
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

{ #category : 'tests - tokens' }
CMTranscriptFollowingTest >> testHiddenThinkingCountsForTheOtherBlock [

	| tool |
	self append: { (self userLine: 'p1') }.
	log handleHookEvent: (self prompt: 'p1').
	self append: {
			(self
				 callLine: 'a1'
				 call: 'm1'
				 block: (self thinkingBlock: '')
				 output: 120
				 thinking: 80).
			(self
				 callLine: 'a2'
				 call: 'm1'
				 block: (self toolBlock: 't1')
				 output: 120
				 thinking: 80) }.
	tool := log handleHookEvent: (self pre: 't1').
	self assert: tool outputTokens equals: 120.
	self deny: tool isTokenEstimate
]

{ #category : 'tests - tokens' }
CMTranscriptFollowingTest >> testLaterUsageOfACallReplacesTheEarlierOne [

	| message |
	self append: { (self userLine: 'p1') }.
	log handleHookEvent: (self prompt: 'p1').
	self append: { (self
			 callLine: 'a1'
			 call: 'm1'
			 block: (self textBlock: 'Hi')
			 output: 10
			 thinking: 0) }.
	log handleHookEvent: (self event: 'Stop').
	self append: { (self
			 callLine: 'a2'
			 call: 'm1'
			 block: (self toolBlock: 't1')
			 output: 90
			 thinking: 0) }.
	log handleHookEvent: (self pre: 't1').
	message := log activityWithId: 'a1#1'.
	self assert: message call outputTokens equals: 90
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
	self assert: (prompt children collect: [ :each | each kind ]) asArray equals: #( #thinking #message ).
	self assert: prompt children first text equals: 'I should look first'.
	self assert: prompt children second text equals: 'First I look.'.
	self assert: prompt children second summary equals: 'First I look.'.
	self assert: prompt children second children asArray equals: { tool }
]

{ #category : 'tests - tokens' }
CMTranscriptFollowingTest >> testPromptTotalsCountEachCallOnce [

	| prompt |
	self append: { (self userLine: 'p1') }.
	prompt := log handleHookEvent: (self prompt: 'p1').
	self append: {
			(self
				 callLine: 'a1'
				 call: 'm1'
				 block: (self textBlock: 'First')
				 output: 300
				 thinking: 100).
			(self
				 callLine: 'a2'
				 call: 'm1'
				 block: (self toolBlock: 't1')
				 output: 300
				 thinking: 100) }.
	log handleHookEvent: (self pre: 't1').
	self append: { (self
			 callLine: 'a3'
			 call: 'm2'
			 block: (self textBlock: 'Then')
			 output: 40
			 thinking: 0) }.
	log handleHookEvent: (self event: 'Stop').
	self assert: prompt outputTokens equals: 340.
	self assert: prompt thinkingTokens equals: 100.
	self assert: prompt inputTokens equals: 2 * (2 + 100 + 1000).
	self deny: prompt isTokenEstimate
]

{ #category : 'tests' }
CMTranscriptFollowingTest >> testTheLastMessageWrittenAfterStopIsRead [
	"Claude Code may write the last message of an answer after it runs the Stop hook"

	| prompt |
	log laterReadDelays: #( 50 ).
	self append: { (self userLine: 'p1') }.
	prompt := log handleHookEvent: (self prompt: 'p1').
	log handleHookEvent: (self event: 'Stop').
	self append: { (self assistantLine: 'a1' type: 'text' text: 'Done.') }.
	self assert: prompt children isEmpty.
	(Delay forMilliseconds: 300) wait.
	self assert: (prompt children collect: [ :each | each text ]) asArray equals: #( 'Done.' )
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

{ #category : 'tests - tokens' }
CMTranscriptFollowingTest >> testThinkingHasItsExactTokensAndTheRestIsShared [

	| thinking message tool |
	self append: { (self userLine: 'p1') }.
	log handleHookEvent: (self prompt: 'p1').
	self append: {
			(self
				 callLine: 'a1'
				 call: 'm1'
				 block: (self thinkingBlock: 'Let me see')
				 output: 300
				 thinking: 100).
			(self
				 callLine: 'a2'
				 call: 'm1'
				 block: (self textBlock: 'Hello')
				 output: 300
				 thinking: 100).
			(self
				 callLine: 'a3'
				 call: 'm1'
				 block: (self toolBlock: 't1')
				 output: 300
				 thinking: 100) }.
	tool := log handleHookEvent: (self pre: 't1').
	thinking := log activityWithId: 'a1#1'.
	message := log activityWithId: 'a2#1'.
	self assert: thinking outputTokens equals: 100.
	self deny: thinking isTokenEstimate.
	self assert: tool isTokenEstimate.
	self assert: tool ownTokens > message ownTokens.
	self assert: (message ownTokens + tool ownTokens - 200) abs <= 1.
	"The message row shows its tool calls with it"
	self assert: message outputTokens equals: message ownTokens + tool ownTokens
]

{ #category : 'tests - tokens' }
CMTranscriptFollowingTest >> testToolCallReadAfterItsHookGetsItsTokens [

	| tool |
	self append: { (self userLine: 'p1') }.
	log handleHookEvent: (self prompt: 'p1').
	tool := log handleHookEvent: (self pre: 't1').
	self assert: tool outputTokens isNil.
	self append: { (self
			 callLine: 'a1'
			 call: 'm1'
			 block: (self toolBlock: 't1')
			 output: 70
			 thinking: 0) }.
	log handleHookEvent: (self event: 'Stop').
	self assert: tool outputTokens equals: 70
]

{ #category : 'tests' }
CMTranscriptFollowingTest >> testToolCallsHangUnderThePrecedingMessage [

	| prompt message tool |
	self append: { (self userLine: 'p1') }.
	prompt := log handleHookEvent: (self prompt: 'p1').
	self append: {
			(self assistantLine: 'a1' type: 'thinking' text: 'Let me think').
			(self assistantLine: 'a2' type: 'text' text: 'First I look.') }.
	tool := log handleHookEvent: (self pre: 't1').
	message := log activityWithId: 'a2#1'.
	self assert: tool parent identicalTo: message.
	self assert: message children asArray equals: { tool }.
	self assert: (prompt children collect: [ :each | each kind ]) asArray equals: #( #thinking #message ).
	self assert: tool depth equals: 2
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
CMTranscriptFollowingTest >> textBlock: aString [

	^ '{"type":"text","text":"' , aString , '"}'
]

{ #category : 'helpers' }
CMTranscriptFollowingTest >> thinkingBlock: aString [

	^ '{"type":"thinking","thinking":"' , aString , '"}'
]

{ #category : 'helpers' }
CMTranscriptFollowingTest >> toolBlock: anId [
	"A Bash call, like the one pre: sends"

	^ '{"type":"tool_use","id":"' , anId , '","name":"Bash","input":{"command":"ls"}}'
]

{ #category : 'helpers' }
CMTranscriptFollowingTest >> userLine: aPromptId [

	^ '{"type":"user","promptId":"' , aPromptId , '","message":{"role":"user","content":"do it"}}'
]
