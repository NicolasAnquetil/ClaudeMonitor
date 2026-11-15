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
CMTranscriptReaderTest >> testCustomTitleWins [

	| file |
	file := self titledTranscript.
	file writeStreamDo: [ :stream |
			stream
				setToEnd;
				nextPutAll: '{"type":"custom-title","customTitle":"My name"}';
				lf ].
	self assert: (CMTranscriptReader new titleIn: file) equals: 'My name'
]

{ #category : 'tests' }
CMTranscriptReaderTest >> testExplanationBeforeAToolUse [

	self assert: (CMTranscriptReader new explanationIn: self transcript beforeToolUse: 't1') equals: 'First I look.'
]

{ #category : 'tests' }
CMTranscriptReaderTest >> testMissingFile [

	self assert: (CMTranscriptReader new explanationIn: FileSystem memory / 'none.jsonl' beforeToolUse: 't1') isNil
]

{ #category : 'tests' }
CMTranscriptReaderTest >> testNoTitleYet [

	self assert: (CMTranscriptReader new titleIn: self transcript) isNil
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
CMTranscriptReaderTest >> testStartTimeIsTheFirstTimestamp [

	self
		assert: (CMTranscriptReader new startTimeIn: self titledTranscript)
		equals: (DateAndTime fromString: '2026-11-15T10:27:34.232Z')
]

{ #category : 'tests' }
CMTranscriptReaderTest >> testTitleIsTheLatestAiTitle [

	self assert: (CMTranscriptReader new titleIn: self titledTranscript) equals: 'Better title'
]

{ #category : 'tests' }
CMTranscriptReaderTest >> testUnknownToolUseTakesTheTextAtTheEnd [

	self assert: (CMTranscriptReader new explanationIn: self transcript beforeToolUse: 'not-yet') equals: 'Then I fix.'
]

{ #category : 'tests' }
CMTranscriptReaderTest >> titledTranscript [

	| file |
	file := FileSystem memory / 'titled.jsonl'.
	file writeStreamDo: [ :stream |
			#( '{"type":"mode","mode":"normal"}' '{"type":"user","timestamp":"2026-11-15T10:27:34.232Z","message":{"content":"hi"}}'
			   '{"type":"ai-title","aiTitle":"First title"}' '{"type":"user","timestamp":"2026-11-15T10:30:00.000Z","message":{"content":"more"}}'
			   '{"type":"ai-title","aiTitle":"Better title"}' ) do: [ :line |
					stream
						nextPutAll: line;
						lf ] ].
	^ file
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
