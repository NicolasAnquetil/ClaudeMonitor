"
I read a Claude Code session transcript (a JSON Lines file) to find what Claude wrote just before a tool call: the text blocks of the assistant messages between the previous user entry and the tool_use with the given id.

Transcripts grow to several megabytes, so I only read the last tailSize bytes. If the tool_use is not in the transcript yet, I take the assistant text at the end of the file.
"
Class {
	#name : 'CMTranscriptReader',
	#superclass : 'Object',
	#instVars : [
		'tailSize'
	],
	#category : 'ClaudeMonitor-Model',
	#package : 'ClaudeMonitor',
	#tag : 'Model'
}

{ #category : 'private' }
CMTranscriptReader >> contentOf: anEntry [

	| message content |
	message := anEntry at: 'message' ifAbsent: [ ^ #(  ) ].
	message isDictionary ifFalse: [ ^ #(  ) ].
	content := message at: 'content' ifAbsent: [ ^ #(  ) ].
	^ content isArray
		  ifTrue: [ content ]
		  ifFalse: [ #(  ) ]
]

{ #category : 'private' }
CMTranscriptReader >> entry: anEntry hasToolUse: aToolUseId [

	^ (self contentOf: anEntry) anySatisfy: [ :block |
			  block isDictionary and: [
				  (block at: 'type' ifAbsent: [ nil ]) = 'tool_use' and: [ (block at: 'id' ifAbsent: [ nil ]) = aToolUseId ] ] ]
]

{ #category : 'following' }
CMTranscriptReader >> entryOf: aLine [
	"Only what matters, without parsing everything: a user entry gives the prompt it belongs to
	(its result can be big), an assistant entry (a block of a model call, with its usage) is parsed"

	| start stop |
	(aLine includesSubstring: '"type":"assistant"') ifTrue: [
			^ [
				  (STONJSON fromString: aLine) ifNotNil: [ :entry |
						  entry isDictionary
							  ifTrue: [ entry ]
							  ifFalse: [ nil ] ] ]
				  on: Error
				  do: [ nil ] ].
	(aLine includesSubstring: '"type":"user"') ifFalse: [ ^ nil ].
	start := aLine indexOfSubCollection: '"promptId":"'.
	start = 0 ifTrue: [ ^ nil ].
	start := start + 12.
	stop := aLine indexOf: $" startingAt: start.
	stop = 0 ifTrue: [ ^ nil ].
	^ Dictionary new
		  at: 'type' put: 'user';
		  at: 'promptId' put: (aLine copyFrom: start to: stop - 1);
		  at: 'isSidechain' put: (aLine includesSubstring: '"isSidechain":true');
		  yourself
]

{ #category : 'reading' }
CMTranscriptReader >> explanationIn: aFileReference beforeToolUse: aToolUseId [
	"The assistant text written since the last user entry, up to the tool_use with this id
	(or up to the end of the transcript when that tool_use is not written yet). Nil if there is none."

	| entries end texts |
	aFileReference exists ifFalse: [ ^ nil ].
	entries := self tailEntriesOf: aFileReference.
	end := aToolUseId ifNil: [ 0 ] ifNotNil: [ entries findLast: [ :each | self entry: each hasToolUse: aToolUseId ] ].
	end = 0 ifTrue: [ end := entries size + 1 ].
	texts := OrderedCollection new.
	end - 1 to: 1 by: -1 do: [ :index |
			| type |
			type := (entries at: index) at: 'type' ifAbsent: [ nil ].
			type = 'user' ifTrue: [ ^ self join: texts ].
			type = 'assistant' ifTrue: [ (self textsOf: (entries at: index)) reverseDo: [ :each | texts addFirst: each ] ] ].
	^ self join: texts
]

{ #category : 'private' }
CMTranscriptReader >> join: someTexts [

	| text |
	text := String lf , String lf join: (someTexts collect: [ :each | each trimBoth ]).
	^ text isEmpty
		  ifTrue: [ nil ]
		  ifFalse: [ text ]
]

{ #category : 'following' }
CMTranscriptReader >> newEntriesIn: aFileReference from: aPosition [
	"The entries in the complete lines written after aPosition (a line still being written is left for
	the next read), and the position after them"

	| bytes last |
	bytes := aFileReference binaryReadStreamDo: [ :stream |
			         stream position: (aPosition min: stream size).
			         stream upToEnd ].
	last := bytes lastIndexOf: 10.
	last = 0 ifTrue: [
			^ {
				  #(  ).
				  aPosition } ].
	^ {
		  ((bytes copyFrom: 1 to: last) utf8Decoded lines collect: [ :line | self entryOf: line ] thenSelect: [ :each | each notNil ]).
		  (aPosition + last) }
]

{ #category : 'reading' }
CMTranscriptReader >> startTimeIn: aFileReference [
	"The timestamp of the first transcript entry that has one, in local time. Nil if none."

	aFileReference exists ifFalse: [ ^ nil ].
	aFileReference readStreamDo: [ :stream |
			[ stream atEnd ] whileFalse: [
					([ STONJSON fromString: stream nextLine ]
						 on: Error
						 do: [ nil ]) ifNotNil: [ :entry |
							(entry isDictionary and: [ entry includesKey: 'timestamp' ]) ifTrue: [
									^ [ (DateAndTime fromString: (entry at: 'timestamp')) asLocal ]
										  on: Error
										  do: [ nil ] ] ] ] ].
	^ nil
]

{ #category : 'reading' }
CMTranscriptReader >> tailEntriesOf: aFileReference [
	"The JSON entries of the last tailSize bytes, skipping the first line, which may be cut"

	| bytes start lines |
	bytes := aFileReference binaryReadStreamDo: [ :stream |
			         stream size > self tailSize ifTrue: [ stream position: stream size - self tailSize ].
			         stream upToEnd ].
	start := 1.
	aFileReference size > self tailSize ifTrue: [ start := (bytes indexOf: 10) + 1 ].
	lines := (bytes copyFrom: start to: bytes size) utf8Decoded lines.
	^ lines
		  collect: [ :line |
				  [ STONJSON fromString: line ]
					  on: Error
					  do: [ nil ] ]
		  thenSelect: [ :each | each isDictionary ]
]

{ #category : 'accessing' }
CMTranscriptReader >> tailSize [

	^ tailSize ifNil: [ 400 * 1024 ]
]

{ #category : 'accessing' }
CMTranscriptReader >> tailSize: anInteger [

	tailSize := anInteger
]

{ #category : 'private' }
CMTranscriptReader >> textsOf: anEntry [

	^ (self contentOf: anEntry)
		  select: [ :block | block isDictionary and: [ (block at: 'type' ifAbsent: [ nil ]) = 'text' ] ]
		  thenCollect: [ :block | block at: 'text' ifAbsent: [ '' ] ]
]

{ #category : 'reading' }
CMTranscriptReader >> titleIn: aFileReference [
	"The latest session title: a custom-title (set with /rename) wins over an ai-title. Nil if none yet."

	| custom ai |
	aFileReference exists ifFalse: [ ^ nil ].
	(self tailEntriesOf: aFileReference) do: [ :entry |
			(entry at: 'type' ifAbsent: [ nil ]) = 'custom-title' ifTrue: [ custom := entry at: 'customTitle' ifAbsent: [ custom ] ].
			(entry at: 'type' ifAbsent: [ nil ]) = 'ai-title' ifTrue: [ ai := entry at: 'aiTitle' ifAbsent: [ ai ] ] ].
	^ custom ifNil: [ ai ]
]
