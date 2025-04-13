(unzipFunction as function, transfColsFunction as function, Source as table, mapTypeTable as table) as table =>
let
    // Your full existing query
    //Source = DianFEZip,
    AddUnzippedColumn = Table.AddColumn(Source, "UnzippedFiles", each unzipFunction([Content])),
    ExpandUnzippedList = Table.ExpandListColumn(AddUnzippedColumn, "UnzippedFiles"),
    ExtractZipMetadata = Table.ExpandRecordColumn(ExpandUnzippedList, "UnzippedFiles", {"FileName", "Content"}, {"FileName", "BinaryContent"}),
    LoadExcelWorkbooks = Table.AddColumn(ExtractZipMetadata, "ExcelTables", each Excel.Workbook([BinaryContent])),
    ExpandExcelTables = Table.ExpandTableColumn(LoadExcelWorkbooks, "ExcelTables", {"Name", "Data", "Item", "Kind", "Hidden"}, {"SheetName", "Data", "Item", "Kind", "Hidden"}),
    KeepOnlyData = Table.SelectColumns(ExpandExcelTables,{"Data"}),
    PromoteHeaders = Table.AddColumn(KeepOnlyData, "PromotedData", each Table.PromoteHeaders([Data], [PromoteAllScalars=true])),
    KeepPromotedTables = Table.SelectColumns(PromoteHeaders,{"PromotedData"}),
    ExpandInternalColumns = Table.ExpandTableColumn(
        KeepPromotedTables,
        "PromotedData",
        Table.ColumnNames(KeepPromotedTables{0}[PromotedData])
    ),
    TransfColsDynamicStep = transfColsFunction(ExpandInternalColumns, mapTypeTable)
in
    TransfColsDynamicStep