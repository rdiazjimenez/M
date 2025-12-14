let
    Source = Excel.CurrentWorkbook(){[Name="TableReportAccount"]}[Content],
    ChangeType = Table.TransformColumnTypes(Source,{{"ID", type text}, {"ReportID", Int64.Type}, {"Title", type text}, {"IsTotal", type logical}}),
    AddParent = fnAddParentColumn(ChangeType, "ID", "Parent"),
    AddParentChild = fnAddParentChild(AddParent,"ID","Parent", "Title"),
    ChangeTypeFinal = Table.TransformColumnTypes(AddParentChild,{{"ID", type text}, {"Parent", type text}, {"Path", type text}, {"Title", type text}, {"HierarchyDepth", Int64.Type}, {"EndlessLoop", type logical}, {"IsLeaf", type logical}, {"IsTotal", type text}})
in
    ChangeTypeFinal
