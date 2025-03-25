(apiParams as record) =>
let
    // Parametros de llamada al API
    /*
    getParams = "start_date=2024-01-01"
    postParams = "{
        ""year"": 2025,
        ""month_start"": 1,
        ""month_end"": 1,
        ""includes_tax_difference"": false
    }",
    */
    // Extract parameters from the record
    endpointData = Record.FieldOrDefault(apiParams, "endpointData", ""),
    endpointURL = endpointData[endpointURL],
    endpointType = endpointData[Type],
    apiHeaders = Record.FieldOrDefault(apiParams, "apiHeaders", ""),
    getParams = Record.FieldOrDefault(apiParams, "getParams", null),
    pageNum = Record.FieldOrDefault(apiParams, "pageNum", null),
    pageSize = Record.FieldOrDefault(apiParams, "pageSize", null),
    postParams = Record.FieldOrDefault(apiParams, "postParams", null),
    Source = LibPQ("Api.getApiResult")(endpointURL, endpointType, apiHeaders, getParams, pageNum, pageSize, postParams)
in
    Source