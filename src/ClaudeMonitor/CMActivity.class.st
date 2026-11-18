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
		'children',
		'call',
		'groupId'
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

{ #category : 'tokens' }
CMActivity >> call [
	"The model call that wrote me (a CMModelCall), when the transcript told it"

	^ call
]

{ #category : 'tokens' }
CMActivity >> call: aModelCall [

	call := aModelCall
]

{ #category : 'tokens' }
CMActivity >> callsBelow [
	"The model calls of me and everything under me, each once"

	| calls |
	calls := IdentitySet new.
	self withAllChildrenDo: [ :each | each call ifNotNil: [ :c | calls add: c ] ].
	^ calls
]

{ #category : 'hierarchy' }
CMActivity >> children [

	^ children ifNil: [ children := OrderedCollection new ]
]

{ #category : 'testing' }
CMActivity >> contentMatches: aString [
	"Whether its tool, why, explanation, subject, text or response contains aString, ignoring case"

	^ {
		  toolName.
		  why.
		  explanation.
		  self subject.
		  self text.
		  response } anySatisfy: [ :each | each isString and: [ each includesSubstring: aString caseSensitive: false ] ]
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

{ #category : 'testing' }
CMActivity >> filterKind [
	"Its type for the filter of the monitor: a step of a plan counts as a tool call"

	^ self isStep
		  ifTrue: [ #tool ]
		  ifFalse: [ kind ]
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

{ #category : 'accessing' }
CMActivity >> groupId [
	"The id of the session row I am listed under: a session the user started, else my Claude Code session"

	^ groupId ifNil: [ sessionId ]
]

{ #category : 'accessing' }
CMActivity >> groupId: aString [

	groupId := aString
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

{ #category : 'tokens' }
CMActivity >> inputTokens [
	"For a prompt: the context all its calls read"

	^ self callsBelow inject: 0 into: [ :sum :each | sum + each inputTokens ]
]

{ #category : 'testing' }
CMActivity >> isFailed [

	^ status = #failed
]

{ #category : 'testing' }
CMActivity >> isMessage [
	"Text Claude wrote to the user, read from the transcript"

	^ kind = #message
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

{ #category : 'testing' }
CMActivity >> isStep [
	"One step of a plan or of a to-do list"

	^ kind = #step
]

{ #category : 'testing' }
CMActivity >> isThinking [
	"Claude's reasoning, read from the transcript"

	^ kind = #thinking
]

{ #category : 'testing' }
CMActivity >> isThought [

	^ self isMessage or: [ self isThinking ]
]

{ #category : 'tokens' }
CMActivity >> isTokenEstimate [

	self isPrompt ifTrue: [ ^ false ].
	(call notNil and: [ call isEstimateFor: self ]) ifTrue: [ ^ true ].
	^ self isMessage and: [ self children anySatisfy: [ :each | each isTokenEstimate ] ]
]

{ #category : 'testing' }
CMActivity >> isTool [

	^ kind = #tool
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
CMActivity >> moveTo: anActivity [
	"Leave my parent for anActivity"

	parent ifNotNil: [ :old | old children removeAllSuchThat: [ :each | each == self ] ].
	parent := nil.
	self parent: anActivity
]

{ #category : 'tokens' }
CMActivity >> outputTokens [
	"The tokens Claude wrote for me: a prompt counts all its calls, a message counts its tool calls too"

	| tokens |
	self isPrompt ifTrue: [
			self callsBelow ifEmpty: [ ^ nil ].
			^ self callsBelow inject: 0 into: [ :sum :each | sum + each outputTokens ] ].
	self isMessage ifFalse: [ ^ self ownTokens ].
	tokens := self ownTokens.
	self children do: [ :each | each outputTokens ifNotNil: [ :n | tokens := (tokens ifNil: [ 0 ]) + n ] ].
	^ tokens
]

{ #category : 'tokens' }
CMActivity >> ownTokens [
	"The output tokens of what I show myself"

	^ call ifNotNil: [ :c | c tokensOf: self ]
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

{ #category : 'accessing' }
CMActivity >> shortToolName [
	"mcp__pharo__image_evaluate -> pharo image_evaluate"

	self isPrompt ifTrue: [ ^ 'prompt' ].
	self isMessage ifTrue: [ ^ 'message' ].
	self isThinking ifTrue: [ ^ 'thinking' ].
	self isStep ifTrue: [ ^ 'step' ].
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

{ #category : 'accessing' }
CMActivity >> stepState [
	"For a to-do step: 'pending', 'in_progress' or 'completed'; nil for a plan step"

	^ self input at: 'state' ifAbsent: [ nil ]
]

{ #category : 'accessing' }
CMActivity >> subject [
	"The main argument of the call: the command, the file, the method, the code or the prompt"

	| in |
	(self isThought or: [ self isStep ]) ifTrue: [ ^ self text ].
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
	text := text asString lines detect: [ :line | line trimBoth notEmpty ] ifNone: [ '' ].
	^ text size > 120
		  ifTrue: [ (text first: 117) , '...' ]
		  ifFalse: [ text ]
]

{ #category : 'accessing' }
CMActivity >> text [
	"The text of a message, a thinking or a step"

	^ (self input at: 'text' ifAbsent: [ '' ]) asString
]

{ #category : 'tokens' }
CMActivity >> thinkingTokens [
	"For a prompt: the thinking tokens of all its calls"

	^ self callsBelow inject: 0 into: [ :sum :each | sum + each thinkingTokens ]
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

{ #category : 'tokens' }
CMActivity >> withAllChildrenDo: aBlock [

	aBlock value: self.
	self children do: [ :each | each withAllChildrenDo: aBlock ]
]
