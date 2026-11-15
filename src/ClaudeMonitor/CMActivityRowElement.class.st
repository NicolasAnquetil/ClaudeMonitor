"
I am one line of the ClaudeMonitor timeline: a status dot (orange running, green ok, red failed), the time, a badge with the tool name, the summary (why or subject) and the duration.
"
Class {
	#name : 'CMActivityRowElement',
	#superclass : 'BlElement',
	#instVars : [
		'activity',
		'statusDot',
		'durationLabel',
		'isSelected'
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
	self buildRow
]

{ #category : 'initialization' }
CMActivityRowElement >> buildRow [

	| badge time summary |
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
				 left: 8
				 bottom: 2
				 right: 8);
		clipChildren: true.
	statusDot := BlElement new
		             extent: CMStyle dotSize asPoint;
		             geometry: BlCircleGeometry new;
		             yourself.
	time := CMStyle label: (CMStyle code: (activity startedAt ifNil: [ '' ] ifNotNil: [ :t | t asTime print24 ])).
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
	summary := (CMStyle label: (CMStyle text: activity summary))
		           constraintsDo: [ :c | c linear weight: 1 ];
		           yourself.
	durationLabel := CMStyle label: (CMStyle code: '').
	self addChildren: {
			statusDot.
			time.
			badge.
			summary.
			durationLabel }.
	self update
]

{ #category : 'updating' }
CMActivityRowElement >> durationString [

	activity isPrompt ifTrue: [ ^ '' ].
	^ activity durationMilliseconds ifNil: [ '...' ] ifNotNil: [ :ms |
			  ms < 1000
				  ifTrue: [ ms rounded printString , ' ms' ]
				  ifFalse: [ (ms / 1000.0 printShowingDecimalPlaces: 1) , ' s' ] ]
]

{ #category : 'updating' }
CMActivityRowElement >> selected: aBoolean [

	isSelected := aBoolean.
	self updateBackground
]

{ #category : 'updating' }
CMActivityRowElement >> update [
	"Show the current status and duration of my activity"

	statusDot background: (CMStyle colorForStatus: activity status).
	durationLabel text: (CMStyle code: self durationString).
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
