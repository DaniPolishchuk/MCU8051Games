;; ============================================================
;; SNAKE - 8051 Assembly
;; MCU 8051 IDE Simulator
;; Display: 1x LED Matrix 8x8 (Rows=P1, Columns=P0)
;; Input: 4 Tasten an P3.0-P3.3 (aktiv low)
;;   P3.0 = Hoch, P3.1 = Runter, P3.2 = Links, P3.3 = Rechts
;; LED Condition: Row=1, Column=1
;; Dim Interval: 1000
;; ============================================================

;; --- Register-Adressen ---
AR0         EQU 00h
AR1         EQU 01h
AR2         EQU 02h
AR3         EQU 03h
AR4         EQU 04h
AR5         EQU 05h
AR6         EQU 06h
AR7         EQU 07h

;; --- RAM-Adressen ---
SNAKE_DIR   EQU 30h        ; Richtung: 0=hoch,1=runter,2=links,3=rechts
SNAKE_LEN   EQU 31h        ; Aktuelle Laenge
SNAKE_HEAD  EQU 32h        ; Index des Kopfes im Ring-Buffer
FOOD_POS    EQU 33h        ; Futter-Position (High-Nibble=X, Low-Nibble=Y)
GAME_STATE  EQU 34h        ; 0=Warten, 1=Spielen, 2=Game Over
RNG_SEED    EQU 35h        ; Zufall
FRAME_CNT   EQU 36h        ; Frame-Zaehler
MUX_ROW     EQU 37h        ; Aktuelle Multiplex-Zeile
MUX_DELAY   EQU 38h        ; Verzoegerung pro Zeile
SCORE       EQU 39h        ; Punktestand

; Spielfeld: 8 Bytes (1 Byte pro Zeile, Bit=Spalte) - SCHLANGE
FIELD       EQU 40h        ; 40h-47h

; Futter-Feld: 8 Bytes (1 Byte pro Zeile) - FUTTER
FOOD_FIELD  EQU 5Ch        ; 5Ch-63h

; Schlangen-Body: Ring-Buffer, max 20 Segmente
; Jedes Byte: High-Nibble=X(0-7), Low-Nibble=Y(0-7)
SNAKE_BUF   EQU 48h        ; 48h-5Bh (20 Bytes)
SNAKE_MAX   EQU 20         ; Max Schlangenlaenge

;; --- Konstanten ---
GAME_SPEED  EQU 1           ; Jeder Frame ein Game-Tick (schnellste)
MUX_DLY_VAL EQU 10          ; Instruktionen pro Zeile warten

DIR_UP      EQU 0
DIR_DOWN    EQU 1
DIR_LEFT    EQU 2
DIR_RIGHT   EQU 3

;; --- Vektoren ---
        ORG 0000h
        LJMP MAIN

;; --- Lookup-Tabelle ---
        ORG 0020h
BIT_TBL:
        DB 01h, 02h, 04h, 08h, 10h, 20h, 40h, 80h

;; ============================================================
;; MAIN
;; ============================================================
        ORG 0030h
MAIN:
        MOV SP, #70h
        LCALL GAME_INIT

;; === HAUPTSCHLEIFE ===
;; Zeigt eine Zeile an, wartet, naechste Zeile.
;; Nach 8 Zeilen (1 Frame) -> Frame-Counter erhoehen.
;; Nach GAME_SPEED Frames -> Spiellogik.
MAIN_LP:
        LCALL READ_INPUT     ; Tasten JEDEN Durchlauf lesen
        LCALL DISPLAY_ROW
        LCALL MUX_WAIT
        INC MUX_ROW
        MOV A, MUX_ROW
        CJNE A, #8, MAIN_LP
        MOV MUX_ROW, #0
        ;; Ein Frame fertig
        INC FRAME_CNT
        MOV A, FRAME_CNT
        CJNE A, #GAME_SPEED, MAIN_LP
        MOV FRAME_CNT, #0
        ;; Spiellogik
        LCALL GAME_LOGIC
        LCALL BUILD_FIELD
        SJMP MAIN_LP

;; ============================================================
;; MUX_WAIT: Kurze Verzoegerung damit Zeile sichtbar bleibt
;; ============================================================
MUX_WAIT:
        MOV R7, #MUX_DLY_VAL
MW_LP:  NOP
        NOP
        NOP
        NOP
        NOP
        DJNZ R7, MW_LP
        RET

;; ============================================================
;; GAME_INIT
;; ============================================================
GAME_INIT:
        MOV SNAKE_DIR, #DIR_RIGHT
        MOV SNAKE_LEN, #1
        MOV SNAKE_HEAD, #0
        MOV GAME_STATE, #0
        MOV RNG_SEED, #0A7h
        MOV FRAME_CNT, #0
        MOV MUX_ROW, #0
        MOV SCORE, #0

        ;; Schlange initialisieren: 1 Segment in der Mitte
        MOV R0, #SNAKE_BUF
        MOV @R0, #44h       ; X=4, Y=4

        ;; Futter platzieren
        MOV FOOD_POS, #66h   ; X=6, Y=6

        ;; Spielfeld aufbauen
        LCALL BUILD_FIELD
        RET

;; ============================================================
;; BIT_MASK: A = Pos (0-7), return A = (1 << Pos)
;; ============================================================
BIT_MASK:
        MOV DPTR, #BIT_TBL
        MOVC A, @A+DPTR
        RET

;; ============================================================
;; BUILD_FIELD: Spielfeld-Array aus Schlange + Futter aufbauen
;; ============================================================
BUILD_FIELD:
        ;; Schlangen-Feld loeschen
        MOV R0, #FIELD
        MOV R7, #8
BF_CL:  MOV @R0, #00h
        INC R0
        DJNZ R7, BF_CL

        ;; Futter-Feld loeschen
        MOV R0, #FOOD_FIELD
        MOV R7, #8
BF_CL2: MOV @R0, #00h
        INC R0
        DJNZ R7, BF_CL2

        ;; Schlange ins Feld zeichnen
        MOV A, SNAKE_HEAD
        CLR C
        SUBB A, SNAKE_LEN
        INC A
        JNB ACC.7, BF_IDX_OK
        ADD A, #SNAKE_MAX
BF_IDX_OK:
        MOV R1, A
        MOV A, SNAKE_LEN
        MOV R7, A

BF_DRAW:
        MOV A, #SNAKE_BUF
        ADD A, R1
        MOV R0, A
        MOV A, @R0
        MOV R2, A
        ANL A, #0Fh
        ADD A, #FIELD
        MOV R0, A
        MOV A, R2
        SWAP A
        ANL A, #0Fh
        LCALL BIT_MASK
        ORL A, @R0
        MOV @R0, A
        INC R1
        MOV A, R1
        CJNE A, #SNAKE_MAX, BF_NW
        MOV R1, #0
BF_NW:  DJNZ R7, BF_DRAW

        ;; Futter ins FOOD_FIELD zeichnen
        MOV A, FOOD_POS
        MOV R2, A
        ANL A, #0Fh
        ADD A, #FOOD_FIELD
        MOV R0, A
        MOV A, R2
        SWAP A
        ANL A, #0Fh
        LCALL BIT_MASK
        ORL A, @R0
        MOV @R0, A

        RET

;; ============================================================
;; DISPLAY_ROW: Eine Zeile auf die Matrix ausgeben
;; P0 = Columns (Schlange + Futter zusammen), P1 = Row
;; P2 = Futter-Markierung (fuer rote Farbe im IDE-Patch)
;; ============================================================
DISPLAY_ROW:
        ;; Alle aus
        MOV P1, #00h
        MOV P0, #00h
        MOV P2, #00h
        ;; Schlangen-Daten laden
        MOV A, MUX_ROW
        ADD A, #FIELD
        MOV R0, A
        MOV A, @R0
        MOV R2, A            ; R2 = Schlange
        ;; Futter-Daten laden
        MOV A, MUX_ROW
        ADD A, #FOOD_FIELD
        MOV R0, A
        MOV A, @R0
        MOV R3, A            ; R3 = Futter
        ;; P0 = Schlange + Futter (alles sichtbar)
        MOV A, R2
        ORL A, R3
        MOV P0, A
        ;; P2 = nur Futter (Rot-Markierung)
        MOV A, R3
        MOV P2, A
        ;; Zeile aktivieren
        MOV A, MUX_ROW
        LCALL BIT_MASK
        MOV P1, A
        RET

;; ============================================================
;; READ_INPUT: Tasten lesen und Richtung setzen
;; ============================================================
READ_INPUT:
        ;; Warte-Modus: beliebige Taste startet
        MOV A, GAME_STATE
        JNZ RI_PLAY

        MOV A, P3
        ORL A, #0F0h        ; Obere Bits ignorieren
        CJNE A, #0FFh, RI_START
        RET
RI_START:
        MOV GAME_STATE, #1

RI_PLAY:
        ;; Game Over: beliebige Taste -> Neustart
        MOV A, GAME_STATE
        CJNE A, #2, RI_DIR
        MOV A, P3
        ORL A, #0F0h
        CJNE A, #0FFh, RI_RESTART
        RET
RI_RESTART:
        LCALL GAME_INIT
        MOV GAME_STATE, #1
        RET

RI_DIR:
        ;; Richtungstasten pruefen (aktiv low)
        JNB P3.0, RI_UP
        JNB P3.1, RI_DOWN
        JNB P3.2, RI_LEFT
        JNB P3.3, RI_RIGHT
        RET
RI_UP:
        ;; Nicht rueckwaerts erlauben
        MOV A, SNAKE_DIR
        CJNE A, #DIR_DOWN, RI_UP_OK
        RET
RI_UP_OK:
        MOV SNAKE_DIR, #DIR_UP
        RET
RI_DOWN:
        MOV A, SNAKE_DIR
        CJNE A, #DIR_UP, RI_DN_OK
        RET
RI_DN_OK:
        MOV SNAKE_DIR, #DIR_DOWN
        RET
RI_LEFT:
        MOV A, SNAKE_DIR
        CJNE A, #DIR_RIGHT, RI_LF_OK
        RET
RI_LF_OK:
        MOV SNAKE_DIR, #DIR_LEFT
        RET
RI_RIGHT:
        MOV A, SNAKE_DIR
        CJNE A, #DIR_LEFT, RI_RT_OK
        RET
RI_RT_OK:
        MOV SNAKE_DIR, #DIR_RIGHT
        RET

;; ============================================================
;; GAME_LOGIC: Schlange bewegen, Kollision pruefen
;; ============================================================
GAME_LOGIC:
        MOV A, GAME_STATE
        CJNE A, #1, GLG_RET  ; Nur im Spielzustand

        ;; Kopf-Position holen
        MOV A, #SNAKE_BUF
        ADD A, SNAKE_HEAD
        MOV R0, A
        MOV A, @R0           ; A = aktuelle Kopf-XY
        MOV R2, A
        ;; X und Y trennen
        SWAP A
        ANL A, #0Fh
        MOV R3, A            ; R3 = X
        MOV A, R2
        ANL A, #0Fh
        MOV R4, A            ; R4 = Y

        ;; Neue Position berechnen basierend auf Richtung
        MOV A, SNAKE_DIR
        CJNE A, #DIR_UP, GL_D1
        DEC R4               ; Y-1
        SJMP GL_MOVED
GL_D1:  CJNE A, #DIR_DOWN, GL_D2
        INC R4               ; Y+1
        SJMP GL_MOVED
GL_D2:  CJNE A, #DIR_LEFT, GL_D3
        DEC R3               ; X-1
        SJMP GL_MOVED
GL_D3:  ;; DIR_RIGHT
        INC R3               ; X+1

GL_MOVED:
        ;; Wand-Kollision pruefen (0-7 Bereich)
        MOV A, R3
        ANL A, #0F8h        ; Bits 3-7 gesetzt? -> ausserhalb
        JNZ GL_DIE
        MOV A, R4
        ANL A, #0F8h
        JNZ GL_DIE

        ;; Neue Position zusammenbauen
        MOV A, R3
        SWAP A               ; X in High-Nibble
        ORL A, R4            ; Y in Low-Nibble
        MOV R5, A            ; R5 = neue Position XY

        ;; Selbst-Kollision: Pruefen ob neue Pos in Schlange ist
        MOV A, SNAKE_HEAD
        CLR C
        SUBB A, SNAKE_LEN
        INC A
        JNB ACC.7, GL_SC_OK
        ADD A, #SNAKE_MAX
GL_SC_OK:
        MOV R1, A            ; Start-Index
        MOV A, SNAKE_LEN
        MOV R7, A

GL_SC_LP:
        MOV A, #SNAKE_BUF
        ADD A, R1
        MOV R0, A
        MOV A, @R0
        CJNE A, AR5, GL_SC_NX
        ;; Treffer! Selbst-Kollision
        SJMP GL_DIE
GL_SC_NX:
        INC R1
        MOV A, R1
        CJNE A, #SNAKE_MAX, GL_SC_NW
        MOV R1, #0
GL_SC_NW:
        DJNZ R7, GL_SC_LP

        ;; Neuen Kopf einfuegen
        MOV A, SNAKE_HEAD
        INC A
        CJNE A, #SNAKE_MAX, GL_NH_OK
        MOV A, #0
GL_NH_OK:
        MOV SNAKE_HEAD, A
        ADD A, #SNAKE_BUF
        MOV R0, A
        MOV A, R5
        MOV @R0, A           ; Neue Kopfposition speichern

        ;; Futter gefressen?
        MOV A, R5
        CJNE A, FOOD_POS, GL_NO_FOOD
        ;; Ja! Laenge erhoehen
        MOV A, SNAKE_LEN
        CJNE A, #SNAKE_MAX, GL_GROW
        SJMP GL_NEW_FOOD     ; Max erreicht, nicht wachsen
GL_GROW:
        INC SNAKE_LEN
        INC SCORE
GL_NEW_FOOD:
        LCALL PLACE_FOOD
        SJMP GLG_RET

GL_NO_FOOD:
        ;; Kein Futter -> Schlange bleibt gleich lang (Schwanz wird nicht behalten)
        ;; (der Ring-Buffer regelt das automatisch ueber SNAKE_LEN)
        SJMP GLG_RET

GL_DIE:
        LCALL GAME_INIT
        MOV GAME_STATE, #1   ; Sofort weiterspielen
GLG_RET:
        RET

;; ============================================================
;; PLACE_FOOD: Neues Futter an zufaelliger Position
;; ============================================================
PLACE_FOOD:
        LCALL RANDOM
        MOV A, RNG_SEED
        ANL A, #77h          ; X=0-7 (High), Y=0-7 (Low)
        ;; Sicherstellen dass Nibbles < 8
        MOV R2, A
        SWAP A
        ANL A, #07h          ; X begrenzen
        SWAP A
        MOV R3, A
        MOV A, R2
        ANL A, #07h          ; Y begrenzen
        ORL A, R3
        MOV FOOD_POS, A
        RET

;; ============================================================
;; RANDOM (LFSR 8-Bit)
;; ============================================================
RANDOM:
        MOV A, RNG_SEED
        MOV C, ACC.7
        JNB ACC.5, RN1
        CPL C
RN1:    JNB ACC.4, RN2
        CPL C
RN2:    JNB ACC.3, RN3
        CPL C
RN3:    RLC A
        MOV RNG_SEED, A
        RET

;; ============================================================
        END
