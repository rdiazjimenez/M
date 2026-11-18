// =============================================
// Function: GetApiConnInfo
// Description:
//   Retrieves a Siigo API token and builds authentication headers.
// Parameters:
//   - SiigoApiInfo (table): A table with at least the following fields:
//       * name = "username", value = <your Siigo username>
//       * name = "accessKey", value = <your Siigo access key>
//       * name = "partnerId", value = <your Partner-Id>
//       * name = "apiUrl", value = <Siigo login endpoint URL>
// Returns:
//   - A record with authentication headers only (Authorization, Content-Type, Partner-Id).
//     Raw credentials and token are NOT returned.
// =============================================

(SiigoApiInfo as table) as record =>
let
    requiredFields = {"username", "accessKey", "partnerId", "apiUrl"},
    existingFields = List.Transform(SiigoApiInfo[Name], each Text.Lower(_)),
    missingFields = List.Select(requiredFields, each not List.Contains(existingFields, Text.Lower(_))),

    _ = if List.Count(missingFields) > 0 then
            error "Missing required fields in SiigoApiInfo: " & Text.Combine(missingFields, ", ")
        else
            null,

    getSiigoValue = (filterName as text) =>
        let
            FilterName = Table.SelectRows(SiigoApiInfo, each Text.Lower([Name]) = Text.Lower(filterName)),
            GetValue = FilterName{0}[Value]
        in
            GetValue,

    username = getSiigoValue("username"),
    accessKey = getSiigoValue("accessKey"),
    partnerId = getSiigoValue("partnerId"),
    apiUrl    = getSiigoValue("apiUrl"),

    requestBody = Text.ToBinary("{""username"": """ & username & """, ""access_key"": """ & accessKey & """}"),

    authHeaders = [
        #"Content-Type" = "application/json",
        #"Partner-Id" = partnerId
    ],

    authResponse = Json.Document(Web.Contents(apiUrl, [
        Headers = authHeaders,
        Content = requestBody,
        ManualStatusHandling = {200, 400, 401}
    ])),

    apiHeadersRecord = [
        Authorization = "Bearer " & (if Record.HasFields(authResponse, "access_token") then authResponse[access_token] else error "No se encontró el token en la respuesta."),
        #"Content-Type" = "application/json",
        #"Partner-Id" = partnerId
    ]
in
    apiHeadersRecord
