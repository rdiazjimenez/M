(connSiigoMvto as table) =>
let
    // 1. Origen y filtro de archivos ocultos
    Archivos = Table.SelectRows(connSiigoMvto, each [Attributes]?[Hidden]? <> true),

    // 2. Transformar cada archivo (sin tipificación intermedia — se hace al final)
    Transformados = Table.AddColumn(
        Archivos,
        "Datos",
        each 
            let
                Hoja   = Excel.Workbook([Content], null, true){[Item="Mov-cuenta-contable", Kind="Sheet"]}[Data],
                Limpia = Table.RemoveLastN(Table.Skip(Hoja, 4), 2)
            in
                Table.PromoteHeaders(Limpia, [PromoteAllScalars=true])
    ),

    // 3. Seleccionar solo columnas útiles (renombrando en el mismo paso)
    Reducido = Table.SelectColumns(
        Table.RenameColumns(Transformados, {{"Name", "Source.Name"}}),
        {"Source.Name", "Datos"}
    ),

    // 4. Expandir — nombres derivados dinámicamente del primer archivo
    ColsExpand  = Table.ColumnNames(Reducido{0}[Datos]),
    Expandido   = Table.ExpandTableColumn(Reducido, "Datos", ColsExpand),

    // 5. Tipificación única y final (fecha directo como date)
    Tipificado = Table.TransformColumnTypes(
        Expandido,
        {
            {"Fecha elaboración",        type date},
            {"Código cuentas contables", type text},
            {"Nombre cuenta contable",   type text},
            {"Identificación tercero",   type text},
            {"Nombre tercero",           type text},
            {"Nombre centro de costo",   type text},
            {"Comprobante",              type text},
            {"Descripción",              type text},
            {"Valor base",               type number},
            {"Débito",                   type number},
            {"Crédito",                  type number}
        }
    )
in
    Tipificado
