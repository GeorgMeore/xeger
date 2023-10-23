program xeger;

uses parser, generator;

var
	regex: NodePtr = nil;
	str: AnsiString = '';
	count: integer = 1;
begin
	if ParamCount <> 1 then
	begin
		writeln('usage: ', ParamStr(0), ' REGEX');
		halt(1)
	end;
	Parse(ParamStr(1), regex);
	if IsErrorNode(regex) then
	begin
		writeln('error: failed to parse the regex: ', regex^.message);
		halt(1)
	end;
	randomize;
	while count > 0 do
	begin
		Generate(regex, str);
		writeln(str);
		str := '';
		count := count - 1
	end
end.
