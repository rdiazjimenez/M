// =============================================
// Function: Siigo.getAllPages
// Description:
//   Descarga todas las páginas de un endpoint GET paginado de Siigo
//   (respuesta {pagination{total_results}, results, _links}).
//   - Pide el token una sola vez para todas las páginas.
//   - Reutiliza la página 1 (no la vuelve a pedir).
// Parameters:
//   - EndpointData (table): tabla de endpoints (Name, ID, endpointUrl, Type)
//   - ApiConnInfo (table | record): tabla de parámetros o headers ya construidos
//   - endpointID (text): ID del endpoint, p. ej. "FV"
//   - getParams (text, opcional): query string sin "?"
//   - pageSize (text, opcional): por defecto "100" (máximo de Siigo)
// Returns:
//   - Tabla con una columna "results" (un record por registro), igual que
//     la salida anterior de Siigo.getFV / getNC / getFC / getCC / getTercero.
// Notes:
//   - Siigo permite 100 peticiones por minuto. Con pageSize 100 son
//     ~10.000 registros por minuto.
// History:
//   - 2026-11-17: creada a partir de la lógica repetida en getFV/getNC/getFC/getCC/getTercero.
// =============================================

(EndpointData as table,
 ApiConnInfo as any,
 endpointID as text,
 optional getParams as nullable text,
 optional pageSize as nullable text) as table =>
let
    size       = pageSize ?? "100",
    apiHeaders = if ApiConnInfo is record
                 then ApiConnInfo
                 else LibPQ("Siigo.getApiConnInfo")(ApiConnInfo),

    getPage = (n as number) =>
        LibPQ("Siigo.getApiData")(EndpointData, apiHeaders, endpointID, getParams, Text.From(n), size),

    firstPage  = getPage(1),
    totalPages = Number.RoundUp(Number.From(firstPage[pagination][total_results]) / Number.From(size)),
    otherPages = List.Transform(List.Numbers(2, List.Max({totalPages - 1, 0})), getPage),
    allPages   = {firstPage} & otherPages,

    results = List.Combine(List.Transform(allPages, each [results])),
    toTable = Table.FromList(results, Splitter.SplitByNothing(), {"results"}, null, ExtraValues.Error)
in
    toTable
