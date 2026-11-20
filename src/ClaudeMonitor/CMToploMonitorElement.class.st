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
		'clearedAt',
		'reloadPending',
		'nameField',
		'renamedSession',
		'currentButton',
		'keepSelectionPending',
		'filterText',
		'shownKinds',
		'filterField',
		'tokensDetail',
		'shownColumns'
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

{ #category : 'current session' }
CMToploMonitorElement >> acceptName [

	| name |
	name := nameField text asString trimBoth.
	name ifEmpty: [ ^ self hideNameField ].
	renamedSession ifNil: [ log startSessionNamed: name ] ifNotNil: [ :session | log rename: session to: name ].
	self hideNameField
]

{ #category : 'tree' }
CMToploMonitorElement >> activityAdded: anActivity [
	"Insert the row of a new activity at its place among its siblings, if its parent is unfolded.
	While filtering, a match may bring back parents that were left out: show the tree again"

	| owner ownerIndex wrapper rowIndex |
	(self isHidden: anActivity) ifTrue: [ ^ self updateTitle ].
	self isFiltering ifTrue: [
			(self matchesFilter: anActivity) ifTrue: [ self scheduleReload ].
			^ self updateTitle ].
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
	"The first step of a plan: show the steps, unless the user folded them"
	(wrapper isExpanded not and: [ anActivity isStep and: [ owner children size = 1 and: [ (collapsed includes: owner) not ] ] ])
		ifTrue: [ wrapper expand ]
		ifFalse: [
				wrapper isExpanded ifTrue: [
						rowIndex := (self insertionIndexOf: anActivity under: ownerIndex) + 1.
						table dataAccessor useParentWrapper: wrapper while: [ table dataAccessor add: anActivity afterIndex: rowIndex - 1 ].
						((anActivity isPrompt or: [ anActivity isMessage or: [ anActivity hasChildren ] ]) and: [
							 (collapsed includes: anActivity) not ]) ifTrue: [ (self wrapperAt: rowIndex) expand ] ] ].
	self keepSelection.
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
				  addChild: (CMStyle label: (CMStyle heading: (self sessionTitleOf: anItem)));
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
	"While filtering, an activity that was left out may match now: show the tree again"

	| index |
	index := self indexOf: anActivity.
	index > 0 ifTrue: [ self refreshRowAt: index ].
	(index = 0 and: [ self isFiltering and: [ (self isHidden: anActivity) not and: [ self matchesFilter: anActivity ] ] ]) ifTrue: [
		self scheduleReload ].
	selected == anActivity ifTrue: [ self showDetail: anActivity ].
	self updateTitle
]

{ #category : 'detail' }
CMToploMonitorElement >> addActivityDetailOf: anActivity to: aText [

	| input main inputString |
	aText append: (CMStyle heading: (String streamContents: [ :s |
					  s << anActivity shortToolName << '  -  ' << anActivity status asString.
					  anActivity durationMilliseconds ifNotNil: [ :ms | s << '  -  ' << ms rounded printString << ' ms' ] ])).
	self newLineIn: aText.
	aText append: (CMStyle small: (self contextLineOf: anActivity)).
	anActivity why ifNotNil: [ :why | self section: 'Why' markdown: why in: aText ].
	anActivity explanation ifNotNil: [ :explanation | self section: 'Explanation' markdown: explanation in: aText ].
	input := anActivity input ifNil: [ Dictionary new ].
	main := anActivity isPrompt
		        ifTrue: [ 'prompt' ]
		        ifFalse: [
				        #( 'command' 'code' 'source' 'content' 'new_string' )
					        detect: [ :key | (input at: key ifAbsent: [ nil ]) isString ]
					        ifNone: [ nil ] ].
	inputString := String streamContents: [ :s |
			               main ifNotNil: [ s << (input at: main) asString ].
			               input keys asSortedCollection do: [ :key |
					               (key = main or: [ key = 'description' ]) ifFalse: [
							               s isEmpty ifFalse: [ s cr ].
							               s << key << ': ' << (self printValue: (input at: key)) ] ] ].
	anActivity isPrompt
		ifTrue: [ self section: 'Prompt' markdown: inputString in: aText ]
		ifFalse: [
				self
					section: 'Input'
					text: inputString
					code: true
					in: aText ].
	(anActivity response isNil or: [ anActivity response isEmpty ]) ifFalse: [
			self
				section: (anActivity isFailed
						 ifTrue: [ 'Error' ]
						 ifFalse: [ 'Response' ])
				text: anActivity response
				code: true
				in: aText ]
]

{ #category : 'details' }
CMToploMonitorElement >> addSessionDetailOf: aSession to: aText [
	"The same for every session: its date, whether new prompts go under it, the Claude Code sessions in it"

	| claudeSessions |
	aText append: (CMStyle heading: aSession displayTitle).
	self newLineIn: aText.
	aText append: (CMStyle small: aSession dateString , (log currentSession == aSession
				  ifTrue: [ '   current: new prompts go under it' ]
				  ifFalse: [ '' ])).
	claudeSessions := ((log activities select: [ :each | each groupId = aSession id ]) collect: [ :each | each sessionId ]) asSet
		                  reject: [ :each | each isNil ].
	self
		section: 'Claude Code sessions'
		text: (claudeSessions isEmpty
				 ifTrue: [ 'None yet.' ]
				 ifFalse: [ String cr join: (claudeSessions asSortedCollection collect: [ :id | id ]) ])
		code: false
		in: aText.
	self newLineIn: aText.
	self newLineIn: aText.
	aText append: (CMStyle small: 'Double-click the row to rename it; Current session makes new prompts go under it.')
]

{ #category : 'detail' }
CMToploMonitorElement >> addTextDetailOf: anActivity to: aText [
	"A message, a thinking or a step: its text, whole"

	aText append: (CMStyle heading: (String streamContents: [ :s |
					  s << anActivity shortToolName.
					  anActivity stepState ifNotNil: [ :state | s << '  -  ' << (state copyReplaceAll: '_' with: ' ') ] ])).
	self newLineIn: aText.
	aText append: (CMStyle small: (self contextLineOf: anActivity)).
	self
		section: (anActivity isMessage
				 ifTrue: [ 'Message' ]
				 ifFalse: [
						 anActivity isThinking
							 ifTrue: [ 'Thinking' ]
							 ifFalse: [ 'Step' ] ])
		markdown: anActivity text
		in: aText
]

{ #category : 'tokens' }
CMToploMonitorElement >> addTokensDetailOf: anItem to: aText [
	"For a window opened before the tokens had their own box: they follow the details"

	(self tokensSummaryOf: anItem) ifNotNil: [ :summary |
			self
				section: 'Tokens'
				text: summary
				code: false
				in: aText ]
]

{ #category : 'table' }
CMToploMonitorElement >> applyArrowTokens [
	"Solid triangles to fold and unfold, sized with the font, instead of the theme's small chevrons"

	table
		addTokenNamed: #'iconic-arrow-right' withValue: (ToMaterialDesignIconProvider innerImageNamed: #filled_arrowright);
		addTokenNamed: #'iconic-arrow-down' withValue: (ToMaterialDesignIconProvider innerImageNamed: #filled_arrowdropdown);
		addTokenNamed: #'iconic-arrow-breadth' withValue: self arrowBreadth
]

{ #category : 'updating' }
CMToploMonitorElement >> applyFieldFonts [
	"The text fields in our font size, not the theme's: typed text takes the font-size token, the placeholder its own text.
	A window opened before the filter existed has no filter field"

	{
		(filterField -> 'Text to look for').
		(nameField -> 'Name of the session, then Return') } do: [ :each |
			each key ifNotNil: [ :field |
					field addTokenNamed: #'font-size' withValue: CMStyle fontSize.
					field placeholderText: (CMStyle text: each value).
					field requestNewSkin ] ]
]

{ #category : 'table' }
CMToploMonitorElement >> arrowBreadth [

	^ (CMStyle fontSize * 1.4) rounded
]

{ #category : 'initialization' }
CMToploMonitorElement >> buildBody [
	"The list and the details side by side, with a divider that can be dragged.
	The details of the selected row on top, its tokens in their own box below, with a divider too"

	| pane details |
	table := self newTable.
	table useScrollbar: true.
	self applyArrowTokens.
	table constraintsDo: [ :c | c linear weight: 0.6 ].
	table addEventHandlerOn: BlElementExtentChangedEvent do: [ :event | self fitColumns ].
	detail := self newDetailAlbum.
	detail constraintsDo: [ :c | c linear weight: 0.75 ].
	detail addEventHandlerOn: BlElementExtentChangedEvent do: [ :event | self detailResized ].
	tokensDetail := self newDetailAlbum.
	tokensDetail constraintsDo: [ :c | c linear weight: 0.25 ].
	details := ToPane vertical.
	details constraintsDo: [ :c |
			c horizontal matchParent.
			c vertical matchParent.
			c linear weight: 0.4 ].
	details addChildren: {
			detail.
			tokensDetail }.
	details addDividers.
	pane := ToPane horizontal.
	pane constraintsDo: [ :c |
			c horizontal matchParent.
			c vertical matchParent ].
	pane addChildren: {
			table.
			details }.
	pane addDividers.
	^ pane
]

{ #category : 'filtering' }
CMToploMonitorElement >> buildFilterBar [
	"Which types of entries to show, and a text they must contain. Escape empties the text"

	filterField := ToTextField new.
	filterField placeholderText: (CMStyle text: 'Text to look for').
	filterField constraintsDo: [ :c |
			c horizontal exact: (CMStyle charWidth * 34) rounded.
			c vertical fitContent ].
	filterField whenTextEditedDo: [ :event | self filterTextChanged ].
	filterField whenTextReplacedDo: [ :event | self filterTextChanged ].
	filterField addEditorShortcut: (CMEditorShortcut combination: BlKeyCombination escape action: [ self clearFilterText ]).
	^ BlElement new
		  layout: (BlLinearLayout horizontal
				   alignCenterLeft;
				   interspace: 8;
				   yourself);
		  constraintsDo: [ :c |
				  c horizontal matchParent.
				  c vertical fitContent ];
		  padding: (BlInsets
				   top: 2
				   left: 10
				   bottom: 4
				   right: 10);
		  background: (Color r: 0.94 g: 0.94 b: 0.96);
		  addChildren: {
				  (CMStyle label: (CMStyle button: 'Show:')).
				  (self kindCheckbox: #prompt label: 'Prompts').
				  (self kindCheckbox: #thinking label: 'Thinking').
				  (self kindCheckbox: #message label: 'Messages').
				  (self kindCheckbox: #tool label: 'Tools').
				  (BlElement new
					   constraintsDo: [ :c |
							   c horizontal exact: 16.
							   c vertical exact: 1 ];
					   yourself).
				  (CMStyle label: (CMStyle button: 'Containing:')).
				  filterField.
				  (self button: 'Clear filter' tooltip: 'Show every entry again: all types, no text' action: [ self clearFilter ]) };
		  yourself
]

{ #category : 'initialization' }
CMToploMonitorElement >> buildHeader [

	title := CMStyle label: (CMStyle heading: 'ClaudeMonitor').
	nameField := self newNameField.
	currentButton := self button: 'Current session' tooltip: 'New prompts go under the selected session' action: [ self makeSelectedCurrent ].
	currentButton enabled: false.
	hideReadsButton := self button: 'Hide reads' tooltip: 'Hide the calls that only look at things' action: [ self toggleHideReads ].
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
				  nameField.
				  (self button: 'New session' tooltip: 'List what comes from now on under a session you name' action: [ self newSession ]).
				  currentButton.
				  (self button: 'A-' tooltip: 'Smaller font' action: [ self changeFontSizeBy: -1 ]).
				  (self button: 'A+' tooltip: 'Larger font' action: [ self changeFontSizeBy: 1 ]).
				  hideReadsButton.
				  self button: 'Collapse all' tooltip: 'Fold every prompt, message and plan' action: [ self collapseAll ].
				  (self button: 'Clear' tooltip: 'Hide what happened until now' action: [ self clear ]) };
		  yourself
]

{ #category : 'initialization' }
CMToploMonitorElement >> button: aString tooltip: aTooltip action: aBlock [
	"A Toplo button with a label and a tooltip in our font size, not the theme's.
	The tooltip text is built when shown, so it follows A-/A+"

	^ ToButton new
		  label: (ToLabel text: (CMStyle button: aString));
		  tooltipBuilder: [ :win :request |
				  win root addChild: ((ToLabel text: (CMStyle text: aTooltip size: CMStyle fontSize color: Color black))
							   beMultiLine;
							   yourself) ];
		  clickAction: aBlock;
		  yourself
]

{ #category : 'tokens' }
CMToploMonitorElement >> callsOfSession: aSession [

	| calls |
	calls := IdentitySet new.
	log activities do: [ :each | (each groupId = aSession id and: [ each call notNil ]) ifTrue: [ calls add: each call ] ].
	^ calls
]

{ #category : 'current session' }
CMToploMonitorElement >> canMakeCurrent: anItem [
	"Only a session row, not already current"

	^ (self isSession: anItem) and: [ log currentSession ~~ anItem ]
]

{ #category : 'updating' }
CMToploMonitorElement >> changeFontSizeBy: aNumber [
	"Rows are built with the font size: build them again"

	CMStyle fontSize: CMStyle fontSize + aNumber.
	title text: (CMStyle heading: title text asString).
	self applyArrowTokens.
	self applyFieldFonts.
	self updateColumnTitles.
	self updateButtons.
	self reload.
	selected ifNotNil: [ self showDetail: selected ]
]

{ #category : 'tree' }
CMToploMonitorElement >> childrenOf: anItem [
	"The steps of a plan in their order; otherwise newest first: the prompts of a session (and its
	activities made before any prompt, or under a hidden prompt), the activities of a prompt.
	What the filter leaves out is not there"

	| items |
	items := (self isSession: anItem)
		         ifTrue: [ log activities copy select: [ :each | each groupId = anItem id and: [ (self parentOf: each) == anItem ] ] ]
		         ifFalse: [ anItem children copy ].
	items := items reject: [ :each | (self isHidden: each) or: [ self isFilteredOut: each ] ].
	(items notEmpty and: [ items first isStep ]) ifTrue: [ ^ items asArray ].
	^ (items asArray withIndexCollect: [ :each :index | each -> index ])
		  sort: [ :a :b | self is: a after: b ];
		  collect: [ :each | each key ]
]

{ #category : 'updating' }
CMToploMonitorElement >> clear [
	"Hide what happened until now; what comes next is shown"

	clearedAt := DateAndTime now.
	selected := nil.
	detail text: '' asRopedText.
	tokensDetail ifNotNil: [ tokensDetail text: '' asRopedText ].
	self reload
]

{ #category : 'filtering' }
CMToploMonitorElement >> clearFilter [
	"No filtering: every type shown, no text to look for"

	filterText := ''.
	shownKinds := self filterKinds asSet.
	filterField text: '' asRopedText.
	(self allChildrenBreadthFirstSelect: [ :each | each isKindOf: ToCheckbox ]) do: [ :each | each checked: true ].
	self scheduleReload
]

{ #category : 'filtering' }
CMToploMonitorElement >> clearFilterText [

	filterField text: '' asRopedText.
	self filterTextChanged
]

{ #category : 'updating' }
CMToploMonitorElement >> collapseAll [
	"Fold every prompt, message and plan: the sessions stay open, showing one row per prompt"

	collapsed := IdentitySet withAll:
		             (log activities select: [ :each | each isPrompt or: [ each isMessage or: [ each hasChildren ] ] ]).
	self reload.
	self keepSelection
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

{ #category : 'detail' }
CMToploMonitorElement >> detailColumns [
	"How many monospace characters fit in a line of the details pane, nil before it is laid out"

	(detail isNil or: [ detail width < 1 ]) ifTrue: [ ^ nil ].
	^ (detail width - 20 / CMStyle charWidth) floor max: 20
]

{ #category : 'detail' }
CMToploMonitorElement >> detailResized [
	"Tables in the details fit the pane: lay them out again when it gets wider or narrower"

	self detailColumns = shownColumns ifTrue: [ ^ self ].
	shownColumns := self detailColumns.
	selected ifNotNil: [ self showDetail: selected ]
]

{ #category : 'current session' }
CMToploMonitorElement >> doubleClicked [
	"Any session can be renamed"

	(self isSession: selected) ifTrue: [ self showNameFieldFor: selected ]
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
	(anActivity isPrompt or: [ anActivity isThought or: [ anActivity isStep ] ]) ifTrue: [ ^ '' ].
	anActivity isRunning ifTrue: [ ^ '...' ].
	ms := anActivity durationMilliseconds ifNil: [ ^ '' ].
	ms < 1000 ifTrue: [ ^ ms rounded printString , ' ms' ].
	^ (ms / 1000 printShowingDecimalPlaces: 1) , ' s'
]

{ #category : 'filtering' }
CMToploMonitorElement >> filterKinds [
	"The types of entries the user can show or hide"

	^ #( #prompt #thinking #message #tool )
]

{ #category : 'filtering' }
CMToploMonitorElement >> filterText [
	"Empty in a window opened before the filter existed"

	^ filterText ifNil: [ filterText := '' ]
]

{ #category : 'filtering' }
CMToploMonitorElement >> filterTextChanged [

	| text |
	text := filterField text asString trimBoth.
	text = self filterText ifTrue: [ ^ self ].
	filterText := text.
	self scheduleReload
]

{ #category : 'selection' }
CMToploMonitorElement >> firstIndexOfCurrentSession [
	"The row of the current session, or the top of the list"

	| index |
	index := log currentSession ifNil: [ 0 ] ifNotNil: [ :session | self indexOf: session ].
	^ index max: 1
]

{ #category : 'table' }
CMToploMonitorElement >> fitColumns [
	"The Activity column takes the width left by the fixed ones, the fold arrow (rows have it, not the
	header) and the scrollbar. Toplo applies a column width to the rows already built without their
	tree indentation, so they are built again, on the next frame"

	| first width |
	table header cellContainers ifEmpty: [ ^ self ].
	first := table header cellContainers first.
	width := (table width - self timeColumnWidth - self durationColumnWidth - self tokensColumnWidth - self arrowBreadth - 30) rounded max: 150.
	(first width - width) abs < 4 ifTrue: [ ^ self ].
	first updateWidthWith: width.
	self inUIThread: [ self reload ]
]

{ #category : 'selection' }
CMToploMonitorElement >> goDown [
	"The next row, or without a selection the first row (the session row) of the current session"

	| index |
	index := self selectedIndex.
	index = 0 ifTrue: [ ^ self selectIndex: self firstIndexOfCurrentSession ].
	self selectIndex: index + 1
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

{ #category : 'selection' }
CMToploMonitorElement >> goUp [
	"The previous row, or without a selection the last row of the current session"

	| index |
	index := self selectedIndex.
	index = 0 ifTrue: [ ^ self selectIndex: self lastIndexOfCurrentSession ].
	self selectIndex: index - 1
]

{ #category : 'user sessions' }
CMToploMonitorElement >> hideNameField [

	renamedSession := nil.
	nameField visibility: BlVisibility gone.
	table list requestFocus
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
	filterText := ''.
	shownKinds := self filterKinds asSet.
	self
		layout: BlLinearLayout vertical;
		constraintsDo: [ :c |
				c horizontal matchParent.
				c vertical matchParent ];
		background: Color white.
	self addChildren: {
			self buildHeader.
			self buildFilterBar.
			self buildBody }.
	self applyFieldFonts
]

{ #category : 'tree' }
CMToploMonitorElement >> insertionIndexOf: anActivity under: anOwnerIndex [
	"Where the row of anActivity goes among its siblings: just after the owner when it comes first,
	else just after the rows of the sibling that comes before it (with their descendants)"

	| siblings position previousIndex depth index |
	siblings := self childrenOf: (table dataAccessor unwrappedDataItemAt: anOwnerIndex).
	position := siblings indexOf: anActivity.
	position <= 1 ifTrue: [ ^ anOwnerIndex ].
	previousIndex := self indexOf: (siblings at: position - 1).
	previousIndex = 0 ifTrue: [ ^ anOwnerIndex ].
	depth := (self wrapperAt: previousIndex) nodeDepth.
	index := previousIndex.
	[ index < table dataAccessor size and: [ (self wrapperAt: index + 1) nodeDepth > depth ] ] whileTrue: [ index := index + 1 ].
	^ index
]

{ #category : 'initialization' }
CMToploMonitorElement >> installArrowKeys [
	"Up and Down move from the selected row (see goUp, goDown). The list skin installs its own Up and Down, which move from Toplo's selection: they are replaced, each time the skin is installed"

	| list |
	list := table list.
	{
		BlKeyCombination builder arrowDown build.
		BlKeyCombination builder arrowUp build } do: [ :each | list removeShortcutsWithCombination: each ].
	list
		addShortcut: (BlShortcutWithAction new
				 combination: BlKeyCombination builder arrowDown build;
				 action: [ self goDown ];
				 yourself);
		addShortcut: (BlShortcutWithAction new
				 combination: BlKeyCombination builder arrowUp build;
				 action: [ self goUp ];
				 yourself)
]

{ #category : 'tree' }
CMToploMonitorElement >> is: anAssociation after: anotherAssociation [
	"Newest first; activities with the same time keep their order of arrival, newest first"

	| t1 t2 |
	t1 := anAssociation key startedAt ifNil: [ DateAndTime epoch ].
	t2 := anotherAssociation key startedAt ifNil: [ DateAndTime epoch ].
	t1 = t2 ifTrue: [ ^ anAssociation value > anotherAssociation value ].
	^ t1 > t2
]

{ #category : 'filtering' }
CMToploMonitorElement >> isFilteredOut: anItem [
	"Neither it nor anything under it matches the filter. The parents of what matches stay, to show where it is"

	self isFiltering ifFalse: [ ^ false ].
	((self isSession: anItem) not and: [ self matchesFilter: anItem ]) ifTrue: [ ^ false ].
	^ (self childrenOf: anItem) isEmpty
]

{ #category : 'filtering' }
CMToploMonitorElement >> isFiltering [

	^ self filterText notEmpty or: [ self shownKinds size < self filterKinds size ]
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

{ #category : 'selection' }
CMToploMonitorElement >> keepSelection [
	"Toplo's selection is a row index: put it back on the row of the selected item, wherever it is now"

	| index |
	selected ifNil: [ ^ self ].
	index := self shownIndexOf: selected.
	index = 0 ifTrue: [ ^ table selecter selectedIndex = 0 ifFalse: [ table selecter deselectAll ] ].
	table selecter selectedIndex = index ifFalse: [ table selecter selectOnlyIndex: index ]
]

{ #category : 'selection' }
CMToploMonitorElement >> keepSelectionLater [
	"After Toplo has finished updating its own selection"

	keepSelectionPending == true ifTrue: [ ^ self ].
	keepSelectionPending := true.
	self inUIThread: [
		keepSelectionPending := false.
		self keepSelection ]
]

{ #category : 'filtering' }
CMToploMonitorElement >> kindCheckbox: aKind label: aString [

	| checkbox |
	checkbox := ToCheckbox new.
	^ checkbox
		  labelText: (CMStyle button: aString);
		  checked: (self shownKinds includes: aKind);
		  checkAction: [ self show: aKind checked: checkbox isChecked ];
		  yourself
]

{ #category : 'selection' }
CMToploMonitorElement >> lastIndexOfCurrentSession [
	"The last row shown under the current session, or the bottom of the list"

	| index size |
	size := table dataAccessor size.
	index := self firstIndexOfCurrentSession.
	(log currentSession notNil and: [ (self indexOf: log currentSession) > 0 ]) ifFalse: [ ^ size ].
	[ index < size and: [ (self isSession: (table dataAccessor unwrappedDataItemAt: index + 1)) not ] ] whileTrue: [
		index := index + 1 ].
	^ index
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
		when: CMSessionChanged do: [ :ann | self inUIThread: [ self sessionChanged: ann session ] ] for: self;
		when: CMActivitiesRegrouped do: [ :ann | self scheduleReload ] for: self;
		when: CMSessionStarted do: [ :ann | self inUIThread: [ self sessionStarted: ann session ] ] for: self
]

{ #category : 'current session' }
CMToploMonitorElement >> makeSelectedCurrent [
	"New prompts go under the selected session row"

	(self canMakeCurrent: selected) ifTrue: [ log makeCurrent: selected ]
]

{ #category : 'filtering' }
CMToploMonitorElement >> matchesFilter: anActivity [
	"Its type is shown and it contains the text of the filter"

	^ (self shownKinds includes: anActivity filterKind) and: [
		  self filterText isEmpty or: [ anActivity contentMatches: self filterText ] ]
]

{ #category : 'initialization' }
CMToploMonitorElement >> newDetailAlbum [
	"A read-only text of the details pane, selectable, its lines wrapped"

	^ ToAlbum new
		  beReadonlyWithSelection;
		  withSoftLine;
		  constraintsDo: [ :c |
				  c horizontal matchParent.
				  c vertical matchParent ];
		  yourself
]

{ #category : 'detail' }
CMToploMonitorElement >> newLineIn: aText [

	aText append: (CMStyle text: String cr)
]

{ #category : 'user sessions' }
CMToploMonitorElement >> newNameField [
	"Where the user types the name of a session: Return accepts, Escape cancels. Hidden until needed.
	The keys are editor shortcuts, replacing the editor's own (Return would insert a line ending)"

	| field |
	field := ToTextField new.
	field placeholderText: (CMStyle text: 'Name of the session, then Return').
	field constraintsDo: [ :c |
			c horizontal exact: (CMStyle charWidth * 34) rounded.
			c vertical fitContent ].
	field
		addEditorShortcut: (CMEditorShortcut combination: BlKeyCombination return action: [ self acceptName ]);
		addEditorShortcut: (CMEditorShortcut combination: BlKeyCombination escape action: [ self hideNameField ]).
	field visibility: BlVisibility gone.
	^ field
]

{ #category : 'user sessions' }
CMToploMonitorElement >> newSession [

	self showNameFieldFor: nil
]

{ #category : 'initialization' }
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
			headerCellBuilder: [ :cell :column | self titleCellIn: cell for: column ];
				 cellBuilder: [ :cell :item | cell addChild: (self activityCellFor: item) ];
				 yourself).
			(ToTableColumn new
				 title: 'Started';
				 key: #started;
				 width: self timeColumnWidth;
				 dataIndex: [ :item | item ];
			headerCellBuilder: [ :cell :column | self titleCellIn: cell for: column ];
				 cellBuilder: [ :cell :item | cell addChild: (CMStyle label: (self startedTextOf: item)) ];
				 yourself).
			(ToTableColumn new
				 title: 'Duration';
				 key: #duration;
				 width: self durationColumnWidth;
				 dataIndex: [ :item | item ];
			headerCellBuilder: [ :cell :column | self titleCellIn: cell for: column ];
				 cellBuilder: [ :cell :item | cell addChild: (self durationCellFor: item) ];
				 yourself).
			(ToTableColumn new
				 title: 'Tokens';
				 key: #tokens;
				 width: self tokensColumnWidth;
				 dataIndex: [ :item | item ];
			headerCellBuilder: [ :cell :column | self titleCellIn: cell for: column ];
				 cellBuilder: [ :cell :item | cell addChild: (self tokensCellFor: item) ];
				 yourself) }.
	newTable list
		addEventHandlerOn: ToListPrimarySelectionChangedEvent do: [ :event | self selectionChanged: event ];
		addEventHandlerOn: BlMouseDownEvent do: [ :event | self rowPressed: event ];
		addEventHandlerOn: BlDoubleClickEvent do: [ :event | self doubleClicked ];
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
				 yourself);
		addEventHandlerOn: ToInstallSkinEvent do: [ :event | self inUIThread: [ self installArrowKeys ] ].
	^ newTable
]

{ #category : 'tree' }
CMToploMonitorElement >> parentOf: anActivity [
	"Its prompt, or its session row (a session the user started, else its Claude Code session) when there is no prompt or when the prompt is hidden (cleared)"

	(anActivity parent notNil and: [ (self isHidden: anActivity parent) not ]) ifTrue: [ ^ anActivity parent ].
	^ log sessionWithId: anActivity groupId
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
	self sessions do: [ :each | (self isFilteredOut: each) ifFalse: [ table dataAccessor add: each ] ].
	index := 1.
	[ index <= table dataAccessor size ] whileTrue: [
			| wrapper |
			wrapper := self wrapperAt: index.
			(wrapper isExpanded not and: [ (collapsed includes: wrapper dataItem) not ]) ifTrue: [ wrapper expand ].
			index := index + 1 ].
	self updateTitle
]

{ #category : 'selection' }
CMToploMonitorElement >> rowPressed: anEvent [
	"The row under the mouse becomes the selected row"

	| element |
	anEvent primaryButtonPressed ifFalse: [ ^ self ].
	element := anEvent target.
	[ element notNil and: [ (element isKindOf: ToNodeContainer) not ] ] whileTrue: [ element := element parent ].
	element ifNil: [ ^ self ].
	self select: element holder dataItem
]

{ #category : 'updating' }
CMToploMonitorElement >> scheduleReload [
	"Activities moved: show the tree again, once for a burst of moves"

	reloadPending == true ifTrue: [ ^ self ].
	reloadPending := true.
	self inUIThread: [
			reloadPending := false.
			self reload.
			self keepSelection ]
]

{ #category : 'detail' }
CMToploMonitorElement >> section: aTitle markdown: aString in: aText [
	"aString is written by Claude or the user: show it formatted as Markdown"

	self newLineIn: aText.
	self newLineIn: aText.
	aText append: (CMStyle heading: aTitle).
	self newLineIn: aText.
	aText append: (CMMarkdownComposer textFor: aString asString columns: self detailColumns)
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
CMToploMonitorElement >> select: anItem [
	"anItem becomes the selected row: its details are shown and Toplo's selection is set on its row"

	selected := anItem.
	self keepSelection.
	self showDetail: selected.
	self updateCurrentButton
]

{ #category : 'selection' }
CMToploMonitorElement >> selectIndex: anIndex [

	(anIndex between: 1 and: table dataAccessor size) ifFalse: [ ^ self ].
	table selecter scrollToDataSourcePosition: anIndex.
	self select: (table dataAccessor unwrappedDataItemAt: anIndex)
]

{ #category : 'accessing' }
CMToploMonitorElement >> selected [

	^ selected
]

{ #category : 'selection' }
CMToploMonitorElement >> selectedIndex [

	selected ifNil: [ ^ 0 ].
	^ self shownIndexOf: selected
]

{ #category : 'selection' }
CMToploMonitorElement >> selectionChanged: anEvent [
	"The selected row is set by a click (rowPressed:) or the arrow keys (goUp, goDown), never from Toplo's selection: Toplo keeps it as a row index, which points to another row once rows are inserted above it. Whenever Toplo's selection changes, it is put back on the row of the selected item"

	self keepSelectionLater
]

{ #category : 'tree' }
CMToploMonitorElement >> sessionChanged: aSession [

	| index |
	index := self indexOf: aSession.
	index > 0 ifTrue: [ self refreshRowAt: index ].
	selected == aSession ifTrue: [ self showDetail: aSession ].
	self updateCurrentButton
]

{ #category : 'user sessions' }
CMToploMonitorElement >> sessionStarted: aSession [
	"Its row goes on top, empty for now"

	self reload.
	self keepSelection.
	self updateTitle.
	self updateCurrentButton
]

{ #category : 'current session' }
CMToploMonitorElement >> sessionTitleOf: aSession [
	"Where new prompts go is marked"

	^ log currentSession == aSession
		  ifTrue: [ aSession displayTitle , '  (current)' ]
		  ifFalse: [ aSession displayTitle ]
]

{ #category : 'tree' }
CMToploMonitorElement >> sessions [
	"Newest first. A Claude Code session whose activities all went under sessions of the user is left out"

	| groups |
	groups := (log activities collect: [ :each | each groupId ]) asSet.
	^ (log sessions values select: [ :each | each isByUser or: [ groups includes: each id ] ]) asSortedCollection: [ :a :b |
		  (a startedAt ifNil: [ DateAndTime epoch ]) >= (b startedAt ifNil: [ DateAndTime epoch ]) ]
]

{ #category : 'tokens' }
CMToploMonitorElement >> shortCount: aNumber [

	aNumber < 1000 ifTrue: [ ^ aNumber rounded printString ].
	aNumber < 1000000 ifTrue: [ ^ (aNumber / 1000 printShowingDecimalPlaces: 1) , 'k' ].
	^ (aNumber / 1000000 printShowingDecimalPlaces: 1) , 'M'
]

{ #category : 'filtering' }
CMToploMonitorElement >> show: aKind checked: aBoolean [

	aBoolean
		ifTrue: [ self shownKinds add: aKind ]
		ifFalse: [ self shownKinds remove: aKind ifAbsent: [ nil ] ].
	self scheduleReload
]

{ #category : 'detail' }
CMToploMonitorElement >> showDetail: anItem [

	| text |
	text := '' asRopedText.
	(self isSession: anItem)
		ifTrue: [ self addSessionDetailOf: anItem to: text ]
		ifFalse: [
				(anItem isThought or: [ anItem isStep ])
					ifTrue: [ self addTextDetailOf: anItem to: text ]
					ifFalse: [ self addActivityDetailOf: anItem to: text ] ].
	tokensDetail ifNil: [ self addTokensDetailOf: anItem to: text ] ifNotNil: [ tokensDetail text: (self tokensTextOf: anItem) ].
	detail text: text
]

{ #category : 'user sessions' }
CMToploMonitorElement >> showNameFieldFor: aSessionOrNil [
	"Ask the name of a new session, or the new name of aSessionOrNil"

	renamedSession := aSessionOrNil.
	nameField text: (CMStyle text: (aSessionOrNil ifNil: [ '' ] ifNotNil: [ :s | s displayTitle ])).
	nameField visibility: BlVisibility visible.
	nameField requestFocus
]

{ #category : 'selection' }
CMToploMonitorElement >> shownIndexOf: anItem [
	"The row of anItem, or of its closest ancestor shown (when anItem is in a folded row); 0 if none is shown"

	| item index |
	item := anItem.
	[ item notNil ] whileTrue: [
			index := self indexOf: item.
			index > 0 ifTrue: [ ^ index ].
			item := self parentOf: item ].
	^ 0
]

{ #category : 'filtering' }
CMToploMonitorElement >> shownKinds [
	"All of them in a window opened before the filter existed"

	^ shownKinds ifNil: [ shownKinds := self filterKinds asSet ]
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

	| name color icon |
	name := #filled_checkcircle.
	color := CMStyle colorForStatus: anActivity status.
	anActivity isRunning ifTrue: [ name := #filled_hourglassempty ].
	anActivity isFailed ifTrue: [ name := #filled_error ].
	anActivity isMessage ifTrue: [
			name := #filled_chatbubbleoutline.
			color := CMStyle colorForActivity: anActivity ].
	anActivity isThinking ifTrue: [
			name := #filled_psychology.
			color := CMStyle colorForActivity: anActivity ].
	anActivity isStep ifTrue: [
			anActivity stepState = 'in_progress' ifTrue: [
					name := #filled_playcircle.
					color := Color orange ].
			anActivity stepState = 'pending' ifTrue: [
					name := #filled_radiobuttonunchecked.
					color := Color gray ].
			anActivity stepState ifNil: [
					name := #filled_listalt.
					color := CMStyle colorForActivity: anActivity ] ].
	icon := ToMaterialDesignIconProvider iconNamed: name.
	icon innerImageColor: color.
	icon extent: (CMStyle fontSize * 1.1) rounded asPoint.
	^ icon
]

{ #category : 'tokens' }
CMToploMonitorElement >> summaryOfCalls: aCollection [
	"Totals of model calls, each counted once"

	| sum |
	sum := [ :selector | aCollection inject: 0 into: [ :total :each | total + (each perform: selector) ] ].
	^ String streamContents: [ :s |
			  (s << aCollection size printString << ' model call' << (aCollection size = 1
					    ifTrue: [ '' ]
					    ifFalse: [ 's' ]))
				  << ', counted once each.';
				  cr.
			  (s << 'Written: ' << (sum value: #outputTokens) asStringWithCommas << ' output tokens, '
			   << (sum value: #thinkingTokens) asStringWithCommas)
				  << ' of them thinking.';
				  cr.
			  s << 'Read: ' << (sum value: #inputTokens) asStringWithCommas << ' input tokens: '
			  << (sum value: #newInputTokens) asStringWithCommas << ' new, ' << (sum value: #cacheWriteTokens) asStringWithCommas
			  << ' cache writes, ' << (sum value: #cacheReadTokens) asStringWithCommas << ' cache reads.' ]
]

{ #category : 'accessing' }
CMToploMonitorElement >> table [

	^ table
]

{ #category : 'table' }
CMToploMonitorElement >> timeColumnWidth [

	^ CMStyle timeColumnWidth
]

{ #category : 'table' }
CMToploMonitorElement >> titleCellIn: aCell for: aColumn [

	aCell addChild: ((CMStyle label: (self titleTextOf: aColumn))
			 margin: (BlInsets top: 4 bottom: 4);
			 yourself)
]

{ #category : 'table' }
CMToploMonitorElement >> titleTextOf: aColumn [

	^ (CMStyle text: aColumn title asString size: CMStyle fontSize color: (Color r: 0.2 g: 0.25 b: 0.45))
		  bold;
		  yourself
]

{ #category : 'updating' }
CMToploMonitorElement >> toggleHideReads [

	hideReads := hideReads not.
	hideReadsButton label text: (CMStyle button: (hideReads
				  ifTrue: [ 'Show reads' ]
				  ifFalse: [ 'Hide reads' ])).
	self reload
]

{ #category : 'tokens' }
CMToploMonitorElement >> tokensCellFor: anItem [
	"Right-aligned, so that counts line up"

	^ BlElement new
		  layout: (BlLinearLayout horizontal
				   alignCenterRight;
				   yourself);
		  constraintsDo: [ :c |
				  c horizontal matchParent.
				  c vertical fitContent ];
		  padding: (BlInsets right: 8);
		  addChild: (CMStyle label: (CMStyle code: (self tokensStringOf: anItem)));
		  yourself
]

{ #category : 'tokens' }
CMToploMonitorElement >> tokensColumnWidth [
	"Room for ~999.9k"

	^ (CMStyle charWidth * 8) rounded + 8
]

{ #category : 'accessing' }
CMToploMonitorElement >> tokensDetail [

	^ tokensDetail
]

{ #category : 'tokens' }
CMToploMonitorElement >> tokensDetailOf: anActivity [
	"The tokens of the row, and of the model call it comes from"

	| call own |
	anActivity isPrompt ifTrue: [ ^ anActivity callsBelow ifEmpty: [ nil ] ifNotEmpty: [ :calls | self summaryOfCalls: calls ] ].
	call := anActivity call.
	own := anActivity ownTokens.
	^ String streamContents: [ :s |
			  own ifNil: [ s << 'No model call known for this row.' ] ifNotNil: [
					  s << 'This row: ' << ((anActivity call isEstimateFor: anActivity)
						   ifTrue: [ 'about ' ]
						   ifFalse: [ '' ]) << own asStringWithCommas << ' output tokens'.
					  (anActivity call isEstimateFor: anActivity) ifTrue: [
						  s << ' (estimated: the call''s output is shared among its blocks by size)' ].
					  s << '.' ].
			  (anActivity isMessage and: [ anActivity hasChildren ]) ifTrue: [
					  anActivity outputTokens ifNotNil: [ :n |
							  s cr. s << 'With its tool calls: ' << (anActivity isTokenEstimate
								   ifTrue: [ 'about ' ]
								   ifFalse: [ '' ]) << n asStringWithCommas << ' output tokens.' ] ].
			  call ifNotNil: [
					  s cr. s << 'Its model call: ' << call outputTokens asStringWithCommas << ' output tokens ('
					  << call thinkingTokens asStringWithCommas << ' thinking); read ' << call inputTokens asStringWithCommas
					  << ' input tokens (' << call newInputTokens asStringWithCommas << ' new, ' << call cacheWriteTokens asStringWithCommas
					  << ' cache writes, ' << call cacheReadTokens asStringWithCommas << ' cache reads); '
					  << call shownActivities size printString << ' row' << (call shownActivities size = 1
						   ifTrue: [ ' shows' ]
						   ifFalse: [ 's show' ]) << ' it.' ] ]
]

{ #category : 'tokens' }
CMToploMonitorElement >> tokensStringOf: anItem [

	| tokens |
	tokens := (self isSession: anItem)
		          ifTrue: [
				          (self callsOfSession: anItem)
					          ifEmpty: [ nil ]
					          ifNotEmpty: [ :calls | calls inject: 0 into: [ :sum :each | sum + each outputTokens ] ] ]
		          ifFalse: [ anItem outputTokens ].
	tokens ifNil: [ ^ '' ].
	^ (((self isSession: anItem) not and: [ anItem isTokenEstimate ])
		   ifTrue: [ '~' ]
		   ifFalse: [ '' ]) , (self shortCount: tokens)
]

{ #category : 'tokens' }
CMToploMonitorElement >> tokensSummaryOf: anItem [
	"What the row's tokens were, nil if none is known"

	(self isSession: anItem) ifTrue: [
		^ (self callsOfSession: anItem) ifEmpty: [ nil ] ifNotEmpty: [ :calls | self summaryOfCalls: calls ] ].
	anItem isStep ifTrue: [ ^ nil ].
	^ self tokensDetailOf: anItem
]

{ #category : 'tokens' }
CMToploMonitorElement >> tokensTextOf: anItem [
	"The text of the tokens box"

	| text |
	text := '' asRopedText.
	text append: (CMStyle heading: 'Tokens').
	self newLineIn: text.
	text append: ((self tokensSummaryOf: anItem)
			 ifNil: [ CMStyle small: 'No model call known for this row.' ]
			 ifNotNil: [ :summary | CMStyle text: summary ]).
	^ text
]

{ #category : 'updating' }
CMToploMonitorElement >> updateButtons [
	"Give the header buttons the current font size"

	(self allChildrenBreadthFirstSelect: [ :each | each isKindOf: ToButton ]) do: [ :button |
		button label text: (CMStyle button: button label text asString) ]
]

{ #category : 'table' }
CMToploMonitorElement >> updateColumnTitles [
	"The header is built once: give its titles the current font size"

	table header cellContainers do: [ :container |
		container cell children ifNotEmpty: [ :labels | labels first text: (self titleTextOf: container column) ] ]
]

{ #category : 'current session' }
CMToploMonitorElement >> updateCurrentButton [
	currentButton ifNil: [ ^ self ].
	currentButton enabled: (self canMakeCurrent: selected)
]

{ #category : 'updating' }
CMToploMonitorElement >> updateTitle [

	| shown running failed |
	shown := log activities reject: [ :each | (self isHidden: each) or: [ self isFiltering and: [ (self matchesFilter: each) not ] ] ].
	running := shown count: [ :each | each isRunning ].
	failed := shown count: [ :each | each isFailed ].
	title text: (CMStyle heading: (String streamContents: [ :s |
					  s << 'ClaudeMonitor  -  ' << shown size printString << ' activities'.
					  self isFiltering ifTrue: [ s << ' matching' ].
					  running > 0 ifTrue: [ s << ', ' << running printString << ' running' ].
					  failed > 0 ifTrue: [ s << ', ' << failed printString << ' failed' ] ]))
]

{ #category : 'tree' }
CMToploMonitorElement >> wrapperAt: anIndex [

	^ table dataSource at: anIndex
]
