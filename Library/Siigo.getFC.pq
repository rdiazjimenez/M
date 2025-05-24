(fechaInicio as date, fechaFin as date) =>
let
    queryTableID = "FC",
    endpointData = LibPQ("Siigo.getEndpointData")(queryTableID),

    getParams = "start_date=" & Date.ToText(fechaInicio, "yyyy-MM-dd") & "&end_date=" & Date.ToText(fechaFin, "yyyy-MM-dd"),
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
    expandSupplier = Table.ExpandRecordColumn(expandResults, "supplier", {"identification"}, {"supplier.identification"}),
    expandProvider_invoice = Table.ExpandRecordColumn(expandSupplier, "provider_invoice", {"prefix", "number"}, {"provider.invoice_prefix", "provider.invoice_number"}),
    expandDocument = Table.ExpandRecordColumn(expandProvider_invoice, "document", {"id"}, {"document_id"}),
    changeType = Table.TransformColumnTypes(expandDocument,{{"date", type date}, {"total", type number}, {"balance", type number}, {"id", type text}, {"name", type text}, {"supplier.identification", type text}, {"provider.invoice_prefix", type text}, {"provider.invoice_number", type text}, {"discount_type", type text}, {"cost_center", type text}, {"document_id", Int64.Type}})
in
    changeType
