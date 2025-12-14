(SourceTable as table,
    ParentColumnTitle as text ) =>
let
    Source = TableCOA,
    AddParent = Table.AddColumn(SourceTable, ParentColumnTitle, each if Text.Length([Account]) = 1 then null else Text.Start([Account],Text.Length([Account]) - (if Text.Length([Account]) = 2 then 1 else 2)), type text)
in
    AddParent
