(connPUC as table, optional Idioma as text) =>
let
    // Si el usuario no da el parámetro o es distinto a "ES", el default es "EN"
    lang = if Idioma <> null and Text.Upper(Idioma) = "ES" then "ES" else "EN",
    
    labels = [
        ParentChild = if lang = "ES" then "Padre e Hijo" else "Parent & Child",
        Parent      = if lang = "ES" then "Padre" else "Parent",
        Child       = if lang = "ES" then "Hijo" else "Child",
        Root        = if lang = "ES" then "Raíz" else "Root",
        ColName     = if lang = "ES" then "Tipo" else "Type"
    ],

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

    /* 2.3  Clasificar el nodo usando el record 'labels' */
    AddType = Table.AddColumn(
        AddChildren, "TempType", 
        each  if [HasChildren] and [Parent] <> null then labels[ParentChild]
              else if [HasChildren]                 then labels[Parent]
              else if [Parent]     <> null          then labels[Child]
              else                                       labels[Root],
        type text
    ),

    /* 2.4  Limpiar columnas y renombrar dinámicamente */
    FinalTable = Table.SelectColumns(AddType, {"Código", "Nombre", "Activo", "Parent", "HasChildren", "TempType"}),
    RenameTypeCol = Table.RenameColumns(FinalTable, {{"TempType", labels[ColName]}}),

    /* 2.5  Propagar la marca “Sí” desde hijos a padres */
    Buffered    = Table.Buffer(RenameTypeCol),
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
