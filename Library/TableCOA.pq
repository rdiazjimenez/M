let
    Source = Excel.CurrentWorkbook(){[Name="TableCOA"]}[Content],
    ChangeType = Table.TransformColumnTypes(Source,{{"ID", type text}, {"Title", type text}}),
    AddParent = fnAddParentColumn(ChangeType, "ID", "Parent"),
    AddParentChild = fnAddParentChild(AddParent,"ID","Parent", "Title"),
    ChangeTypeFinal = Table.TransformColumnTypes(AddParentChild,{{"ID", type text}, {"Parent", type text}, {"Path", type text}, {"Title", type text}, {"EndlessLoop", type text}, {"IsLeaf", type text}, {"Level Name 1", type text}, {"HierarchyDepth", Int64.Type}})
in
    ChangeTypeFinal
