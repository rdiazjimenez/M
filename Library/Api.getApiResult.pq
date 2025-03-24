// Minimun pageSize = 10
(endpointURL as text, endpointType as text, apiHeaders as record, optional getParams as text, optional pageNum as text, optional pageSize as text, optional postParams as text) => let

    // Construcción de URL para GET
    pagination = "?page=" & (pageNum ?? "1") & "&page_size=" & (pageSize ?? "10"),
    getApiURL = endpointURL & pagination & "&" & (getParams ?? "1=1"),

    // Construcción de URL para POST
    postApiURL = endpointURL,

    // Solicitud para obtener los clientes
    makePostRequest = Web.Contents(postApiURL, [
        Headers = apiHeaders,
        Content = Text.ToBinary(postParams)
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
            otherwise "Error executing API request"
    
in
    result