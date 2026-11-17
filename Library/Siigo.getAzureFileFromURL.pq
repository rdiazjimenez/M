// =============================================
// Function: Siigo.getAzureFileFromURL
// Description:
//   Descarga el Excel que Siigo deja en Azure Storage (campo file_url de la
//   respuesta de reportes como el Balance de prueba por tercero).
// Returns:
//   - Tabla de Excel.Workbook (hojas/tablas del archivo).
// History:
//   - 2026-11-17: lanza un error descriptivo en vez de devolver texto.
//     Versión anterior en OlderVersions/Siigo.getAzureFileFromURL.20261117.pq
// =============================================

(SiigoAPIResult as any) =>
let
    fileUrl =
        if SiigoAPIResult is record and Record.HasFields(SiigoAPIResult, "file_url") then
            SiigoAPIResult[file_url]
        else
            error Error.Record(
                "Siigo.getAzureFileFromURL",
                "La respuesta de Siigo no trae file_url",
                SiigoAPIResult
            ),
    loaded = try Excel.Workbook(AzureStorage.BlobContents(fileUrl), null, true),
    result =
        if loaded[HasError] then
            error Error.Record(
                "Siigo.getAzureFileFromURL",
                "No se pudo descargar el archivo desde file_url · " & loaded[Error][Message],
                [file_url = fileUrl]
            )
        else
            loaded[Value]
in
    result
