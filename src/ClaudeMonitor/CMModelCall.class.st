"
I am one call to the model, as the session transcript records it: my token usage (the latest the transcript gave), and my blocks in order (thinking, text, tool use), each with its size and, once known, the activity showing it.

The transcript gives tokens per call, not per block. The thinking tokens are given apart: a thinking block has them exactly. The rest of the output is shared among my text and tool use blocks by size, an estimate unless there is only one. A thinking block without an activity (its text was not kept) counts for my first other block that has one.
"
Class {
	#name : 'CMModelCall',
	#superclass : 'Object',
	#instVars : [
		'id',
		'usage',
		'blocks',
		'activities'
	],
	#category : 'ClaudeMonitor',
	#package : 'ClaudeMonitor'
}

{ #category : 'accessing' }
CMModelCall >> activities [
	"The activity showing each block, by block key"

	^ activities ifNil: [ activities := Dictionary new ]
]

{ #category : 'building' }
CMModelCall >> addBlock: aKind key: aKey size: aNumber [

	(self blocks anySatisfy: [ :each | each second = aKey ]) ifTrue: [ ^ self ].
	self blocks add: {
			aKind.
			aKey.
			(aNumber max: 1) }
]

{ #category : 'accessing' }
CMModelCall >> blocks [
	"Arrays { kind. key. size }, in order"

	^ blocks ifNil: [ blocks := OrderedCollection new ]
]

{ #category : 'tokens' }
CMModelCall >> cacheReadTokens [

	^ self numberAt: 'cache_read_input_tokens'
]

{ #category : 'tokens' }
CMModelCall >> cacheWriteTokens [

	^ self numberAt: 'cache_creation_input_tokens'
]

{ #category : 'building' }
CMModelCall >> hasBlock: aKey [

	^ self blocks anySatisfy: [ :each | each second = aKey ]
]

{ #category : 'accessing' }
CMModelCall >> id [

	^ id
]

{ #category : 'accessing' }
CMModelCall >> id: aString [

	id := aString
]

{ #category : 'tokens' }
CMModelCall >> inputTokens [
	"All the context the call read"

	^ self newInputTokens + self cacheWriteTokens + self cacheReadTokens
]

{ #category : 'tokens' }
CMModelCall >> isEstimateFor: anActivity [
	"Thinking is counted apart; the rest is shared by size when there are several blocks"

	| keys |
	keys := (self activities associations select: [ :each | each value == anActivity ]) collect: [ :each | each key ].
	^ self blocks anySatisfy: [ :each |
			  (keys includes: each second) and: [
					  (each first = #thinking
						   ifTrue: [ self thinkingBlocks ]
						   ifFalse: [ self otherBlocks ]) size > 1 ] ]
]

{ #category : 'tokens' }
CMModelCall >> newInputTokens [

	^ self numberAt: 'input_tokens'
]

{ #category : 'tokens' }
CMModelCall >> numberAt: aKey [

	| value |
	value := self usage at: aKey ifAbsent: [ 0 ].
	^ value isNumber
		  ifTrue: [ value ]
		  ifFalse: [ 0 ]
]

{ #category : 'tokens' }
CMModelCall >> otherBlocks [

	^ self blocks reject: [ :each | each first = #thinking ]
]

{ #category : 'tokens' }
CMModelCall >> outputTokens [

	^ self numberAt: 'output_tokens'
]

{ #category : 'tokens' }
CMModelCall >> receiverOfHiddenThinking [
	"The block whose activity counts the thinking that has no activity"

	^ self otherBlocks detect: [ :each | self activities includesKey: each second ] ifNone: [ nil ]
]

{ #category : 'tokens' }
CMModelCall >> shareOf: aBlock [
	"The tokens of aBlock alone"

	| group total tokens |
	aBlock first = #thinking
		ifTrue: [
				group := self thinkingBlocks.
				tokens := self thinkingTokens ]
		ifFalse: [
				group := self otherBlocks.
				tokens := self outputTokens - self thinkingTokens ].
	total := group inject: 0 into: [ :sum :each | sum + each third ].
	^ tokens * aBlock third / total
]

{ #category : 'building' }
CMModelCall >> show: aKey by: anActivity [

	self activities at: aKey put: anActivity.
	anActivity call: self
]

{ #category : 'accessing' }
CMModelCall >> shownActivities [

	^ self activities values
]

{ #category : 'tokens' }
CMModelCall >> thinkingBlocks [

	^ self blocks select: [ :each | each first = #thinking ]
]

{ #category : 'tokens' }
CMModelCall >> thinkingTokens [

	^ (self usage at: 'output_tokens_details' ifAbsent: [ nil ]) ifNil: [ 0 ] ifNotNil: [ :details |
			  details isDictionary
				  ifTrue: [ ((details at: 'thinking_tokens' ifAbsent: [ 0 ]) ifNil: [ 0 ]) min: self outputTokens ]
				  ifFalse: [ 0 ] ]
]

{ #category : 'tokens' }
CMModelCall >> tokensOf: anActivity [
	"The tokens of the blocks anActivity shows, plus the hidden thinking it counts"

	| keys tokens receiver |
	keys := (self activities associations select: [ :each | each value == anActivity ]) collect: [ :each | each key ].
	keys ifEmpty: [ ^ nil ].
	tokens := 0.
	self blocks do: [ :each | (keys includes: each second) ifTrue: [ tokens := tokens + (self shareOf: each) ] ].
	receiver := self receiverOfHiddenThinking.
	(receiver notNil and: [ keys includes: receiver second ]) ifTrue: [
		self thinkingBlocks do: [ :each |
			(self activities includesKey: each second) ifFalse: [ tokens := tokens + (self shareOf: each) ] ] ].
	^ tokens rounded
]

{ #category : 'accessing' }
CMModelCall >> usage [

	^ usage ifNil: [ usage := Dictionary new ]
]

{ #category : 'accessing' }
CMModelCall >> usage: aDictionary [

	aDictionary isDictionary ifTrue: [ usage := aDictionary ]
]
