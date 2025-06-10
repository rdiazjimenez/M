(
    ParamTable as record,
    key1 as nullable text,
    optional key2 as nullable text,
    optional key3 as nullable text,
    optional key4 as nullable text
) as text =>
let
    keys = List.RemoveNulls({key1, key2, key3, key4}),
    values = List.Transform(keys, each Record.Field(ParamTable, _)),
    ruta = Text.Combine(values, "\")
in
    ruta
