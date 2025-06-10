(TablaBancoMvto as table, TablaConcepto as table) as table =>
let
    ListaConceptosBase = Table.Column(TablaConcepto, "Concepto"),
    ListaConceptos = List.Sort(
        ListaConceptosBase,
        (a, b) => Value.Compare(Text.Length(b), Text.Length(a))
    ),

    // Add column with first Concepto that matches the start of Descripción
    TransaccionesConConcepto = Table.AddColumn(TablaBancoMvto, "Concepto Banco", each 
        List.First(
            List.Select(ListaConceptos, (c) => Text.StartsWith([Descripción], c))
        ),
        type text
    ),
    AgregarTerceroBanco = Table.AddColumn(TransaccionesConConcepto, "Tercero Banco", each try Text.Range([Descripción], Text.Length([Concepto Banco])) otherwise "", type text),
    CambiarMayus = Table.TransformColumns(AgregarTerceroBanco,{{"Tercero Banco", Text.Upper, type text}}),
    QuitarEspacios = Table.TransformColumns(CambiarMayus,{{"Tercero Banco", Text.Trim, type text}})
in
    QuitarEspacios
