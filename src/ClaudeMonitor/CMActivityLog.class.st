"
I am the list of activities (CMActivity) received from Claude Code hooks, oldest first.

#handleHookEvent: takes one hook payload (a Dictionary decoded from the JSON Claude Code sends) and creates or completes the matching activity. Every change is announced (CMActivityAdded, CMActivityChanged) so a view can follow along. Hook events arrive on server threads, so changes are serialized with a mutex; announcements are delivered on the thread that received the event.

I keep the last raw payloads in rawEvents, to help debugging the hook format.
"
Class {
	#name : 'CMActivityLog',
	#superclass : 'Object',
	#instVars : [
		'activities',
		'byId',
		'announcer',
		'mutex',
		'transcriptReader',
		'rawEvents',
		'sessions',
		'promptsById',
		'lastPromptBySession'
	],
	#category : 'ClaudeMonitor-Model',
	#package : 'ClaudeMonitor',
	#tag : 'Model'
}

{ #category : 'accessing' }
CMActivityLog >> activities [
	"A copy, safe to iterate while events arrive"

	^ mutex critical: [ activities copy ]
]

{ #category : 'accessing' }
CMActivityLog >> activityWithId: aString [

	^ mutex critical: [ byId at: aString ifAbsent: [ nil ] ]
]

{ #category : 'private' }
CMActivityLog >> add: anActivity [

	mutex critical: [
			activities add: anActivity.
			byId at: anActivity id put: anActivity ].
	announcer announce: (CMActivityAdded new
			 activity: anActivity;
			 yourself)
]

{ #category : 'accessing' }
CMActivityLog >> announcer [

	^ announcer
]

{ #category : 'private' }
CMActivityLog >> explanationFor: aDictionary [
	"What Claude wrote before this call; nil when the transcript cannot be read"

	aDictionary at: 'transcript_path' ifPresent: [ :path |
			^ [ transcriptReader explanationIn: path asFileReference beforeToolUse: (aDictionary at: 'tool_use_id' ifAbsent: [ nil ]) ]
				  on: Error
				  do: [ nil ] ].
	^ nil
]

{ #category : 'hook events' }
CMActivityLog >> handleHookEvent: aDictionary [
	"Create or complete the activity a Claude Code hook payload reports. Unknown events are ignored."

	self rememberRawEvent: aDictionary.
	self noteSessionOf: aDictionary.
	aDictionary at: 'hook_event_name' ifPresent: [ :event |
			event = 'PreToolUse' ifTrue: [ ^ self toolStarted: aDictionary ].
			event = 'PostToolUse' ifTrue: [ ^ self tool: aDictionary finishedWith: #ok ].
			event = 'PostToolUseFailure' ifTrue: [ ^ self tool: aDictionary finishedWith: #failed ].
			event = 'UserPromptSubmit' ifTrue: [ ^ self promptSubmitted: aDictionary ] ].
	^ nil
]

{ #category : 'initialization' }
CMActivityLog >> initialize [

	super initialize.
	activities := OrderedCollection new.
	byId := Dictionary new.
	sessions := Dictionary new.
	announcer := Announcer new.
	mutex := Mutex new.
	rawEvents := OrderedCollection new.
	transcriptReader := CMTranscriptReader new
]

{ #category : 'hierarchy' }
CMActivityLog >> lastPromptBySession [

	^ lastPromptBySession ifNil: [ lastPromptBySession := Dictionary new ]
]

{ #category : 'accessing' }
CMActivityLog >> maxRawEvents [

	^ 50
]

{ #category : 'private' }
CMActivityLog >> maxResponseSize [

	^ 20000
]

{ #category : 'sessions' }
CMActivityLog >> noteSessionOf: aDictionary [
	"Make sure the session of this event is known, and its title up to date.
	The title is read again at most every titleCheckPeriod, as Claude Code updates it."

	| id session isNew |
	id := aDictionary at: 'session_id' ifAbsent: [ ^ nil ].
	isNew := false.
	session := mutex critical: [
			           sessions at: id ifAbsentPut: [
					           isNew := true.
					           CMSession new
						           id: id;
						           yourself ] ].
	aDictionary at: 'transcript_path' ifPresent: [ :path | session transcript ifNil: [ session transcript: path asFileReference ] ].
	isNew ifTrue: [ session startedAt: (self startTimeOf: session) ].
	(isNew or: [ session titleCheckedAt isNil or: [ DateAndTime now - session titleCheckedAt > self titleCheckPeriod ] ]) ifTrue: [
		self refreshTitleOf: session ].
	^ session
]

{ #category : 'hierarchy' }
CMActivityLog >> parentFor: aDictionary [
	"The prompt activity this event belongs to: the one with its prompt_id,
	else the last prompt of its session"

	^ mutex critical: [
			  | prompt |
			  aDictionary at: 'prompt_id' ifPresent: [ :id | prompt := self promptsById at: id ifAbsent: [ nil ] ].
			  prompt ifNil: [
				  aDictionary at: 'session_id' ifPresent: [ :id | prompt := self lastPromptBySession at: id ifAbsent: [ nil ] ] ].
			  prompt ]
]

{ #category : 'hook events' }
CMActivityLog >> promptSubmitted: aDictionary [

	| activity now |
	now := DateAndTime now.
	activity := CMActivity new
		            id: UUID new asString;
		            sessionId: (aDictionary at: 'session_id' ifAbsent: [ nil ]);
		            promptId: (aDictionary at: 'prompt_id' ifAbsent: [ nil ]);
		            kind: #prompt;
		            input: (Dictionary with: 'prompt' -> (aDictionary at: 'prompt' ifAbsent: [ '' ]));
		            status: #ok;
		            startedAt: now;
		            finishedAt: now;
		            yourself.
	self registerPrompt: activity.
	self add: activity.
	^ activity
]

{ #category : 'hierarchy' }
CMActivityLog >> promptsById [

	^ promptsById ifNil: [ promptsById := Dictionary new ]
]

{ #category : 'accessing' }
CMActivityLog >> rawEvents [

	^ mutex critical: [ rawEvents copy ]
]

{ #category : 'sessions' }
CMActivityLog >> refreshTitleOf: aSession [

	| newTitle |
	aSession titleCheckedAt: DateAndTime now.
	aSession transcript ifNil: [ ^ self ].
	newTitle := [ transcriptReader titleIn: aSession transcript ]
		            on: Error
		            do: [ nil ].
	(newTitle isNil or: [ newTitle = aSession title ]) ifTrue: [ ^ self ].
	aSession title: newTitle.
	announcer announce: (CMSessionChanged new
			 session: aSession;
			 yourself)
]

{ #category : 'hierarchy' }
CMActivityLog >> registerPrompt: anActivity [

	mutex critical: [
			anActivity promptId ifNotNil: [ :id | self promptsById at: id put: anActivity ].
			anActivity sessionId ifNotNil: [ :id | self lastPromptBySession at: id put: anActivity ] ]
]

{ #category : 'private' }
CMActivityLog >> rememberRawEvent: aDictionary [

	mutex critical: [
			rawEvents addLast: aDictionary.
			[ rawEvents size > self maxRawEvents ] whileTrue: [ rawEvents removeFirst ] ]
]

{ #category : 'private' }
CMActivityLog >> responseTextIn: aDictionary [

	| value text |
	value := aDictionary at: 'tool_response' ifAbsent: [ aDictionary at: 'error' ifAbsent: [ nil ] ].
	value ifNil: [ ^ '' ].
	text := value isString
		        ifTrue: [ value ]
		        ifFalse: [
				        [ STONJSON toStringPretty: value ]
					        on: Error
					        do: [ value printString ] ].
	^ text size > self maxResponseSize
		  ifTrue: [ (text first: self maxResponseSize) , String lf , '[...]' ]
		  ifFalse: [ text ]
]

{ #category : 'sessions' }
CMActivityLog >> sessionWithId: aString [

	^ mutex critical: [ sessions at: aString ifAbsent: [ nil ] ]
]

{ #category : 'sessions' }
CMActivityLog >> sessions [

	^ mutex critical: [ sessions copy ]
]

{ #category : 'accessing' }
CMActivityLog >> size [

	^ mutex critical: [ activities size ]
]

{ #category : 'sessions' }
CMActivityLog >> startTimeOf: aSession [

	^ (aSession transcript ifNotNil: [ :file |
			   [ transcriptReader startTimeIn: file ]
				   on: Error
				   do: [ nil ] ]) ifNil: [ DateAndTime now ]
]

{ #category : 'sessions' }
CMActivityLog >> titleCheckPeriod [

	^ 20 seconds
]

{ #category : 'hook events' }
CMActivityLog >> tool: aDictionary finishedWith: aStatus [

	| activity |
	activity := (self activityWithId: (self toolUseIdIn: aDictionary)) ifNil: [ self toolStarted: aDictionary ].
	activity
		status: aStatus;
		finishedAt: DateAndTime now;
		reportedDuration: (aDictionary at: 'duration_ms' ifAbsent: [ nil ]);
		response: (self responseTextIn: aDictionary).
	announcer announce: (CMActivityChanged new
			 activity: activity;
			 yourself).
	^ activity
]

{ #category : 'hook events' }
CMActivityLog >> toolStarted: aDictionary [
	"Hook requests are handled concurrently: a PostToolUse may have been handled first,
	or be handled at the same time. Finding or creating the activity is one step under the lock,
	so there is only ever one activity per tool use; PreToolUse then completes it"

	| id input activity isNew |
	id := self toolUseIdIn: aDictionary.
	input := aDictionary at: 'tool_input' ifAbsent: [ Dictionary new ].
	input isDictionary ifFalse: [ input := Dictionary new ].
	isNew := false.
	activity := mutex critical: [
			            byId at: id ifAbsent: [
					            | created |
					            isNew := true.
					            created := CMActivity new
						                       id: id;
						                       kind: #tool;
						                       status: #running;
						                       startedAt: DateAndTime now;
						                       promptId: (aDictionary at: 'prompt_id' ifAbsent: [ nil ]);
						                       parent: (self parentFor: aDictionary);
						                       yourself.
					            activities add: created.
					            byId at: id put: created.
					            created ] ].
	activity
		sessionId: (aDictionary at: 'session_id' ifAbsent: [ nil ]);
		toolName: (aDictionary at: 'tool_name' ifAbsent: [ '?' ]);
		input: input;
		why: (input at: 'description' ifAbsent: [ nil ]).
	activity explanation ifNil: [ activity explanation: (self explanationFor: aDictionary) ].
	announcer announce: ((isNew
			  ifTrue: [ CMActivityAdded ]
			  ifFalse: [ CMActivityChanged ]) new
			 activity: activity;
			 yourself).
	^ activity
]

{ #category : 'private' }
CMActivityLog >> toolUseIdIn: aDictionary [

	^ aDictionary at: 'tool_use_id' ifAbsent: [ UUID new asString ]
]

{ #category : 'accessing' }
CMActivityLog >> transcriptReader [

	^ transcriptReader
]

{ #category : 'accessing' }
CMActivityLog >> transcriptReader: aReader [

	transcriptReader := aReader
]
