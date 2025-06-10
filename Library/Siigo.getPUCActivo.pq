(SiigoPUC as table) =>
let

    // Find parent for each code by checking all shorter codes that are prefixes
    AddParent = Table.AddColumn(SiigoPUC, "Parent", each
        List.Last(
            List.Select(
                SiigoPUC[Código],
                (prefix) => Text.StartsWith([Código], prefix) and [Código] <> prefix
            )
        ),
        type text
    ),

    // Identify children by checking if the code is a prefix to any longer code
    AddChildren = Table.AddColumn(AddParent, "HasChildren", each
        List.AnyTrue(
            List.Transform(
                SiigoPUC[Código],
                (code) => Text.StartsWith(code, [Código]) and code <> [Código]
            )
        )
    , type logical),

    // Classify
    AddType = Table.AddColumn(AddChildren, "Type", each
        if [HasChildren] and [Parent] <> null then "Parent & Child"
        else if [HasChildren] then "Parent"
        else if [Parent] <> null then "Child"
        else "Root"
    ),

    // Clean final output
    FinalTable = Table.SelectColumns(AddType, {"Código", "Nombre", "Activo", "Parent", "HasChildren", "Type"}),

    // 1) Buffer your table (which already has [Código], [Parent], [Activo])
    Buffered = Table.Buffer(FinalTable),

    // 2) Sort so children come before parents
    Sorted = Table.Sort(Buffered, {{"Código", Order.Descending}}),

    // 3) Build initial map: Código → original Activo
    InitialMap = Record.FromList(Buffered[Activo], Buffered[Código]),

    // 4) One-pass propagate: whenever a child is "Sí", force its parent to "Sí"
    FinalMap =
      List.Accumulate(
        Table.ToRecords(Sorted),
        InitialMap,
        (state, row) =>
          let
            code    = row[Código],
            parent  = row[Parent],
            childOn = Record.Field(state, code) = "Sí"
          in
            if parent <> null and childOn then
              // overwrite parent’s field to "Sí" (no error if it already existed)
              Record.TransformFields(state, {{ parent, each "Sí" }})
            else
              state
      ),

    // 5) Add the propagated flag back onto your buffered table
    WithPropagated =
      Table.AddColumn(
        Buffered,
        "ActivoPropagado",
        each Record.Field(FinalMap, [Código]),
        type text
      ),

    // 6) Replace the original Activo column
    RemovedOld = Table.RemoveColumns(WithPropagated, {"Activo"}),
    Renamed   = Table.RenameColumns(RemovedOld, {{"ActivoPropagado","Activo"}}),
    FiltereRow = Table.SelectRows(Renamed, each ([Activo] = "Sí"))
in
    FiltereRow
