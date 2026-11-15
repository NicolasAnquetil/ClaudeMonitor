"
I am announced when activities of a prompt moved to another parent: a message read late took the tool calls that came after it.
"
Class {
	#name : 'CMActivitiesRegrouped',
	#superclass : 'Announcement',
	#instVars : [
		'prompt'
	],
	#category : 'ClaudeMonitor',
	#package : 'ClaudeMonitor'
}

{ #category : 'accessing' }
CMActivitiesRegrouped >> prompt [

	^ prompt
]

{ #category : 'accessing' }
CMActivitiesRegrouped >> prompt: anActivity [

	prompt := anActivity
]
