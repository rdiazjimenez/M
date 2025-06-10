(connexionBancolombiaMvto as table) as table =>
let
    // Conexión a la carpeta
    Source = connexionBancolombiaMvto,

    // Función interna para transformar cada archivo CSV
    fnTransform = (content as binary) as table =>
    let
        OrigenCSV = Csv.Document(content, [Delimiter = ",", Columns = 10, Encoding = 1252, QuoteStyle = QuoteStyle.None]),
        RenombrarColumnas = Table.RenameColumns(OrigenCSV, {
            {"Column1", "Cuenta"}, 
            {"Column4", "Fecha"}, 
            {"Column6", "Valor"}, 
            {"Column8", "Descripción"}
        }),
        LimpiarTexto = Table.TransformColumns(RenombrarColumnas, {
            {"Cuenta", Text.Trim, type text}, 
            {"Column2", Text.Trim, type text}, 
            {"Column3", Text.Trim, type text}, 
            {"Fecha", Text.Trim, type text}, 
            {"Column5", Text.Trim, type text}, 
            {"Valor", Text.Trim, type text}, 
            {"Column7", Text.Trim, type text}, 
            {"Descripción", Text.Trim, type text}
        }),
        SeleccionarColumnas = Table.SelectColumns(LimpiarTexto, {"Cuenta", "Fecha", "Valor", "Descripción"}),

        // Detectar formato de fecha
        DetectarFormatoFecha = try Table.TransformColumns(SeleccionarColumnas, {{"Fecha", each Text.Middle(_, 4, 1), type text}}){0}[Fecha] otherwise "2",

        // Separar fecha según formato detectado
        FechaFormateada = if DetectarFormatoFecha = "2" then
            Table.SplitColumn(SeleccionarColumnas, "Fecha", Splitter.SplitTextByPositions({0, 2, 4}), {"Dia", "Mes", "Año"})
        else
            Table.SplitColumn(SeleccionarColumnas, "Fecha", Splitter.SplitTextByPositions({0, 4, 6}), {"Año", "Mes", "Dia"}),

        // Combinar fecha en formato estándar
        CombinarFecha = Table.CombineColumns(FechaFormateada, {"Año", "Mes", "Dia"}, Combiner.CombineTextByDelimiter("-", QuoteStyle.None), "Fecha"),

        // Tipos correctos
        CambiarTipos = Table.TransformColumnTypes(CombinarFecha, {
            {"Fecha", type date}, 
            {"Valor", type number}
        }),

        // Generar ID único
        AddIndex = Table.AddIndexColumn(CambiarTipos, "IDB", 1, 1, Int64.Type),
        AddID = Table.AddColumn(AddIndex, "ID", each Text.Combine({Text.From(Date.Year([Fecha])), Text.From(Date.Month([Fecha])), Text.From([IDB], "en-US")}, ""), type text),
        RemoveIDB = Table.RemoveColumns(AddID, {"IDB"})
    in
        RemoveIDB,

    // Aplicar transformación a cada archivo
    AplicarTransformacion = Table.AddColumn(Source, "TablaTransformada", each fnTransform([Content])),

    RenombrarNombreArchivo = Table.RenameColumns(AplicarTransformacion, {"Name", "Source.Name"}),
    SeleccionarColumnasNecesarias = Table.SelectColumns(RenombrarNombreArchivo, {"Source.Name", "TablaTransformada"}),
    ExpandirTabla = Table.ExpandTableColumn(SeleccionarColumnasNecesarias, "TablaTransformada", {"Cuenta", "Fecha", "Valor", "Descripción", "ID"}),
    CambiarTiposFinal = Table.TransformColumnTypes(ExpandirTabla, {
        {"Cuenta", type text}, 
        {"Fecha", type date}, 
        {"Valor", type number}, 
        {"Descripción", type text}, 
        {"ID", type text}
    }),
    ReordenarColumnas = Table.ReorderColumns(CambiarTiposFinal, {"Source.Name", "ID", "Cuenta", "Fecha", "Valor", "Descripción"})
in
    ReordenarColumnas
