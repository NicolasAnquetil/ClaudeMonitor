"
I check how CMMarkdownComposer lays out Markdown as Bloc text.
"
Class {
	#name : 'CMMarkdownComposerTest',
	#superclass : 'TestCase',
	#category : 'ClaudeMonitor-Tests',
	#package : 'ClaudeMonitor-Tests'
}

{ #category : 'tests' }
CMMarkdownComposerTest >> lines: aString columns: anInteger [

	^ (CMMarkdownComposer textFor: aString columns: anInteger) asString lines
]

{ #category : 'tests' }
CMMarkdownComposerTest >> testBlocksAreSeparatedByAnEmptyLine [

	self
		assert: (self
				 lines: '# Title
Text

```
x := 1
```'
				 columns: nil)
		equals: #( 'Title' '' 'Text' '' 'x := 1' )
]

{ #category : 'tests' }
CMMarkdownComposerTest >> testBoldIsBold [

	| text |
	text := CMMarkdownComposer textFor: 'a **b** c'.
	self assert: text asString equals: 'a b c'.
	self assert: ((text attributesAt: 3) anySatisfy: [ :each | each isKindOf: BlFontWeightAttribute ]).
	self deny: ((text attributesAt: 1) anySatisfy: [ :each | each isKindOf: BlFontWeightAttribute ])
]

{ #category : 'tests' }
CMMarkdownComposerTest >> testFallsBackToPlainTextOnError [

	| text |
	text := CMMarkdownComposer textFor: 'x'.
	self assert: text asString equals: 'x'.
	text := CMMarkdownComposer textFor: 'a

'.
	self assert: text asString equals: 'a'
]

{ #category : 'tests' }
CMMarkdownComposerTest >> testInlineCodeIsMonospace [

	| text |
	text := CMMarkdownComposer textFor: 'a `b`'.
	self assert: text asString equals: 'a b'.
	self assert: ((text attributesAt: 3) anySatisfy: [ :each | each isKindOf: BlFontFamilyAttribute ])
]

{ #category : 'tests' }
CMMarkdownComposerTest >> testLists [

	self
		assert: (self lines: 'Intro

1. one
   - nested
2. two' columns: nil)
		equals: #( 'Intro' '' '1. one' '– nested' '2. two' )
]

{ #category : 'tests' }
CMMarkdownComposerTest >> testStrikeInGitHubSyntax [

	self assert: (CMMarkdownComposer textFor: 'a ~~b~~') asString equals: 'a b'
]

{ #category : 'tests' }
CMMarkdownComposerTest >> testTableColumnsAreAligned [

	self
		assert: (self
				 lines: '| a | bb |
|---|---|
| ccc | d |'
				 columns: nil)
		equals: #( 'a   | bb' '----+---' 'ccc | d ' )
]

{ #category : 'tests' }
CMMarkdownComposerTest >> testWideTableWrapsItsCells [

	| lines |
	lines := self
		         lines: '| a | b |
|---|---|
| x | one two three four five six |'
		         columns: 20.
	self assert: (lines allSatisfy: [ :each | each size <= 20 ]).
	self assert: lines size > 3.
	self assert: (lines at: 3) trimRight equals: 'x | one two three'
]
