(ParamTable as table) =>
let

    getSiigoValue = (filterName as text) =>
    let
        FilterName = Table.SelectRows(ParamTable, each ([name] = filterName)),
        GetValue = FilterName{0}[value]
    in
        GetValue,

    username = getSiigoValue("username"),
    accessKey = getSiigoValue("accessKey"),
    partnerId = getSiigoValue("partnerId"),
    apiUrl =  getSiigoValue("apiUrl"),

    // Cuerpo de la solicitud para obtener el token
    requestBody = Text.ToBinary("{""username"": """ & username & """, ""access_key"": """ & accessKey & """}"),

    // Encabezados para la autenticación
    authHeaders = [
        #"Content-Type" = "application/json",
        #"Partner-Id" = partnerId
    ],

    // Solicitud para obtener el token
    authResponse = Json.Document(Web.Contents(apiUrl, [
        Headers = authHeaders,
        Content = requestBody,
        ManualStatusHandling = {200, 400, 401}
    ])),

    // Extracción del token
    token = if Record.HasFields(authResponse, "access_token") then authResponse[access_token] else error "No se encontró el token en la respuesta."

in
    token
