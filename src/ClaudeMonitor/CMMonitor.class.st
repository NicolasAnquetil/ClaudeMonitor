"
I am the entry point of ClaudeMonitor: a live view, in Bloc, of what Claude Code does in this workspace (the commands it runs and why), fed by Claude Code hooks.

  CMMonitor start.   ""start receiving hook events on port 8091 and open the window""
  CMMonitor open.    ""open another window on the same log""
  CMMonitor stop.

The hooks are set up in the workspace's .claude/settings.json; they POST each hook payload to CMHookServer.
"
Class {
	#name : 'CMMonitor',
	#superclass : 'Object',
	#instVars : [
		'log',
		'hookServer'
	],
	#classInstVars : [
		'default'
	],
	#category : 'ClaudeMonitor-Core',
	#package : 'ClaudeMonitor',
	#tag : 'Core'
}

{ #category : 'instance creation' }
CMMonitor class >> default [

	^ default ifNil: [ default := self new ]
]

{ #category : 'instance creation' }
CMMonitor class >> open [
	"Open a window on the default monitor's log"

	^ self default open
]

{ #category : 'instance creation' }
CMMonitor class >> reset [
	"Stop and forget the log"

	self stop.
	default := nil
]

{ #category : 'instance creation' }
CMMonitor class >> start [
	"Start receiving hook events and open a window"

	self default startServer.
	^ self open
]

{ #category : 'instance creation' }
CMMonitor class >> stop [

	default ifNotNil: [ default stopServer ]
]

{ #category : 'accessing' }
CMMonitor >> hookServer [

	^ hookServer ifNil: [
			  hookServer := CMHookServer new
				                log: self log;
				                yourself ]
]

{ #category : 'running' }
CMMonitor >> isServerRunning [

	^ hookServer isNotNil and: [ hookServer isRunning ]
]

{ #category : 'accessing' }
CMMonitor >> log [

	^ log ifNil: [ log := CMActivityLog new ]
]

{ #category : 'opening' }
CMMonitor >> open [

	| element space |
	element := CMMonitorElement new
		           log: self log;
		           yourself.
	space := BlSpace new.
	space
		title: 'ClaudeMonitor';
		extent: 1200 @ 700.
	space root addChild: element.
	space addEventHandlerOn: BlSpaceClosedEvent do: [ :event | element detach ].
	space show.
	^ space
]

{ #category : 'running' }
CMMonitor >> startServer [

	self hookServer start
]

{ #category : 'running' }
CMMonitor >> stopServer [

	hookServer ifNotNil: [ hookServer stop ]
]
