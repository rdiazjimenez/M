(connSiigoMvto as table) =>
let
    // 1. Origen: obtén los archivos de la conexión
    Source = connSiigoMvto,

    // 2. Filtra archivos ocultos
    FiltrarArchivosVisibles = Table.SelectRows(Source, each [Attributes]?[Hidden]? <> true),

    // 3. Aplica la transformación directamente (integrando "Transform File")
    TransformarContenido = Table.AddColumn(
        FiltrarArchivosVisibles,
        "Transform File",
        each 
            let
                // Abre el contenido como libro de Excel
                Libro = Excel.Workbook([Content], null, true),
                // Toma la hoja requerida
                Hoja = Libro{[Item="Mov-cuenta-contable",Kind="Sheet"]}[Data],
                // Quita las primeras 4 filas
                QuitarTop = Table.Skip(Hoja,4),
                // Quita las últimas 2 filas
                QuitarBottom = Table.RemoveLastN(QuitarTop,2),
                // Promueve encabezados
                PromoverHeaders = Table.PromoteHeaders(QuitarBottom, [PromoteAllScalars=true]),
                // Tipifica columnas
                Tipificar = Table.TransformColumnTypes(PromoverHeaders,{
                    {"Fecha elaboración", type datetime},
                    {"Código cuentas contables", type text},
                    {"Nombre cuenta contable", type text},
                    {"Identificación tercero", type text},
                    {"Nombre tercero", type text},
                    {"Nombre centro de costo", type text},
                    {"Comprobante", type text},
                    {"Descripción", type text},
                    {"Valor base", type number},
                    {"Débito", type number},
                    {"Crédito", type number}
                })
            in
                Tipificar
    ),

    // 4. Renombra columnas (opcional, puedes omitir si no lo necesitas)
    RenombrarNombreArchivo = Table.RenameColumns(TransformarContenido, {"Name", "Source.Name"}),

    // 5. Conserva solo columnas útiles
    SeleccionarColumnas = Table.SelectColumns(RenombrarNombreArchivo, {"Source.Name", "Transform File"}),

    // 6. Expande la columna de tabla resultante
    ExpandirTransformados = Table.ExpandTableColumn(
        SeleccionarColumnas,
        "Transform File",
        {"Fecha elaboración", "Código cuentas contables", "Nombre cuenta contable", "Identificación tercero", "Nombre tercero", "Nombre centro de costo", "Comprobante", "Descripción", "Valor base", "Débito", "Crédito"}
    ),

    // 7. Cambia tipo a las columnas finales (fecha como date)
    CambiarTipoFinal = Table.TransformColumnTypes(
        ExpandirTransformados,
        {
            {"Fecha elaboración", type date},
            {"Código cuentas contables", type text},
            {"Nombre cuenta contable", type text},
            {"Identificación tercero", type text},
            {"Nombre tercero", type text},
            {"Nombre centro de costo", type text},
            {"Comprobante", type text},
            {"Descripción", type text},
            {"Valor base", type number},
            {"Débito", type number},
            {"Crédito", type number}
        }
    )
in
    CambiarTipoFinal
