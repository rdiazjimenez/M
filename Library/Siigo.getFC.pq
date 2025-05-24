(fechaInicio as date, fechaFin as date) =>
let
    queryTableID = "FC",
    endpointData = LibPQ("Siigo.getEndpointData")(queryTableID),

    getParams = "date_start=" & Date.ToText(paramFechaInicioReportes, "yyyy-MM-dd") & "&date_end=" & Date.ToText(paramFechaFinReportes, "yyyy-MM-dd"),
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
    expandResults = Table.ExpandRecordColumn(expandResultsRecords, "results", {"id", "document", "number", "name", "date", "cost_center", "supplier", "total", "balance", "provider_invoice", "discount_type", "items", "retentions", "payments", "metadata"}, {"id", "document", "number", "name", "date", "cost_center", "supplier", "total", "balance", "provider_invoice", "discount_type", "items", "retentions", "payments", "metadata"}),
    expandItems = Table.ExpandListColumn(expandResults, "items"),
    expandDetails = Table.ExpandRecordColumn(expandItems, "items", {"account", "customer", "cost_center", "description", "value"}, {"account", "customer.1", "cost_center.1", "description", "value"}),
    expandAccount = Table.ExpandRecordColumn(expandDetails, "account", {"code", "movement"}, {"code", "movement"}),
    expandCustomer = Table.ExpandRecordColumn(expandAccount, "customer.1", {"identification"}, {"identification"})
in
    expandCustomer
