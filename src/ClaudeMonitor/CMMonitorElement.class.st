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
		'hideReads',
		'sessionRows'
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
	"Insert the row just below its parent (its prompt, or the title of its session): newest first at each level"

	| row parentRow |
	(rowsById includesKey: anActivity id) ifTrue: [ ^ self updateRowFor: anActivity ].
	row := CMActivityRowElement new activity: anActivity.
	row addEventHandlerOn: BlClickEvent do: [ :event |
			self select: anActivity.
			self requestFocus ].
	row disclosure addEventHandlerOn: BlClickEvent do: [ :event |
			event consumed: true.
			self toggle: anActivity.
			self requestFocus ].
	rowsById at: anActivity id put: row.
	parentRow := anActivity parent
		             ifNil: [ self sessionRowFor: anActivity ]
		             ifNotNil: [ :prompt | rowsById at: prompt id ifAbsent: [ self sessionRowFor: anActivity ] ].
	list addChild: row at: (list childIndexOf: parentRow) + 1.
	self applyFilterTo: row.
	anActivity parent ifNotNil: [ :prompt | rowsById at: prompt id ifPresent: [ :each | each update ] ].
	self trimRows.
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
							self addLine: (CMStyle small: '[... cut]').
							^ self ].
					self addLine: (isCode
							 ifTrue: [ CMStyle code: piece ]
							 ifFalse: [ CMStyle text: piece ]) ] ]
]

{ #category : 'filtering' }
CMMonitorElement >> applyFilterTo: aRow [

	aRow visibility: ((self isShown: aRow)
			 ifTrue: [ BlVisibility visible ]
			 ifFalse: [ BlVisibility gone ])
]

{ #category : 'initialization' }
CMMonitorElement >> buildBody [

	| detailScroller |
	"The right padding leaves room for the scrollbar laid over the list"
	list := BlElement new
		        layout: BlLinearLayout vertical;
		        padding: (BlInsets right: 12);
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
	detailScroller := (self scrollable: detail)
		                  constraintsDo: [ :c | c linear weight: 0.45 ];
		                  background: (Color r: 0.985 g: 0.985 b: 0.975);
		                  yourself.
	"Lines are cut to the width of the pane: cut them again when it changes"
	detailScroller addEventHandlerOn: BlElementExtentChangedEvent do: [ :event | selected ifNotNil: [ self showDetail: selected ] ].
	^ BlElement new
		  layout: BlLinearLayout horizontal;
		  constraintsDo: [ :c |
				  c horizontal matchParent.
				  c vertical matchParent ];
		  addChildren: {
				  ((self withScrollbar: (self scrollable: list))
					   constraintsDo: [ :c | c linear weight: 0.55 ];
					   yourself).
				  (BlElement new
					   background: (Color gray alpha: 0.4);
					   constraintsDo: [ :c |
							   c horizontal exact: 1.
							   c vertical matchParent ];
					   yourself).
				  detailScroller };
		  yourself
]

{ #category : 'initialization' }
CMMonitorElement >> buildContent [

	self addChild: self buildHeader.
	self addChild: self buildBody
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
				  c vertical exact: CMStyle headerHeight ];
		  padding: (BlInsets left: 10 right: 10);
		  background: (Color r: 0.94 g: 0.94 b: 0.96);
		  addChildren: {
				  header.
				  (BlElement new
					   constraintsDo: [ :c |
							   c linear weight: 1.
							   c vertical exact: 1 ];
					   yourself).
				  (self button: 'A-' action: [ :button | self changeFontSizeBy: -1 ]).
				  (self button: 'A+' action: [ :button | self changeFontSizeBy: 1 ]).
				  ((self button: 'Hide reads' action: [ :button | self toggleHideReads: button ])
					   background: (hideReads
							    ifTrue: [ CMStyle selectionColor ]
							    ifFalse: [ Color white ]);
					   yourself).
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
		          addChild: (CMStyle label: (CMStyle button: aString));
		          yourself.
	button addEventHandlerOn: BlClickEvent do: [ :event | aBlock value: button ].
	^ button
]

{ #category : 'updating' }
CMMonitorElement >> changeFontSizeBy: aNumber [

	CMStyle fontSize: CMStyle fontSize + aNumber.
	self rebuild
]

{ #category : 'updating' }
CMMonitorElement >> clear [

	list removeChildren.
	rowsById removeAll.
	self sessionRows removeAll.
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

{ #category : 'keyboard' }
CMMonitorElement >> goLeft [

	selected ifNil: [ ^ self ].
	rowsById at: selected id ifPresent: [ :row | (selected hasChildren and: [ row isExpanded ]) ifTrue: [ ^ self toggle: selected ] ].
	selected parent ifNotNil: [ :prompt | self selectAndShow: prompt ]
]

{ #category : 'keyboard' }
CMMonitorElement >> goRight [

	selected ifNil: [ ^ self ].
	selected hasChildren ifFalse: [ ^ self ].
	rowsById at: selected id ifPresent: [ :row | row isExpanded ifFalse: [ ^ self toggle: selected ] ].
	self selectAndShow: selected children last
]

{ #category : 'keyboard' }
CMMonitorElement >> handleKey: anEvent [
	"Up and down move to the previous or next visible row;
	left folds a prompt or goes to the parent, right unfolds a prompt or goes to its first tool call"

	| key |
	key := anEvent key.
	key = KeyboardKey up ifTrue: [
			anEvent consumed: true.
			^ self selectNextBy: -1 ].
	key = KeyboardKey down ifTrue: [
			anEvent consumed: true.
			^ self selectNextBy: 1 ].
	key = KeyboardKey left ifTrue: [
			anEvent consumed: true.
			^ self goLeft ].
	key = KeyboardKey right ifTrue: [
			anEvent consumed: true.
			^ self goRight ]
]

{ #category : 'updating' }
CMMonitorElement >> inUIThread: aBlock [
	"Announcements arrive on server threads. The task runs in Bloc's UI loop:
	an error there must not stop the loop, so it is only reported"

	self enqueueTask: (BlTaskAction new action: [
				 aBlock
					 on: Error
					 do: [ :error | self crTrace: 'ClaudeMonitor UI: ' , error description ] ])
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
	self addEventHandlerOn: BlKeyDownEvent do: [ :event | self handleKey: event ].
	self buildContent
]

{ #category : 'filtering' }
CMMonitorElement >> isRead: anActivity [

	^ CMStyle readToolNames includes: anActivity toolName
]

{ #category : 'filtering' }
CMMonitorElement >> isShown: aRow [
	"Not filtered out, and not inside a folded prompt"

	(hideReads and: [ self isRead: aRow activity ]) ifTrue: [ ^ false ].
	aRow activity ancestorsDo: [ :ancestor | rowsById at: ancestor id ifPresent: [ :row | row isExpanded ifFalse: [ ^ false ] ] ].
	^ true
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
		when: CMActivityChanged do: [ :ann | self inUIThread: [ self updateRowFor: ann activity ] ] for: self;
		when: CMSessionChanged do: [ :ann | self inUIThread: [ self updateSessionRowFor: ann session ] ] for: self.
	self updateHeader
]

{ #category : 'detail' }
CMMonitorElement >> maxDetailLines [

	^ 400
]

{ #category : 'detail' }
CMMonitorElement >> maxLineWidth [
	"Characters that fit in the detail pane at the current font size"

	| width |
	width := detail parent ifNil: [ 0 ] ifNotNil: [ :scroller | scroller width ].
	width = 0 ifTrue: [ width := self width * 0.45 ].
	^ ((width max: 400) - 20 / CMStyle charWidth) floor max: 30
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

{ #category : 'updating' }
CMMonitorElement >> rebuild [
	"Build everything again, e.g. after a font size change"

	| previous |
	previous := selected.
	self removeChildren.
	rowsById removeAll.
	self sessionRows removeAll.
	selected := nil.
	self buildContent.
	log ifNotNil: [ log activities do: [ :each | self addRowFor: each ] ].
	previous ifNotNil: [ self select: previous ].
	self updateHeader
]

{ #category : 'updating' }
CMMonitorElement >> refreshVisibility [

	list children do: [ :each | (each isKindOf: CMActivityRowElement) ifTrue: [ self applyFilterTo: each ] ]
]

{ #category : 'accessing' }
CMMonitorElement >> rowCount [

	^ list childrenCount
]

{ #category : 'keyboard' }
CMMonitorElement >> scrollToShow: aRow [
	"Scroll the list just enough for the row to be fully visible"

	| scroller top bottom |
	scroller := list parent.
	top := aRow position y + scroller scrollPosition y.
	bottom := top + aRow height.
	top < 0 ifTrue: [ ^ scroller scrollVerticallyBy: top negated ].
	bottom > scroller height ifTrue: [ scroller scrollVerticallyBy: scroller height - bottom ]
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

{ #category : 'keyboard' }
CMMonitorElement >> selectAndShow: anActivity [

	self select: anActivity.
	rowsById at: anActivity id ifPresent: [ :row | self scrollToShow: row ]
]

{ #category : 'keyboard' }
CMMonitorElement >> selectNextBy: aDelta [

	| rows index |
	rows := self visibleRows.
	rows ifEmpty: [ ^ self ].
	index := selected
		         ifNil: [
				         aDelta > 0
					         ifTrue: [ 0 ]
					         ifFalse: [ rows size + 1 ] ]
		         ifNotNil: [ rows findFirst: [ :row | row activity == selected ] ].
	index := index + aDelta min: rows size max: 1.
	self selectAndShow: (rows at: index) activity
]

{ #category : 'accessing' }
CMMonitorElement >> selected [

	^ selected
]

{ #category : 'sessions' }
CMMonitorElement >> sessionRowFor: anActivity [
	"The title row of the activity's session, added on top of the list when this session is new to me"

	| key session row |
	key := anActivity sessionId ifNil: [ '?' ].
	^ self sessionRows at: key ifAbsent: [
			  session := (log ifNotNil: [ log sessionWithId: key ]) ifNil: [
					             CMSession new
						             id: key;
						             startedAt: anActivity startedAt;
						             yourself ].
			  row := CMSessionRowElement new session: session.
			  list addChild: row at: 1.
			  self sessionRows at: key put: row ]
]

{ #category : 'sessions' }
CMMonitorElement >> sessionRows [

	^ sessionRows ifNil: [ sessionRows := Dictionary new ]
]

{ #category : 'detail' }
CMMonitorElement >> showDetail: anActivity [

	| input main |
	detail removeChildren.
	self addLine: (CMStyle heading: (String streamContents: [ :s |
					  s << anActivity shortToolName << '  -  ' << anActivity status asString.
					  anActivity durationMilliseconds ifNotNil: [ :ms | s << '  -  ' << ms rounded printString << ' ms' ] ])).
	self addLine: (CMStyle small: (self contextLineOf: anActivity)).
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

{ #category : 'updating' }
CMMonitorElement >> toggle: anActivity [
	"Fold or unfold the tool calls of a prompt"

	rowsById at: anActivity id ifPresent: [ :row |
			anActivity hasChildren ifFalse: [ ^ self ].
			row expanded: row isExpanded not.
			self refreshVisibility ]
]

{ #category : 'filtering' }
CMMonitorElement >> toggleHideReads: aButton [

	hideReads := hideReads not.
	aButton background: (hideReads
			 ifTrue: [ CMStyle selectionColor ]
			 ifFalse: [ Color white ]).
	self refreshVisibility
]

{ #category : 'updating' }
CMMonitorElement >> trimRows [
	"Forget the oldest rows beyond maxRows, and the title of a session left with no rows"

	[ rowsById size > self maxRows ] whileTrue: [
			| last |
			last := list children last.
			list removeChild: last.
			(last isKindOf: CMActivityRowElement) ifTrue: [ rowsById removeKey: last activity id ifAbsent: [ ] ].
			(last isKindOf: CMSessionRowElement) ifTrue: [ self sessionRows removeKey: last session id ifAbsent: [ ] ] ].
	(list hasChildren and: [ list children last isKindOf: CMSessionRowElement ]) ifTrue: [
			| last |
			last := list children last.
			list removeChild: last.
			self sessionRows removeKey: last session id ifAbsent: [ ] ]
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

{ #category : 'sessions' }
CMMonitorElement >> updateSessionRowFor: aSession [

	self sessionRows at: aSession id ifPresent: [ :row | row update ]
]

{ #category : 'keyboard' }
CMMonitorElement >> visibleRows [

	^ list children select: [ :each | (each isKindOf: CMActivityRowElement) and: [ each visibility isVisible ] ]
]

{ #category : 'initialization' }
CMMonitorElement >> withScrollbar: aScrollable [
	"A pane holding aScrollable with a vertical scrollbar laid over its right edge"

	^ BlElement new
		  constraintsDo: [ :c |
				  c horizontal matchParent.
				  c vertical matchParent ];
		  addChild: aScrollable;
		  addChild: (BlVerticalScrollbarElement new
				   constraintsDo: [ :c |
						   c ignoreByLayout.
						   c ignored horizontal alignRight ];
				   attachTo: aScrollable;
				   yourself);
		  yourself
]
