"
I receive Claude Code hook events over HTTP on localhost and hand them to a CMActivityLog.

The hooks POST each payload as JSON to http://127.0.0.1:<port>/event (default port 8091). I always answer 200 quickly, even for a payload I cannot use, so a hook never slows Claude Code down.
"
Class {
	#name : 'CMHookServer',
	#superclass : 'Object',
	#instVars : [
		'port',
		'log',
		'server'
	],
	#category : 'ClaudeMonitor-Server',
	#package : 'ClaudeMonitor',
	#tag : 'Server'
}

{ #category : 'defaults' }
CMHookServer class >> defaultPort [

	^ 8091
]

{ #category : 'running' }
CMHookServer >> handle: aRequest [
	"Always answer quickly: a hook must never slow Claude Code down"

	(aRequest method = #POST and: [ aRequest uri path = 'event' ]) ifFalse: [ ^ ZnResponse notFound: aRequest uri ].
	[ log handleHookEvent: (STONJSON fromString: aRequest contents) ]
		on: Error
		do: [ :error | self crTrace: 'ClaudeMonitor: ' , error description ].
	^ ZnResponse ok: (ZnEntity text: 'ok')
]

{ #category : 'accessing' }
CMHookServer >> isRunning [

	^ server isNotNil and: [ server isRunning ]
]

{ #category : 'accessing' }
CMHookServer >> log [

	^ log
]

{ #category : 'accessing' }
CMHookServer >> log: anActivityLog [

	log := anActivityLog
]

{ #category : 'accessing' }
CMHookServer >> port [

	^ port ifNil: [ self class defaultPort ]
]

{ #category : 'accessing' }
CMHookServer >> port: anInteger [

	port := anInteger
]

{ #category : 'running' }
CMHookServer >> start [

	self stop.
	server := (ZnServer on: self port)
		          bindingAddress: #[ 127 0 0 1 ];
		          onRequestRespond: [ :request | self handle: request ];
		          yourself.
	server start
]

{ #category : 'running' }
CMHookServer >> stop [

	server ifNotNil: [ server stop ].
	server := nil
]
