(EndpointData as table,
 ApiConnInfo as table) =>
let
    endpointID = "CECO",
    getParams = null,
    pageSize = "100",

    // Call the function with the parameters
    ApiResult = LibPQ("Siigo.getApiData")(EndpointData, ApiConnInfo, endpointID, getParams, "1", pageSize),
    total_results = Number.RoundUp(Number.From(ApiResult[pagination][total_results]) / Number.From(pageSize)),
    ListNumbers = List.Numbers(1,total_results,1),
    toTable = Table.FromList(ListNumbers, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    getPage = Table.AddColumn(toTable, "fetchApiRecords", each LibPQ("Siigo.getApiData")(EndpointData, ApiConnInfo, endpointID, getParams, Text.From([Column1]), pageSize)),
    expandResultsList = Table.ExpandRecordColumn(getPage, "fetchApiRecords", {"pagination", "results", "_links"}, {"pagination", "results", "_links"}),
    removeCols = Table.SelectColumns(expandResultsList,{"results"}),
    expandResultsRecords = Table.ExpandListColumn(removeCols, "results")
in
    expandResultsRecords
