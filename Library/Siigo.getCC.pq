(fechaInicio as date, fechaFin as date) =>
let
    queryTableID = "CC",
    endpointData = LibPQ("Siigo.getEndpointData")(queryTableID),

    getParams = "date_start=" & Date.ToText(fechaInicio, "yyyy-MM-dd") & "&date_end=" & Date.ToText(fechaFin, "yyyy-MM-dd"),
    postParams = null,
    pageSize = "250",

    // Define the API parameters
    apiParams = [
        endpointData = endpointData,
        apiHeaders = LibPQ("Api.createApiHeaders")(getToken, paramSiigoApiPartnerId),
        getParams = getParams,
        postParams = postParams
    ],
    
    // Call the function with the parameters
    ApiResult = LibPQ("Api.getApiResultWrapper")(apiParams, "1", pageSize),
    total_results = Number.RoundUp(Number.From(ApiResult[pagination][total_results]) / Number.From(pageSize)),
    ListNumbers = List.Numbers(1,total_results,1),
    toTable = Table.FromList(ListNumbers, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    getPage = Table.AddColumn(toTable, "fetchApiRecords", each LibPQ("Api.getApiResultWrapper")(apiParams, Text.From([Column1]), pageSize)),
    expandResultsList = Table.ExpandRecordColumn(getPage, "fetchApiRecords", {"pagination", "results", "_links"}, {"pagination", "results", "_links"}),
    removeCols = Table.SelectColumns(expandResultsList,{"results"}),
    expandResultsRecords = Table.ExpandListColumn(removeCols, "results"),
    expandResults = Table.ExpandRecordColumn(expandResultsRecords, "results", {"id", "document", "number", "name", "date", "items", "observations", "metadata"}, {"id", "document", "number", "name", "date", "items", "observations", "metadata"}),
    expandItems = Table.ExpandListColumn(expandResults, "items"),
    expandItemsDetails = Table.ExpandRecordColumn(expandItems, "items", {"account", "customer", "cost_center", "description", "value", "tax", "due", "product"}, {"account", "customer", "cost_center", "description", "value", "tax", "due", "product"}),
    expandAccount = Table.ExpandRecordColumn(expandItemsDetails, "account", {"code", "movement"}, {"account.code", "account.movement"}),
    expandedCustomer = Table.ExpandRecordColumn(expandAccount, "customer", {"identification"}, {"customer.identification"}),
    changeType = Table.TransformColumnTypes(expandedCustomer,{{"number", Int64.Type}, {"name", type text}, {"date", type date}, {"account.code", type text}, {"account.movement", type text}, {"customer.identification", type text}, {"cost_center", type text}, {"description", type text}, {"observations", type text}, {"value", type number}, {"id", type text}})
in
    changeType
