(EndpointData as table,
 ApiConnInfo as table) =>
let
    endpointID = "CECO",
    getParams = null,
    pageSize = "100",

    // Call the function with the parameters
    ApiResult = LibPQ("Siigo.getApiData")(EndpointData, ApiConnInfo, endpointID, getParams, "1", pageSize),
    ToTable = Table.FromList(ApiResult, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    ExpandCol = Table.ExpandRecordColumn(ToTable, "Column1", {"id", "code", "name", "active"}, {"id", "code", "name", "active"}),
    ChangeType = Table.TransformColumnTypes(ExpandCol,{{"id", type text}, {"code", type text}, {"name", type text}, {"active", type logical}}),
    AddCol = Table.AddColumn(ChangeType, "code name", each Text.Combine({[code], [name]}, " - "), type text)
in
    AddCol
