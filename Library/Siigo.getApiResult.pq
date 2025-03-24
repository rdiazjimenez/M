(endPointURL as text, pageNum as text, pageSize as text, optional requestContent as text) => let
    
    // Extracción del token
    token = getToken,

    pagination = "?page=" & pageNum & "&page_size=" & pageSize,

    // Encabezados para la solicitud de clientes con el token JWT
    apiHeaders = [
        Authorization = "Bearer " & token,
        #"Content-Type" = "application/json",
        #"Partner-Id" = partnerId
    ],

    // Convertir texto del content a binary
    requestContentB = if requestContent <> null then Text.ToBinary(requestContent) else null,

    // Solicitud para obtener los clientes
    apiResponsePOST = Web.Contents(endPointURL & pagination, [
        Headers = apiHeaders,
        Content = requestContentB
    ]),

    apiResponseGET = Web.Contents(endPointURL & pagination, [
        Headers = apiHeaders
    ]),

    apiResponse = if requestContentB = null then apiResponsePOST else apiResponseGET,

    // Convertir la respuesta JSON a tabla
    result = Json.Document(apiResponse)
    
in
    result