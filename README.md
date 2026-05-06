# Snake - 8051 Assembly (MCU 8051 IDE)

A Snake game written in 8051 Assembly, running in the MCU 8051 IDE Simulator.

## Features

- 8x8 LED matrix playing field
- Green snake, red food (dual-color via IDE patch)
- Arrow keys / WASD control (via IDE patch)
- Flicker-free display thanks to persistent LED states (via IDE patch)
- Auto-reset on collision (wall or self)
- Snake grows when eating food
- Pseudo-random food placement (LFSR)

## Simulator Hardware Configuration

### LED Matrix (8x8)

| Parameter | Value |
|-----------|-------|
| Columns (PORT) | 0 |
| Columns (BIT) | 0, 1, 2, 3, 4, 5, 6, 7 |
| Rows (PORT BIT) | Port 1, Bits 0-7 |
| LED Condition | Row=1, Column=1 |
| Dim Interval | 1000 |
| Mapping | Random |
| Color | Green |

### Simple Keypad (4 keys)

| Key | Port | Bit | Function |
|-----|------|-----|----------|
| A | 3 | 0 | Up |
| B | 3 | 1 | Down |
| C | 3 | 2 | Left |
| D | 3 | 3 | Right |

### Port Assignment

| Port | Function |
|------|----------|
| P0 | LED matrix columns (snake + food) |
| P1 | LED matrix rows |
| P2 | Food marker (for red color, IDE patch) |
| P3.0-P3.3 | Direction keys (active low) |

## How to Play

1. Open project `Snake.mcu8051ide` in the IDE
2. Press F11 (Compile)
3. Set up Virtual HW (LED Matrix + Simple Keypad, see above)
4. Start simulation (F2, then Run)
5. Press any key to start the game
6. Use arrow keys / WASD to steer (Keypad window must have focus)
7. Eat food (red) to grow the snake
8. Hit a wall or yourself to auto-restart

## IDE Modifications

We extended the MCU 8051 IDE source code in two places to make the game
playable. Without these patches, the LED matrix in the simulator does not
work well for games (multiplexing issues, no keyboard input).

### 1. Dual-Color LED Matrix + Persistent Display

**File:** `lib/pale/ledmatrix.tcl` (inside the .app bundle at
`/Applications/MCU8051IDE.app/Contents/Resources/app/lib/pale/ledmatrix.tcl`)

**Problem:** The LED matrix in the simulator only shows the current port state.
With multiplexing (driving one row at a time), LEDs flicker because only the
active row is visible. Additionally, the matrix only supports a single color.

**Solution:** Two new instance variables (`prev_state_green`, `prev_state_red`)
that hold the LED state persistently:

- `prev_state_green(row,col)`: Set to 1 when row is active AND column is active
  (P0). Remains 1 until the row becomes active again and the column is then 0.
  This keeps the snake visible without flickering.

- `prev_state_red(row,col)`: Set to 1 when row is active AND Port 2 (same pin
  as column) is HIGH. Overrides the green color.
  This keeps the food permanently displayed in red.

**Changes in detail:**

```tcl
# New instance variables
private variable prev_state_red
private variable prev_state_green

# Initialization in constructor (for-loop alongside prev_state)
set prev_state_red($j,$i) 0
set prev_state_green($j,$i) 0

# In new_state method, after the image switch:
# 1. Set/clear green flag when row is active
# 2. Apply green flag (LED stays green permanently)
# 3. Set/clear red flag when row is active + check P2
# 4. Apply red flag (overrides green with red)
```

### 2. Keyboard Control for Simple Keypad

**File:** `lib/pale/simplekeypad.tcl` (inside the .app bundle at
`/Applications/MCU8051IDE.app/Contents/Resources/app/lib/pale/simplekeypad.tcl`)

**Problem:** The Simple Keypad only responds to mouse clicks. A game requires
keyboard input.

**Solution:** Keyboard bindings for arrow keys and WASD, plus two new methods
`key_down` (press key) and `key_up` (release key).

**Changes in detail:**

```tcl
# At the end of create_gui, after bindtags:
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

# New methods:
public method key_down {i}  ;# Momentary key press
public method key_up {i}    ;# Key release
```

**Mapping:**
- Key 0 (Up/W) -> Key A -> P3.0
- Key 1 (Down/S) -> Key B -> P3.1
- Key 2 (Left/A) -> Key C -> P3.2
- Key 3 (Right/D) -> Key D -> P3.3

**Note:** The Simple Keypad window must have focus for keyboard events to
register. The bindings are also set on the root window (`.`), so it often
works without explicit focus as well.

## Technical Details (Assembly)

### Memory Layout

| Address | Contents |
|---------|----------|
| 30h-39h | Game variables (direction, length, score, etc.) |
| 40h-47h | Playing field (8 bytes, snake) |
| 48h-5Bh | Snake ring buffer (max 20 segments) |
| 5Ch-63h | Food field (8 bytes) |
| 70h+ | Stack |

### Playing Field Representation

Each snake segment is stored as a byte: high nibble = X (0-7),
low nibble = Y (0-7). The ring buffer allows efficient growth without
shifting data.

### Main Loop

```
MAIN_LP:
    READ_INPUT        <- Read keys every iteration
    DISPLAY_ROW       <- Output one row
    MUX_WAIT          <- Short delay (50 NOPs)
    Next row
    After 8 rows: GAME_LOGIC + BUILD_FIELD
```

No timer interrupts. Everything runs synchronously in the main loop. This
avoids race conditions and works reliably in the simulator.

### Multiplexing

The display is driven row by row (P1 = one row active, P0 = columns).
Thanks to the IDE patches, each LED remains persistently visible until
explicitly cleared.

## Files

| File | Description |
|------|-------------|
| `snake.asm` | Game source code (8051 Assembly) |
| `Snake.mcu8051ide` | IDE project file |
| `snakeLEDMetrix.vhc` | LED matrix virtual hardware config |
| `snakeSimpleKeypad.vhc` | Simple keypad virtual hardware config |

## Requirements

- MCU 8051 IDE (macOS build from github.com/paulscalise1/mcu8051ide-macOS)
- The IDE patches described above must be applied to the installed .app
- Processor: AT89S52, Clock: 12 MHz

## Known Limitations

- Keyboard input sometimes requires holding the key briefly depending on
  simulator speed
- Score is only visible in the RAM window (address 39h)
- Maximum snake length: 20 segments
