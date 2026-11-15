"
I announce that the title of a session of a CMActivityLog changed.
"
Class {
	#name : 'CMSessionChanged',
	#superclass : 'Announcement',
	#instVars : [
		'session'
	],
	#category : 'ClaudeMonitor-Model',
	#package : 'ClaudeMonitor',
	#tag : 'Model'
}

{ #category : 'accessing' }
CMSessionChanged >> session [

	^ session
]

{ #category : 'accessing' }
CMSessionChanged >> session: aSession [

	session := aSession
]
