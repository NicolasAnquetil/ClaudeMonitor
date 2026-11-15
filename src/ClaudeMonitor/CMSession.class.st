"
I am a Claude Code session, as seen by ClaudeMonitor: its id, its title and when it started.

The title is the one Claude Code gives the session (an ai-title entry of the transcript, or a custom-title one after /rename). Claude Code updates it as the session goes, so it is read again from time to time (see CMActivityLog>>noteSessionOf:).
"
Class {
	#name : 'CMSession',
	#superclass : 'Object',
	#instVars : [
		'id',
		'title',
		'startedAt',
		'transcript',
		'titleCheckedAt'
	],
	#category : 'ClaudeMonitor-Model',
	#package : 'ClaudeMonitor',
	#tag : 'Model'
}

{ #category : 'printing' }
CMSession >> dateString [
	"e.g. Sun 15 Nov 2026, 11:27"

	| date |
	startedAt ifNil: [ ^ '' ].
	date := startedAt asDate.
	^ String streamContents: [ :s |
			  s << (date dayOfWeekName first: 3) << ' ' << date dayOfMonth printString << ' ' << (date monthName first: 3) << ' '
			  << date year printString.
			  s << ', ' << (startedAt asTime print24 first: 5) ]
]

{ #category : 'printing' }
CMSession >> displayTitle [

	^ (title isNil or: [ title isEmpty ])
		  ifTrue: [ 'Session ' , self shortId ]
		  ifFalse: [ title ]
]

{ #category : 'accessing' }
CMSession >> id [

	^ id
]

{ #category : 'accessing' }
CMSession >> id: aString [

	id := aString
]

{ #category : 'printing' }
CMSession >> printOn: aStream [

	aStream << self displayTitle << ' (' << self dateString << ')'
]

{ #category : 'printing' }
CMSession >> shortId [

	^ (id ifNil: [ '?' ]) first: ((id ifNil: [ '?' ]) size min: 8)
]

{ #category : 'accessing' }
CMSession >> startedAt [

	^ startedAt
]

{ #category : 'accessing' }
CMSession >> startedAt: aDateAndTime [

	startedAt := aDateAndTime
]

{ #category : 'accessing' }
CMSession >> title [

	^ title
]

{ #category : 'accessing' }
CMSession >> title: aString [

	title := aString
]

{ #category : 'accessing' }
CMSession >> titleCheckedAt [

	^ titleCheckedAt
]

{ #category : 'accessing' }
CMSession >> titleCheckedAt: aDateAndTime [

	titleCheckedAt := aDateAndTime
]

{ #category : 'accessing' }
CMSession >> transcript [

	^ transcript
]

{ #category : 'accessing' }
CMSession >> transcript: aFileReference [

	transcript := aFileReference
]
