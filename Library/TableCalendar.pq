let
    Source = TableJournal,
    AppendTB = Table.Combine({Source, TableTrialBalance}),
    GetDates = Table.SelectColumns(AppendTB,{"Date"}),
    start = Table.SelectRows(GetDates, let earliest = List.Min(GetDates[Date]) in each [Date] = earliest){0}[Date],
    end = Table.SelectRows(GetDates, let latest = List.Max(GetDates[Date]) in each [Date] = latest){0}[Date],
    Result = fnCalendarTable(start, end)
in
    Result
