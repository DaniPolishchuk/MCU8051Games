# Snake - 8051 Assembly (MCU 8051 IDE)

Ein Snake-Spiel in 8051 Assembly, das im MCU 8051 IDE Simulator laeuft.

## Features

- 8x8 LED-Matrix Spielfeld
- Gruene Schlange, rotes Futter (Dual-Color durch IDE-Patch)
- Steuerung ueber Pfeiltasten / WASD (durch IDE-Patch)
- Kein Flackern dank persistenter LED-Zustaende (durch IDE-Patch)
- Auto-Reset bei Kollision (Wand oder Selbst)
- Schlange waechst beim Fressen
- Pseudo-Zufalls Futter-Platzierung (LFSR)

## Hardware-Konfiguration im Simulator

### LED Matrix (8x8)

| Parameter | Wert |
|-----------|------|
| Columns (PORT) | 0 |
| Columns (BIT) | 0, 1, 2, 3, 4, 5, 6, 7 |
| Rows (PORT BIT) | Port 1, Bits 0-7 |
| LED Condition | Row=1, Column=1 |
| Dim Interval | 1000 |
| Mapping | Random |
| Farbe | Green |

### Simple Keypad (4 Tasten)

| Taste | Port | Bit | Funktion |
|-------|------|-----|----------|
| A | 3 | 0 | Hoch |
| B | 3 | 1 | Runter |
| C | 3 | 2 | Links |
| D | 3 | 3 | Rechts |

### Port-Belegung

| Port | Funktion |
|------|----------|
| P0 | LED-Matrix Columns (Schlange + Futter) |
| P1 | LED-Matrix Rows |
| P2 | Futter-Markierung (fuer rote Farbe, IDE-Patch) |
| P3.0-P3.3 | Richtungstasten (aktiv low) |

## Spielanleitung

1. Projekt `Snake.mcu8051ide` in der IDE oeffnen
2. F11 druecken (Compilieren)
3. Virtual HW einrichten (LED Matrix + Simple Keypad, siehe oben)
4. Simulation starten (F2, dann Run)
5. Beliebige Taste druecken → Spiel startet
6. Pfeiltasten / WASD zum Steuern (Keypad-Fenster muss Fokus haben)
7. Futter (rot) fressen → Schlange waechst
8. Wand oder sich selbst treffen → automatischer Neustart

## IDE-Modifikationen

Wir haben den MCU 8051 IDE Quellcode an zwei Stellen erweitert, um das Spiel
spielbar zu machen. Ohne diese Patches funktioniert die LED-Matrix im Simulator
nicht gut fuer Spiele (Multiplexing-Probleme, keine Tastatur-Eingabe).

### 1. Dual-Color LED-Matrix + Persistente Anzeige

**Datei:** `lib/pale/ledmatrix.tcl` (in der .app Bundle unter
`/Applications/MCU8051IDE.app/Contents/Resources/app/lib/pale/ledmatrix.tcl`)

**Problem:** Die LED-Matrix im Simulator zeigt nur den aktuellen Port-Zustand.
Bei Multiplexing (Zeile fuer Zeile ansteuern) blinken die LEDs, weil nur die
aktive Zeile sichtbar ist. Ausserdem unterstuetzt die Matrix nur eine Farbe.

**Loesung:** Zwei neue Instanz-Variablen (`prev_state_green`, `prev_state_red`)
die den LED-Zustand persistent halten:

- `prev_state_green(row,col)`: Wird auf 1 gesetzt wenn Row aktiv UND Column
  aktiv (P0). Bleibt 1 bis Row erneut aktiv wird und Column dann 0 ist.
  → Schlange leuchtet dauerhaft gruen ohne Blinken.

- `prev_state_red(row,col)`: Wird auf 1 gesetzt wenn Row aktiv UND Port 2
  (gleicher Pin wie Column) HIGH ist. Ueberschreibt die gruene Farbe.
  → Futter leuchtet dauerhaft rot.

**Aenderungen im Detail:**

```tcl
# Neue Instanz-Variablen
private variable prev_state_red
private variable prev_state_green

# Initialisierung im Constructor (for-Loop bei prev_state)
set prev_state_red($j,$i) 0
set prev_state_green($j,$i) 0

# In new_state Methode, nach dem image-Switch:
# 1. Green-Flag setzen/loeschen wenn Row aktiv
# 2. Green-Flag anwenden (LED dauerhaft gruen)
# 3. Red-Flag setzen/loeschen wenn Row aktiv + P2 pruefen
# 4. Red-Flag anwenden (ueberschreibt gruen mit rot)
```

### 2. Tastatur-Steuerung fuer Simple Keypad

**Datei:** `lib/pale/simplekeypad.tcl` (in der .app Bundle unter
`/Applications/MCU8051IDE.app/Contents/Resources/app/lib/pale/simplekeypad.tcl`)

**Problem:** Das Simple Keypad reagiert nur auf Mausklicks. Fuer ein Spiel
braucht man Tastatur-Eingabe.

**Loesung:** Keyboard-Bindings fuer Pfeiltasten und WASD, plus zwei neue
Methoden `key_down` (Taste druecken) und `key_up` (Taste loslassen).

**Aenderungen im Detail:**

```tcl
# Am Ende von create_gui, nach bindtags:
foreach w [list $win .] {
    bind $w <KeyPress-Up>      "$this key_down 0"
    bind $w <KeyRelease-Up>    "$this key_up 0"
    bind $w <KeyPress-Down>    "$this key_down 1"
    bind $w <KeyRelease-Down>  "$this key_up 1"
    bind $w <KeyPress-Left>    "$this key_down 2"
    bind $w <KeyRelease-Left>  "$this key_up 2"
    bind $w <KeyPress-Right>   "$this key_down 3"
    bind $w <KeyRelease-Right> "$this key_up 3"
    bind $w <KeyPress-w>       "$this key_down 0"
    bind $w <KeyRelease-w>     "$this key_up 0"
    bind $w <KeyPress-s>       "$this key_down 1"
    bind $w <KeyRelease-s>     "$this key_up 1"
    bind $w <KeyPress-a>       "$this key_down 2"
    bind $w <KeyRelease-a>     "$this key_up 2"
    bind $w <KeyPress-d>       "$this key_down 3"
    bind $w <KeyRelease-d>     "$this key_up 3"
}

# Neue Methoden:
public method key_down {i}  ;# Taste momentan druecken
public method key_up {i}    ;# Taste loslassen
```

**Mapping:**
- Taste 0 (↑/W) → Key A → P3.0
- Taste 1 (↓/S) → Key B → P3.1
- Taste 2 (←/A) → Key C → P3.2
- Taste 3 (→/D) → Key D → P3.3

**Hinweis:** Das Simple Keypad Fenster muss den Fokus haben damit die
Tastatur-Events ankommen. Die Bindings werden auch auf das Root-Fenster (`.`)
gesetzt, sodass es oft auch ohne expliziten Fokus funktioniert.

## Technische Details (Assembly)

### Speicher-Layout

| Adresse | Inhalt |
|---------|--------|
| 30h-39h | Spielvariablen (Richtung, Laenge, Score, etc.) |
| 40h-47h | Spielfeld (8 Bytes, Schlange) |
| 48h-5Bh | Schlangen-Ring-Buffer (max 20 Segmente) |
| 5Ch-63h | Futter-Feld (8 Bytes) |
| 70h+ | Stack |

### Spielfeld-Darstellung

Jedes Segment der Schlange wird als Byte gespeichert: High-Nibble = X (0-7),
Low-Nibble = Y (0-7). Der Ring-Buffer erlaubt effizientes Wachsen ohne
Verschieben.

### Hauptschleife

```
MAIN_LP:
    READ_INPUT        ← Tasten bei jedem Durchlauf lesen
    DISPLAY_ROW       ← Eine Zeile ausgeben
    MUX_WAIT          ← Kurz warten (50 NOPs)
    Naechste Zeile
    Nach 8 Zeilen: GAME_LOGIC + BUILD_FIELD
```

Kein Timer-Interrupt. Alles synchron in der Hauptschleife. Das vermeidet
Race-Conditions und funktioniert zuverlaessig im Simulator.

### Multiplexing

Das Display wird zeilenweise angesteuert (P1 = eine Zeile aktiv, P0 = Spalten).
Dank der IDE-Patches bleibt jede LED persistent sichtbar bis sie explizit
geloescht wird.

## Dateien

| Datei | Beschreibung |
|-------|-------------|
| `snake.asm` | Spiel-Quellcode (8051 Assembly) |
| `Snake.mcu8051ide` | IDE-Projektdatei |
| `ANLEITUNG.txt` | Kurze Einrichtungsanleitung |

## Voraussetzungen

- MCU 8051 IDE (macOS Build von github.com/paulscalise1/mcu8051ide-macOS)
- Die oben beschriebenen Patches muessen in der installierten .app angewendet sein
- Processor: AT89S52, Clock: 12 MHz

## Bekannte Einschraenkungen

- Die Tastatur-Eingabe erfordert manchmal laengeres Druecken je nach
  Simulator-Geschwindigkeit
- Score ist nur im RAM-Fenster sichtbar (Adresse 39h)
- Maximale Schlangenlaenge: 20 Segmente
