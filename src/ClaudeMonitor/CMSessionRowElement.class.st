"
I am the title line of a session in the ClaudeMonitor timeline: the session title and the date and time it started. The activities of the session are listed below me, newest first.
"
Class {
	#name : 'CMSessionRowElement',
	#superclass : 'BlElement',
	#instVars : [
		'session',
		'titleLabel',
		'dateLabel'
	],
	#category : 'ClaudeMonitor-UI',
	#package : 'ClaudeMonitor',
	#tag : 'UI'
}

{ #category : 'updating' }
CMSessionRowElement >> session [

	^ session
]

{ #category : 'initialization' }
CMSessionRowElement >> session: aSession [

	session := aSession.
	titleLabel := CMStyle label: (CMStyle heading: '').
	dateLabel := CMStyle label: (CMStyle small: '').
	self
		layout: (BlLinearLayout horizontal
				 alignCenterLeft;
				 interspace: 12;
				 yourself);
		constraintsDo: [ :c |
				c horizontal matchParent.
				c vertical exact: (CMStyle rowHeight * 1.4) rounded ];
		padding: (BlInsets
				 top: 4
				 left: 8
				 bottom: 2
				 right: 8);
		background: (Color r: 0.88 g: 0.9 b: 0.95);
		border: (BlBorder paint: (Color r: 0.7 g: 0.74 b: 0.85) width: 1);
		clipChildren: true;
		addChildren: {
				titleLabel.
				dateLabel }.
	self update
]

{ #category : 'updating' }
CMSessionRowElement >> update [

	titleLabel text: (CMStyle heading: session displayTitle).
	dateLabel text: (CMStyle small: (String streamContents: [ :s | s << session dateString << '   session ' << session shortId ]))
]
