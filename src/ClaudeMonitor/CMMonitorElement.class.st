"
I show a CMActivityLog live, in Bloc: a timeline of activities on the left (newest on top) and the details of the selected one on the right (why, explanation, full input, response).

I follow the log through its announcements. They arrive on server threads, so I apply them in the UI thread with enqueueTask:.

Open me with CMMonitor open.
"
Class {
	#name : 'CMMonitorElement',
	#superclass : 'BlElement',
	#instVars : [
		'log',
		'header',
		'list',
		'detail',
		'rowsById',
		'selected',
		'hideReads'
	],
	#category : 'ClaudeMonitor-UI',
	#package : 'ClaudeMonitor',
	#tag : 'UI'
}

{ #category : 'detail' }
CMMonitorElement >> addLine: aText [

	detail addChild: (CMStyle label: aText)
]

{ #category : 'updating' }
CMMonitorElement >> addRowFor: anActivity [

	| row |
	(rowsById includesKey: anActivity id) ifTrue: [ ^ self updateRowFor: anActivity ].
	row := CMActivityRowElement new activity: anActivity.
	row addEventHandlerOn: BlClickEvent do: [ :event | self select: anActivity ].
	self applyFilterTo: row.
	rowsById at: anActivity id put: row.
	list addChild: row at: 1.
	[ list childrenCount > self maxRows ] whileTrue: [
			| last |
			last := list children last.
			rowsById removeKey: last activity id ifAbsent: [ ].
			list removeChild: last ].
	self updateHeader
]

{ #category : 'detail' }
CMMonitorElement >> addText: aString code: isCode [
	"BlTextElement shows one line: split the text in lines, and long lines in pieces"

	| count |
	count := 0.
	aString asString lines do: [ :line |
			(self piecesOf: line) do: [ :piece |
					count := count + 1.
					count > self maxDetailLines ifTrue: [
							self addLine: (CMStyle text: '[... cut]' size: 11 color: Color gray).
							^ self ].
					self addLine: (isCode
							 ifTrue: [ CMStyle code: piece ]
							 ifFalse: [ CMStyle text: piece ]) ] ]
]

{ #category : 'filtering' }
CMMonitorElement >> applyFilterTo: aRow [

	aRow visibility: ((hideReads and: [ self isRead: aRow activity ])
			 ifTrue: [ BlVisibility gone ]
			 ifFalse: [ BlVisibility visible ])
]

{ #category : 'initialization' }
CMMonitorElement >> buildBody [

	list := BlElement new
		        layout: BlLinearLayout vertical;
		        constraintsDo: [ :c |
				        c horizontal matchParent.
				        c vertical fitContent ];
		        yourself.
	detail := BlElement new
		          layout: (BlLinearLayout vertical
				           interspace: 1;
				           yourself);
		          constraintsDo: [ :c |
				          c horizontal matchParent.
				          c vertical fitContent ];
		          padding: (BlInsets all: 10);
		          yourself.
	^ BlElement new
		  layout: BlLinearLayout horizontal;
		  constraintsDo: [ :c |
				  c horizontal matchParent.
				  c vertical matchParent ];
		  addChildren: {
				  ((self scrollable: list)
					   constraintsDo: [ :c | c linear weight: 0.55 ];
					   yourself).
				  (BlElement new
					   background: (Color gray alpha: 0.4);
					   constraintsDo: [ :c |
							   c horizontal exact: 1.
							   c vertical matchParent ];
					   yourself).
				  ((self scrollable: detail)
					   constraintsDo: [ :c | c linear weight: 0.45 ];
					   background: (Color r: 0.985 g: 0.985 b: 0.975);
					   yourself) };
		  yourself
]

{ #category : 'initialization' }
CMMonitorElement >> buildHeader [

	header := CMStyle label: (CMStyle heading: 'ClaudeMonitor').
	^ BlElement new
		  layout: (BlLinearLayout horizontal
				   alignCenterLeft;
				   interspace: 12;
				   yourself);
		  constraintsDo: [ :c |
				  c horizontal matchParent.
				  c vertical exact: 34 ];
		  padding: (BlInsets left: 10 right: 10);
		  background: (Color r: 0.94 g: 0.94 b: 0.96);
		  addChildren: {
				  header.
				  (BlElement new
					   constraintsDo: [ :c |
							   c linear weight: 1.
							   c vertical exact: 1 ];
					   yourself).
				  (self button: 'Hide reads' action: [ :button | self toggleHideReads: button ]).
				  (self button: 'Clear' action: [ :button | self clear ]) };
		  yourself
]

{ #category : 'initialization' }
CMMonitorElement >> button: aString action: aBlock [

	| button |
	button := BlElement new
		          layout: BlFrameLayout new;
		          constraintsDo: [ :c |
				          c horizontal fitContent.
				          c vertical fitContent ];
		          padding: (BlInsets
				           top: 3
				           left: 8
				           bottom: 3
				           right: 8);
		          geometry: (BlRoundedRectangleGeometry cornerRadius: 4);
		          border: (BlBorder paint: Color gray width: 1);
		          background: Color white;
		          addChild: (CMStyle label: (CMStyle text: aString size: 11 color: Color black));
		          yourself.
	button addEventHandlerOn: BlClickEvent do: [ :event | aBlock value: button ].
	^ button
]

{ #category : 'updating' }
CMMonitorElement >> clear [

	list removeChildren.
	rowsById removeAll.
	selected := nil.
	detail removeChildren.
	self updateHeader
]

{ #category : 'detail' }
CMMonitorElement >> contextLineOf: anActivity [

	| session |
	session := anActivity sessionId ifNil: [ '?' ].
	^ String streamContents: [ :s |
			  anActivity startedAt ifNotNil: [ :t | s << t asDate yyyymmdd << ' ' << t asTime print24 << '   ' ].
			  s << 'session ' << (session first: (session size min: 8)) ]
]

{ #category : 'releasing' }
CMMonitorElement >> detach [
	"Stop following the log, when my window closes"

	log ifNotNil: [ log announcer unsubscribe: self ]
]

{ #category : 'updating' }
CMMonitorElement >> inUIThread: aBlock [
	"Announcements arrive on server threads"

	self enqueueTask: (BlTaskAction new action: aBlock)
]

{ #category : 'initialization' }
CMMonitorElement >> initialize [

	super initialize.
	rowsById := Dictionary new.
	hideReads := false.
	self
		layout: BlLinearLayout vertical;
		constraintsDo: [ :c |
				c horizontal matchParent.
				c vertical matchParent ];
		background: Color white.
	self addChild: self buildHeader.
	self addChild: self buildBody
]

{ #category : 'filtering' }
CMMonitorElement >> isRead: anActivity [

	^ CMStyle readToolNames includes: anActivity toolName
]

{ #category : 'accessing' }
CMMonitorElement >> log [

	^ log
]

{ #category : 'accessing' }
CMMonitorElement >> log: anActivityLog [
	"Show the activities already in the log, then follow it"

	log ifNotNil: [ log announcer unsubscribe: self ].
	log := anActivityLog.
	log activities do: [ :each | self addRowFor: each ].
	log announcer
		when: CMActivityAdded do: [ :ann | self inUIThread: [ self addRowFor: ann activity ] ] for: self;
		when: CMActivityChanged do: [ :ann | self inUIThread: [ self updateRowFor: ann activity ] ] for: self.
	self updateHeader
]

{ #category : 'detail' }
CMMonitorElement >> maxDetailLines [

	^ 400
]

{ #category : 'detail' }
CMMonitorElement >> maxLineWidth [

	^ 100
]

{ #category : 'accessing' }
CMMonitorElement >> maxRows [

	^ 500
]

{ #category : 'detail' }
CMMonitorElement >> piecesOf: aLine [

	| width line pieces |
	width := self maxLineWidth.
	line := aLine copyReplaceAll: String tab with: '    '.
	line isEmpty ifTrue: [ ^ #( ' ' ) ].
	pieces := OrderedCollection new.
	1 to: line size by: width do: [ :start | pieces add: (line copyFrom: start to: (start + width - 1 min: line size)) ].
	^ pieces
]

{ #category : 'detail' }
CMMonitorElement >> printValue: anObject [

	anObject isString ifTrue: [ ^ anObject ].
	^ [ STONJSON toStringPretty: anObject ]
		  on: Error
		  do: [ anObject printString ]
]

{ #category : 'accessing' }
CMMonitorElement >> rowCount [

	^ list childrenCount
]

{ #category : 'initialization' }
CMMonitorElement >> scrollable: anElement [

	^ BlScrollableElement new
		  constraintsDo: [ :c |
				  c horizontal matchParent.
				  c vertical matchParent ];
		  addChild: anElement;
		  yourself
]

{ #category : 'detail' }
CMMonitorElement >> section: aString [

	detail addChild: ((CMStyle label: (CMStyle heading: aString))
			 margin: (BlInsets top: 10 bottom: 2);
			 yourself)
]

{ #category : 'updating' }
CMMonitorElement >> select: anActivity [

	selected ifNotNil: [ rowsById at: selected id ifPresent: [ :row | row selected: false ] ].
	selected := anActivity.
	rowsById at: anActivity id ifPresent: [ :row | row selected: true ].
	self showDetail: anActivity
]

{ #category : 'accessing' }
CMMonitorElement >> selected [

	^ selected
]

{ #category : 'detail' }
CMMonitorElement >> showDetail: anActivity [

	| input main |
	detail removeChildren.
	self addLine: (CMStyle heading: (String streamContents: [ :s |
					  s << anActivity shortToolName << '  -  ' << anActivity status asString.
					  anActivity durationMilliseconds ifNotNil: [ :ms | s << '  -  ' << ms rounded printString << ' ms' ] ])).
	self addLine: (CMStyle text: (self contextLineOf: anActivity) size: 11 color: Color gray).
	anActivity why ifNotNil: [ :why |
			self
				section: 'Why';
				addText: why code: false ].
	anActivity explanation ifNotNil: [ :text |
			self
				section: 'Explanation';
				addText: text code: false ].
	input := anActivity input.
	main := anActivity isPrompt
		        ifTrue: [ 'prompt' ]
		        ifFalse: [
				        #( 'command' 'code' 'source' 'content' 'new_string' )
					        detect: [ :key | (input at: key ifAbsent: [ nil ]) isString ]
					        ifNone: [ nil ] ].
	self section: (anActivity isPrompt
			 ifTrue: [ 'Prompt' ]
			 ifFalse: [ 'Input' ]).
	main ifNotNil: [ self addText: (input at: main) code: anActivity isPrompt not ].
	input keys asSortedCollection do: [ :key |
			(key = main or: [ key = 'description' ]) ifFalse: [
				self addText: (String streamContents: [ :s | s << key << ': ' << (self printValue: (input at: key)) ]) code: true ] ].
	(anActivity response isNil or: [ anActivity response isEmpty ]) ifFalse: [
			self section: (anActivity isFailed
					 ifTrue: [ 'Error' ]
					 ifFalse: [ 'Response' ]).
			self addText: anActivity response code: true ]
]

{ #category : 'filtering' }
CMMonitorElement >> toggleHideReads: aButton [

	hideReads := hideReads not.
	aButton background: (hideReads
			 ifTrue: [ CMStyle selectionColor ]
			 ifFalse: [ Color white ]).
	list children do: [ :row | self applyFilterTo: row ]
]

{ #category : 'updating' }
CMMonitorElement >> updateHeader [

	| running failed |
	running := rowsById count: [ :row | row activity isRunning ].
	failed := rowsById count: [ :row | row activity isFailed ].
	header text: (CMStyle heading: (String streamContents: [ :s |
					  s << 'ClaudeMonitor  -  ' << rowsById size printString << ' activities'.
					  running > 0 ifTrue: [ s << ', ' << running printString << ' running' ].
					  failed > 0 ifTrue: [ s << ', ' << failed printString << ' failed' ] ]))
]

{ #category : 'updating' }
CMMonitorElement >> updateRowFor: anActivity [

	rowsById at: anActivity id ifPresent: [ :row | row update ].
	selected == anActivity ifTrue: [ self showDetail: anActivity ].
	self updateHeader
]
