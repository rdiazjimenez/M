let
    Source =
        let
            func =
                (ParChTable as table,
                 ChildKey as text,
                 ParentKey as text,
                 LevelColumnName as text) =>

                let
                        // =============================
    // 1. Preparacion de datos base
    // =============================
    Base_SelectKeysAndLevel =
        Table.SelectColumns(ParChTable, {ChildKey, ParentKey, LevelColumnName}),

    Base_ForceTextKeys =
        Table.TransformColumnTypes(
            Base_SelectKeysAndLevel,
            {{ChildKey, type text}, {ParentKey, type text}}
        ),

    Base_ReplaceNullParents =
        Table.ReplaceValue(
            Base_ForceTextKeys,
            null,
            "",
            Replacer.ReplaceValue,
            {ParentKey}
        ),

    // =======================================
    // 2. Deteccion de padres faltantes
    // =======================================
    Detected_MissingParentNodes =
        List.Buffer(
            List.Select(
                List.Difference(
                    List.Distinct(Table.Column(Base_ReplaceNullParents, ParentKey)),
                    List.Distinct(Table.Column(Base_ReplaceNullParents, ChildKey))
                ),
                each _ <> ""
            )
        ),

    Base_AddSyntheticRootNodes =
        Table.Buffer(
            Table.Combine(
                {
                    Base_ReplaceNullParents,
                    #table(
                        {ChildKey, LevelColumnName, ParentKey},
                        List.Transform(
                            Detected_MissingParentNodes,
                            each {
                                _,
                                "Unknown TopLevel"
                                    & Text.From(
                                        List.PositionOf(
                                            Detected_MissingParentNodes,
                                            _
                                        )
                                    ),
                                ""
                            }
                        )
                    )
                }
            )
        ),

    // =======================================
    // 3. Deteccion inicial de hojas
    // =======================================
    Join_ChildToParentCheck =
        Table.NestedJoin(
            Base_AddSyntheticRootNodes,
            {ChildKey},
            Base_AddSyntheticRootNodes,
            {ParentKey},
            "ChildrenCheck",
            JoinKind.LeftOuter
        ),

    Flag_IsLeaf_Initial =
        Table.AddColumn(
            Join_ChildToParentCheck,
            "IsLeaf",
            each if Table.IsEmpty([ChildrenCheck]) then "yes" else "no"
        ),

    Normalize_Nulls_AfterLeafCheck =
        Table.ReplaceValue(
            Flag_IsLeaf_Initial,
            null,
            "",
            Replacer.ReplaceValue,
            {ParentKey, LevelColumnName}
        ),

    // =======================================
    // 4. Inicializacion de path y seed
    // =======================================
    Init_Path =
        Table.AddColumn(
            Normalize_Nulls_AfterLeafCheck,
            "Path",
            each Text.Trim(
                Record.Field(_, ChildKey)
                    & "|"
                    & Record.Field(_, ParentKey),
                "|"
            )
        ),

    Init_NodeName =
        Table.DuplicateColumn(Init_Path, LevelColumnName, "NodeName"),

    Iteration_SeedTable =
        Table.DuplicateColumn(Init_NodeName, ParentKey, "NodeParentKey"),

    // =======================================
    // 5. Algoritmo iterativo Parent-Child
    // =======================================
    Iterate_ResolveAllParents_WithLoopGuard =
        List.Generate(
            () =>
                [
                    Result = Iteration_SeedTable,
                    Level = 1,
                    EndlessLoop = false,
                    StopEndlessLoop = false
                ],
            each Table.RowCount([Result]) > 0 and not [StopEndlessLoop],
            each
                [
                    Result =
                        let
                            Iter_JoinToParent =
                                Table.NestedJoin(
                                    [Result],
                                    {ParentKey},
                                    Base_AddSyntheticRootNodes,
                                    {ChildKey},
                                    "ParentJoin",
                                    JoinKind.Inner
                                ),

                            Iter_RemoveOldParentKey =
                                Table.RemoveColumns(
                                    Iter_JoinToParent,
                                    {ParentKey}
                                ),

                            Iter_ExpandParent =
                                Table.ExpandTableColumn(
                                    Iter_RemoveOldParentKey,
                                    "ParentJoin",
                                    {ParentKey, LevelColumnName},
                                    {"ParentKey.1", "Name.1"}
                                ),

                            Iter_RestoreParentKey =
                                Table.DuplicateColumn(
                                    Iter_ExpandParent,
                                    "ParentKey.1",
                                    ParentKey
                                ),

                            Iter_ExtendPath =
                                Table.CombineColumns(
                                    Iter_RestoreParentKey,
                                    {"Path", "ParentKey.1"},
                                    Combiner.CombineTextByDelimiter("|", QuoteStyle.None),
                                    "Path"
                                ),

                            Iter_ExtendNamePath =
                                Table.CombineColumns(
                                    Iter_ExtendPath,
                                    {LevelColumnName, "Name.1"},
                                    Combiner.CombineTextByDelimiter("|", QuoteStyle.None),
                                    LevelColumnName
                                )
                        in
                            Iter_ExtendNamePath,

                    Level = [Level] + 1,
                    EndlessLoop =
                        Table.SelectColumns(Result, {ChildKey})
                            = Table.SelectColumns([Result], {ChildKey}),
                    StopEndlessLoop = [EndlessLoop]
                ]
        ),

    // =======================================
    // 6. Consolidacion de iteraciones
    // =======================================
    Collect_AllIterations =
        Table.FromList(
            Iterate_ResolveAllParents_WithLoopGuard,
            Splitter.SplitByNothing(),
            null,
            null,
            ExtraValues.Error
        ),

    Expand_IterationMetadata =
        Table.ExpandRecordColumn(
            Collect_AllIterations,
            "Column1",
            {"Result", "Level", "EndlessLoop"},
            {"Result", "Level", "EndlessLoop"}
        ),

    Expand_HierarchyResult =
        Table.ExpandTableColumn(
            Expand_IterationMetadata,
            "Result",
            {LevelColumnName, ParentKey, ChildKey, "Path", "NodeName", "NodeParentKey"},
            {"Name", "ParentKey", "NodeKey", "Path", "NodeName", "NodeParentKey"}
        ),

    // =======================================
    // 7. Filtrado de nodos raiz
    // =======================================
    Filter_RootNodes =
        Table.SelectRows(
            Expand_HierarchyResult,
            each ([ParentKey] = null or [ParentKey] = "")
        ),

    Remove_ParentKey_ForRoots =
        Table.RemoveColumns(Filter_RootNodes, {"ParentKey"}),

    Clean_PathDelimiters =
        Table.TransformColumns(
            Remove_ParentKey_ForRoots,
            {{"Path", each Text.Trim(_, "|")}}
        ),

    Normalize_NameOrder_RootToLeaf =
        Table.TransformColumns(
            Clean_PathDelimiters,
            {{"Name", each Text.Combine(List.Reverse(Text.Split(_, "|")), "|")}}
        ),

    Normalize_PathOrder_RootToLeaf =
        Table.TransformColumns(
            Normalize_NameOrder_RootToLeaf,
            {{"Path", each Text.Combine(List.Reverse(Text.Split(_, "|")), "|")}}
        ),

    // =======================================
    // 8. Expansion por niveles
    // =======================================
    Order_CoreHierarchyColumns =
        Table.ReorderColumns(
            Normalize_PathOrder_RootToLeaf,
            {"NodeKey", "NodeParentKey", "Path", "NodeName", "Level", "Name"}
        ),

    Split_NameInto_LevelColumns =
        Table.SplitColumn(
            Order_CoreHierarchyColumns,
            "Name",
            Splitter.SplitTextByDelimiter("|", QuoteStyle.Csv),
            List.Transform(
                {1 .. Table.RowCount(Collect_AllIterations)},
                each "Level Name " & Text.From(_)
            )
        ),

    // =======================================
    // 9. Join con tabla original
    // =======================================
    Join_BackToOriginalTable =
        Table.NestedJoin(
            Split_NameInto_LevelColumns,
            {"NodeKey"},
            ParChTable,
            {ChildKey},
            "OriginalJoin",
            JoinKind.LeftOuter
        ),

    Expand_OriginalAttributes =
        Table.ExpandTableColumn(
            Join_BackToOriginalTable,
            "OriginalJoin",
            List.Difference(
                Table.ColumnNames(ParChTable),
                Table.ColumnNames(Normalize_Nulls_AfterLeafCheck)
            )
        ),

    Rename_LevelToHierarchyDepth =
        Table.RenameColumns(
            Expand_OriginalAttributes,
            {{"Level", "HierarchyDepth"}}
        ),

    // =======================================
    // 10. IsLeaf final
    // =======================================
    All_ParentNodeKeys =
        List.Buffer(Rename_LevelToHierarchyDepth[NodeParentKey]),

    Flag_IsLeaf_Final =
        Table.AddColumn(
            Rename_LevelToHierarchyDepth,
            "IsLeaf",
            each not List.Contains(All_ParentNodeKeys, [NodeKey])
        ),

    // =======================================
    // 11. Garantia Level 1..6
    // =======================================
    Ensure_Level2_Exists =
        if Table.HasColumns(Flag_IsLeaf_Final, "Level Name 2")
        then Flag_IsLeaf_Final
        else Table.AddColumn(Flag_IsLeaf_Final, "Level Name 2", each null, type text),

    Ensure_Level3_Exists =
        if Table.HasColumns(Ensure_Level2_Exists, "Level Name 3")
        then Ensure_Level2_Exists
        else Table.AddColumn(Ensure_Level2_Exists, "Level Name 3", each null, type text),

    Ensure_Level4_Exists =
        if Table.HasColumns(Ensure_Level3_Exists, "Level Name 4")
        then Ensure_Level3_Exists
        else Table.AddColumn(Ensure_Level3_Exists, "Level Name 4", each null, type text),

    Ensure_Level5_Exists =
        if Table.HasColumns(Ensure_Level4_Exists, "Level Name 5")
        then Ensure_Level4_Exists
        else Table.AddColumn(Ensure_Level4_Exists, "Level Name 5", each null, type text),

    Ensure_Level6_Exists =
        if Table.HasColumns(Ensure_Level5_Exists, "Level Name 6")
        then Ensure_Level5_Exists
        else Table.AddColumn(Ensure_Level5_Exists, "Level Name 6", each null, type text),

    // =======================================
    // 12. Reorden final
    // =======================================
    ReorderedColumns =
        Table.ReorderColumns(
            Ensure_Level6_Exists,
            List.RemoveItems(
                Table.ColumnNames(Ensure_Level6_Exists),
                {"Level Name 1","Level Name 2","Level Name 3","Level Name 4","Level Name 5","Level Name 6"}
            )
            & {"Level Name 1","Level Name 2","Level Name 3","Level Name 4","Level Name 5","Level Name 6"}
        ),
    Extract_Level1_Node = Table.AddColumn(ReorderedColumns, "Level 1 Node", each Text.BeforeDelimiter([Path], "|"), type text),
    Extract_Level2_Node = Table.AddColumn(Extract_Level1_Node, "Level 2 Node", each Text.BetweenDelimiters([Path], "|", "|"), type text),
    Extract_Level3_Node = Table.AddColumn(Extract_Level2_Node, "Level 3 Node", each Text.BetweenDelimiters([Path], "|", "|", 1, 0), type text),
    Extract_Level4_Node = Table.AddColumn(Extract_Level3_Node, "Level 4 Node", each Text.BetweenDelimiters([Path], "|", "|", 2, 0), type text),
    Extract_Level5_Node = Table.AddColumn(Extract_Level4_Node, "Level 5 Node", each Text.BetweenDelimiters([Path], "|", "|", 3, 0), type text),
    Extract_Level6_Node = Table.AddColumn(Extract_Level5_Node, "Level 6 Node", each Text.BetweenDelimiters([Path], "|", "|", 4, 0), type text),
    // =======================================
    // 13. Control de loop infinito
    // =======================================
    Iteration_Count =
        List.Count(Iterate_ResolveAllParents_WithLoopGuard),

    Last_IterationSnapshot =
        Table.SelectRows(
            Expand_HierarchyResult,
            each ([Level] = Iteration_Count)
        ),

    Detected_EndlessLoop =
        Last_IterationSnapshot[EndlessLoop]{0},

    Final_Output =
        if Detected_EndlessLoop
        then
            [
                Message = "The data is in an endless loop. Check table 'Endless Loop'",
                #"Endless Loop" = Last_IterationSnapshot
            ]
        else
            Extract_Level6_Node
            in
                Final_Output
        in
            func
in
    Source
