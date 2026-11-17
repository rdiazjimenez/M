// =============================================
// Function: Siigo.getBalancePrueba
// Description:
//   Balance de prueba de Siigo en el que se decide, por parámetros, qué cuentas
//   traen el detalle por tercero y cuáles vienen consolidadas por cuenta.
//   Combina dos reportes de Siigo:
//     * "BPT" POST /v1/test-balance-report-by-thirdparty → con tercero
//     * "BP"  POST /v1/test-balance-report               → sin tercero (general)
//   Las cuentas sin tercero se piden al balance general, que es mucho más liviano,
//   y se excluyen del reporte por tercero cuando se puede (clases completas).
// Parameters:
//   - filtroBalance (text): body JSON, el mismo de Siigo.getBalancePruebaTercero, p. ej.
//       {"year": 2026, "month_start": 10, "month_end": 10, "includes_tax_difference": false}
//     opcionales: "account_start", "account_end"
//   - EndpointData (table): tabla de endpoints (Name, ID, endpointUrl, Type).
//     Si no tiene el ID "BP", se deduce de la URL de "BPT".
//   - ApiConnInfo (table | record): tabla de parámetros o headers ya construidos
//     con Siigo.getApiConnInfo (recomendado: un solo token para todas las llamadas)
//   - opciones (record, opcional):
//       * DetalleTercero (logical, por defecto true)
//           true  → detalle por tercero, salvo las CuentasSinTercero
//           false → todo el balance sin tercero (solo balance general)
//       * CuentasSinTercero (list de text, o text separado por comas; por defecto {})
//           prefijos de cuenta que se traen sin tercero, p. ej. {"4"} o "4,5,6"
// Returns:
//   - Tabla con las mismas columnas de Siigo.getBalancePruebaTercero.
//     En las cuentas sin tercero, Identificación, Sucursal y Nombre tercero van en null.
// Usage:
//   = LibPQ("Siigo.getBalancePrueba")(FiltroJSON, SiigoEndpoint, Headers, [CuentasSinTercero = {"4"}])
// Notes:
//   - Prefijos de un dígito (clases completas: "4") sí ahorran tiempo: esa clase no
//     se pide al reporte por tercero. Prefijos más largos ("4135") salen correctos
//     pero sin ahorro: la clase se descarga con tercero y se filtra localmente.
//   - Si el filtro ya trae account_start/account_end, el reporte por tercero se pide
//     con ese rango tal cual y la separación se hace localmente.
//   - CUENTA_FINAL_RELLENO: cómo se completa account_end al partir por clases
//     ("3" → "3999999999"). Verificar con Siigo la primera vez.
// History:
//   - 2026-11-17: creada a partir de Siigo.getBalancePruebaTercero.
// =============================================

(filtroBalance as text,
 EndpointData as table,
 ApiConnInfo as any,
 optional opciones as nullable record) as table =>
let
    // ---------- Opciones ----------
    opts           = opciones ?? [],
    detalleTercero = Record.FieldOrDefault(opts, "DetalleTercero", true) ?? true,
    sinTerceroRaw  = Record.FieldOrDefault(opts, "CuentasSinTercero", {}) ?? {},
    sinTerceroList = if sinTerceroRaw is text then Text.Split(sinTerceroRaw, ",") else sinTerceroRaw,
    sinTercero     = List.Select(List.Transform(sinTerceroList, each Text.Trim(Text.From(_))), each _ <> ""),

    CUENTA_FINAL_RELLENO = "999999999",

    esSinTercero = (codigo as nullable text) as logical =>
        if not detalleTercero then true
        else codigo <> null and List.AnyTrue(List.Transform(sinTercero, (p) => Text.StartsWith(codigo, p))),

    // ---------- Un solo token para todas las llamadas ----------
    apiHeaders = if ApiConnInfo is record then ApiConnInfo
                 else LibPQ("Siigo.getApiConnInfo")(ApiConnInfo),

    // ---------- Endpoint del balance general (BP) ----------
    tieneBP   = List.Contains(List.Transform(EndpointData[ID], Text.From), "BP"),
    endpoints = if tieneBP then EndpointData
                else Table.InsertRows(EndpointData, 0, {
                    Record.TransformFields(
                        LibPQ("Siigo.getEndpointData")(EndpointData, "BPT"),
                        {
                            {"ID", each "BP"},
                            {"Name", each "Balance de prueba"},
                            {"endpointUrl", each Text.Replace(_, "test-balance-report-by-thirdparty", "test-balance-report")}
                        },
                        MissingField.Ignore)
                }),

    // ---------- Fechas (igual que Siigo.getBalancePruebaTercero) ----------
    filtro    = Json.Document(filtroBalance),
    yearNum   = filtro[year],
    monthFrom = Number.Min({filtro[month_start], 12}),
    monthTo   = Number.Min({filtro[month_end], 12}),
    startDate = #date(yearNum, monthFrom, 1),
    endDate   = Date.EndOfMonth(#date(yearNum, monthTo, 1)),

    columnas = {"Nivel", "Transaccional", "Código cuenta contable", "Nombre Cuenta contable",
                "Identificación", "Sucursal", "Nombre tercero",
                "Saldo Inicial", "Movimiento Débito", "Movimiento Crédito", "Saldo final",
                "MovimientoDebitoCredito", "Fecha inicio", "Fecha fin"},
    tipos = {
        {"Nivel", type text}, {"Transaccional", type text},
        {"Código cuenta contable", type text}, {"Nombre Cuenta contable", type text},
        {"Identificación", type text}, {"Sucursal", type text}, {"Nombre tercero", type text},
        {"Saldo Inicial", type number}, {"Movimiento Débito", type number},
        {"Movimiento Crédito", type number}, {"Saldo final", type number},
        {"MovimientoDebitoCredito", type number}, {"Fecha inicio", type date}, {"Fecha fin", type date}
    },

    // ---------- Parte CON tercero ----------
    tieneRango = Record.HasFields(filtro, "account_start") or Record.HasFields(filtro, "account_end"),
    clases     = List.Transform({1..9}, Text.From),
    clasesCon  = List.Select(clases, each not List.Contains(sinTercero, _)),

    // Agrupa clases consecutivas en rangos: {"1","2","3","5","6"} → {{"1","3"},{"5","6"}}
    rangos = List.Accumulate(clasesCon, {}, (acc, c) =>
        if List.Count(acc) > 0 and Number.From(List.Last(acc){1}) + 1 = Number.From(c)
        then List.RemoveLastN(acc, 1) & {{List.Last(acc){0}, c}}
        else acc & {{c, c}}),

    bodiesTercero =
        if not detalleTercero or List.Count(clasesCon) = 0 then {}
        else if tieneRango or List.Count(clasesCon) = List.Count(clases) then {filtroBalance}
        else List.Transform(rangos, (r) => Text.FromBinary(Json.FromValue(
                 filtro & [account_start = r{0}, account_end = r{1} & CUENTA_FINAL_RELLENO]))),

    partesTercero = List.Transform(bodiesTercero, (b) =>
        LibPQ("Siigo.getBalancePruebaTercero")(b, endpoints, apiHeaders)),
    conTercero =
        if List.Count(partesTercero) = 0 then #table(columnas, {})
        else Table.SelectRows(
                 Table.Combine(partesTercero),
                 each not esSinTercero(Text.Trim(Text.From([Código cuenta contable])))),

    // ---------- Parte SIN tercero (balance general) ----------
    necesitaGeneral = not detalleTercero or List.Count(sinTercero) > 0,

    leerGeneral = () =>
        let
            apiResult = LibPQ("Siigo.getApiData")(endpoints, apiHeaders, "BP", filtroBalance),
            libro     = LibPQ("Siigo.getAzureFileFromURL")(apiResult),
            hoja      = Table.SelectRows(libro, each [Kind] = "Sheet"){0}[Data],

            // La fila de encabezados es la que empieza con "Nivel"
            col1      = List.Transform(Table.Column(hoja, Table.ColumnNames(hoja){0}),
                                       each Text.Trim(Text.From(_ ?? ""))),
            filaEnc   = List.PositionOf(col1, "Nivel"),
            conEnc    = if filaEnc < 0
                        then error Error.Record("Siigo.getBalancePrueba",
                                 "No se encontró la fila de encabezados (""Nivel"") en el balance general",
                                 [PrimerasFilas = Text.Combine(List.FirstN(col1, 10), " | ")])
                        else Table.PromoteHeaders(Table.Skip(hoja, filaEnc), [PromoteAllScalars = true]),

            requeridas = {"Nivel", "Transaccional", "Código cuenta contable", "Nombre Cuenta contable",
                          "Saldo Inicial", "Movimiento Débito", "Movimiento Crédito", "Saldo final"},
            faltantes  = List.Difference(requeridas, Table.ColumnNames(conEnc)),
            validada   = if List.Count(faltantes) > 0
                         then error Error.Record("Siigo.getBalancePrueba",
                                  "Al balance general le faltan columnas: " & Text.Combine(faltantes, ", "),
                                  [ColumnasEncontradas = Text.Combine(Table.ColumnNames(conEnc), ", ")])
                         else Table.SelectColumns(conEnc, requeridas),

            tipadaCod  = Table.TransformColumns(validada,
                             {{"Código cuenta contable", each if _ = null then null else Text.Trim(Text.From(_)), type text}}),
            // Solo filas de cuenta (quita totales y pies de página)
            soloCuentas = Table.SelectRows(tipadaCod, each
                             [Código cuenta contable] <> null and [Código cuenta contable] <> ""
                             and Text.Contains("0123456789", Text.Start([Código cuenta contable], 1))
                             and esSinTercero([Código cuenta contable])),

            conTerceroNull = Table.AddColumn(Table.AddColumn(Table.AddColumn(soloCuentas,
                                 "Identificación", each null), "Sucursal", each null), "Nombre tercero", each null),
            tipada   = Table.TransformColumnTypes(conTerceroNull, List.Select(tipos, each List.Contains(Table.ColumnNames(conTerceroNull), _{0}))),
            movDC    = Table.AddColumn(tipada, "MovimientoDebitoCredito", each [Movimiento Débito] - [Movimiento Crédito], type number),
            fIni     = Table.AddColumn(movDC, "Fecha inicio", each startDate, type date),
            fFin     = Table.AddColumn(fIni, "Fecha fin", each endDate, type date)
        in
            fFin,

    sinTerceroTabla = if necesitaGeneral then leerGeneral() else #table(columnas, {}),

    // ---------- Resultado ----------
    combinado = Table.Combine({conTercero, sinTerceroTabla}),
    resultado = Table.TransformColumnTypes(
                    Table.SelectColumns(combinado, columnas, MissingField.UseNull), tipos)
in
    resultado
