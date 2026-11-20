"
I am announced when the user removed entries from a CMActivityLog: activities (each with everything under it), and the session row they were under when the whole session was removed.
"
Class {
	#name : 'CMActivitiesRemoved',
	#superclass : 'Announcement',
	#instVars : [
		'activities',
		'session'
	],
	#category : 'ClaudeMonitor-Model',
	#package : 'ClaudeMonitor',
	#tag : 'Model'
}

{ #category : 'accessing' }
CMActivitiesRemoved >> activities [

	^ activities ifNil: [ #(  ) ]
]

{ #category : 'accessing' }
CMActivitiesRemoved >> activities: aCollection [

	activities := aCollection
]

{ #category : 'accessing' }
CMActivitiesRemoved >> session [
	"The session removed, nil when only activities were"

	^ session
]

{ #category : 'accessing' }
CMActivitiesRemoved >> session: aSession [

	session := aSession
]
