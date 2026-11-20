"
I turn a Markdown string, parsed by Microdown, into the Bloc text of the details pane, in the sizes and colors of CMStyle.

	(CMMarkdownComposer textFor: '# Title
Some **bold** and `code`.') inspect.

I render headings, bold, italic, strike, inline code, links (clickable), bullet and numbered lists (nested), quotes, code blocks, tables (as aligned monospace text) and horizontal lines.
If Microdown fails on the string, I give the string back as plain text.

While visiting, my slots hold the style of the text being emitted; preserve: restores them after a nested element.
"
Class {
	#name : 'CMMarkdownComposer',
	#superclass : 'MicrodownVisitor',
	#instVars : [
		'text',
		'fontSize',
		'color',
		'bold',
		'italic',
		'strike',
		'monospace',
		'background',
		'url',
		'margin',
		'listDepth',
		'maxColumns'
	],
	#category : 'ClaudeMonitor-UI',
	#package : 'ClaudeMonitor',
	#tag : 'UI'
}

{ #category : 'instance creation' }
CMMarkdownComposer class >> openLink: aUrlString [

	[ WebBrowser openOn: aUrlString ]
		on: Error
		do: [ :e | self inform: 'Cannot open ' , aUrlString ]
]

{ #category : 'instance creation' }
CMMarkdownComposer class >> preprocess: aString [
	"GitHub writes strike as ~~x~~, Microdown as ~x~"

	^ aString asString copyReplaceAll: '~~' with: '~'
]

{ #category : 'instance creation' }
CMMarkdownComposer class >> textFor: aString [
	"The Bloc text of aString read as Markdown, or aString as plain text if Microdown fails on it"

	^ self textFor: aString columns: nil
]

{ #category : 'instance creation' }
CMMarkdownComposer class >> textFor: aString columns: anInteger [
	"The same, tables fitting in anInteger monospace characters"

	^ [
		  self new
			  maxColumns: anInteger;
			  compose: aString ]
		  on: Error
		  do: [ CMStyle text: aString asString ]
]

{ #category : 'composing' }
CMMarkdownComposer >> beBold [

	bold := true
]

{ #category : 'composing' }
CMMarkdownComposer >> beMonospace [

	monospace := true
]

{ #category : 'tables' }
CMMarkdownComposer >> cellTextOf: aCell [
	"A cell is a collection of inline nodes: their text, in monospace so that columns align"

	| composer |
	composer := self class new.
	composer beMonospace.
	aCell do: [ :node | composer visit: node ].
	^ composer text
]

{ #category : 'composing' }
CMMarkdownComposer >> compose: aString [

	self visit: (Microdown parse: (self class preprocess: aString)).
	self trimTrailingNewLines.
	^ text
]

{ #category : 'composing' }
CMMarkdownComposer >> emit: aString [
	"Append aString in the current style"

	| piece link |
	aString isEmpty ifTrue: [ ^ self ].
	piece := CMStyle text: (aString copyReplaceAll: String tab with: '    ') size: fontSize color: color.
	bold ifTrue: [ piece bold ].
	italic ifTrue: [ piece italic ].
	monospace ifTrue: [ CMStyle monospace: piece ].
	strike ifTrue: [ piece lineThroughDo: [ :decoration |  ] ].
	background ifNotNil: [ piece background: background ].
	url ifNotNil: [
			link := url.
			piece underlineColor: CMStyle linkColor.
			piece onClick: [ :aPiece :aWorld :anEditor :anEvent | self class openLink: link ] ].
	margin > 0 ifTrue: [ piece paragraphMargin: (BlInsets left: margin) ].
	text append: piece
]

{ #category : 'tables' }
CMMarkdownComposer >> emitRow: cells widths: widths bold: isHeader [
	"One line of text per line of the highest cell"

	| lines height |
	lines := widths withIndexCollect: [ :width :column |
			         column <= cells size
				         ifTrue: [ self lineIntervalsOf: (cells at: column) asString width: width ]
				         ifFalse: [ { (1 to: 0) } ] ].
	height := (lines collect: [ :each | each size ]) max.
	1 to: height do: [ :lineIndex |
			lineIndex > 1 ifTrue: [ self emit: String cr ].
			widths withIndexDo: [ :width :column |
					| piece interval |
					column > 1 ifTrue: [ self emitTableSeparator: ' | ' ].
					interval := lineIndex <= (lines at: column) size
						            ifTrue: [ (lines at: column) at: lineIndex ]
						            ifFalse: [ 1 to: 0 ].
					piece := interval isEmpty
						         ifTrue: [ '' asRopedText ]
						         ifFalse: [ (cells at: column) copyFrom: interval first to: interval last ].
					isHeader ifTrue: [ piece bold ].
					margin > 0 ifTrue: [ piece paragraphMargin: (BlInsets left: margin) ].
					text append: piece.
					self preserve: [
							monospace := true.
							self emit: (String new: width - piece size withAll: $ ) ] ] ]
]

{ #category : 'tables' }
CMMarkdownComposer >> emitTableRule: widths [

	self emitTableSeparator: ('-+-' join: (widths collect: [ :width | String new: width withAll: $- ]))
]

{ #category : 'tables' }
CMMarkdownComposer >> emitTableSeparator: aString [

	self preserve: [
			monospace := true.
			bold := false.
			italic := false.
			background := nil.
			color := Color lightGray.
			self emit: aString ]
]

{ #category : 'composing' }
CMMarkdownComposer >> endsWithNewLine [

	^ text isEmpty or: [ (text at: text size) = Character cr ]
]

{ #category : 'composing' }
CMMarkdownComposer >> ensureBlankLine [
	"Blocks are separated by an empty line, except at the start"

	text isEmpty ifTrue: [ ^ self ].
	self ensureNewLine.
	(text size >= 2 and: [ (text at: text size - 1) = Character cr ]) ifFalse: [ self emit: String cr ]
]

{ #category : 'composing' }
CMMarkdownComposer >> ensureNewLine [

	self endsWithNewLine ifFalse: [ self emit: String cr ]
]

{ #category : 'tables' }
CMMarkdownComposer >> fit: widths [
	"Narrow the widest columns until the table fits in maxColumns, the separators included"

	| result available |
	result := widths copy.
	maxColumns ifNil: [ ^ result ].
	available := maxColumns - (3 * (widths size - 1)) - (margin / CMStyle charWidth) ceiling.
	[ (result inject: 0 into: [ :sum :each | sum + each ]) > available and: [ result max > 6 ] ] whileTrue: [
			| widest |
			widest := result indexOf: result max.
			result at: widest put: (result at: widest) - 1 ].
	^ result
]

{ #category : 'composing' }
CMMarkdownComposer >> indentWidth [

	^ (CMStyle charWidth * 3) rounded
]

{ #category : 'initialization' }
CMMarkdownComposer >> initialize [

	super initialize.
	text := '' asRopedText.
	fontSize := CMStyle fontSize.
	color := Color black.
	bold := false.
	italic := false.
	strike := false.
	monospace := false.
	margin := 0.
	listDepth := 0
]

{ #category : 'tables' }
CMMarkdownComposer >> lineIntervalsOf: aString width: width [
	"Where to cut aString in lines of at most width characters: at spaces, or inside a word longer than a line"

	| intervals start |
	intervals := OrderedCollection new.
	start := 1.
	[ aString size - start + 1 > width ] whileTrue: [
			| stop space |
			space := (start to: start + width) reverse detect: [ :i | (aString at: i) = Character space ] ifNone: [ nil ].
			stop := (space isNotNil and: [ space > start ])
				        ifTrue: [ space - 1 ]
				        ifFalse: [ start + width - 1 ].
			intervals add: (start to: stop).
			start := stop + 1.
			[ start <= aString size and: [ (aString at: start) = Character space ] ] whileTrue: [ start := start + 1 ] ].
	intervals add: (start to: aString size).
	^ intervals
]

{ #category : 'tables' }
CMMarkdownComposer >> maxColumns: anInteger [
	"The width of the pane, in monospace characters: tables wrap their cells to fit in it"

	maxColumns := anInteger
]

{ #category : 'composing' }
CMMarkdownComposer >> preserve: aBlock [
	"aBlock changes the style for a nested element; restore it afterwards"

	| saved |
	saved := {
		         fontSize.
		         color.
		         bold.
		         italic.
		         strike.
		         monospace.
		         background.
		         url.
		         margin }.
	aBlock ensure: [
			fontSize := saved at: 1.
			color := saved at: 2.
			bold := saved at: 3.
			italic := saved at: 4.
			strike := saved at: 5.
			monospace := saved at: 6.
			background := saved at: 7.
			url := saved at: 8.
			margin := saved at: 9 ]
]

{ #category : 'composing' }
CMMarkdownComposer >> text [

	^ text
]

{ #category : 'composing' }
CMMarkdownComposer >> trimTrailingNewLines [

	[ text isNotEmpty and: [ (text at: text size) = Character cr ] ] whileTrue: [ text delete: text size to: text size ]
]

{ #category : 'visiting' }
CMMarkdownComposer >> visitAnchor: anAnchor [
	"@name at the start of a line: not an anchor in what Claude writes, keep it as text"

	self ensureBlankLine.
	self emit: '@' , anAnchor label
]

{ #category : 'visiting' }
CMMarkdownComposer >> visitBold: aBold [

	self preserve: [
			bold := true.
			super visitBold: aBold ]
]

{ #category : 'visiting' }
CMMarkdownComposer >> visitBreak: aBreak [

	self emit: String cr
]

{ #category : 'visiting' }
CMMarkdownComposer >> visitCode: aCode [

	self ensureBlankLine.
	self preserve: [
			monospace := true.
			color := CMStyle codeColor.
			background := CMStyle codeBackground.
			margin := margin + self indentWidth.
			self emit: aCode body ]
]

{ #category : 'visiting' }
CMMarkdownComposer >> visitComment: aComment [
	"A line starting with %: keep it as text"

	self ensureBlankLine.
	self emit: '%' , aComment bodyString
]

{ #category : 'visiting' }
CMMarkdownComposer >> visitHeader: aHeader [

	self ensureBlankLine.
	self preserve: [
			bold := true.
			color := CMStyle headingColor.
			fontSize := fontSize + (#( 8 5 2 ) at: aHeader level ifAbsent: [ 0 ]).
			super visitHeader: aHeader ]
]

{ #category : 'visiting' }
CMMarkdownComposer >> visitHorizontalLine: aLine [

	self ensureBlankLine.
	self preserve: [
			monospace := true.
			color := Color lightGray.
			self emit: (String new: (maxColumns ifNil: [ 40 ]) withAll: $-) ]
]

{ #category : 'visiting' }
CMMarkdownComposer >> visitInlineSpace: aSpace [
	"<br>"

	self emit: String cr
]

{ #category : 'visiting' }
CMMarkdownComposer >> visitItalic: anItalic [

	self preserve: [
			italic := true.
			super visitItalic: anItalic ]
]

{ #category : 'visiting' }
CMMarkdownComposer >> visitLink: aLink [

	self preserve: [
			url := aLink url.
			color := CMStyle linkColor.
			super visitLink: aLink ]
]

{ #category : 'visiting' }
CMMarkdownComposer >> visitList: aList bullets: aBlock [
	"aBlock gives the bullet of the item at an index"

	listDepth = 0
		ifTrue: [ self ensureBlankLine ]
		ifFalse: [ self ensureNewLine ].
	listDepth := listDepth + 1.
	[
		aList children withIndexDo: [ :item :index |
				self preserve: [
						margin := margin + self indentWidth.
						self ensureNewLine.
						self preserve: [
								bold := false.
								italic := false.
								color := Color gray.
								self emit: (aBlock value: index) , ' ' ].
						self visitChildrenOf: item ] ] ] ensure: [ listDepth := listDepth - 1 ].
	self ensureNewLine
]

{ #category : 'visiting' }
CMMarkdownComposer >> visitMath: aMath [

	self ensureBlankLine.
	self preserve: [
			monospace := true.
			italic := true.
			margin := margin + self indentWidth.
			self emit: aMath body ]
]

{ #category : 'visiting' }
CMMarkdownComposer >> visitMathInline: aMath [

	self preserve: [
			monospace := true.
			italic := true.
			self emit: aMath bodyString ]
]

{ #category : 'visiting' }
CMMarkdownComposer >> visitMonospace: aMonospace [

	self preserve: [
			monospace := true.
			color := CMStyle codeColor.
			background := CMStyle codeBackground.
			super visitMonospace: aMonospace ]
]

{ #category : 'visiting' }
CMMarkdownComposer >> visitOrderedList: aList [

	self visitList: aList bullets: [ :index | (aList startIndex + index - 1) printString , '.' ]
]

{ #category : 'visiting' }
CMMarkdownComposer >> visitParagraph: aParagraph [

	self ensureBlankLine.
	super visitParagraph: aParagraph
]

{ #category : 'visiting' }
CMMarkdownComposer >> visitQuote: aQuote [

	self ensureBlankLine.
	self preserve: [
			color := Color gray.
			italic := true.
			margin := margin + self indentWidth.
			super visitQuote: aQuote ]
]

{ #category : 'visiting' }
CMMarkdownComposer >> visitRaw: aRaw [

	self emit: aRaw bodyString
]

{ #category : 'visiting' }
CMMarkdownComposer >> visitStrike: aStrike [

	self preserve: [
			strike := true.
			super visitStrike: aStrike ]
]

{ #category : 'tables' }
CMMarkdownComposer >> visitTable: aTable [
	"Aligned monospace columns, the header in bold and underlined by a rule.
	Cells too wide for the pane wrap inside their column"

	| rows widths |
	self ensureBlankLine.
	rows := aTable rows collect: [ :row | row collect: [ :cell | self cellTextOf: cell ] ].
	rows isEmpty ifTrue: [ ^ self ].
	widths := (1 to: (rows inject: 0 into: [ :max :row | max max: row size ])) collect: [ :column |
			          rows inject: 1 into: [ :max :row |
					          max max: (column <= row size
							           ifTrue: [ (row at: column) size ]
							           ifFalse: [ 0 ]) ] ].
	widths := self fit: widths.
	rows withIndexDo: [ :row :index |
			self ensureNewLine.
			self emitRow: row widths: widths bold: (index = 1 and: [ aTable hasHeader ]).
			(index = 1 and: [ aTable hasHeader ]) ifTrue: [
					self ensureNewLine.
					self emitTableRule: widths ] ]
]

{ #category : 'visiting' }
CMMarkdownComposer >> visitText: aText [

	self emit: aText bodyString
]

{ #category : 'visiting' }
CMMarkdownComposer >> visitUnorderedList: aList [

	self visitList: aList bullets: [ :index | #( '•' '–' '·' ) at: listDepth - 1 \\ 3 + 1 ]
]
