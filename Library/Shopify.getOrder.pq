(connShopify as table) as table =>
let
    // 1. Load files from Shopify connection
    Source = connShopify,

    // 2. Filter to only include files related to OrdersContabilidad
    FilterOrdersFiles = Table.SelectRows(Source, each Text.Contains([Name], "OrdersContabilidad")),

    // 3. Exclude hidden files
    ExcludeHiddenFiles = Table.SelectRows(FilterOrdersFiles, each [Attributes]?[Hidden]? <> true),

    // 4. Transform each file (in-line logic of fnTransformShopifyOrder)
    TransformFiles = Table.AddColumn(
        ExcludeHiddenFiles,
        "TransformedData",
        each
            let
                // Read the Excel file from Content
                ExcelData = Excel.Workbook([Content], null, true),
                Orders1 = ExcelData{[Name="Orders"]}[Data],
                PromotedHeaders = Table.PromoteHeaders(Orders1, [PromoteAllScalars=true]),
                InsertedFacturaVenta = Table.AddColumn(
                    PromotedHeaders, 
                    "Factura venta",
                    each 
                        let
                            tag = [Tags],
                            posFV = Text.PositionOf(tag, "FV"),
                            extrae = 
                                if posFV >= 0 then
                                    let
                                        startPos = posFV,
                                        espacios = List.Select(Text.PositionOfAny(tag, {" "}, startPos + 2), each _ > startPos),
                                        endPos = if List.Count(espacios) > 0 then List.First(espacios) else Text.Length(tag),
                                        len = endPos - startPos,
                                        fv = Text.Middle(tag, startPos, len),
                                        // Si termina en coma, la quitamos
                                        resultado = if Text.EndsWith(fv, ",") then Text.BeforeDelimiter(fv, ",") else fv
                                    in
                                        resultado
                                else if tag = "no_facturar" then
                                    "no_facturar"
                                else
                                    null
                        in
                            extrae,
                    type text
                ),
                ChangedTypeWithLocale = Table.TransformColumnTypes(InsertedFacturaVenta, {{"Created At", type datetimezone}}, "en-US"),
                ChangedType1 = Table.TransformColumnTypes(ChangedTypeWithLocale, {{"Price: Current Total", type number}, {"Tax 1: Rate", type number}}),
                RemovedOtherColumns = Table.SelectColumns(
                    ChangedType1,
                    {"Name", "Created At", "Price: Current Subtotal", "Tax 1: Price", "Price: Total Discount", "Price: Total Shipping", "Price: Current Total", "Payment: Status", "Top Row", "Line: Type", "Line: Tax 1 Price", "Line: Fulfillment Status", "Transaction: Processed At", "Transaction: Currency", "Transaction: Shop Currency Amount", "Transaction: Status", "Transaction: Gateway", "Metafield: custom.fecha_de_pago [date]", "Metafield: custom.metodo_de_pago [single_line_text_field]", "Factura venta", "Tags"}
                ),
                RenamedMetodo = Table.RenameColumns(RemovedOtherColumns, {{"Metafield: custom.metodo_de_pago [single_line_text_field]", "Metodo"}}),
                ChangedType2 = Table.TransformColumnTypes(
                    RenamedMetodo,
                    {
                        {"Price: Current Total", type number},
                        {"Created At", type date},
                        {"Price: Current Subtotal", type number},
                        {"Price: Total Discount", type number},
                        {"Price: Total Shipping", type number}
                    }
                ),
                RenamedFechaPago = Table.RenameColumns(ChangedType2, {{"Metafield: custom.fecha_de_pago [date]", "Fecha pago"}})
            in
                RenamedFechaPago
    ),

    // 5. Rename file column
    RenameFileColumn = Table.RenameColumns(TransformFiles, {"Name", "Source.Name"}),

    // 6. Keep only relevant columns
    KeepRelevantColumns = Table.SelectColumns(RenameFileColumn, {"Source.Name", "TransformedData"}),

    // 7. Expand transformed table content
    ExpandTransformedTable = Table.ExpandTableColumn(
        KeepRelevantColumns,
        "TransformedData",
        {
            "Name", "Created At", "Price: Current Subtotal", "Tax 1: Price", "Price: Total Discount", "Price: Total Shipping", "Price: Current Total", "Payment: Status", "Top Row", "Line: Type", "Line: Tax 1 Price", "Line: Fulfillment Status", "Transaction: Processed At", "Transaction: Currency", "Transaction: Shop Currency Amount", "Transaction: Status", "Transaction: Gateway", "Fecha pago", "Metodo", "Factura venta", "Tags"
        }
    ),

    // 8. Set initial column types
    SetInitialColumnTypes = Table.TransformColumnTypes(
        ExpandTransformedTable,
        {
            {"Source.Name", type text},
            {"Name", type text},
            {"Created At", type date},
            {"Price: Current Total", type number},
            {"Payment: Status", type text},
            {"Factura venta", type text},
            {"Fecha pago", type date},
            {"Price: Current Subtotal", type number},
            {"Price: Total Discount", type number},
            {"Price: Total Shipping", type number},
            {"Tax 1: Price", type number},
            {"Line: Type", type text},
            {"Line: Tax 1 Price", type number},
            {"Line: Fulfillment Status", type text},
            {"Transaction: Currency", type text},
            {"Transaction: Gateway", type text},
            {"Metodo", type text},
            {"Transaction: Status", type text},
            {"Transaction: Shop Currency Amount", type number},
            {"Transaction: Processed At", type datetimezone},
            {"Tags", type text}
        }
    ),

    // 9. Change ProcessAt type
    NormalizeProcessAt = Table.TransformColumnTypes(SetInitialColumnTypes, {{"Transaction: Processed At", type date}}),

    // 10. Sort rows by order name
    SortByName = Table.Sort(NormalizeProcessAt, {{"Name", Order.Ascending}}),

    // 11. Reorder columns for final output
    ReorderFinalColumns = Table.ReorderColumns(
        SortByName,
        {"Source.Name", "Name", "Created At", "Price: Current Total", "Payment: Status", "Fecha pago", "Factura venta", "Metodo"}
    )
in
    ReorderFinalColumns
