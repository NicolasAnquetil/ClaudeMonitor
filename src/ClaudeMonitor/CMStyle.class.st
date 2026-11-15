"
I gather the colors and text styles of the ClaudeMonitor UI, on my class side.
"
Class {
	#name : 'CMStyle',
	#superclass : 'Object',
	#category : 'ClaudeMonitor-UI',
	#package : 'ClaudeMonitor',
	#tag : 'UI'
}

{ #category : 'styles' }
CMStyle class >> code: aString [

	^ (self text: aString size: 12 color: (Color r: 0.15 g: 0.15 b: 0.2))
		  monospace;
		  yourself
]

{ #category : 'styles' }
CMStyle class >> colorForActivity: anActivity [

	| tool |
	anActivity isPrompt ifTrue: [ ^ Color r: 0.2 g: 0.3 b: 0.6 ].
	anActivity isPharoTool ifTrue: [ ^ Color r: 0.5 g: 0.3 b: 0.65 ].
	tool := anActivity toolName ifNil: [ '' ].
	tool = 'Bash' ifTrue: [ ^ Color r: 0.15 g: 0.45 b: 0.7 ].
	(#( 'Edit' 'Write' 'NotebookEdit' ) includes: tool) ifTrue: [ ^ Color r: 0.6 g: 0.45 b: 0.1 ].
	(self readToolNames includes: tool) ifTrue: [ ^ Color gray ].
	^ Color r: 0.2 g: 0.55 b: 0.55
]

{ #category : 'styles' }
CMStyle class >> colorForStatus: aSymbol [

	aSymbol = #running ifTrue: [ ^ Color orange ].
	aSymbol = #failed ifTrue: [ ^ Color red ].
	^ Color r: 0.2 g: 0.65 b: 0.3
]

{ #category : 'styles' }
CMStyle class >> heading: aString [

	^ (self text: aString size: 13 color: (Color r: 0.2 g: 0.25 b: 0.45))
		  bold;
		  yourself
]

{ #category : 'styles' }
CMStyle class >> label: aText [

	^ BlTextElement new text: aText
]

{ #category : 'styles' }
CMStyle class >> promptRowColor [

	^ Color r: 0.93 g: 0.95 b: 1.0
]

{ #category : 'styles' }
CMStyle class >> readToolNames [
	"Tools that only look at things, hidden by the 'Hide reads' filter"

	^ #( 'Read' 'Grep' 'Glob' 'ToolSearch' 'LS' 'mcp__pharo__class_get' 'mcp__pharo__method_get' 'mcp__pharo__class_search'
	     'mcp__pharo__method_search' 'mcp__pharo__method_source_search' 'mcp__pharo__method_reference_search'
	     'mcp__pharo__tool_search' 'mcp__pharo__tool_get' )
]

{ #category : 'styles' }
CMStyle class >> selectionColor [

	^ Color r: 0.85 g: 0.9 b: 1.0
]

{ #category : 'styles' }
CMStyle class >> text: aString [

	^ self text: aString size: 12 color: Color black
]

{ #category : 'styles' }
CMStyle class >> text: aString size: aNumber color: aColor [

	^ aString asString asRopedText
		  fontSize: aNumber;
		  foreground: aColor;
		  yourself
]
