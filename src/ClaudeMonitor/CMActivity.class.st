"
I am one thing Claude Code did in a session, as reported by its hooks: a tool call (kind #tool) or a prompt the user submitted (kind #prompt).

A tool call starts #running when the PreToolUse hook arrives and becomes #ok or #failed when PostToolUse or PostToolUseFailure arrives with the same tool_use_id.

- why: the short reason Claude gave with the call (the description of a Bash command), when there is one.
- explanation: the text Claude wrote just before the call, read from the session transcript (best effort: not every text reaches the transcript).
- input: the tool input, as the hook sent it (a Dictionary).
- response: a printable excerpt of the tool response or error.
- startedAt, finishedAt: when the hook events arrived. Hooks run asynchronously, so these are late by up to a few seconds; reportedDuration is the duration_ms Claude Code measured, and is preferred.
"
Class {
	#name : 'CMActivity',
	#superclass : 'Object',
	#instVars : [
		'id',
		'sessionId',
		'kind',
		'toolName',
		'input',
		'why',
		'explanation',
		'status',
		'startedAt',
		'finishedAt',
		'response',
		'reportedDuration',
		'promptId',
		'parent',
		'children'
	],
	#category : 'ClaudeMonitor-Model',
	#package : 'ClaudeMonitor',
	#tag : 'Model'
}

{ #category : 'hierarchy' }
CMActivity >> addChild: anActivity [

	(self children includes: anActivity) ifFalse: [ self children add: anActivity ]
]

{ #category : 'hierarchy' }
CMActivity >> ancestorsDo: aBlock [

	parent ifNotNil: [
			aBlock value: parent.
			parent ancestorsDo: aBlock ]
]

{ #category : 'hierarchy' }
CMActivity >> children [

	^ children ifNil: [ children := OrderedCollection new ]
]

{ #category : 'hierarchy' }
CMActivity >> depth [

	^ parent ifNil: [ 0 ] ifNotNil: [ parent depth + 1 ]
]

{ #category : 'printing' }
CMActivity >> durationMilliseconds [
	"The duration Claude Code measured when it reported one, else the time between the hook events. Nil while running."

	reportedDuration ifNotNil: [ ^ reportedDuration ].
	(startedAt isNil or: [ finishedAt isNil ]) ifTrue: [ ^ nil ].
	^ (finishedAt - startedAt) asMilliSeconds
]

{ #category : 'accessing' }
CMActivity >> explanation [

	^ explanation
]

{ #category : 'accessing' }
CMActivity >> explanation: aString [

	explanation := aString
]

{ #category : 'accessing' }
CMActivity >> finishedAt [

	^ finishedAt
]

{ #category : 'accessing' }
CMActivity >> finishedAt: aDateAndTime [

	finishedAt := aDateAndTime
]

{ #category : 'printing' }
CMActivity >> firstStatementOf: someCode [
	"The first line of code that is not a temporaries declaration, a comment or blank"

	^ (someCode lines collect: [ :line | line trimBoth ])
		  detect: [ :line | line isNotEmpty and: [ (line beginsWith: '|') not and: [ (line beginsWith: '"') not ] ] ]
		  ifNone: [ someCode trimBoth ]
]

{ #category : 'hierarchy' }
CMActivity >> hasChildren [

	^ children isNotNil and: [ children isNotEmpty ]
]

{ #category : 'accessing' }
CMActivity >> id [

	^ id
]

{ #category : 'accessing' }
CMActivity >> id: aString [

	id := aString
]

{ #category : 'accessing' }
CMActivity >> input [

	^ input ifNil: [ Dictionary new ]
]

{ #category : 'accessing' }
CMActivity >> input: aDictionary [

	input := aDictionary
]

{ #category : 'testing' }
CMActivity >> isFailed [

	^ status = #failed
]

{ #category : 'testing' }
CMActivity >> isPharoTool [
	"A call to the Pharo MCP server, e.g. mcp__pharo__image_evaluate"

	^ toolName isNotNil and: [ toolName beginsWith: 'mcp__pharo__' ]
]

{ #category : 'testing' }
CMActivity >> isPrompt [

	^ kind = #prompt
]

{ #category : 'testing' }
CMActivity >> isRunning [

	^ status = #running
]

{ #category : 'accessing' }
CMActivity >> kind [

	^ kind
]

{ #category : 'accessing' }
CMActivity >> kind: aSymbol [

	kind := aSymbol
]

{ #category : 'printing' }
CMActivity >> methodSubjectFrom: aSourceOrSources in: anInput [
	"Class>>selector for method_compile; the selectors of several sources are joined"

	| sources selectors |
	sources := aSourceOrSources isString
		           ifTrue: [ { aSourceOrSources } ]
		           ifFalse: [ aSourceOrSources ].
	selectors := sources collect: [ :each |
			             (each isString and: [ each isNotEmpty ])
				             ifTrue: [ (each lines first substrings: ' ') first ]
				             ifFalse: [ '?' ] ].
	^ String streamContents: [ :s |
			  s << (anInput at: 'class' ifAbsent: [ '?' ]) asString.
			  (anInput at: 'side' ifAbsent: [ nil ]) = 'class' ifTrue: [ s << ' class' ].
			  s << '>>'.
			  selectors do: [ :each | s << each ] separatedBy: [ s << ', ' ] ]
]

{ #category : 'hierarchy' }
CMActivity >> parent [
	"The prompt that led to this activity, nil for a prompt"

	^ parent
]

{ #category : 'hierarchy' }
CMActivity >> parent: anActivity [

	parent := anActivity.
	anActivity ifNotNil: [ anActivity addChild: self ]
]

{ #category : 'printing' }
CMActivity >> printOn: aStream [

	aStream << self shortToolName << ': ' << self summary
]

{ #category : 'hierarchy' }
CMActivity >> promptId [

	^ promptId
]

{ #category : 'hierarchy' }
CMActivity >> promptId: aString [

	promptId := aString
]

{ #category : 'accessing' }
CMActivity >> reportedDuration [

	^ reportedDuration
]

{ #category : 'accessing' }
CMActivity >> reportedDuration: aNumberOfMilliseconds [

	reportedDuration := aNumberOfMilliseconds
]

{ #category : 'accessing' }
CMActivity >> response [

	^ response
]

{ #category : 'accessing' }
CMActivity >> response: aString [

	response := aString
]

{ #category : 'accessing' }
CMActivity >> sessionId [

	^ sessionId
]

{ #category : 'accessing' }
CMActivity >> sessionId: aString [

	sessionId := aString
]

{ #category : 'printing' }
CMActivity >> shortToolName [
	"mcp__pharo__image_evaluate -> pharo image_evaluate"

	self isPrompt ifTrue: [ ^ 'prompt' ].
	toolName ifNil: [ ^ '?' ].
	(toolName beginsWith: 'mcp__') ifFalse: [ ^ toolName ].
	^ (toolName allButFirst: 5) copyReplaceAll: '__' with: ' '
]

{ #category : 'accessing' }
CMActivity >> startedAt [

	^ startedAt
]

{ #category : 'accessing' }
CMActivity >> startedAt: aDateAndTime [

	startedAt := aDateAndTime
]

{ #category : 'accessing' }
CMActivity >> status [

	^ status
]

{ #category : 'accessing' }
CMActivity >> status: aSymbol [

	status := aSymbol
]

{ #category : 'printing' }
CMActivity >> subject [
	"The main argument of the call: the command, the file, the method, the code or the prompt"

	| in |
	in := self input.
	self isPrompt ifTrue: [ ^ (in at: 'prompt' ifAbsent: [ '' ]) asString ].
	in at: 'source' ifPresent: [ :source | ^ self methodSubjectFrom: source in: in ].
	in at: 'code' ifPresent: [ :code | code isString ifTrue: [ ^ self firstStatementOf: code ] ].
	#( 'command' 'file_path' 'pattern' 'url' 'query' 'name' 'class' 'skill' 'prompt' 'description' ) do: [ :key |
		in at: key ifPresent: [ :value | value isString ifTrue: [ ^ value ] ] ].
	^ in isEmpty
		  ifTrue: [ '' ]
		  ifFalse: [ in values first printString ]
]

{ #category : 'printing' }
CMActivity >> summary [
	"One line for the timeline: the why when Claude gave one, else the subject"

	| text |
	text := (why isNil or: [ why isEmpty ])
		        ifTrue: [ self subject ]
		        ifFalse: [ why ].
	text := text asString lines ifEmpty: [ '' ] ifNotEmpty: [ :lines | lines first ].
	^ text size > 120
		  ifTrue: [ (text first: 117) , '...' ]
		  ifFalse: [ text ]
]

{ #category : 'accessing' }
CMActivity >> toolName [

	^ toolName
]

{ #category : 'accessing' }
CMActivity >> toolName: aString [

	toolName := aString
]

{ #category : 'accessing' }
CMActivity >> why [

	^ why
]

{ #category : 'accessing' }
CMActivity >> why: aString [

	why := aString
]
