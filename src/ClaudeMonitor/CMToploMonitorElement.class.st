"
I am the ClaudeMonitor window built with Toplo widgets, following a CMActivityLog live:
- a tree table: sessions, the prompts of each session, the tool calls of each prompt; with the start time and the duration in their own columns,
- a details pane on the selected activity, in a read-only ToAlbum (text can be selected and copied),
- a divider between both that can be dragged.

Keys: up and down move in the list; left folds a prompt or goes to its parent; right unfolds a prompt or goes to its first tool call.

	CMToploMonitorElement openOn: CMMonitor default log
"
Class {
	#name : 'CMToploMonitorElement',
	#superclass : 'ToElement',
	#instVars : [
		'log',
		'title',
		'hideReadsButton',
		'table',
		'detail',
		'selected',
		'hideReads',
		'collapsed',
		'clearedAt'
	],
	#category : 'ClaudeMonitor-UI',
	#package : 'ClaudeMonitor',
	#tag : 'UI'
}

{ #category : 'opening' }
CMToploMonitorElement class >> openOn: anActivityLog [
	"Open a window following anActivityLog"

	| element space |
	element := self new.
	space := BlSpace new.
	space
		title: 'ClaudeMonitor';
		extent: 1200 @ 700.
	space root addChild: element.
	element log: anActivityLog.
	space addEventHandlerOn: BlSpaceClosedEvent do: [ :event | element detach ].
	space show.
	^ space
]

{ #category : 'tree' }
CMToploMonitorElement >> activityAdded: anActivity [
	"Insert the row of a new activity just below its parent, if the parent is unfolded"

	| owner ownerIndex wrapper |
	(self isHidden: anActivity) ifTrue: [ ^ self updateTitle ].
	(self indexOf: anActivity) > 0 ifTrue: [ ^ self activityChanged: anActivity ].
	owner := (self parentOf: anActivity) ifNil: [ ^ self updateTitle ].
	ownerIndex := self indexOf: owner.
	ownerIndex = 0 ifTrue: [
			(self isSession: owner) ifFalse: [ ^ self updateTitle ].
			"A new session: its row, unfolded, shows the activity"
			table dataAccessor addFirst: owner.
			(self wrapperAt: 1) expand.
			self keepSelection.
			^ self updateTitle ].
	wrapper := self wrapperAt: ownerIndex.
	wrapper isExpanded ifTrue: [
			table dataAccessor useParentWrapper: wrapper while: [ table dataAccessor add: anActivity afterIndex: ownerIndex ].
			(anActivity isPrompt and: [ (collapsed includes: anActivity) not ]) ifTrue: [ (self wrapperAt: ownerIndex + 1) expand ].
			self keepSelection ].
	"The owner may have had no children: show its fold arrow"
	self refreshRowAt: ownerIndex.
	self updateTitle
]

{ #category : 'table' }
CMToploMonitorElement >> activityCellFor: anItem [
	"A session shows its title; an activity its status icon, its tool badge and its summary"

	| cell |
	cell := BlElement new
		        layout: (BlLinearLayout horizontal
				         alignCenterLeft;
				         interspace: 8;
				         yourself);
		        constraintsDo: [ :c |
				        c horizontal matchParent.
				        c vertical fitContent ];
		        padding: (BlInsets top: 2 bottom: 2);
		        clipChildren: true;
		        yourself.
	(self isSession: anItem) ifTrue: [
			^ cell
				  addChild: (CMStyle label: (CMStyle heading: anItem displayTitle));
				  yourself ].
	cell addChildren: {
			(self statusIconFor: anItem).
			(BlElement new
				 layout: BlFrameLayout new;
				 constraintsDo: [ :c |
						 c horizontal fitContent.
						 c vertical fitContent ];
				 padding: (BlInsets
						  top: 2
						  left: 6
						  bottom: 2
						  right: 6);
				 geometry: (BlRoundedRectangleGeometry cornerRadius: 4);
				 background: (CMStyle colorForActivity: anItem);
				 addChild: (CMStyle label: (CMStyle badge: anItem shortToolName));
				 yourself).
			(CMStyle label: (CMStyle text: anItem summary)) }.
	^ cell
]

{ #category : 'tree' }
CMToploMonitorElement >> activityChanged: anActivity [

	| index |
	index := self indexOf: anActivity.
	index > 0 ifTrue: [ self refreshRowAt: index ].
	selected == anActivity ifTrue: [ self showDetail: anActivity ].
	self updateTitle
]

{ #category : 'detail' }
CMToploMonitorElement >> addActivityDetailOf: anActivity to: aText [

	| input main |
	aText append: (CMStyle heading: (String streamContents: [ :s |
					  s << anActivity shortToolName << '  -  ' << anActivity status asString.
					  anActivity durationMilliseconds ifNotNil: [ :ms | s << '  -  ' << ms rounded printString << ' ms' ] ])).
	self newLineIn: aText.
	aText append: (CMStyle small: (self contextLineOf: anActivity)).
	anActivity why ifNotNil: [ :why |
			self
				section: 'Why'
				text: why
				code: false
				in: aText ].
	anActivity explanation ifNotNil: [ :explanation |
			self
				section: 'Explanation'
				text: explanation
				code: false
				in: aText ].
	input := anActivity input ifNil: [ Dictionary new ].
	main := anActivity isPrompt
		        ifTrue: [ 'prompt' ]
		        ifFalse: [
				        #( 'command' 'code' 'source' 'content' 'new_string' )
					        detect: [ :key | (input at: key ifAbsent: [ nil ]) isString ]
					        ifNone: [ nil ] ].
	self
		section: (anActivity isPrompt
				 ifTrue: [ 'Prompt' ]
				 ifFalse: [ 'Input' ])
		text: (String streamContents: [ :s |
					 main ifNotNil: [ s << (input at: main) asString ].
					 input keys asSortedCollection do: [ :key |
							 (key = main or: [ key = 'description' ]) ifFalse: [
									 s isEmpty ifFalse: [ s cr ].
									 s << key << ': ' << (self printValue: (input at: key)) ] ] ])
		code: anActivity isPrompt not
		in: aText.
	(anActivity response isNil or: [ anActivity response isEmpty ]) ifFalse: [
			self
				section: (anActivity isFailed
						 ifTrue: [ 'Error' ]
						 ifFalse: [ 'Response' ])
				text: anActivity response
				code: true
				in: aText ]
]

{ #category : 'detail' }
CMToploMonitorElement >> addSessionDetailOf: aSession to: aText [

	aText append: (CMStyle heading: aSession displayTitle).
	self newLineIn: aText.
	aText append: (CMStyle small: aSession dateString , '   session ' , aSession id)
]

{ #category : 'table' }
CMToploMonitorElement >> applyArrowTokens [
	"Solid triangles to fold and unfold, sized with the font, instead of the theme's small chevrons"

	table
		addTokenNamed: #'iconic-arrow-right' withValue: (ToMaterialDesignIconProvider innerImageNamed: #filled_arrowright);
		addTokenNamed: #'iconic-arrow-down' withValue: (ToMaterialDesignIconProvider innerImageNamed: #filled_arrowdropdown);
		addTokenNamed: #'iconic-arrow-breadth' withValue: self arrowBreadth
]

{ #category : 'table' }
CMToploMonitorElement >> arrowBreadth [

	^ (CMStyle fontSize * 1.4) rounded
]

{ #category : 'initialization' }
CMToploMonitorElement >> buildBody [
	"The list and the details side by side, with a divider that can be dragged"

	| pane |
	table := self newTable.
	table useScrollbar: true.
	self applyArrowTokens.
	table constraintsDo: [ :c | c linear weight: 0.6 ].
	table addEventHandlerOn: BlElementExtentChangedEvent do: [ :event | self fitColumns ].
	detail := ToAlbum new
		          beReadonlyWithSelection;
		          withSoftLine;
		          yourself.
	detail constraintsDo: [ :c |
			c horizontal matchParent.
			c vertical matchParent.
			c linear weight: 0.4 ].
	pane := ToPane horizontal.
	pane constraintsDo: [ :c |
			c horizontal matchParent.
			c vertical matchParent ].
	pane addChildren: {
			table.
			detail }.
	pane addDividers.
	^ pane
]

{ #category : 'initialization' }
CMToploMonitorElement >> buildHeader [

	title := CMStyle label: (CMStyle heading: 'ClaudeMonitor').
	hideReadsButton := ToButton new
		                   labelText: 'Hide reads';
		                   clickAction: [ self toggleHideReads ];
		                   yourself.
	^ BlElement new
		  layout: (BlLinearLayout horizontal
				   alignCenterLeft;
				   interspace: 8;
				   yourself);
		  constraintsDo: [ :c |
				  c horizontal matchParent.
				  c vertical fitContent ];
		  padding: (BlInsets
				   top: 4
				   left: 10
				   bottom: 4
				   right: 10);
		  background: (Color r: 0.94 g: 0.94 b: 0.96);
		  addChildren: {
				  title.
				  (BlElement new
					   constraintsDo: [ :c |
							   c horizontal matchParent.
							   c vertical exact: 1 ];
					   yourself).
				  (ToButton new
					   labelText: 'A-';
					   tooltipString: 'Smaller font';
					   clickAction: [ self changeFontSizeBy: -1 ];
					   yourself).
				  (ToButton new
					   labelText: 'A+';
					   tooltipString: 'Larger font';
					   clickAction: [ self changeFontSizeBy: 1 ];
					   yourself).
				  hideReadsButton.
				  (ToButton new
					   labelText: 'Clear';
					   tooltipString: 'Hide what happened until now';
					   clickAction: [ self clear ];
					   yourself) };
		  yourself
]

{ #category : 'updating' }
CMToploMonitorElement >> changeFontSizeBy: aNumber [
	"Rows are built with the font size: build them again"

	CMStyle fontSize: CMStyle fontSize + aNumber.
	title text: (CMStyle heading: title text asString).
	self applyArrowTokens.
	self reload.
	selected ifNotNil: [ self showDetail: selected ]
]

{ #category : 'tree' }
CMToploMonitorElement >> childrenOf: anItem [
	"Newest first: the prompts of a session (and its tool calls made before any prompt, or under a
	hidden prompt), the tool calls of a prompt"

	| items |
	items := (self isSession: anItem)
		         ifTrue: [ log activities copy select: [ :each | each sessionId = anItem id and: [ (self parentOf: each) == anItem ] ] ]
		         ifFalse: [ anItem children copy ].
	^ (items reject: [ :each | self isHidden: each ]) reversed asArray
]

{ #category : 'updating' }
CMToploMonitorElement >> clear [
	"Hide what happened until now; what comes next is shown"

	clearedAt := DateAndTime now.
	selected := nil.
	detail text: '' asRopedText.
	self reload
]

{ #category : 'detail' }
CMToploMonitorElement >> contextLineOf: anActivity [

	| session |
	session := anActivity sessionId ifNil: [ '?' ].
	^ String streamContents: [ :s |
			  anActivity startedAt ifNotNil: [ :t | s << t asDate yyyymmdd << ' ' << t asTime print24 << '   ' ].
			  s << 'session ' << (session first: (session size min: 8)) ]
]

{ #category : 'updating' }
CMToploMonitorElement >> detach [
	"Stop following the log, when my window closes"

	log ifNotNil: [ log announcer unsubscribe: self ]
]

{ #category : 'accessing' }
CMToploMonitorElement >> detail [

	^ detail
]

{ #category : 'table' }
CMToploMonitorElement >> durationCellFor: anItem [
	"Right-aligned, so that durations line up"

	^ BlElement new
		  layout: (BlLinearLayout horizontal
				   alignCenterRight;
				   yourself);
		  constraintsDo: [ :c |
				  c horizontal matchParent.
				  c vertical fitContent ];
		  padding: (BlInsets right: 8);
		  addChild: (CMStyle label: (CMStyle code: ((self isSession: anItem)
						     ifTrue: [ '' ]
						     ifFalse: [ self durationStringOf: anItem ])));
		  yourself
]

{ #category : 'table' }
CMToploMonitorElement >> durationColumnWidth [

	^ CMStyle durationColumnWidth + 8
]

{ #category : 'table' }
CMToploMonitorElement >> durationStringOf: anActivity [

	| ms |
	anActivity isPrompt ifTrue: [ ^ '' ].
	anActivity isRunning ifTrue: [ ^ '...' ].
	ms := anActivity durationMilliseconds ifNil: [ ^ '' ].
	ms < 1000 ifTrue: [ ^ ms rounded printString , ' ms' ].
	^ (ms / 1000 printShowingDecimalPlaces: 1) , ' s'
]

{ #category : 'table' }
CMToploMonitorElement >> fitColumns [
	"The Activity column takes the width left by the fixed ones, the fold arrow (rows have it, not the
	header) and the scrollbar. Toplo applies a column width to the rows already built without their
	tree indentation, so they are built again, on the next frame"

	| first width |
	table header cellContainers ifEmpty: [ ^ self ].
	first := table header cellContainers first.
	width := (table width - self timeColumnWidth - self durationColumnWidth - self arrowBreadth - 30) rounded max: 150.
	(first width - width) abs < 4 ifTrue: [ ^ self ].
	first updateWidthWith: width.
	self inUIThread: [ self reload ]
]

{ #category : 'selection' }
CMToploMonitorElement >> goLeft [
	"Fold the selected row, or go to its parent"

	| index wrapper |
	index := self selectedIndex.
	index = 0 ifTrue: [ ^ self ].
	wrapper := self wrapperAt: index.
	(wrapper isExpanded and: [ (self childrenOf: selected) notEmpty ]) ifTrue: [ ^ wrapper collapse ].
	(self isSession: selected) ifTrue: [ ^ self ].
	self selectIndex: (self indexOf: (self parentOf: selected))
]

{ #category : 'selection' }
CMToploMonitorElement >> goRight [
	"Unfold the selected row, or go to its first child"

	| index wrapper |
	index := self selectedIndex.
	index = 0 ifTrue: [ ^ self ].
	(self childrenOf: selected) ifEmpty: [ ^ self ].
	wrapper := self wrapperAt: index.
	wrapper isExpanded ifFalse: [ ^ wrapper expand ].
	self selectIndex: index + 1
]

{ #category : 'updating' }
CMToploMonitorElement >> inUIThread: aBlock [
	"Announcements arrive on server threads. The task runs in Bloc's UI loop:
	an error there must not stop the loop, so it is only reported"

	self enqueueTask: (BlTaskAction new action: [
				 aBlock
					 on: Error
					 do: [ :error | self crTrace: 'ClaudeMonitor UI: ' , error description ] ])
]

{ #category : 'tree' }
CMToploMonitorElement >> indexOf: anItem [
	"Position of anItem among the rows shown, 0 if it is not shown"

	| accessor |
	accessor := table dataAccessor.
	1 to: accessor size do: [ :index | (accessor unwrappedDataItemAt: index) == anItem ifTrue: [ ^ index ] ].
	^ 0
]

{ #category : 'initialization' }
CMToploMonitorElement >> initialize [

	super initialize.
	hideReads := false.
	collapsed := IdentitySet new.
	self
		layout: BlLinearLayout vertical;
		constraintsDo: [ :c |
				c horizontal matchParent.
				c vertical matchParent ];
		background: Color white.
	self addChildren: {
			self buildHeader.
			self buildBody }
]

{ #category : 'tree' }
CMToploMonitorElement >> isHidden: anActivity [

	(clearedAt notNil and: [ anActivity startedAt notNil and: [ anActivity startedAt < clearedAt ] ]) ifTrue: [ ^ true ].
	^ hideReads and: [ CMStyle readToolNames includes: anActivity toolName ]
]

{ #category : 'tree' }
CMToploMonitorElement >> isSession: anItem [

	^ anItem isKindOf: CMSession
]

{ #category : 'tree' }
CMToploMonitorElement >> keepSelection [
	"Toplo's selection is a row index: after rows were inserted above it, select the same activity again"

	| index |
	selected ifNil: [ ^ self ].
	index := self indexOf: selected.
	index = 0 ifTrue: [ ^ self ].
	table selecter selectedIndex = index ifFalse: [ table selecter selectOnlyIndex: index ]
]

{ #category : 'accessing' }
CMToploMonitorElement >> log [

	^ log
]

{ #category : 'accessing' }
CMToploMonitorElement >> log: anActivityLog [
	"Show the activities already in the log, then follow it"

	log ifNotNil: [ log announcer unsubscribe: self ].
	log := anActivityLog.
	self reload.
	log announcer
		when: CMActivityAdded do: [ :ann | self inUIThread: [ self activityAdded: ann activity ] ] for: self;
		when: CMActivityChanged do: [ :ann | self inUIThread: [ self activityChanged: ann activity ] ] for: self;
		when: CMSessionChanged do: [ :ann | self inUIThread: [ self sessionChanged: ann session ] ] for: self
]

{ #category : 'detail' }
CMToploMonitorElement >> newLineIn: aText [

	aText append: (CMStyle text: String cr)
]

{ #category : 'table' }
CMToploMonitorElement >> newTable [
	"Selection and folding events are dispatched by the inner list, not by the table"

	| newTable |
	newTable := ToTreeTableElement new.
	newTable constraintsDo: [ :c |
			c horizontal matchParent.
			c vertical matchParent ].
	newTable nodeManager childrenGetter: [ :item | self childrenOf: item ].
	newTable columns: {
			(ToTableColumn new
				 title: 'Activity';
				 key: #activity;
				 dataIndex: [ :item | item ];
				 cellBuilder: [ :cell :item | cell addChild: (self activityCellFor: item) ];
				 yourself).
			(ToTableColumn new
				 title: 'Started';
				 key: #started;
				 width: self timeColumnWidth;
				 dataIndex: [ :item | item ];
				 cellBuilder: [ :cell :item | cell addChild: (CMStyle label: (self startedTextOf: item)) ];
				 yourself).
			(ToTableColumn new
				 title: 'Duration';
				 key: #duration;
				 width: self durationColumnWidth;
				 dataIndex: [ :item | item ];
				 cellBuilder: [ :cell :item | cell addChild: (self durationCellFor: item) ];
				 yourself) }.
	newTable list
		addEventHandlerOn: ToListPrimarySelectionChangedEvent do: [ :event | self selectionChanged: event ];
		addEventHandlerOn: ToTreeDataItemWrapperExpandedEvent
		do: [ :event | collapsed remove: event wrapper dataItem ifAbsent: [ nil ] ];
		addEventHandlerOn: ToTreeDataItemWrapperCollapsedEvent do: [ :event | collapsed add: event wrapper dataItem ];
		addShortcut: (BlShortcutWithAction new
				 combination: BlKeyCombination builder arrowLeft build;
				 action: [ self goLeft ];
				 yourself);
		addShortcut: (BlShortcutWithAction new
				 combination: BlKeyCombination builder arrowRight build;
				 action: [ self goRight ];
				 yourself).
	^ newTable
]

{ #category : 'tree' }
CMToploMonitorElement >> parentOf: anActivity [
	"Its prompt, or its session when there is no prompt or when the prompt is hidden (cleared)"

	(anActivity parent notNil and: [ (self isHidden: anActivity parent) not ]) ifTrue: [ ^ anActivity parent ].
	^ log sessionWithId: anActivity sessionId
]

{ #category : 'detail' }
CMToploMonitorElement >> printValue: anObject [

	anObject isString ifTrue: [ ^ anObject ].
	^ [ STONJSON toStringPretty: anObject ]
		  on: Error
		  do: [ anObject printString ]
]

{ #category : 'tree' }
CMToploMonitorElement >> refreshRowAt: anIndex [

	table dataSource notifyItemsChanged: (anIndex to: anIndex)
]

{ #category : 'tree' }
CMToploMonitorElement >> reload [
	"Show the log again from scratch, keeping folded what the user folded"

	| index |
	table dataAccessor removeAll.
	self sessions do: [ :each | table dataAccessor add: each ].
	index := 1.
	[ index <= table dataAccessor size ] whileTrue: [
			| wrapper |
			wrapper := self wrapperAt: index.
			(wrapper isExpanded not and: [ (collapsed includes: wrapper dataItem) not ]) ifTrue: [ wrapper expand ].
			index := index + 1 ].
	self updateTitle
]

{ #category : 'detail' }
CMToploMonitorElement >> section: aTitle text: aString code: isCode in: aText [

	self newLineIn: aText.
	self newLineIn: aText.
	aText append: (CMStyle heading: aTitle).
	self newLineIn: aText.
	aText append: (isCode
			 ifTrue: [ CMStyle code: (aString asString copyReplaceAll: String tab with: '    ') ]
			 ifFalse: [ CMStyle text: aString asString ])
]

{ #category : 'selection' }
CMToploMonitorElement >> selectIndex: anIndex [

	(anIndex between: 1 and: table dataAccessor size) ifFalse: [ ^ self ].
	table selecter scrollToDataSourcePosition: anIndex.
	table selecter selectOnlyIndex: anIndex
]

{ #category : 'accessing' }
CMToploMonitorElement >> selected [

	^ selected
]

{ #category : 'selection' }
CMToploMonitorElement >> selectedIndex [

	selected ifNil: [ ^ 0 ].
	^ self indexOf: selected
]

{ #category : 'selection' }
CMToploMonitorElement >> selectionChanged: anEvent [

	| indexes |
	indexes := anEvent selectedIndexes.
	indexes ifEmpty: [ ^ self ].
	selected := table dataAccessor unwrappedDataItemAt: indexes first.
	self showDetail: selected
]

{ #category : 'tree' }
CMToploMonitorElement >> sessionChanged: aSession [

	| index |
	index := self indexOf: aSession.
	index > 0 ifTrue: [ self refreshRowAt: index ]
]

{ #category : 'tree' }
CMToploMonitorElement >> sessions [
	"Newest first"

	^ log sessions values asSortedCollection: [ :a :b |
		  (a startedAt ifNil: [ DateAndTime epoch ]) >= (b startedAt ifNil: [ DateAndTime epoch ]) ]
]

{ #category : 'detail' }
CMToploMonitorElement >> showDetail: anItem [

	| text |
	text := '' asRopedText.
	(self isSession: anItem)
		ifTrue: [ self addSessionDetailOf: anItem to: text ]
		ifFalse: [ self addActivityDetailOf: anItem to: text ].
	detail text: text
]

{ #category : 'table' }
CMToploMonitorElement >> startedTextOf: anItem [
	"Sessions show their start time too: the date is in their details"

	| time |
	time := anItem startedAt ifNil: [ '' ] ifNotNil: [ :t | t asTime print24 ].
	^ (self isSession: anItem)
		  ifTrue: [ CMStyle small: time ]
		  ifFalse: [ CMStyle code: time ]
]

{ #category : 'table' }
CMToploMonitorElement >> statusIconFor: anActivity [

	| icon |
	icon := ToMaterialDesignIconProvider iconNamed: (anActivity isRunning
			         ifTrue: [ #filled_hourglassempty ]
			         ifFalse: [
					         anActivity isFailed
						         ifTrue: [ #filled_error ]
						         ifFalse: [ #filled_checkcircle ] ]).
	icon innerImageColor: (CMStyle colorForStatus: anActivity status).
	icon extent: (CMStyle fontSize * 1.1) rounded asPoint.
	^ icon
]

{ #category : 'accessing' }
CMToploMonitorElement >> table [

	^ table
]

{ #category : 'table' }
CMToploMonitorElement >> timeColumnWidth [

	^ CMStyle timeColumnWidth
]

{ #category : 'updating' }
CMToploMonitorElement >> toggleHideReads [

	hideReads := hideReads not.
	hideReadsButton labelText: (hideReads
			 ifTrue: [ 'Show reads' ]
			 ifFalse: [ 'Hide reads' ]).
	self reload
]

{ #category : 'updating' }
CMToploMonitorElement >> updateTitle [

	| shown running failed |
	shown := log activities reject: [ :each | self isHidden: each ].
	running := shown count: [ :each | each isRunning ].
	failed := shown count: [ :each | each isFailed ].
	title text: (CMStyle heading: (String streamContents: [ :s |
					  s << 'ClaudeMonitor  -  ' << shown size printString << ' activities'.
					  running > 0 ifTrue: [ s << ', ' << running printString << ' running' ].
					  failed > 0 ifTrue: [ s << ', ' << failed printString << ' failed' ] ]))
]

{ #category : 'tree' }
CMToploMonitorElement >> wrapperAt: anIndex [

	^ table dataSource at: anIndex
]
