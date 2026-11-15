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
		'rawEvents'
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
	announcer := Announcer new.
	mutex := Mutex new.
	rawEvents := OrderedCollection new.
	transcriptReader := CMTranscriptReader new
]

{ #category : 'accessing' }
CMActivityLog >> maxRawEvents [

	^ 50
]

{ #category : 'private' }
CMActivityLog >> maxResponseSize [

	^ 20000
]

{ #category : 'hook events' }
CMActivityLog >> promptSubmitted: aDictionary [

	| activity now |
	now := DateAndTime now.
	activity := CMActivity new
		            id: UUID new asString;
		            sessionId: (aDictionary at: 'session_id' ifAbsent: [ nil ]);
		            kind: #prompt;
		            input: (Dictionary with: 'prompt' -> (aDictionary at: 'prompt' ifAbsent: [ '' ]));
		            status: #ok;
		            startedAt: now;
		            finishedAt: now;
		            yourself.
	self add: activity.
	^ activity
]

{ #category : 'accessing' }
CMActivityLog >> rawEvents [

	^ mutex critical: [ rawEvents copy ]
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

{ #category : 'accessing' }
CMActivityLog >> size [

	^ mutex critical: [ activities size ]
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
	"Hook requests are handled concurrently, so a PostToolUse may have been handled first:
	then complete the existing activity with what only PreToolUse tells"

	| id input existing activity |
	id := self toolUseIdIn: aDictionary.
	input := aDictionary at: 'tool_input' ifAbsent: [ Dictionary new ].
	input isDictionary ifFalse: [ input := Dictionary new ].
	existing := self activityWithId: id.
	activity := existing ifNil: [
			            CMActivity new
				            id: id;
				            kind: #tool;
				            status: #running;
				            startedAt: DateAndTime now;
				            yourself ].
	activity
		sessionId: (aDictionary at: 'session_id' ifAbsent: [ nil ]);
		toolName: (aDictionary at: 'tool_name' ifAbsent: [ '?' ]);
		input: input;
		why: (input at: 'description' ifAbsent: [ nil ]).
	activity explanation ifNil: [ activity explanation: (self explanationFor: aDictionary) ].
	existing ifNil: [ self add: activity ] ifNotNil: [
			announcer announce: (CMActivityChanged new
					 activity: activity;
					 yourself) ].
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
