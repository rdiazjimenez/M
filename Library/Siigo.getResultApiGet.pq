// fnQueryAPI
let
    Source = (endPointURL as text, pageNum as text, pageSize as text) => let
        
        // Extracción del token
        token = getToken,
    
        pagination = "?page=" & pageNum & "&page_size=" & pageSize,
    
        // Encabezados para la solicitud de clientes con el token JWT
        apiHeaders = [
            Authorization = "Bearer " & token,
            #"Content-Type" = "application/json",
            #"Partner-Id" = partnerId
        ],
    
        // Solicitud para obtener los clientes
        apiResponse = Web.Contents(endPointURL & pagination, [
            Headers = apiHeaders
        ]),
    
        // Convertir la respuesta JSON a tabla
        result = Json.Document(apiResponse),
        // Convertir la respuesta JSON a tabla
        results = result[results],
        toTable = Table.FromList(results, Splitter.SplitByNothing(), null, null, ExtraValues.Error)
        
    in
        toTable
in
    Source