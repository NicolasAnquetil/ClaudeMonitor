"
I test the sessions the user starts in the monitor: what comes after one is started is listed under it.
"
Class {
	#name : 'CMUserSessionTest',
	#superclass : 'TestCase',
	#instVars : [
		'log'
	],
	#category : 'ClaudeMonitor-Tests',
	#package : 'ClaudeMonitor-Tests'
}

{ #category : 'running' }
CMUserSessionTest >> prompt: aText inSession: aSessionId [

	^ log handleHookEvent: (Dictionary new
			   at: 'hook_event_name' put: 'UserPromptSubmit';
			   at: 'session_id' put: aSessionId;
			   at: 'prompt_id' put: UUID new asString;
			   at: 'prompt' put: aText;
			   yourself)
]

{ #category : 'running' }
CMUserSessionTest >> setUp [

	super setUp.
	log := CMActivityLog new
]

{ #category : 'tests' }
CMUserSessionTest >> testClaudeSessionRefreshDoesNotTouchAUserSessionTitle [

	| session |
	session := log startUserSessionNamed: 'Mine'.
	log refreshTitleOf: session.
	self assert: session displayTitle equals: 'Mine'
]

{ #category : 'tests' }
CMUserSessionTest >> testRenamingASessionIsAnnounced [

	| session announced |
	session := log startUserSessionNamed: 'Draft'.
	log announcer when: CMSessionChanged do: [ :ann | announced := ann session ] for: self.
	log rename: session to: 'Final'.
	self assert: session displayTitle equals: 'Final'.
	self assert: announced identicalTo: session
]

{ #category : 'tests' }
CMUserSessionTest >> testStartingASessionAddsIt [

	| session |
	session := log startUserSessionNamed: 'Token costs'.
	self assert: session isByUser.
	self assert: session displayTitle equals: 'Token costs'.
	self assert: (log sessionWithId: session id) identicalTo: session.
	self assert: log currentUserSession identicalTo: session
]

{ #category : 'tests' }
CMUserSessionTest >> testStartingAnotherSessionTakesOver [

	| first second prompt |
	first := log startUserSessionNamed: 'One'.
	second := log startUserSessionNamed: 'Two'.
	prompt := self prompt: 'p' inSession: 's1'.
	self assert: prompt groupId equals: second id.
	self deny: first id equals: second id
]

{ #category : 'tests' }
CMUserSessionTest >> testStartingIsAnnounced [

	| announced |
	log announcer when: CMSessionStarted do: [ :ann | announced := ann session ] for: self.
	self assert: (log startUserSessionNamed: 'New') identicalTo: announced
]

{ #category : 'tests' }
CMUserSessionTest >> testWhatComesAfterGoesUnderTheUserSession [

	| before session after other tool |
	before := self prompt: 'before' inSession: 's1'.
	session := log startUserSessionNamed: 'Mine'.
	after := self prompt: 'after' inSession: 's1'.
	other := self prompt: 'in another Claude session' inSession: 's2'.
	tool := self toolCall: 't1' inSession: 's3'.
	self assert: before groupId equals: 's1'.
	self assert: after groupId equals: session id.
	self assert: other groupId equals: session id.
	self assert: tool groupId equals: session id.
	"The Claude session is kept"
	self assert: after sessionId equals: 's1'
]

{ #category : 'tests' }
CMUserSessionTest >> testWithoutUserSessionActivitiesAreInTheirClaudeSession [

	| prompt |
	prompt := self prompt: 'first' inSession: 's1'.
	self assert: prompt groupId equals: 's1'.
	self assert: log currentUserSession isNil
]

{ #category : 'running' }
CMUserSessionTest >> toolCall: anId inSession: aSessionId [

	^ log handleHookEvent: (Dictionary new
			   at: 'hook_event_name' put: 'PreToolUse';
			   at: 'session_id' put: aSessionId;
			   at: 'tool_use_id' put: anId;
			   at: 'tool_name' put: 'Bash';
			   at: 'tool_input' put: (Dictionary with: 'command' -> 'ls');
			   yourself)
]
