(fechaInicio as date,
 fechaFin as date,
 EndpointData as table,
 ApiConnInfo as table) =>
let
    endpointID = "Tercero",
    getParams = "date_start=" & Date.ToText(fechaInicio, "yyyy-MM-dd") & "&date_end=" & Date.ToText(Date.AddDays(fechaFin, 1), "yyyy-MM-dd"),
    pageSize = "100",

    // Call the function with the parameters
    ApiResult = LibPQ("Siigo.getApiData")(EndpointData, ApiConnInfo, endpointID, getParams, "1", pageSize),
    total_results = Number.RoundUp(Number.From(ApiResult[pagination][total_results]) / Number.From(pageSize)),
    ListNumbers = List.Numbers(1,total_results,1),
    toTable = Table.FromList(ListNumbers, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    getPage = Table.AddColumn(toTable, "fetchApiRecords", each LibPQ("Siigo.getApiData")(EndpointData, ApiConnInfo, endpointID, getParams, Text.From([Column1]), pageSize)),
    expandResultsList = Table.ExpandRecordColumn(getPage, "fetchApiRecords", {"pagination", "results", "_links"}, {"pagination", "results", "_links"}),
    removeCols = Table.SelectColumns(expandResultsList,{"results"}),
    expandResultsRecords = Table.ExpandListColumn(removeCols, "results"),
    expandResults = Table.ExpandRecordColumn(expandResultsRecords, "results", {"id", "document", "prefix", "number", "name", "date", "customer", "cost_center", "seller", "total", "balance", "observations", "items", "payments", "stamp", "mail", "metadata", "public_url"}, {"id", "document", "prefix", "number", "name", "date", "customer", "cost_center", "seller", "total", "balance", "observations", "items", "payments", "stamp", "mail", "metadata", "public_url"}),
    expandCustomer = Table.ExpandRecordColumn(expandResults, "customer", {"identification"}, {"identification"}),
    changeType = Table.TransformColumnTypes(expandCustomer,{{"id", type text}, {"seller", type text}, {"identification", type text}, {"name", type text}, {"observations", type text}, {"public_url", type text}, {"number", Int64.Type}, {"date", type date}, {"cost_center", type text}, {"total", type number}, {"balance", type number}})
in
    changeType
