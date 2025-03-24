(token as text, partnerId as text) as record => [
    Authorization = "Bearer " & token,
    #"Content-Type" = "application/json",
    #"Partner-Id" = partnerId
]