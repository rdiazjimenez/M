(connPUC as table) =>
let
    Source = connPUC,
    ContentData = Source{0}[Content],
    ImportData = Excel.Workbook(ContentData, [UseHeaders = true, InferSheetDimensions = true]),
    SheetData = ImportData{0}[Data],
    RemoveTopRows = Table.Skip(SheetData,5),
    RemoveBottomRows = Table.RemoveLastN(RemoveTopRows,2),
    PromoteHeaders = Table.PromoteHeaders(RemoveBottomRows, [PromoteAllScalars=true])
in
    PromoteHeaders
