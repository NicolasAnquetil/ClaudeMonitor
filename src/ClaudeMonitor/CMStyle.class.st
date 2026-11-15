"
I gather the colors and text styles of the ClaudeMonitor UI, on my class side.

All sizes derive from fontSize (15 by default), which the A- and A+ buttons of the window change:

	CMStyle fontSize: 16.
"
Class {
	#name : 'CMStyle',
	#superclass : 'Object',
	#classInstVars : [
		'fontSize'
	],
	#category : 'ClaudeMonitor-UI',
	#package : 'ClaudeMonitor',
	#tag : 'UI'
}

{ #category : 'styles' }
CMStyle class >> badge: aString [

	^ self text: aString size: self smallFontSize color: Color white
]

{ #category : 'styles' }
CMStyle class >> button: aString [

	^ self text: aString size: self smallFontSize color: Color black
]

{ #category : 'sizes' }
CMStyle class >> charWidth [
	"Approximate width of a monospace character"

	^ self fontSize * 0.62
]

{ #category : 'styles' }
CMStyle class >> code: aString [

	^ (self text: aString size: self fontSize color: (Color r: 0.15 g: 0.15 b: 0.2))
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

{ #category : 'sizes' }
CMStyle class >> defaultFontSize [

	^ 15
]

{ #category : 'colors' }
CMStyle class >> disclosureColor [

	^ Color r: 0.3 g: 0.33 b: 0.48
]

{ #category : 'sizes' }
CMStyle class >> disclosureSize [
	"Side of the fold/unfold triangle"

	^ (self fontSize * 0.75) rounded
]

{ #category : 'sizes' }
CMStyle class >> disclosureWidth [

	^ (self fontSize * 1.2) rounded
]

{ #category : 'sizes' }
CMStyle class >> dotSize [

	^ (self fontSize * 0.7) rounded
]

{ #category : 'sizes' }
CMStyle class >> durationColumnWidth [
	"Room for 999.9 s"

	^ (self charWidth * 9) rounded
]

{ #category : 'sizes' }
CMStyle class >> fontSize [

	^ fontSize ifNil: [ self defaultFontSize ]
]

{ #category : 'sizes' }
CMStyle class >> fontSize: aNumber [

	fontSize := aNumber max: 8
]

{ #category : 'sizes' }
CMStyle class >> headerHeight [

	^ (self fontSize * 2.6) rounded
]

{ #category : 'styles' }
CMStyle class >> heading: aString [

	^ (self text: aString size: self fontSize + 1 color: (Color r: 0.2 g: 0.25 b: 0.45))
		  bold;
		  yourself
]

{ #category : 'sizes' }
CMStyle class >> indentWidth [

	^ (self fontSize * 1.4) rounded
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

{ #category : 'sizes' }
CMStyle class >> rowHeight [

	^ (self fontSize * 1.9) rounded
]

{ #category : 'styles' }
CMStyle class >> selectionColor [

	^ Color r: 0.85 g: 0.9 b: 1.0
]

{ #category : 'styles' }
CMStyle class >> small: aString [

	^ self text: aString size: self smallFontSize color: Color gray
]

{ #category : 'sizes' }
CMStyle class >> smallFontSize [

	^ self fontSize - 2
]

{ #category : 'styles' }
CMStyle class >> text: aString [

	^ self text: aString size: self fontSize color: Color black
]

{ #category : 'styles' }
CMStyle class >> text: aString size: aNumber color: aColor [

	^ aString asString asRopedText
		  fontSize: aNumber;
		  foreground: aColor;
		  yourself
]

{ #category : 'sizes' }
CMStyle class >> timeColumnWidth [
	"Room for 00:00:00 in monospace"

	^ (self charWidth * 9) rounded
]
