unit generator;

interface

uses parser;

procedure Generate(regex: NodePtr; var str: AnsiString);

implementation

procedure GenerateAlt(alt: NodePtr; var str: AnsiString);
begin
	Generate(alt^.nodes[1 + random(alt^.count)], str)
end;

procedure GenerateConcat(concat: NodePtr; var str: AnsiString);
var
	i: integer;
begin
	for i := 1 to concat^.count do
		Generate(concat^.nodes[i], str)
end;

procedure GenerateQuant(quant: NodePtr; var str: AnsiString);
var
	i, count: word;
begin
	count := quant^.min + random(quant^.max - quant^.min + 1);
	for i := 1 to count do
		Generate(quant^.node, str)
end;

procedure Generate(regex: NodePtr; var str: AnsiString);
begin
	case regex^.kind of
		StrNode:
			str := str + regex^.str;
		AltNode:
			GenerateAlt(regex, str);
		ConcatNode:
			GenerateConcat(regex, str);
		QuantNode:
			GenerateQuant(regex, str)
	end
end;

end.
