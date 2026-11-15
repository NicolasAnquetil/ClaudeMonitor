"
I announce a change to one activity of a CMActivityLog.
"
Class {
	#name : 'CMActivityAnnouncement',
	#superclass : 'Announcement',
	#instVars : [
		'activity'
	],
	#category : 'ClaudeMonitor-Model',
	#package : 'ClaudeMonitor',
	#tag : 'Model'
}

{ #category : 'accessing' }
CMActivityAnnouncement >> activity [

	^ activity
]

{ #category : 'accessing' }
CMActivityAnnouncement >> activity: anActivity [

	activity := anActivity
]
