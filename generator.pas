unit generator;

interface

uses parser;

procedure GenerateLine(regex: NodePtr);

implementation

procedure GenerateChars(regex: NodePtr);
var
	i: word;
begin
	case regex^.kind of
		CharNode:
			write(regex^.ch);
		AltNode:
			GenerateChars(regex^.nodes[1 + random(regex^.count)]);
		ConcatNode:
			for i := 1 to regex^.count do
				GenerateChars(regex^.nodes[i]);
		QuantNode:
			for i := 1 to regex^.min + random(regex^.max - regex^.min + 1) do
				GenerateChars(regex^.node)
	end
end;

procedure GenerateLine(regex: NodePtr);
begin
	GenerateChars(regex);
	writeln()
end;

end.
