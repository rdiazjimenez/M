// =============================================
// Function: Api.getApiResult
// Description:
//   Llamada REST genérica (GET paginado o POST con body JSON).
//   - Usa URL base fija + RelativePath/Query (compatible con actualización
//     programada en Power BI Service: evita "dynamic data source").
//   - Si la API responde HTTP >= 400, lanza un error con el mensaje de la API
//     (en Siigo: Errors[].Code / Errors[].Message) en lugar de un error genérico.
// Parameters:
//   - endpointURL (text): URL completa del endpoint, p. ej. https://api.siigo.com/v1/invoices
//   - endpointType (text): "Get" o "Post" (no distingue mayúsculas)
//   - apiHeaders (record): headers de autenticación (ver Siigo.getApiConnInfo)
//   - params (text, opcional):
//       GET  → query string sin "?", p. ej. "date_start=2026-01-01&date_end=2026-01-31"
//       POST → body JSON como texto
//   - pageNum (text, opcional, solo GET): por defecto "1"
//   - pageSize (text, opcional, solo GET): por defecto "10" (Siigo: máx 100)
// Returns:
//   - El JSON de la respuesta (record o list).
// History:
//   - 2026-11-17: RelativePath/Query, ManualStatusHandling y errores con el
//     mensaje de la API. Versión anterior en OlderVersions/Api.getApiResult.20261117.pq
// =============================================

(endpointURL as text,
 endpointType as text,
 apiHeaders as record,
 optional params as nullable text,
 optional pageNum as nullable text,
 optional pageSize as nullable text) =>
let
    // URL base estática + ruta relativa
    parts   = Uri.Parts(endpointURL),
    baseUrl = parts[Scheme] & "://" & parts[Host],
    relPath = Text.TrimStart(parts[Path], "/"),
    isPost  = Text.Upper(endpointType) = "POST",

    // Query para GET: paginación + parámetros adicionales
    extraQuery = if params = null or Text.Trim(params) = "" then []
                 else Uri.Parts("http://x/?" & params)[Query],
    getQuery   = Record.Combine({
                     [page = pageNum ?? "1", page_size = pageSize ?? "10"],
                     extraQuery
                 }),

    options = [
        RelativePath = relPath,
        Headers = apiHeaders,
        ManualStatusHandling = {400, 401, 403, 404, 405, 408, 409, 415, 422, 429, 500, 502, 503, 504}
    ] & (
        if isPost
        then [Content = Text.ToBinary(params ?? "{}")]
        else [Query = getQuery]
    ),

    raw    = Web.Contents(baseUrl, options),
    status = Value.Metadata(raw)[Response.Status],
    body   = Binary.Buffer(raw),
    json   = try Json.Document(body) otherwise null,

    bodyText   = try Text.Start(Text.FromBinary(body), 500) otherwise null,
    apiMessage = try Text.Combine(
                     List.Transform(json[Errors], each Text.From([Code]) & ": " & Text.From([Message])),
                     " | ")
                 otherwise bodyText,

    result =
        if status >= 400 then
            error Error.Record(
                "Api.getApiResult",
                "HTTP " & Text.From(status) & " en /" & relPath & (if apiMessage <> null then " · " & apiMessage else ""),
                [Status = status, Endpoint = endpointURL, Body = bodyText]
            )
        else if json = null then
            error Error.Record(
                "Api.getApiResult",
                "La respuesta de /" & relPath & " no es JSON",
                [Status = status, Endpoint = endpointURL, Body = bodyText]
            )
        else
            json
in
    result
