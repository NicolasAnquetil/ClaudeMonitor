"
Tests for ClaudeMonitor, using hook payloads shaped like the ones Claude Code sends.
"
Class {
	#name : 'CMTranscriptReaderTest',
	#superclass : 'TestCase',
	#instVars : [
		'log'
	],
	#category : 'ClaudeMonitor-Tests',
	#package : 'ClaudeMonitor-Tests'
}

{ #category : 'tests' }
CMTranscriptReaderTest >> testExplanationBeforeAToolUse [

	self assert: (CMTranscriptReader new explanationIn: self transcript beforeToolUse: 't1') equals: 'First I look.'
]

{ #category : 'tests' }
CMTranscriptReaderTest >> testMissingFile [

	self assert: (CMTranscriptReader new explanationIn: FileSystem memory / 'none.jsonl' beforeToolUse: 't1') isNil
]

{ #category : 'tests' }
CMTranscriptReaderTest >> testOnlyTheTailIsRead [

	| reader |
	reader := CMTranscriptReader new
		          tailSize: 120;
		          yourself.
	self assert: (reader explanationIn: self transcript beforeToolUse: 'not-yet') equals: 'Then I fix.'
]

{ #category : 'tests' }
CMTranscriptReaderTest >> testParallelToolUsesShareTheExplanation [

	self assert: (CMTranscriptReader new explanationIn: self transcript beforeToolUse: 't2') equals: 'First I look.'
]

{ #category : 'tests' }
CMTranscriptReaderTest >> testUnknownToolUseTakesTheTextAtTheEnd [

	self assert: (CMTranscriptReader new explanationIn: self transcript beforeToolUse: 'not-yet') equals: 'Then I fix.'
]

{ #category : 'tests' }
CMTranscriptReaderTest >> transcript [

	| file |
	file := FileSystem memory / 'transcript.jsonl'.
	file writeStreamDo: [ :stream |
			#( '{"type":"user","message":{"role":"user","content":"do it"}}' '{"type":"assistant","message":{"content":[{"type":"thinking","thinking":""}]}}'
			   '{"type":"assistant","message":{"content":[{"type":"text","text":"First I look."}]}}'
			   '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Bash"}]}}'
			   '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t2","name":"Bash"}]}}'
			   '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t1"}]}}'
			   '{"type":"assistant","message":{"content":[{"type":"text","text":"Then I fix."}]}}' ) do: [ :line |
					stream
						nextPutAll: line;
						lf ] ].
	^ file
]
