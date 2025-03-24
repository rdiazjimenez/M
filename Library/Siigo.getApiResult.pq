(endPointURL as text, optional pageNum as text, optional pageSize as text, optional requestContent as text) => let
    
    // Extracción del token
    token = getToken,

    pagination = "?page=" & pageNum & "&page_size=" & pageSize,

    // Encabezados para la solicitud de clientes con el token JWT
    apiHeaders = [
        Authorization = "Bearer " & token,
        #"Content-Type" = "application/json",
        #"Partner-Id" = partnerId
    ],

    endPointURLComplete = if pageNum = null or pageSize = null then endPointURL else endPointURL & pagination, 

    // Convertir texto del content a binary
    requestContentBinary = if requestContent <> null then Text.ToBinary(requestContent) else null,

    // Solicitud para obtener los clientes
    apiResponsePOST = Web.Contents(endPointURLComplete, [
        Headers = apiHeaders,
        Content = requestContentBinary
    ]),

    apiResponseGET = Web.Contents(endPointURLComplete, [
        Headers = apiHeaders
    ]),

    apiResponse = if requestContentBinary = null then apiResponsePOST else apiResponseGET,

    // Convertir la respuesta JSON a tabla
    result = Json.Document(apiResponse)
    
in
    result