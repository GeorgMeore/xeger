unit parser;

interface

const
	{ since we are parsing strings, we can't have more than 255 of anything }
	MaxNodes = 255;
	WordMax = 1 shl 16 - 1;

type
	NodeType = (ErrorNode, AltNode, ConcatNode, StrNode, QuantNode);
	NodePtr = ^Node;
	Node = record
		case kind: NodeType of
			ErrorNode: (
				message: string
			);
			AltNode, ConcatNode: (
				count: integer;
				nodes: array [1..MaxNodes] of NodePtr;
			);
			StrNode: (
				str: string;
			);
			QuantNode: (
				node: NodePtr;
				min, max: word;
			)
	end;

{ since a regex ast is expected to exist throughout all of the program execution,
  we don't need to bother with memory disposing }

procedure Parse(regex: string; var result: NodePtr);
function IsErrorNode(node: NodePtr): boolean;

implementation

type
	CharIterator = record
		s: string;
		i: integer;
	end;

procedure InitCharIterator(var iter: CharIterator; var s: string);
begin
	iter.s := s;
	iter.i := 1
end;

function CharIteratorPeek(var iter: CharIterator): char;
begin
	if iter.i <= length(iter.s) then
		CharIteratorPeek := iter.s[iter.i]
	else
		CharIteratorPeek := #0
end;

procedure CharIteratorNext(var iter: CharIterator);
begin
	iter.i := iter.i + 1
end;

procedure NewErrorNode(var node: NodePtr; wanted: string; got: char);
begin
	new(node);
	node^.kind := ErrorNode;
	if got = #0 then
		node^.message := 'wanted ''' + wanted + ''', got ''EOL'''
	else
		node^.message := 'wanted ''' + wanted + ''', got ''' + got + ''''
end;

procedure NewArrayNode(var node: NodePtr; kind: NodeType);
begin
	new(node);
	node^.kind := kind;
	node^.count := 0
end;

procedure NewStrNode(var node: NodePtr; str: string);
begin
	new(node);
	node^.kind := StrNode;
	node^.str := str
end;

procedure NewQuantNode(var node: NodePtr; min, max: word);
begin
	new(node);
	node^.kind := QuantNode;
	node^.min := min;
	node^.max := max
end;

procedure ArrayNodeAdd(var anode, node: NodePtr);
begin
	anode^.count := anode^.count + 1;
	anode^.nodes[anode^.count] := node
end;

function IsNumeric(c: char): boolean;
begin
	IsNumeric := (c >= '0') and (c <= '9')
end;

function IsAlpha(c: char): boolean;
begin
	IsAlpha :=
		(c >= 'a') and (c <= 'z') or
		(c >= 'A') and (c <= 'Z')
end;

function IsAlnum(c: char): boolean;
begin
	IsAlnum := IsAlpha(c) or IsNumeric(c)
end;

procedure ParseAlternative(var iter: CharIterator; var result: NodePtr); forward;

{ GROUP ::= '(' ALTERNATIVE ')' }
procedure ParseGroup(var iter: CharIterator; var result: NodePtr);
begin
	CharIteratorNext(iter);
	ParseAlternative(iter, result);
	if IsErrorNode(result) then
		exit;
	if CharIteratorPeek(iter) <> ')' then
	begin
		NewErrorNode(result, ')', CharIteratorPeek(iter));
		exit
	end;
	CharIteratorNext(iter)
end;

{ STRING ::= ALNUM+ }
procedure ParseStr(var iter: CharIterator; var result: NodePtr);
var
	str: string = '';
begin
	while IsAlnum(CharIteratorPeek(iter)) do
	begin
		str := str + CharIteratorPeek(iter);
		CharIteratorNext(iter)
	end;
	NewStrNode(result, str)
end;

{ ESCAPED ::= '\' ANY }
procedure ParseEscaped(var iter: CharIterator; var result: NodePtr);
begin
	CharIteratorNext(iter);
	if CharIteratorPeek(iter) = #0 then
	begin
		NewErrorNode(result, 'any character', #0);
		exit
	end;
	NewStrNode(result, CharIteratorPeek(iter));
	CharIteratorNext(iter)
end;

{ SIMPLE ::= GROUP | STRING | ESCAPED }
procedure ParseSimple(var iter: CharIterator; var result: NodePtr);
var
	next: char;
begin
	next := CharIteratorPeek(iter);
	if next = '(' then
		ParseGroup(iter, result)
	else if next = '\' then
		ParseEscaped(iter, result)
	else if IsAlnum(next) then
		ParseStr(iter, result)
	else
		NewErrorNode(result, 'digit or letter or ( or \', CharIteratorPeek(iter))
end;

function IsQuantChar(c: char): boolean;
begin
	IsQuantChar := (c = '?') or (c = '*') or (c = '+') or (c = '{')
end;

{ NUMBER ::= DIGIT+ }
procedure ParseNumber(var iter: CharIterator; var result: word);
var
	digit: word;
begin
	if not IsNumeric(CharIteratorPeek(iter)) then
		exit;
	result := 0;
	while IsNumeric(CharIteratorPeek(iter)) do
	begin
		digit := ord(CharIteratorPeek(iter)) - ord('0');
		CharIteratorNext(iter);
		result := result*10 + digit
	end
end;

{ RANGE ::= '{' [NUMBER] ',' [NUMBER] '}' }
procedure ParseRange(var iter: CharIterator; var result: NodePtr);
var
	min: word = 0;
	max: word = WordMax;
begin
	CharIteratorNext(iter);
	ParseNumber(iter, min);
	if CharIteratorPeek(iter) <> ',' then
	begin
		NewErrorNode(result, ',', CharIteratorPeek(iter));
		exit
	end;
	CharIteratorNext(iter);
	ParseNumber(iter, max);
	if CharIteratorPeek(iter) <> '}' then
	begin
		NewErrorNode(result, '}', CharIteratorPeek(iter));
		exit
	end;
	NewQuantNode(result, min, max)
end;

{ QUANTIFIER ::= '?' | '*' | '+' | RANGE }
procedure ParseQuant(var iter: CharIterator; var result: NodePtr);
var
	next: char;
begin
	next := CharIteratorPeek(iter);
	case next of
		'?':
			NewQuantNode(result, 0, 1);
		'*':
			NewQuantNode(result, 0, WordMax);
		'+':
			NewQuantNode(result, 1, WordMax);
		'{':
			ParseRange(iter, result)
	end;
	CharIteratorNext(iter)
end;

{ TERM ::= SIMPLE [QUANTIFIER] }
procedure ParseTerm(var iter: CharIterator; var result: NodePtr);
var
	tmp: NodePtr;
begin
	ParseSimple(iter, result);
	if IsErrorNode(result) then
		exit;
	if not IsQuantChar(CharIteratorPeek(iter)) then
		exit;
	tmp := result;
	ParseQuant(iter, result);
	if IsErrorNode(result) then
		exit;
	result^.node := tmp
end;

function IsTermChar(c: char): boolean;
begin
	IsTermChar := IsAlnum(c) or (c = '(') or (c = '\')
end;

{ CONCATENATION ::= TERM {TERM} }
procedure ParseConcatenation(var iter: CharIterator; var result: NodePtr);
var
	tmp: NodePtr;
begin
	ParseTerm(iter, result);
	if IsErrorNode(result) then
		exit;
	if not IsTermChar(CharIteratorPeek(iter)) then
		exit;
	tmp := result;
	NewArrayNode(result, ConcatNode);
	ArrayNodeAdd(result, tmp);
	while IsTermChar(CharIteratorPeek(iter)) do
	begin
		ParseTerm(iter, tmp);
		if IsErrorNode(tmp) then
		begin
			result := tmp;
			exit
		end;
		ArrayNodeAdd(result, tmp)
	end
end;

{ ALTERNATIVE ::= CONCATENATION {'|' CONCATENATION} }
procedure ParseAlternative(var iter: CharIterator; var result: NodePtr);
var
	tmp: NodePtr;
begin
	ParseConcatenation(iter, result);
	if IsErrorNode(result) then
		exit;
	if CharIteratorPeek(iter) <> '|' then
		exit;
	tmp := result;
	NewArrayNode(result, AltNode);
	ArrayNodeAdd(result, tmp);
	while CharIteratorPeek(iter) = '|' do
	begin
		CharIteratorNext(iter);
		ParseConcatenation(iter, tmp);
		if IsErrorNode(tmp) then
		begin
			result := tmp;
			exit
		end;
		ArrayNodeAdd(result, tmp)
	end
end;

function IsErrorNode(node: NodePtr): boolean;
begin
	IsErrorNode := node^.kind = ErrorNode
end;

{ REGEX ::= ALTERNATIVE #0 }
procedure Parse(regex: string; var result: NodePtr);
var
	iter: CharIterator;
begin
	InitCharIterator(iter, regex);
	ParseAlternative(iter, result);
	if IsErrorNode(result) then
		exit;
	if CharIteratorPeek(iter) = #0 then
		exit;
	NewErrorNode(result, 'EOL', CharIteratorPeek(iter))
end;

end.
