let
    Source = (authUrl, username, accessKey, partnerId) =>
let
    // Variables configurables
    //username = PAR_username,
    //accessKey = PAR_accessKey,
    //partnerId = PAR_partnerId,  // Cambia según el nombre real de tu aplicación

    // URL para obtener el token
    //authUrl = PAR_apiUrl,

    // Cuerpo de la solicitud para obtener el token
    requestBody = Text.ToBinary("{""username"": """ & username & """, ""access_key"": """ & accessKey & """}"),

    // Encabezados para la autenticación
    authHeaders = [
        #"Content-Type" = "application/json",
        #"Partner-Id" = partnerId
    ],

    // Solicitud para obtener el token
    authResponse = Json.Document(Web.Contents(authUrl, [
        Headers = authHeaders,
        Content = requestBody,
        ManualStatusHandling = {200, 400, 401}
    ])),

    // Extracción del token
    token = if Record.HasFields(authResponse, "access_token") then authResponse[access_token] else error "No se encontró el token en la respuesta."

in
    token
in
    Source
