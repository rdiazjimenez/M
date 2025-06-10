(connPUC as table) =>
let
    /*--------------------------------------------------
     * 1. Importar y depurar el PUC desde el Excel
     *-------------------------------------------------*/
    Source           = connPUC,
    ContentData      = Source{0}[Content],
    ImportData       = Excel.Workbook(ContentData, [UseHeaders = true, InferSheetDimensions = true]),
    SheetData        = ImportData{0}[Data],
    RemoveTopRows    = Table.Skip(SheetData, 5),
    RemoveBottomRows = Table.RemoveLastN(RemoveTopRows, 2),
    PromoteHeaders   = Table.PromoteHeaders(RemoveBottomRows, [PromoteAllScalars = true]),

    /*--------------------------------------------------
     * 2. Construir la jerarquía y propagar “Activo”
     *-------------------------------------------------*/
    Base            = PromoteHeaders,

    /* 2.1  Encontrar padre directo de cada código */
    AddParent = Table.AddColumn(
        Base, "Parent",
        each List.Last(
                List.Select(
                    Base[Código],
                    (prefix) => Text.StartsWith([Código], prefix) and [Código] <> prefix
                )
             ),
        type text
    ),

    /* 2.2  Detectar si tiene hijos                    */
    AddChildren = Table.AddColumn(
        AddParent, "HasChildren",
        each List.AnyTrue(
                List.Transform(
                    Base[Código],
                    (code) => Text.StartsWith(code, [Código]) and code <> [Código]
                )
             ),
        type logical
    ),

    /* 2.3  Clasificar el nodo                         */
    AddType = Table.AddColumn(
        AddChildren, "Type",
        each  if [HasChildren] and [Parent] <> null then "Parent & Child"
              else if [HasChildren]                 then "Parent"
              else if [Parent]     <> null          then "Child"
              else                                       "Root"
    ),

    /* 2.4  Limpiar columnas                           */
    FinalTable = Table.SelectColumns(AddType, {"Código", "Nombre", "Activo", "Parent", "HasChildren", "Type"}),

    /* 2.5  Propagar la marca “Sí” desde hijos a padres */
    Buffered    = Table.Buffer(FinalTable),
    Sorted      = Table.Sort(Buffered, {{"Código", Order.Descending}}),
    InitialMap  = Record.FromList(Buffered[Activo], Buffered[Código]),

    FinalMap = List.Accumulate(
        Table.ToRecords(Sorted),
        InitialMap,
        (state, row) =>
            let
                code    = row[Código],
                parent  = row[Parent],
                childOn = Record.Field(state, code) = "Sí"
            in
                if parent <> null and childOn
                then Record.TransformFields(state, {{ parent, each "Sí" }})
                else state
    ),

    WithPropagated = Table.AddColumn(
        Buffered, "ActivoPropagado",
        each Record.Field(FinalMap, [Código]),
        type text
    ),
    RemovedOld = Table.RemoveColumns(WithPropagated, {"Activo"}),
    Renamed    = Table.RenameColumns(RemovedOld, {{"ActivoPropagado", "Activo"}}),

    /* 2.6  Filtrar solamente los registros activos     */
    Filtered = Table.SelectRows(Renamed, each ([Activo] = "Sí"))
in
    Filtered
