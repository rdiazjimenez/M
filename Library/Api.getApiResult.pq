// Minimun pageSize = 10
(endpointURL as text,
 endpointType as text,
 apiHeaders as record,
 optional params as text,
 optional pageNum as text,
 optional pageSize as text) => let

    // Construcción de URL para GET
    pagination = "?page=" & (pageNum ?? "1") & "&page_size=" & (pageSize ?? "10"),
    getApiURL = endpointURL & pagination & "&" & (params ?? "1=1"),

    // Solicitud para obtener los clientes
    makePostRequest = Web.Contents(endpointURL, [
        Headers = apiHeaders,
        Content = Text.ToBinary(params)
    ]),

    makeGetRequest = Web.Contents(getApiURL, [
        Headers = apiHeaders
    ]),

    apiResponse = if endpointType = "Post" then
            makePostRequest
        else
            makeGetRequest,

    jsonResponse = Json.Document(apiResponse),

    result = try jsonResponse
            otherwise "Error:" & Text.FromBinary(apiResponse)
    
in
    result
