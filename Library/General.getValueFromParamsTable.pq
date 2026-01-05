(
    ParamTable as record,
    key1 as nullable text
	) as text =>
let
    value = Text.From(Record.Field(ParamTable, key1))
in
    value
