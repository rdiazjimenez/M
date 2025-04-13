(ParamTransfColsDynamicSource as table, ParamTransfColsDynamicMapType as table, Source as table, TypeMap as table) as table =>
let
    //Source = ParamTransfColsDynamicSource,
    //TypeMap = ParamTransfColsDynamicMapType,
    // Function to map type string to actual M type
    TypeMapFunction = (typeText as text) as type =>
        if typeText = "number" then type number
        else if typeText = "text" then type text
        else if typeText = "date" then type date
        else if typeText = "datetime" then type datetime
        else if typeText = "boolean" then type logical
        else if typeText = "time" then type time
        else type any,

    // Get current columns
    AvailableColumns = Table.ColumnNames(Source),
    NormalizeName = Text.Lower,

    // Build transformations with optional renaming
    BuildTransformations = List.Transform(
        Table.ToRecords(TypeMap),
        each
            let
                desiredColumn = [Column],
                matchCase = if Record.HasFields(_, "MatchCase") and [MatchCase] = true then true else false,

                actualColumn =
                    if matchCase then
                        if List.Contains(AvailableColumns, desiredColumn) then desiredColumn else null
                    else
                        try List.First(List.Select(AvailableColumns, (c) => Text.Lower(c) = Text.Lower(desiredColumn))) otherwise null,

                columnType = TypeMapFunction([Type]),
                hasLocale = Record.HasFields(_, "Locale") and [Locale] <> null and Text.Trim([Locale]) <> "",
                renameTo = if Record.HasFields(_, "RenameTo") and [RenameTo] <> null and Text.Trim([RenameTo]) <> "" then [RenameTo] else null,

                result =
                    if actualColumn <> null then
                        [
                            Name = actualColumn,
                            Type = columnType,
                            Locale = if hasLocale then [Locale] else null,
                            NewName = renameTo
                        ]
                    else
                        null
            in
                result
    ),

    // Clean nulls
    Cleaned = List.RemoveNulls(BuildTransformations),

    // Prepare rename list: {oldName, newName}
    RenamePairs = List.Transform(
        List.Select(Cleaned, each Record.HasFields(_, "NewName") and _[NewName] <> null),
        each { _[Name], _[NewName] }
    ),

    // Apply renames first
    RenamedTable = Table.RenameColumns(Source, RenamePairs, MissingField.Ignore),

    // Prepare transformation lists
    WithLocale = List.Select(Cleaned, each _[Locale] <> null),
    WithoutLocale = List.Select(Cleaned, each _[Locale] = null),

    // Map to format for TransformColumnTypes
    ColumnTypeList_NoLocale = List.Transform(WithoutLocale, each { if Record.HasFields(_, "NewName") and _[NewName] <> null then _[NewName] else _[Name], _[Type] }),
    ColumnTypeList_Locale = List.Transform(WithLocale, each { if Record.HasFields(_, "NewName") and _[NewName] <> null then _[NewName] else _[Name], _[Type], _[Locale] }),

    // Apply type transformations
    AfterTypeNoLocale = Table.TransformColumnTypes(RenamedTable, ColumnTypeList_NoLocale),
    AfterTypeWithLocale = List.Accumulate(
        ColumnTypeList_Locale,
        AfterTypeNoLocale,
        (state, current) => Table.TransformColumnTypes(state, { { current{0}, current{1} } }, current{2})
    )
in
    AfterTypeWithLocale