"
I am announced when the user starts a session of their own: what comes after is listed under it.
"
Class {
	#name : 'CMSessionStarted',
	#superclass : 'Announcement',
	#instVars : [
		'session'
	],
	#category : 'ClaudeMonitor',
	#package : 'ClaudeMonitor'
}

{ #category : 'accessing' }
CMSessionStarted >> session [

	^ session
]

{ #category : 'accessing' }
CMSessionStarted >> session: aSession [

	session := aSession
]
