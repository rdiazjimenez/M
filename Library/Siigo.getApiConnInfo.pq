// =============================================
// Function: Siigo.getApiConnInfo
// Description:
//   Obtiene un token de Siigo API y construye los headers de autenticación.
// Parameters:
//   - SiigoApiInfo (table): tabla Name/Value con al menos:
//       * username  = <usuario API de Siigo>
//       * accessKey = <access key de Siigo>
//       * partnerId = <Partner-Id: 3-100 caracteres alfanuméricos, sin espacios>
//       * apiUrl    = <URL de autenticación de Siigo>
// Returns:
//   - Record con los headers (Authorization, Content-Type, Partner-Id).
//     No devuelve credenciales ni el token por separado.
// Notes:
//   - El token dura 24 h. Para no pedir un token por cada página, calcula los
//     headers una vez y pásalos como record a Siigo.getApiData / Siigo.getAllPages.
// History:
//   - 2026-11-17: body con Json.FromValue (escapa caracteres especiales),
//     validación de campos efectiva, error con el mensaje de Siigo.
//     Versión anterior en OlderVersions/Siigo.getApiConnInfo.20261117.pq
// =============================================

(SiigoApiInfo as table) as record =>
let
    requiredFields = {"username", "accessKey", "partnerId", "apiUrl"},
    existingFields = List.Transform(SiigoApiInfo[Name], each Text.Lower(_)),
    missingFields  = List.Select(requiredFields, each not List.Contains(existingFields, Text.Lower(_))),

    getSiigoValue = (filterName as text) =>
        Table.SelectRows(SiigoApiInfo, each Text.Lower([Name]) = Text.Lower(filterName)){0}[Value],

    // Se evalúa explícitamente (en M un paso que nadie referencia nunca se ejecuta)
    validated =
        if List.Count(missingFields) > 0 then
            error "Faltan campos en SiigoApiInfo: " & Text.Combine(missingFields, ", ")
        else
            true,

    username  = getSiigoValue("username"),
    accessKey = getSiigoValue("accessKey"),
    partnerId = getSiigoValue("partnerId"),
    apiUrl    = getSiigoValue("apiUrl"),

    authRaw = Web.Contents(apiUrl, [
        Headers = [
            #"Content-Type" = "application/json",
            #"Partner-Id"   = partnerId
        ],
        Content = Json.FromValue([username = username, access_key = accessKey]),
        ManualStatusHandling = {400, 401, 403, 404, 405, 415, 429, 500, 502, 503, 504}
    ]),
    authStatus = Value.Metadata(authRaw)[Response.Status],
    authBody   = Binary.Buffer(authRaw),
    authJson   = try Json.Document(authBody) otherwise null,
    authText   = try Text.Start(Text.FromBinary(authBody), 500) otherwise null,
    apiMessage = try Text.Combine(
                     List.Transform(authJson[Errors], each Text.From([Code]) & ": " & Text.From([Message])),
                     " | ")
                 otherwise authText,

    token =
        if validated and authStatus = 200 and authJson is record and Record.HasFields(authJson, "access_token") then
            authJson[access_token]
        else
            error Error.Record(
                "Siigo.getApiConnInfo",
                "No se pudo obtener el token de Siigo (HTTP " & Text.From(authStatus) & ")"
                    & (if apiMessage <> null then " · " & apiMessage else ""),
                [Status = authStatus, Url = apiUrl]
            ),

    apiHeadersRecord = [
        Authorization   = "Bearer " & token,
        #"Content-Type" = "application/json",
        #"Partner-Id"   = partnerId
    ]
in
    apiHeadersRecord
