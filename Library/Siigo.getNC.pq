(fechaInicio as date, fechaFin as date) =>
let

    queryTableID = "NC",
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
    expandResults = Table.ExpandRecordColumn(expandResultsRecords, "results", {"id", "document", "number", "name", "date", "invoice", "invoice_data", "reason", "customer", "cost_center", "seller", "total", "items", "payments", "stamp", "mail", "metadata"}, {"id", "document", "number", "name", "date", "invoice", "invoice_data", "reason", "customer", "cost_center", "seller", "total", "items", "payments", "stamp", "mail", "metadata"}),
    expandInvoice = Table.ExpandRecordColumn(expandResults, "invoice", {"id", "name"}, {"invoice.id", "invoice.name"}),
    expandInvoice_data = Table.ExpandRecordColumn(expandInvoice, "invoice_data", {"cufe", "number", "date", "prefix"}, {"invoice_data.cufe", "invoice_data.number", "invoice_data.date", "invoice_data.prefix"}),
    expandCustomer = Table.ExpandRecordColumn(expandInvoice_data, "customer", {"identification"}, {"customer.identification"}),
    changeType = Table.TransformColumnTypes(expandCustomer,{{"id", type text}, {"number", Int64.Type}, {"name", type text}, {"date", type date}, {"invoice.id", type text}, {"invoice.name", type text}, {"invoice_data.cufe", type text}, {"invoice_data.prefix", type text}, {"customer.identification", type text}, {"cost_center", type text}, {"seller", type text}, {"total", type number}, {"reason", Int64.Type}, {"invoice_data.date", type date}, {"invoice_data.number", Int64.Type}})
in
    changeType
