// Minimun pageSize = 10
(endPointURL as text, optional getParams as text, optional pageNum as text, optional pageSize as text, optional postParams as text) => let
    
    // Extracción del token
    token = getToken,

    // Encabezados para la solicitud de clientes con el token JWT
    apiHeaders = [
        Authorization = "Bearer " & token,
        #"Content-Type" = "application/json",
        #"Partner-Id" = partnerId
    ],

    // Construcción de URL para GET
    pagination = "?page=" & pageNum ?? 1 & "&page_size=" & pageSize ?? 10,
    getApiURL = endPointURL & pagination & "&" & getParams ?? "1=1",

    // Construcción de URL para POST
    postApiURL = endPointURL,

    // Solicitud para obtener los clientes
    postApiResponse = Web.Contents(postApiURL, [
        Headers = apiHeaders,
        Content = Text.ToBinary(postParams)
    ]),

    getApiResponse = Web.Contents(getApiURL, [
        Headers = apiHeaders
    ]),

    apiResponse = if getParams <> null then getApiResponse else postApiResponse,

    // Convertir la respuesta JSON a tabla
    result = Json.Document(apiResponse)
    
in
    result