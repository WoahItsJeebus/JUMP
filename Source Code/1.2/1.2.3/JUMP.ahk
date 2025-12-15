#Requires AutoHotkey >=2.0.19
#SingleInstance Force

CoordMode("Mouse", "Screen")
CoordMode("Menu", "Screen")
SetTitleMatchMode 2
DetectHiddenWindows(true)

global version := "1.2.3"
global APP := MinesweeperApp()

; ----------------------------
; Minesweeper GUI
; ----------------------------
class MinesweeperApp {
    __New() {
        this.CellSize := 22
        this.Padding  := 10
        this.HeaderH  := 40 + (this.Padding * 2)
		
        this.HiddenBg   := 0xBDBDBD
        this.RevealBg   := 0xE6E6E6
        this.MineBg     := 0xFFB0B0
        this.FlagColor  := 0xCC0000
        this.TextColor  := 0x000000

		this.CustomCfg := { W: 9, H: 9, Mines: 10 } ; default custom
		this.Mode := "Beginner"

        this.Gui := Gui("+Resize", "JUMP - Minesweeper")
        this.Gui.SetFont("s10", "Segoe UI")
		
		; Menu bar
		this.MBar := MenuBar()
		this.Gui.MenuBar := this.MBar
		this.Gui.MarginX := this.Padding
		this.Gui.MarginY := this.Padding

		; Game menu
		this.GameMenu := Menu()
		this.GameMenu.Add("New Game", (*) => this.NewGame("Beginner (9x9, 10 Mines)"))
		this.MBar.Add("Game", this.GameMenu)
		
		; Script menu
		this.ScriptMenu := Menu()
		this.ScriptMenu.Add("Reload", reloadScript.Bind())
		this.ScriptMenu.Add("About", (*) => MsgBox("Jeebus' Unoptimized Minesweeper Player (JUMP)`nVersion " version "`n`nA simple Minesweeper clone built with AutoHotkey v2.0.19.`n`n(c) 2025 WoahItsJeebus", "About JUMP", "Iconi"))
		this.MBar.Add("Script", this.ScriptMenu)

		; Add difficulty levels as submenu of script menu
		this.DifficultyMenu := Menu()
		this.DifficultyMenu.Add("Beginner (9x9, 10 Mines)", (*) => this.NewGame("Beginner (9x9, 10 Mines)"))
		this.DifficultyMenu.Add("Intermediate (16x16, 40 Mines)", (*) => this.NewGame("Intermediate (16x16, 40 Mines)"))
		this.DifficultyMenu.Add("Expert (30x16, 99 Mines)", (*) => this.NewGame("Expert (30x16, 99 Mines)"))
		this.DifficultyMenu.Add("Custom...", (*) => this.PromptCustomDifficulty())
		this.GameMenu.Add("Difficulty", this.DifficultyMenu)

		; Visuals menu
		this.VisualsMenu := Menu()
		this.VisualsMenu.Add("Cell Size: " this.CellSize "px", (*) => this.setCellSize())
		this.MBar.Add("Visuals", this.VisualsMenu)
		
		this.TxtMode := this.Gui.AddText("x10 y5 w200 Center Section", "")
        this.TxtMines := this.Gui.AddText("x10 y+m w80 Left", "Mines: 0")
        this.TxtTime  := this.Gui.AddText("x+m yp w80 Right", "Time: 0")
		
        this.TimerFn := ObjBindMethod(this, "Tick")

        this.Cells := []
        this.CellByHwnd := Map()

        ; hook mouse clicks globally
        OnMessage(0x0201, WM_LBUTTONDOWN) ; WM_LBUTTONDOWN
        OnMessage(0x0204, WM_RBUTTONDOWN) ; WM_RBUTTONDOWN


        ; keep header controls aligned while allowing window resizing
        this._InLayout := false
        this.Gui.OnEvent("Size", ObjBindMethod(this, "OnSize"))

        
        ; throttle heavy grid relayout during live resizing
        this._SizeArmed := false
        this._PendingW := 0
        this._PendingH := 0
        this._PendingMinMax := 0
        this._SizeTimerFn := ObjBindMethod(this, "_ApplyPendingSize")
		
        this.Gui.Show("Hide")

        this.NewGame("Beginner (9x9, 10 Mines)")

        this.Gui.Title := "JUMP - Minesweeper"
        ; NewGame() computes an ideal size for the current grid.
        this.Gui.Show("Center")
    }

	setCellSize() {
		local oldName := "Cell Size: " this.CellSize "px"
		input := InputBox("Enter new cell size in pixels (minimum 16):", "Cell Size: " this.CellSize, "H100")
		if (input = "")
			return
		newSize := this._ParseInt(input.Value, this.CellSize)
		if (newSize < 16) {
			MsgBox("Cell size must be at least 16 pixels.", "Invalid Size", "Icon!")
			return
		}
		
		this.VisualsMenu.Rename(oldName, "Cell Size: " newSize "px")
		this.CellSize := newSize
		this.NewGame("Custom")
	}

    NewGame(modeText) {
        this.StopTimer()

        ; *** FIX: Always tear down the previous grid first ***
        this.DestroyGrid()
		
        this.GameOver := false
        this.FirstClick := true
        this.RevealedCount := 0
        this.FlagCount := 0
        this.StartTick := 0
        this.Elapsed := 0

        cfg := this.ModeToConfig(modeText)
        this.W := cfg.W, this.H := cfg.H, this.Mines := cfg.Mines, this.Mode := this._parseMode(modeText)
        this.Total := this.W * this.H

        ; data arrays (1-based)
        this.HasMine  := []
        this.Adj      := []
        this.Revealed := []
        this.Flagged  := []
        Loop this.Total {
            this.HasMine.Push(false)
            this.Adj.Push(0)
            this.Revealed.Push(false)
            this.Flagged.Push(false)
        }
        this.UpdateStatus()
		this.Gui.Title := "JUMP - Minesweeper"
		this.TxtMode.Text := this.Mode " — (" this.W "x" this.H ", " this.Mines " Mines)"
        this.TxtTime.Text := "Time: 0"

		this.ApplyIdealSize()

        this.BuildGrid()

        ; Re-layout everything against the *actual* current client size.
        this._GetClientSize(this.Gui.Hwnd, &cw, &ch)
        this.LayoutAll(cw, ch)
	}

	_parseMode(modeText) {
		if InStr(modeText, "Beginner")
			return "Beginner"
		else if InStr(modeText, "Intermediate")
			return "Intermediate"
		else if InStr(modeText, "Expert")
			return "Expert"
		else if InStr(modeText, "Custom")
			return "Custom"
		else
			return "Unknown"
	}

	PromptCustomDifficulty() {
		defW := 9, defH := 9, defM := 10
		if IsObject(this.CustomCfg) {
			defW := this.CustomCfg.W
			defH := this.CustomCfg.H
			defM := this.CustomCfg.Mines
		}

		MIN_W := 5, MAX_W := 60
		MIN_H := 5, MAX_H := 40

		dlg := Gui("+Owner" this.Gui.Hwnd " -MinimizeBox -MaximizeBox", "Custom Difficulty")
		dlg.SetFont("s10", "Segoe UI")

		dlg.AddText("x12 y12 w80", "Width:")
		edtW := dlg.AddEdit("x100 y10 w90 Number", defW)
		dlg.AddUpDown("Range" MIN_W "-" MAX_W, defW)

		dlg.AddText("x12 y42 w80", "Height:")
		edtH := dlg.AddEdit("x100 y40 w90 Number", defH)
		dlg.AddUpDown("Range" MIN_H "-" MAX_H, defH)

		dlg.AddText("x12 y72 w80", "Mines:")
		edtM := dlg.AddEdit("x100 y70 w90 Number", defM)
		; mines range depends on W/H, so we validate on OK

		info := dlg.AddText("x12 y102 w240", "Tip: Mines must be <= (W*H - 9)`n(to keep first click + 3×3 safe).")

		btnOK := dlg.AddButton("x52 y140 w80 Default", "OK")
		btnCancel := dlg.AddButton("x142 y140 w80", "Cancel")

		btnCancel.OnEvent("Click", (*) => dlg.Destroy())

		okClicked(*) {
			w := this._ParseInt(edtW.Value, defW)
			h := this._ParseInt(edtH.Value, defH)
			; clamp W/H
			w := this._Clamp(w, MIN_W, MAX_W)
			h := this._Clamp(h, MIN_H, MAX_H)

			total := w * h

			; enforce at least 1 mine, and at most total-9 for guaranteed 3x3 safe
			maxM := total - 9
			if (maxM < 1)
				maxM := 1

			m := this._ParseInt(edtM.Value, defM)
			m := this._Clamp(m, 1, maxM)

			if (this._ParseInt(edtM.Value, m) != m) {
				MsgBox "Mines adjusted to " m " (allowed: 1.." maxM ").", "Custom Difficulty", "Icon!"
			}

			this.CustomCfg := { W: w, H: h, Mines: m }
			dlg.Destroy()
			this.NewGame("Custom")
		}
		
		btnOK.OnEvent("Click", okClicked)
		dlg.Show("AutoSize Center")
	}

	_Clamp(v, lo, hi) {
		if (v < lo)
			return lo
		if (v > hi)
			return hi
		return v
	}

	_ParseInt(val, fallback := 0) {
		; safe integer parse for AHK v2
		try {
			n := Integer(val)
			return n
		} catch {
			return fallback
		}
	}

    ModeToConfig(modeText) {
		if InStr(modeText, "Beginner")
				return { W: 9, H: 9, Mines: 10 }
		else if InStr(modeText, "Intermediate")
			return { W: 16, H: 16, Mines: 40 }
		else if InStr(modeText, "Expert")
			return { W: 30, H: 16, Mines: 99 }
		else if InStr(modeText, "Custom")
			; if user hasn't set one yet, fall back
			return IsObject(this.CustomCfg) ? this.CustomCfg : { W: 9, H: 9, Mines: 10 }
		else ; Return a default set
			return { W: 9, H: 9, Mines: 10 }
	}

    ; ---------- layout / sizing ----------
    GetIdealClientSize() {
        ; Desired *client* size, based on grid dimensions + padding.
        gridW := this.W * this.CellSize
        gridH := this.H * this.CellSize

        clientW := (this.Padding * 2) + gridW
        clientH := this.HeaderH + gridH + this.Padding  ; bottom breathing room

        return { W: clientW, H: clientH }
    }

    ApplyIdealSize() {
        if !IsObject(this.Gui) || !this.Gui.Hwnd
            return

        sz := this.GetIdealClientSize()

        ; Snap the window to the exact grid size (AutoSize won't reliably shrink).
        this._SetClientSize(sz.W, sz.H)

        ; Prevent resizing smaller than the grid (otherwise controls get clipped).
        try this.Gui.Opt("+MinSize" sz.W "x" sz.H)

        this._LastClientW := sz.W
        this._LastClientH := sz.H

        ; Layout header + (if present) grid against the new client size.
        this.LayoutAll(sz.W, sz.H)
    }

    LayoutAll(clientW, clientH) {
        this.LayoutHeader(clientW)
        this.LayoutGrid(clientW, clientH)
    }

    ComputeGridOrigin(clientW, clientH) {
        gridW := this.W * this.CellSize
        gridH := this.H * this.CellSize

        ; Center in client area, but never push tighter than padding/header.
        ox := Floor((clientW - gridW) / 2)
        oy := this.HeaderH + Floor(((clientH - this.HeaderH) - gridH) / 2)

        if (ox < this.Padding)
            ox := this.Padding
        if (oy < this.HeaderH)
            oy := this.HeaderH

        return { X: ox, Y: oy }
    }

    LayoutGrid(clientW, clientH) {
        ; No grid yet? still compute origin so BuildGrid can use it.
        origin := this.ComputeGridOrigin(clientW, clientH)
        this.GridOriginX := origin.X
        this.GridOriginY := origin.Y

        if (this.Cells.Length = 0)
            return

        ; Move all cell controls to keep the grid centered.
        Loop this.Total {
            idx := A_Index
            x := this.XFromIdx(idx)
            y := this.YFromIdx(idx)

            px := this.GridOriginX + (x - 1) * this.CellSize
            py := this.GridOriginY + (y - 1) * this.CellSize

            try this.Cells[idx].Move(px, py, this.CellSize, this.CellSize)
        }

		for _, tile in this.Cells {
			; compute x,y for this tile
			; tile.Move(,, this.CellSize, this.CellSize)
			
			tile.Redraw()
		}

		; Best: redraw once at the end (fast + fixes artifacts)
		ForceRedrawHwnd(this.Gui.Hwnd)
    }

    _ApplyPendingSize() {
        this._SizeArmed := false

        if (this._PendingMinMax = 1) ; minimized
            return

        if this._InLayout
            return

        this._InLayout := true
        try this.LayoutAll(this._PendingW, this._PendingH)
        finally this._InLayout := false
    }

    LayoutHeader(clientW) {
        if !IsObject(this.Gui)
            return

        ; clientW here is the *client* width.
        pad := this.Padding
        gap := pad
        avail := clientW - (pad * 2)

        ; Guard against weird edge cases (shouldn't happen with MinSize, but still).
        if (avail < 100)
            avail := 100

        half := Floor((avail - gap) / 2)
        if (half < 40)
            half := 40

        xMine := pad
        xTime := pad + half + gap

        ; Mode centered across the full width.
        this.TxtMode.Move(pad,, avail,)

        ; Left/right status blocks.
        this.TxtMines.Move(xMine,, half,)
        this.TxtTime.Move(xTime,, half,)

        this.TxtMode.Redraw()
        this.TxtMines.Redraw()
        this.TxtTime.Redraw()
    }

    OnSize(guiObj, MinMax, Width, Height) {
        ; Width/Height are client dimensions.
        ; MinMax: 0 = restored, 1 = minimized, 2 = maximized
        if (MinMax = 1)
            return

        ; Ignore our own programmatic resizing.
        if this._InLayout
            return

        this._PendingMinMax := MinMax
        this._PendingW := Width
        this._PendingH := Height
        this._LastClientW := Width
        this._LastClientH := Height

        ; Throttle: moving hundreds of controls on every mouse-move is expensive.
        if !this._SizeArmed {
            this._SizeArmed := true
            SetTimer(this._SizeTimerFn, -15)
        }
    }

    _SetClientSize(targetW, targetH) {
        hwnd := this.Gui.Hwnd
        if !hwnd
            return

        try {
            mm := WinGetMinMax("ahk_id " hwnd)
            if (mm != 0)
                WinRestore("ahk_id " hwnd)
        }

        ; Current outer size
        WinGetPos(,, &outerW, &outerH, "ahk_id " hwnd)

        ; Current client size
        this._GetClientSize(hwnd, &clientW, &clientH)

        ; Convert desired client size -> outer size, preserving borders/title/menu.
        deltaW := outerW - clientW
        deltaH := outerH - clientH

        this._InLayout := true
        try this.Gui.Move(,, targetW + deltaW, targetH + deltaH)
        finally this._InLayout := false
    }

    _GetClientSize(hwnd, &w, &h) {
        rc := Buffer(16, 0)
        DllCall("GetClientRect", "ptr", hwnd, "ptr", rc)
        w := NumGet(rc, 8, "int")   ; right
        h := NumGet(rc, 12, "int")  ; bottom
    }


    DestroyGrid() {
        ; Tear down the previous grid cleanly so the GUI can *shrink* as well as grow.
        for ctrl in this.Cells {
            try {
                if IsObject(ctrl)
                    ctrl.Destroy() ; preferred (also removes from AHK's internal control list)
            } catch {
                try {
                    if IsObject(ctrl) && ctrl.Hwnd
                        DllCall("DestroyWindow", "ptr", ctrl.Hwnd)
                }
            }
        }
        this.Cells := []
        this.CellByHwnd := Map()

        ; Force the GUI to repaint (prevents "ghost" artifacts)
        if IsObject(this.Gui) && this.Gui.Hwnd {
            ; RDW_INVALIDATE(0x1) | RDW_ERASE(0x4) | RDW_ALLCHILDREN(0x80)
            DllCall("RedrawWindow", "ptr", this.Gui.Hwnd, "ptr", 0, "ptr", 0, "uint", 0x1|0x4|0x80)
        }
    }

    BuildGrid() {
        baseX := this.Padding
        baseY := this.HeaderH

        ; Place the grid based on the *current* client size (centered).
        if IsObject(this.Gui) && this.Gui.Hwnd {
            this._GetClientSize(this.Gui.Hwnd, &cw, &ch)
            origin := this.ComputeGridOrigin(cw, ch)
            baseX := origin.X
            baseY := origin.Y
            this.GridOriginX := baseX
            this.GridOriginY := baseY
        }

        ; make grid
        Loop this.H {
            y := A_Index
            Loop this.W {
                x := A_Index
                idx := this.Idx(x, y)

                px := baseX + (x-1) * this.CellSize
                py := baseY + (y-1) * this.CellSize

                ; SS_NOTIFY (0x100) helps make static controls clickable in some themes
                ctrl := this.Gui.AddText(
                    Format("x{} y{} w{} h{} Border Center 0x100", px, py, this.CellSize, this.CellSize),
                    ""
                )
                this.Cells.Push(ctrl)
                this.CellByHwnd[ctrl.Hwnd] := idx

                this.SetCellHiddenVisual(idx)
            }
        }
    }

    ; ---------- click routing ----------
    HandleClick(btn, ctrlHwnd) {
        if this.GameOver
            return

        if !this.CellByHwnd.Has(ctrlHwnd)
            return

        idx := this.CellByHwnd[ctrlHwnd]

        if (btn = "L")
            this.Reveal(idx)
        else if (btn = "R")
            this.ToggleFlag(idx)
    }

    ; ---------- game logic ----------
    Reveal(idx) {
        if this.Revealed[idx] || this.Flagged[idx]
            return

        if this.FirstClick {
            this.FirstClick := false
            this.GenerateField(idx)
            this.StartTimer()
        }

        if this.HasMine[idx] {
            this.RevealMineAndLose(idx)
            return
        }

        this.RevealCell(idx)

        ; flood reveal if zero
        if (this.Adj[idx] = 0)
            this.FloodReveal(idx)

        this.CheckWin()
    }

    ToggleFlag(idx) {
        if this.Revealed[idx]
            return

        if this.Flagged[idx] {
            this.Flagged[idx] := false
            this.FlagCount -= 1
            this.SetCellHiddenVisual(idx)
        } else {
            this.Flagged[idx] := true
            this.FlagCount += 1
            this.SetCellFlagVisual(idx)
        }
        this.UpdateStatus()
    }

    RevealCell(idx) {
        if this.Revealed[idx]
            return
        this.Revealed[idx] := true
        this.RevealedCount += 1

        ctrl := this.Cells[idx]
        this.SetBg(ctrl, this.RevealBg)

        n := this.Adj[idx]
        if (n > 0) {
            ctrl.Text := n
            this.SetTextColor(ctrl, this.NumberColor(n))
            ctrl.SetFont("Bold")
        } else {
            ctrl.Text := ""
            this.SetTextColor(ctrl, this.TextColor)
            ctrl.SetFont("Norm")
        }
    }

    FloodReveal(startIdx) {
        ; BFS using array + pointer (fast)
        q := [startIdx]
        qi := 1

        while (qi <= q.Length) {
            cur := q[qi]
            qi += 1

            x := this.XFromIdx(cur)
            y := this.YFromIdx(cur)

            for nIdx in this.Neighbors(x, y) {
                if this.Revealed[nIdx] || this.Flagged[nIdx]
                    continue
                if this.HasMine[nIdx]
                    continue

                this.RevealCell(nIdx)

                if (this.Adj[nIdx] = 0)
                    q.Push(nIdx)
            }
        }
    }

    CheckWin() {
        if (this.RevealedCount >= (this.Total - this.Mines)) {
            this.GameOver := true
            this.StopTimer()

            ; show remaining mines as flags (optional)
            Loop this.Total {
                i := A_Index
                if this.HasMine[i] && !this.Flagged[i] {
                    this.Flagged[i] := true
                    this.SetCellFlagVisual(i)
                }
            }

            MsgBox("You win 🎉`nTime: " this.Elapsed "s", "JUMP - Minesweeper", "Iconi")
        }
    }

    RevealMineAndLose(triggerIdx) {
        this.GameOver := true
        this.StopTimer()

        ; reveal all mines
        Loop this.Total {
            i := A_Index
            if this.HasMine[i] {
                ctrl := this.Cells[i]
                this.SetBg(ctrl, this.MineBg)
                this.SetTextColor(ctrl, 0x000000)
                ctrl.SetFont("Bold")
                ctrl.Text := "💣"
            }
        }

        MsgBox("Boom. You hit a mine.`nTime: " this.Elapsed "s", "JUMP - Minesweeper", "Iconx")
    }

    ; ---------- field generation ----------
    GenerateField(firstIdx) {
        ; Make a 3x3 safe zone around first click
        safe := Map()
        fx := this.XFromIdx(firstIdx)
        fy := this.YFromIdx(firstIdx)

        for sIdx in this.NeighborsInclusive(fx, fy)
            safe[sIdx] := true

        ; candidates for mines
        candidates := []
        Loop this.Total {
            i := A_Index
            if !safe.Has(i)
                candidates.Push(i)
        }

        ; shuffle candidates (Fisher–Yates)
        n := candidates.Length
        Loop n {
            i := n - A_Index + 1
            if (i <= 1)
                break
            j := Random(1, i)
            tmp := candidates[i]
            candidates[i] := candidates[j]
            candidates[j] := tmp
        }

        ; place mines
        Loop this.Mines {
            mIdx := candidates[A_Index]
            this.HasMine[mIdx] := true
        }

        ; compute adjacency counts
        Loop this.Total {
            idx := A_Index
            if this.HasMine[idx] {
                this.Adj[idx] := 0
                continue
            }
            x := this.XFromIdx(idx)
            y := this.YFromIdx(idx)
            count := 0
            for nIdx in this.Neighbors(x, y)
                if this.HasMine[nIdx]
                    count += 1
            this.Adj[idx] := count
        }
    }

    ; ---------- visuals ----------
    SetCellHiddenVisual(idx) {
        ctrl := this.Cells[idx]
        this.SetBg(ctrl, this.HiddenBg)
        this.SetTextColor(ctrl, this.TextColor)
        ctrl.SetFont("Norm")
        ctrl.Text := ""
    }

    SetCellFlagVisual(idx) {
        ctrl := this.Cells[idx]
        this.SetBg(ctrl, this.HiddenBg)
        this.SetTextColor(ctrl, this.FlagColor)
        ctrl.SetFont("Bold")
        ctrl.Text := "⚑"
    }

    SetBg(ctrl, rgb) => ctrl.Opt("Background" Format("{:06X}", rgb))
    SetTextColor(ctrl, rgb) => ctrl.Opt("c" Format("{:06X}", rgb))

    NumberColor(n) {
        switch n {
            case 1: return 0x0000CC
            case 2: return 0x008800
            case 3: return 0xCC0000
            case 4: return 0x000088
            case 5: return 0x880000
            case 6: return 0x008888
            case 7: return 0x000000
            case 8: return 0x666666
        }
        return this.TextColor
    }

    UpdateStatus() {
        left := this.Mines - this.FlagCount
        this.TxtMines.Text := "Mines: " left
    }

    ; ---------- timer ----------
    StartTimer() {
        this.StartTick := A_TickCount
        this.Elapsed := 0
        SetTimer(this.TimerFn, 200)
    }

    StopTimer() => SetTimer(this.TimerFn, 0)

    Tick() {
        if this.GameOver || this.FirstClick
            return
        secs := Floor((A_TickCount - this.StartTick) / 1000)
        if (secs != this.Elapsed) {
            this.Elapsed := secs
            this.TxtTime.Text := "Time: " secs
        }
    }

    ; ---------- indexing / neighbors ----------
    Idx(x, y) => (y - 1) * this.W + x
    XFromIdx(idx) => Mod(idx - 1, this.W) + 1
    YFromIdx(idx) => Floor((idx - 1) / this.W) + 1

    Neighbors(x, y) {
        out := []
        Loop 3 {
            dy := A_Index - 2
            Loop 3 {
                dx := A_Index - 2
                if (dx = 0 && dy = 0)
                    continue
                nx := x + dx
                ny := y + dy
                if (nx < 1 || nx > this.W || ny < 1 || ny > this.H)
                    continue
                out.Push(this.Idx(nx, ny))
            }
        }
        return out
    }

    NeighborsInclusive(x, y) {
        out := []
        Loop 3 {
            dy := A_Index - 2
            Loop 3 {
                dx := A_Index - 2
                nx := x + dx
                ny := y + dy
                if (nx < 1 || nx > this.W || ny < 1 || ny > this.H)
                    continue
                out.Push(this.Idx(nx, ny))
            }
        }
        return out
    }
}

; ----------------------------
; Windows message handlers
; ----------------------------
WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global APP
    if !IsObject(APP) || !IsObject(APP.Gui)
        return
    MouseGetPos(,, &winHwnd, &ctrlHwnd, 2)
    if (winHwnd != APP.Gui.Hwnd)
        return
    APP.HandleClick("L", ctrlHwnd)
}

WM_RBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global APP
    if !IsObject(APP) || !IsObject(APP.Gui)
        return
    MouseGetPos(,, &winHwnd, &ctrlHwnd, 2)
    if (winHwnd != APP.Gui.Hwnd)
        return
    APP.HandleClick("R", ctrlHwnd)
}

; =======================
;  MISC FUNCTIONS
; =======================
reloadScript(*) {
	local MainGui := APP ? APP.Gui : ""

	; Hide the GUI to avoid flicker
	if MainGui
		MainGui.Destroy()

	; Reload the script
	Reload()
}

; Forces a real redraw of a HWND (control or gui)
ForceRedrawHwnd(hwnd) {
    static RDW_INVALIDATE := 0x1
         , RDW_ERASE      := 0x4
         , RDW_UPDATENOW  := 0x100
         , RDW_ALLCHILDREN:= 0x80
    DllCall("RedrawWindow", "ptr", hwnd, "ptr", 0, "ptr", 0
        , "uint", RDW_INVALIDATE | RDW_ERASE | RDW_UPDATENOW | RDW_ALLCHILDREN)
}