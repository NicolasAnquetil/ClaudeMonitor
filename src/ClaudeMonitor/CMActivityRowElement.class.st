"
I am one line of the ClaudeMonitor timeline, indented by the depth of my activity (prompts at the top, the tool calls they led to below them):
- a disclosure triangle, for a prompt, to fold or unfold its tool calls,
- a status dot (orange running, green ok, red failed),
- the start time and the duration, each in a fixed-width column,
- a badge with the tool name and the summary (why or subject).
"
Class {
	#name : 'CMActivityRowElement',
	#superclass : 'BlElement',
	#instVars : [
		'activity',
		'statusDot',
		'durationLabel',
		'isSelected',
		'expanded',
		'disclosure'
	],
	#category : 'ClaudeMonitor-UI',
	#package : 'ClaudeMonitor',
	#tag : 'UI'
}

{ #category : 'accessing' }
CMActivityRowElement >> activity [

	^ activity
]

{ #category : 'initialization' }
CMActivityRowElement >> activity: anActivity [

	activity := anActivity.
	isSelected := false.
	expanded := true.
	self buildRow
]

{ #category : 'initialization' }
CMActivityRowElement >> buildRow [

	| badge summary |
	self
		layout: (BlLinearLayout horizontal
				 alignCenterLeft;
				 interspace: 8;
				 yourself);
		constraintsDo: [ :c |
				c horizontal matchParent.
				c vertical exact: CMStyle rowHeight ];
		padding: (BlInsets
				 top: 2
				 left: 8 + (activity depth * CMStyle indentWidth)
				 bottom: 2
				 right: 8);
		clipChildren: true.
	disclosure := (self column: CMStyle disclosureWidth alignRight: false)
		              addChild: (CMStyle label: (CMStyle text: ''));
		              yourself.
	statusDot := BlElement new
		             extent: CMStyle dotSize asPoint;
		             geometry: BlCircleGeometry new;
		             yourself.
	badge := BlElement new
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
		         background: (CMStyle colorForActivity: activity);
		         addChild: (CMStyle label: (CMStyle badge: activity shortToolName));
		         yourself.
	"The summary takes the room left and is clipped, so the duration column stays in view"
	summary := BlElement new
		           layout: (BlLinearLayout horizontal
				            alignCenterLeft;
				            yourself);
		           constraintsDo: [ :c |
				           c horizontal matchParent.
				           c linear weight: 1.
				           c vertical fitContent ];
		           clipChildren: true;
		           addChild: (CMStyle label: (CMStyle text: activity summary));
		           yourself.
	durationLabel := CMStyle label: (CMStyle code: '').
	self addChildren: {
			disclosure.
			statusDot.
			((self column: CMStyle timeColumnWidth alignRight: false)
				 addChild: (CMStyle label: (CMStyle code: (activity startedAt ifNil: [ '' ] ifNotNil: [ :t | t asTime print24 ])));
				 yourself).
			badge.
			summary.
			((self column: CMStyle durationColumnWidth alignRight: true)
				 addChild: durationLabel;
				 yourself) }.
	self update
]

{ #category : 'initialization' }
CMActivityRowElement >> column: aWidth alignRight: aBoolean [
	"A fixed-width cell, so that times and durations line up from row to row"

	| cellLayout |
	cellLayout := BlLinearLayout horizontal.
	aBoolean
		ifTrue: [ cellLayout alignCenterRight ]
		ifFalse: [ cellLayout alignCenterLeft ].
	^ BlElement new
		  layout: cellLayout;
		  constraintsDo: [ :c |
				  c horizontal exact: aWidth.
				  c vertical fitContent ];
		  yourself
]

{ #category : 'accessing' }
CMActivityRowElement >> disclosure [

	^ disclosure
]

{ #category : 'updating' }
CMActivityRowElement >> disclosureString [
	"Plain characters: the UI font has no triangles"

	activity hasChildren ifFalse: [ ^ '' ].
	^ self isExpanded
		  ifTrue: [ '-' ]
		  ifFalse: [ '+' ]
]

{ #category : 'updating' }
CMActivityRowElement >> durationString [

	activity isPrompt ifTrue: [ ^ '' ].
	^ activity durationMilliseconds ifNil: [ '...' ] ifNotNil: [ :ms |
			  ms < 1000
				  ifTrue: [ ms rounded printString , ' ms' ]
				  ifFalse: [ (ms / 1000.0 printShowingDecimalPlaces: 1) , ' s' ] ]
]

{ #category : 'accessing' }
CMActivityRowElement >> expanded: aBoolean [

	expanded := aBoolean.
	self update
]

{ #category : 'accessing' }
CMActivityRowElement >> isExpanded [
	"Rows start expanded; nil for a row built before folding existed"

	^ expanded ~~ false
]

{ #category : 'updating' }
CMActivityRowElement >> selected: aBoolean [

	isSelected := aBoolean.
	self updateBackground
]

{ #category : 'updating' }
CMActivityRowElement >> update [
	"Show the current status, duration and disclosure of my activity"

	statusDot background: (CMStyle colorForStatus: activity status).
	durationLabel text: (CMStyle code: self durationString).
	disclosure ifNotNil: [ disclosure children first text: (CMStyle text: self disclosureString) ].
	self updateBackground
]

{ #category : 'updating' }
CMActivityRowElement >> updateBackground [

	self background: (isSelected
			 ifTrue: [ CMStyle selectionColor ]
			 ifFalse: [
					 activity isPrompt
						 ifTrue: [ CMStyle promptRowColor ]
						 ifFalse: [ Color white ] ])
]
