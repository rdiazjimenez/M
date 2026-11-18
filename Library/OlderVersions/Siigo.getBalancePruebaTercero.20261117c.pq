// =============================================
// Function: Siigo.getBalancePruebaTercero
// Description:
//   Genera el Balance de prueba por tercero (POST, endpoint "BPT"), descarga el
//   Excel desde file_url y lo devuelve como tabla tipada.
//   Opcionalmente, algunas cuentas se traen SIN tercero (consolidadas por cuenta)
//   desde el balance de prueba general (POST, endpoint "BP"), que es más liviano.
// Parameters:
//   - filtroBalanceTercero (text): body JSON, p. ej.
//       {"year": 2026, "month_start": 1, "month_end": 10, "includes_tax_difference": false}
//     opcionales: "account_start", "account_end"
//   - EndpointData (table): tabla de endpoints. Si no trae el ID "BP", su URL se
//     deduce de la de "BPT".
//   - ApiConnInfo (table | record): tabla de parámetros o headers ya construidos
//     (recomendado record: un solo token para todas las llamadas)
//   - CuentasSinTercero (list | text, opcional): prefijos de cuenta que se traen
//     sin tercero, p. ej. {"4"} o "4,5,6". "*" = todo el balance sin tercero.
//     Si se omite, el resultado es el de siempre (todo con tercero).
// Notes:
//   - month 13 = periodo de cierre; para las columnas de fecha se trata como diciembre.
//   - Prefijos de un dígito (clases: "4") se excluyen del reporte por tercero con
//     account_start/account_end, lo que reduce la descarga. Como Siigo exige que
//     esas cuentas existan, los límites son la primera y la última cuenta (orden de
//     texto) que aparecen en el balance general dentro de cada rango de clases. Prefijos más largos
//     ("4135") salen correctos, pero se filtran localmente (sin ahorro).
//   - Si el filtro ya trae account_start/account_end, el reporte por tercero se pide
//     con ese rango tal cual y la separación se hace localmente.
//   - En las cuentas sin tercero, Identificación, Sucursal y Nombre tercero van en null.
// History:
//   - 2026-11-17 (b): parámetro opcional CuentasSinTercero.
//     Versión anterior en OlderVersions/Siigo.getBalancePruebaTercero.20261117b.pq
//   - 2026-11-17: "Fecha fin" = último día del mes final (antes quedaba el día 1);
//     month_start/month_end = 13 ya no generan error de fecha;
//     no se envían page/page_size a un POST.
//     Versión anterior en OlderVersions/Siigo.getBalancePruebaTercero.20261117.pq
// =============================================

(filtroBalanceTercero as text,
 EndpointData as table,
 ApiConnInfo as any,
 optional CuentasSinTercero as any) =>
let
    // ---------- Parámetros comunes ----------
    filtro    = Json.Document(filtroBalanceTercero),
    yearNum   = filtro[year],
    monthFrom = List.Min({filtro[month_start], 12}),
    monthTo   = List.Min({filtro[month_end], 12}),
    startDate = #date(yearNum, monthFrom, 1),
    endDate   = Date.EndOfMonth(#date(yearNum, monthTo, 1)),

    tipos = {
        {"Nivel", type text}, {"Transaccional", type text},
        {"Código cuenta contable", type text}, {"Nombre Cuenta contable", type text},
        {"Identificación", type text}, {"Sucursal", type text}, {"Nombre tercero", type text},
        {"Saldo Inicial", type number}, {"Movimiento Débito", type number},
        {"Movimiento Crédito", type number}, {"Saldo final", type number}
    },
    columnas = List.Transform(tipos, each _{0}) & {"MovimientoDebitoCredito", "Fecha inicio", "Fecha fin"},

    // Movimiento neto + fechas + tipos (igual para ambos reportes)
    completar = (t as table) as table =>
        let
            movDC = Table.AddColumn(t, "MovimientoDebitoCredito",
                        each [Movimiento Débito] - [Movimiento Crédito], type number),
            fIni  = Table.AddColumn(movDC, "Fecha inicio", each startDate, type date),
            fFin  = Table.AddColumn(fIni, "Fecha fin", each endDate, type date)
        in
            Table.TransformColumnTypes(fFin, tipos),

    // ---------- Reporte por tercero (BPT) ----------
    leerTercero = (body as text, headers as any) as table =>
        let
            apiResult  = LibPQ("Siigo.getApiData")(EndpointData, headers, "BPT", body),
            fileResult = LibPQ("Siigo.getAzureFileFromURL")(apiResult),
            Sheet      = fileResult{[Item = "bal-prueba-por-tercero", Kind = "Sheet"]}[Data],
            sinTop     = Table.Skip(Sheet, 4),
            sinPie     = Table.RemoveLastN(sinTop, 2),
            promoted   = Table.PromoteHeaders(sinPie, [PromoteAllScalars = true])
        in
            completar(promoted),

    // ---------- Opción CuentasSinTercero ----------
    prefijosRaw = if CuentasSinTercero = null then {}
                  else if CuentasSinTercero is text then Text.Split(CuentasSinTercero, ",")
                  else CuentasSinTercero,
    prefijos0   = List.Select(List.Transform(prefijosRaw, each Text.Trim(Text.From(_))), each _ <> ""),
    clases      = List.Transform({1..9}, Text.From),
    prefijos    = if List.Contains(prefijos0, "*") then clases else prefijos0,

    esSinTercero = (codigo) =>
        codigo <> null and List.AnyTrue(List.Transform(prefijos, (p) => Text.StartsWith(Text.Trim(Text.From(codigo)), p))),

    conOpcion = () =>
        let
            headers = if ApiConnInfo is record then ApiConnInfo
                      else LibPQ("Siigo.getApiConnInfo")(ApiConnInfo),

            // Endpoint BP: de la tabla o deducido de BPT
            endpoints =
                if List.Contains(List.Transform(EndpointData[ID], Text.From), "BP") then EndpointData
                else Table.InsertRows(EndpointData, 0, {
                    Record.TransformFields(
                        LibPQ("Siigo.getEndpointData")(EndpointData, "BPT"),
                        {{"ID", each "BP"},
                         {"Name", each "Balance de prueba"},
                         {"endpointUrl", each Text.Replace(_, "test-balance-report-by-thirdparty", "test-balance-report")}},
                        MissingField.Ignore)}),

            // Balance general (BP): da las cuentas sin tercero y los límites de los rangos
            libro   = LibPQ("Siigo.getAzureFileFromURL")(
                          LibPQ("Siigo.getApiData")(endpoints, headers, "BP", filtroBalanceTercero)),
            hoja    = Table.SelectRows(libro, each [Kind] = "Sheet"){0}[Data],
            col1    = List.Transform(Table.Column(hoja, Table.ColumnNames(hoja){0}), each Text.Trim(Text.From(_ ?? ""))),
            filaEnc = List.PositionOf(col1, "Nivel"),
            general = if filaEnc < 0
                      then error Error.Record("Siigo.getBalancePruebaTercero",
                               "No se encontró la fila de encabezados (""Nivel"") en el balance general",
                               [PrimerasFilas = Text.Combine(List.FirstN(col1, 10), " | ")])
                      else Table.PromoteHeaders(Table.Skip(hoja, filaEnc), [PromoteAllScalars = true]),
            requeridas = {"Nivel", "Transaccional", "Código cuenta contable", "Nombre Cuenta contable",
                          "Saldo Inicial", "Movimiento Débito", "Movimiento Crédito", "Saldo final"},
            faltantes  = List.Difference(requeridas, Table.ColumnNames(general)),
            validada   = if List.Count(faltantes) > 0
                         then error Error.Record("Siigo.getBalancePruebaTercero",
                                  "Al balance general le faltan columnas: " & Text.Combine(faltantes, ", "),
                                  [ColumnasEncontradas = Text.Combine(Table.ColumnNames(general), ", ")])
                         else Table.SelectColumns(general, requeridas),
            // Solo filas de cuenta (quita totales y pies)
            codigoTexto = Table.TransformColumns(validada,
                              {{"Código cuenta contable", each Text.Trim(Text.From(_ ?? "")), type text}}),
            soloCuentas = Table.Buffer(Table.SelectRows(codigoTexto, each
                              [Código cuenta contable] <> ""
                              and Text.Contains("0123456789", Text.Start([Código cuenta contable], 1)))),
            sinTercero  = completar(Table.SelectColumns(
                              Table.SelectRows(soloCuentas, each esSinTercero([Código cuenta contable])),
                              List.Transform(tipos, each _{0}), MissingField.UseNull)),
            codigos     = List.Buffer(soloCuentas[Código cuenta contable]),

            // Parte con tercero: rangos de clases consecutivas que no van sin tercero
            clasesCon  = List.Select(clases, each not List.Contains(prefijos, _)),
            rangos     = List.Accumulate(clasesCon, {}, (acc, c) =>
                             if List.Count(acc) > 0 and Number.From(List.Last(acc){1}) + 1 = Number.From(c)
                             then List.RemoveLastN(acc, 1) & {{List.Last(acc){0}, c}}
                             else acc & {{c, c}}),
            tieneRango = Record.HasFields(filtro, "account_start") or Record.HasFields(filtro, "account_end"),
            bodies     =
                if List.Count(clasesCon) = 0 then {}
                else if tieneRango or List.Count(clasesCon) = 9 then {filtroBalanceTercero}
                else List.RemoveNulls(List.Transform(rangos, (r) =>
                         let
                             // Siigo exige cuentas que existan: se usan la primera y la última
                             // cuenta del balance general dentro del rango de clases
                             enRango = List.Select(codigos, each Text.Start(_, 1) >= r{0} and Text.Start(_, 1) <= r{1})
                         in
                             if List.Count(enRango) = 0 then null
                             else Text.FromBinary(Json.FromValue(
                                 filtro & [account_start = List.Min(enRango), account_end = List.Max(enRango)])))),
            conTercero = Table.SelectRows(
                             Table.Combine({#table(columnas, {})} & List.Transform(bodies, each leerTercero(_, headers))),
                             each not esSinTercero([Código cuenta contable]))
        in
            Table.SelectColumns(Table.Combine({conTercero, sinTercero}), columnas),

    resultado = if List.Count(prefijos) = 0
                then leerTercero(filtroBalanceTercero, ApiConnInfo)
                else conOpcion()
in
    resultado
