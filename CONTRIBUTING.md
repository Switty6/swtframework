# Cum să contribui

Salut! Mă bucur că vrei să contribui la SWT Framework. Iată cum poți ajuta:

## Dacă găsești un bug

Spune-mi ce s-a întâmplat:
- Ce ai făcut când a apărut problema
- Ce eroare ai primit (dacă e cazul)
- Pe ce versiune rulezi framework-ul

## Dacă vrei să adaugi ceva nou

1. Fă fork la repo
2. Creează un branch nou: `git checkout -b feature/ceva-tare`
3. Adaugă codul tău
4. Testează că merge
5. Fă un Pull Request și spune-mi ce ai adăugat

## Cum să scrii codul

Încearcă să urmezi aceste reguli simple:

- Folosește tab/4 spatii pentru indentare
- Numele variabilelor în camelCase: `playerData`, `databaseConfig`
- Numele funcțiilor tot în camelCase: `getPlayerData()`
- Constantele cu majuscule: `MAX_PLAYERS`
- Adaugă comentarii dacă codul e complicat

### Exemplu:

```lua
local function getPlayerData(playerId)
    if not playerId then
        return nil
    end
    
    local playerData = SWT.GetPlayer(playerId)
    return playerData
end
```

## Commit messages

Scrie ceva de genul: `feat: adaugă sistem de cache` sau `fix: corectează bug-ul cu baza de date`

Nu trebuie să fie foarte formal, doar să înțeleg ce ai făcut.

## Unde să pui codul

```
swtframework/
├── config.lua          # Configurații
├── fxmanifest.lua      # Manifest FiveM
├── server/             # Scripturi server
│   ├── main.lua        # Punct de intrare
│   ├── database.lua    # Logica bazei de date
│   ├── cache.lua       # Sistem de cache
│   └── events.lua      # Event handlers
└── utils/              # Utilitare
    └── logger.lua      # Sistem de logging
```

## Ai întrebări?

Deschide un issue pe GitHub sau dă-mi un mesaj. Nu ezita să întrebi!
