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
		'lastPromptBySession',
		'fileSystem',
		'transcriptPositions',
		'transcriptPrompts',
		'transcriptLock',
		'calls',
		'callsByKey',
		'currentUserSession'
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
	self group: anActivity.

	mutex critical: [
			activities add: anActivity.
			byId at: anActivity id put: anActivity ].
	announcer announce: (CMActivityAdded new
			 activity: anActivity;
			 yourself)
]

{ #category : 'hook events' }
CMActivityLog >> addStepsOf: aToolActivity [
	"A to-do list or a plan: one child activity per step, in order"

	(self planStepsIn: aToolActivity input) withIndexDo: [ :step :index |
			self add: (CMActivity new
					 id: aToolActivity id , '#step' , index printString;
					 sessionId: aToolActivity sessionId;
					 kind: #step;
					 input: step;
					 status: #ok;
					 startedAt: aToolActivity startedAt;
					 finishedAt: aToolActivity startedAt;
					 parent: aToolActivity;
					 yourself) ]
]

{ #category : 'accessing' }
CMActivityLog >> announcer [

	^ announcer
]

{ #category : 'transcript' }
CMActivityLog >> callOf: anEntry [
	"The model call anEntry is part of, with the usage it gives (the latest replaces the earlier)"

	| message messageId call |
	message := anEntry at: 'message' ifAbsent: [ ^ nil ].
	message isDictionary ifFalse: [ ^ nil ].
	messageId := message at: 'id' ifAbsent: [ ^ nil ].
	call := self calls at: messageId ifAbsentPut: [
			        CMModelCall new
				        id: messageId;
				        yourself ].
	call usage: (message at: 'usage' ifAbsent: [ nil ]).
	^ call
]

{ #category : 'transcript' }
CMActivityLog >> calls [
	"The model calls read in the transcripts, by message id"

	^ calls ifNil: [ calls := Dictionary new ]
]

{ #category : 'transcript' }
CMActivityLog >> callsByKey [
	"The model call of each block, by block key: an activity id for a message or a thinking, a tool use id for a tool call"

	^ callsByKey ifNil: [ callsByKey := Dictionary new ]
]

{ #category : 'user sessions' }
CMActivityLog >> currentUserSession [
	"The session the user started last: new prompts are listed under it"

	^ currentUserSession
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

{ #category : 'transcript' }
CMActivityLog >> fileSystem [
	"Where transcript paths are looked up: the disk, or a memory file system in tests"

	^ fileSystem ifNil: [ fileSystem := FileSystem disk ]
]

{ #category : 'transcript' }
CMActivityLog >> fileSystem: aFileSystem [

	fileSystem := aFileSystem
]

{ #category : 'transcript' }
CMActivityLog >> followTranscriptOf: aDictionary [
	"Add what Claude wrote in the session transcript since it was last read: messages, thinking"

	| path sessionId |
	path := aDictionary at: 'transcript_path' ifAbsent: [ ^ self ].
	sessionId := aDictionary at: 'session_id' ifAbsent: [ ^ self ].
	self transcriptLock critical: [
			| result |
			result := [
			          transcriptReader
				          newEntriesIn: (self fileSystem referenceTo: path)
				          from: (self transcriptPositions at: sessionId ifAbsent: [ 0 ]) ]
				          on: Error
				          do: [ ^ self ].
			self transcriptPositions at: sessionId put: result second.
			result first do: [ :entry | self noteTranscriptEntry: entry inSession: sessionId ] ]
]

{ #category : 'user sessions' }
CMActivityLog >> group: anActivity [
	"An activity with no parent goes under the current session of the user, if any"

	anActivity parent ifNil: [ currentUserSession ifNotNil: [ :session | anActivity groupId: session id ] ]
]

{ #category : 'hook events' }
CMActivityLog >> handleHookEvent: aDictionary [
	"Create or complete the activity a Claude Code hook payload reports. What Claude wrote in the
	transcript since the last event comes first, so that it lands before this event's activity.
	Stop (end of an answer) only reads the transcript. Unknown events are ignored."

	self rememberRawEvent: aDictionary.
	self noteSessionOf: aDictionary.
	self followTranscriptOf: aDictionary.
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

{ #category : 'transcript' }
CMActivityLog >> link: aKey of: aCall [
	"Tie the block aKey to its activity, if it exists already; otherwise its activity will be tied when created"

	self callsByKey at: aKey put: aCall.
	(self activityWithId: aKey) ifNotNil: [ :activity | aCall show: aKey by: activity ]
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

{ #category : 'transcript' }
CMActivityLog >> noteTranscriptEntry: anEntry inSession: aSessionId [
	"A user entry tells the prompt; an assistant entry is one block of a model call: a message, a thinking
	(both shown when they have text) or a tool use"

	| call |
	(anEntry at: 'isSidechain' ifAbsent: [ false ]) == true ifTrue: [ ^ self ].
	(anEntry at: 'type' ifAbsent: [ nil ]) = 'user' ifTrue: [ ^ self transcriptPrompts at: aSessionId put: (anEntry at: 'promptId') ].
	call := self callOf: anEntry.
	(transcriptReader contentOf: anEntry) withIndexDo: [ :block :index |
			| type text key |
			type := block at: 'type' ifAbsent: [ nil ].
			type = 'tool_use'
				ifTrue: [
						key := block at: 'id' ifAbsent: [ nil ].
						(call notNil and: [ key notNil ]) ifTrue: [
								call addBlock: #tool key: key size: (self sizeOfToolInput: (block at: 'input' ifAbsent: [ nil ])).
								self link: key of: call ] ]
				ifFalse: [
						(type = 'text' or: [ type = 'thinking' ]) ifTrue: [
								text := block at: type ifAbsent: [ nil ].
								text isString ifFalse: [ text := '' ].
								key := (anEntry at: 'uuid' ifAbsent: [ UUID new asString ]) , '#' , index printString.
								text trimBoth ifNotEmpty: [
										self
											thought: text
											kind: (type = 'text'
													 ifTrue: [ #message ]
													 ifFalse: [ #thinking ])
											id: key
											at: (anEntry at: 'timestamp' ifAbsent: [ nil ])
											inSession: aSessionId ].
								call ifNotNil: [
										call
											addBlock: (type = 'text'
													 ifTrue: [ #message ]
													 ifFalse: [ #thinking ])
											key: key
											size: text size.
										self link: key of: call ] ] ] ].
	call ifNotNil: [ self tokensChangedIn: call ]
]

{ #category : 'hierarchy' }
CMActivityLog >> ownerOfToolFor: aDictionary [
	"A tool call hangs under the last message of its prompt, or under the prompt"

	| prompt |
	prompt := (self parentFor: aDictionary) ifNil: [ ^ nil ].
	^ prompt children reversed detect: [ :each | each isMessage ] ifNone: [ prompt ]
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
CMActivityLog >> planItemIn: aLine [
	"The text of a Markdown heading or list item ('# Plan', '- step', '* step', '1. step'), else an empty string"

	| line dot |
	line := aLine trimBoth.
	line isEmpty ifTrue: [ ^ '' ].
	line first = $# ifTrue: [ ^ (line copyWithoutAll: '#') trimBoth ].
	(line first = $- or: [ line first = $* ]) ifTrue: [ ^ line allButFirst trimBoth ].
	dot := line indexOf: $..
	(dot > 1 and: [ (line first: dot - 1) allSatisfy: [ :each | each isDigit ] ]) ifTrue: [ ^ (line allButFirst: dot) trimBoth ].
	^ ''
]

{ #category : 'hook events' }
CMActivityLog >> planStepsIn: anInput [
	"The steps of a TodoWrite to-do list ('todos') or of a plan-mode plan ('plan', in Markdown:
	its headings and list items), each as a Dictionary with 'text' (and 'state' for a to-do)"

	anInput at: 'todos' ifPresent: [ :todos |
			todos isArray ifTrue: [
					^ (todos select: [ :each | each isDictionary ]) collect: [ :each |
							  Dictionary new
								  at: 'text' put: (each at: 'content' ifAbsent: [ '' ]) asString;
								  at: 'state' put: (each at: 'status' ifAbsent: [ 'pending' ]);
								  yourself ] ] ].
	anInput at: 'plan' ifPresent: [ :plan |
			plan isString ifTrue: [
					^ (plan lines collect: [ :line | self planItemIn: line ] thenSelect: [ :text | text notEmpty ]) collect: [ :text |
						  Dictionary with: 'text' -> text ] ] ].
	^ #(  )
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

{ #category : 'hierarchy' }
CMActivityLog >> regroupToolCallsOf: aPrompt [
	"Put each tool call of aPrompt under the last message written before it, or under the prompt.
	Needed when a message is read after the tool calls that follow it"

	| entries owner moved |
	entries := OrderedCollection new.
	aPrompt children do: [ :each |
			(each isMessage or: [ each isTool ]) ifTrue: [ entries add: each ].
			each isMessage ifTrue: [ entries addAll: (each children select: [ :child | child isTool ]) ] ].
	entries := entries asArray sort: [ :a :b |
		           (a startedAt ifNil: [ DateAndTime epoch ]) <= (b startedAt ifNil: [ DateAndTime epoch ]) ].
	owner := aPrompt.
	moved := false.
	entries do: [ :each |
			each isMessage
				ifTrue: [ owner := each ]
				ifFalse: [
						each parent == owner ifFalse: [
								each moveTo: owner.
								moved := true ] ] ].
	moved ifTrue: [
			announcer announce: (CMActivitiesRegrouped new
					 prompt: aPrompt;
					 yourself) ]
]

{ #category : 'private' }
CMActivityLog >> rememberRawEvent: aDictionary [

	mutex critical: [
			rawEvents addLast: aDictionary.
			[ rawEvents size > self maxRawEvents ] whileTrue: [ rawEvents removeFirst ] ]
]

{ #category : 'user sessions' }
CMActivityLog >> rename: aSession to: aString [

	aSession title: aString.
	announcer announce: (CMSessionChanged new
			 session: aSession;
			 yourself)
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

{ #category : 'transcript' }
CMActivityLog >> sizeOfToolInput: anInput [

	^ [ (STONJSON toString: anInput) size ]
		  on: Error
		  do: [ anInput printString size ]
]

{ #category : 'sessions' }
CMActivityLog >> startTimeOf: aSession [

	^ (aSession transcript ifNotNil: [ :file |
			   [ transcriptReader startTimeIn: file ]
				   on: Error
				   do: [ nil ] ]) ifNil: [ DateAndTime now ]
]

{ #category : 'user sessions' }
CMActivityLog >> startUserSessionNamed: aString [
	"From now on, new prompts (and tool calls without a prompt) are listed under a new session"

	| session |
	session := CMSession new
		           id: 'user-' , UUID new asString;
		           title: aString;
		           startedAt: DateAndTime now;
		           titleCheckedAt: DateAndTime now;
		           beByUser;
		           yourself.
	mutex critical: [
			sessions at: session id put: session.
			currentUserSession := session ].
	announcer announce: (CMSessionStarted new
			 session: session;
			 yourself).
	^ session
]

{ #category : 'transcript' }
CMActivityLog >> thought: aString kind: aKind id: anId at: aTimestamp inSession: aSessionId [
	"A message or a thinking, under its prompt. Entries of prompts written before the monitor
	started are skipped, like their tool calls were"

	| prompt time activity |
	(self activityWithId: anId) ifNotNil: [ ^ self ].
	prompt := (self transcriptPrompts at: aSessionId ifAbsent: [ nil ])
		          ifNil: [ self lastPromptBySession at: aSessionId ifAbsent: [ nil ] ]
		          ifNotNil: [ :promptId | self promptsById at: promptId ifAbsent: [ ^ self ] ].
	time := [ (DateAndTime fromString: aTimestamp) asLocal ]
		        on: Error
		        do: [ DateAndTime now ].
	activity := CMActivity new
		            id: anId;
		            sessionId: aSessionId;
		            kind: aKind;
		            input: (Dictionary with: 'text' -> aString);
		            status: #ok;
		            startedAt: time;
		            finishedAt: time;
		            parent: prompt;
		            yourself.
	self add: activity.
	(aKind = #message and: [ prompt notNil ]) ifTrue: [ self regroupToolCallsOf: prompt ]
]

{ #category : 'sessions' }
CMActivityLog >> titleCheckPeriod [

	^ 20 seconds
]

{ #category : 'transcript' }
CMActivityLog >> tokensChangedIn: aCall [
	"The rows of aCall and the rows above them show other token counts"

	| changed |
	changed := IdentitySet new.
	aCall shownActivities do: [ :each |
			changed add: each.
			each ancestorsDo: [ :ancestor | changed add: ancestor ] ].
	changed do: [ :each |
			announcer announce: (CMActivityChanged new
					 activity: each;
					 yourself) ]
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
						                       parent: (self ownerOfToolFor: aDictionary);
						                       yourself.
					            self group: created.
					            activities add: created.
					            byId at: id put: created.
					            created ] ].
	isNew ifTrue: [
		self transcriptLock critical: [
			(self callsByKey at: id ifAbsent: [ nil ]) ifNotNil: [ :c | c show: id by: activity ] ] ].
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
	isNew ifTrue: [ self addStepsOf: activity ].
	^ activity
]

{ #category : 'private' }
CMActivityLog >> toolUseIdIn: aDictionary [

	^ aDictionary at: 'tool_use_id' ifAbsent: [ UUID new asString ]
]

{ #category : 'transcript' }
CMActivityLog >> transcriptLock [

	^ transcriptLock ifNil: [ transcriptLock := Mutex new ]
]

{ #category : 'transcript' }
CMActivityLog >> transcriptPositions [
	"Session id -> position in its transcript up to which it was read"

	^ transcriptPositions ifNil: [ transcriptPositions := Dictionary new ]
]

{ #category : 'transcript' }
CMActivityLog >> transcriptPrompts [
	"Session id -> id of the prompt the transcript is at"

	^ transcriptPrompts ifNil: [ transcriptPrompts := Dictionary new ]
]

{ #category : 'accessing' }
CMActivityLog >> transcriptReader [

	^ transcriptReader
]

{ #category : 'accessing' }
CMActivityLog >> transcriptReader: aReader [

	transcriptReader := aReader
]
