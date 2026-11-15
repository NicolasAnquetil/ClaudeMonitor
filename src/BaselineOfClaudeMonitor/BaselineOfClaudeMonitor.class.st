"
Baseline of ClaudeMonitor, a live Bloc view of what Claude Code does in a workspace, fed by Claude Code hooks.

Metacello new
	baseline: 'ClaudeMonitor';
	repository: 'github://NicolasAnquetil/ClaudeMonitor:main/src';
	load.
"
Class {
	#name : 'BaselineOfClaudeMonitor',
	#superclass : 'BaselineOf',
	#category : 'BaselineOfClaudeMonitor',
	#package : 'BaselineOfClaudeMonitor'
}

{ #category : 'baselines' }
BaselineOfClaudeMonitor >> baseline: spec [

	<baseline>
	spec for: #common do: [
			spec baseline: 'Bloc' with: [ spec repository: 'github://pharo-graphics/Bloc:v3.0.0/src' ].
			"Toplo v0.11.0 is the version built on Bloc v3.0.0"
			spec baseline: 'Toplo' with: [ spec repository: 'github://pharo-graphics/Toplo:v0.11.0/src' ].
			spec
				package: 'ClaudeMonitor' with: [ spec requires: #( 'Bloc' 'Toplo' ) ];
				package: 'ClaudeMonitor-Tests' with: [ spec requires: #( 'ClaudeMonitor' ) ].
			spec
				group: 'Core' with: #( 'ClaudeMonitor' );
				group: 'Tests' with: #( 'ClaudeMonitor-Tests' );
				group: 'default' with: #( 'Core' 'Tests' ) ]
]
