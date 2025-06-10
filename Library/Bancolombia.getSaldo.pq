(conexionBancolombiaSaldo as table) as table =>
let
    // -----------------------------------------------
    // 1. Conexión a carpeta de archivos PDF Bancolombia
    // -----------------------------------------------
    Origen = conexionBancolombiaSaldo,

    // -----------------------------------------------
    // 2. Función inline para transformar cada PDF
    // -----------------------------------------------
    fnTransform = (contenido as binary) as table =>
    let
        SourcePDFTables      = Pdf.Tables(contenido, [Implementation = "1.3"]),

        // Extraer tabla principal (Table001)
        RawTable             = SourcePDFTables{[Id = "Table001"]}[Data],
        RawTableTransposed   = Table.Transpose(RawTable),
        RemoveDollarRows     = Table.SelectRows(RawTableTransposed, each [Column1] <> "$"),
        CleanTable           = Table.Transpose(RemoveDollarRows),

        // Separar columnas centrales y de borde
        SelectCenterCols     = Table.SelectColumns(CleanTable, {"Column3", "Column4"}),
        RenameCenterCols     = Table.RenameColumns(SelectCenterCols, {{"Column3", "Column1"}, {"Column4", "Column2"}}),

        SelectEdgeCols       = Table.SelectColumns(CleanTable, {"Column1", "Column2"}),

        // Unir ambas
        CombineResults       = Table.Combine({RenameCenterCols, SelectEdgeCols}),
        ChangeAmountType     = Table.TransformColumnTypes(CombineResults, {{"Column2", type number}}),

        // Promover encabezados
        TransposeForHeaders  = Table.Transpose(ChangeAmountType),
        ValuesWithHeaders    = Table.PromoteHeaders(TransposeForHeaders, [PromoteAllScalars = true]),

        // Extraer periodo desde Page001 y sumarle un día
        PageData             = SourcePDFTables{[Id = "Page001"]}[Data],
        TransposePageData    = Table.Transpose(PageData),
        FilterPeriodRow      = Table.SelectRows(TransposePageData, each Text.Contains([Column2], "DESDE")),
        KeepPeriodColumn     = Table.SelectColumns(FilterPeriodRow, {"Column2"}),
        ExtractPeriodText    = Table.TransformColumns(KeepPeriodColumn, {{"Column2", each Text.AfterDelimiter(_, ": "), type text}}),
        ChangePeriodType     = Table.TransformColumnTypes(ExtractPeriodText, {{"Column2", type date}}),
        PeriodPlusOneDay     = Table.TransformColumns(ChangePeriodType, {"Column2", each Date.AddDays(_, 1)}),

        // Agregar columna Periodo
        AddPeriodToValues    = Table.AddColumn(ValuesWithHeaders, "Periodo", each PeriodPlusOneDay{0}[Column2]),

        // Reordenar columnas
        ReorderColumns       = Table.ReorderColumns(
                                   AddPeriodToValues,
                                   {"Periodo", "SALDO PROMEDIO", "CUENTAS X COBRAR",
                                    "VALOR INTERESES PAGADOS", "RETEFUENTE", "SALDO ANTERIOR",
                                    "TOTAL ABONOS", "TOTAL CARGOS", "SALDO ACTUAL"}
                               ),
        ResultadoSeguro = try ReorderColumns otherwise null
    in
        ResultadoSeguro,

    // -----------------------------------------------
    // 3. Aplicar transformación a cada archivo
    // -----------------------------------------------
    AplicarTransformacion = Table.AddColumn(Origen, "DatosPDF", each fnTransform([Content])),
    RenombrarColFuente    = Table.RenameColumns(AplicarTransformacion, {{"Name", "NombreArchivo"}}),
    SeleccionaColumnas    = Table.SelectColumns(RenombrarColFuente, {"NombreArchivo", "DatosPDF"}),

    // Expandir columnas transformadas
    ExpandeDatos          = Table.ExpandTableColumn(
                               SeleccionaColumnas,
                               "DatosPDF",
                               {"Periodo", "SALDO PROMEDIO", "CUENTAS X COBRAR",
                                "VALOR INTERESES PAGADOS", "RETEFUENTE", "SALDO ANTERIOR",
                                "TOTAL ABONOS", "TOTAL CARGOS", "SALDO ACTUAL"}
                           ),

    // Tipificar columnas numéricas y fecha
    TipificaCampos        = Table.TransformColumnTypes(
                               ExpandeDatos,
                               {
                                   {"Periodo", type date},
                                   {"SALDO PROMEDIO", type number},
                                   {"CUENTAS X COBRAR", type number},
                                   {"VALOR INTERESES PAGADOS", type number},
                                   {"RETEFUENTE", type number},
                                   {"SALDO ANTERIOR", type number},
                                   {"TOTAL ABONOS", type number},
                                   {"TOTAL CARGOS", type number},
                                   {"SALDO ACTUAL", type number}
                               }
                           ),

    // Orden final
    OrdenaPorPeriodo      = Table.Sort(TipificaCampos, {{"Periodo", Order.Ascending}})
in
    OrdenaPorPeriodo
