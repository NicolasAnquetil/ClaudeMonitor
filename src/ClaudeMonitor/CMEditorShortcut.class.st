"
I am a text editor shortcut that runs a block. Added to a text field, I replace the editor's own shortcut for the same keys: Return accepts what was typed instead of inserting a line ending.
"
Class {
	#name : 'CMEditorShortcut',
	#superclass : 'AlbEditorShortcut',
	#instVars : [
		'action'
	],
	#category : 'ClaudeMonitor-UI',
	#package : 'ClaudeMonitor',
	#tag : 'UI'
}

{ #category : 'instance creation' }
CMEditorShortcut class >> combination: aKeyCombination action: aBlock [
	^ self new combination: aKeyCombination action: aBlock
]

{ #category : 'accessing' }
CMEditorShortcut >> combination: aKeyCombination action: aBlock [
	combination := aKeyCombination.
	action := aBlock
]

{ #category : 'accessing' }
CMEditorShortcut >> description [

	^ 'Runs the action given for these keys'
]

{ #category : 'accessing' }
CMEditorShortcut >> name [

	^ 'Run an action'
]

{ #category : 'accessing' }
CMEditorShortcut >> performOnEditor: aTextEditor element: anEditorElement dueTo: aShortcutEvent [

	action value
]
