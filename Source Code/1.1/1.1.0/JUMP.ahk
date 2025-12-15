#Requires AutoHotkey >=2.0.19
#SingleInstance Force

CoordMode("Mouse", "Screen")
CoordMode("Menu", "Screen")
SetTitleMatchMode 2
DetectHiddenWindows(true)

global version := "1.1.0"
global APP := MinesweeperApp()

; ----------------------------
; Minesweeper GUI
; ----------------------------
class MinesweeperApp {
    __New() {
        this.CellSize := 22
        this.Padding  := 10
        this.HeaderH  := 50

        this.HiddenBg   := 0xBDBDBD
        this.RevealBg   := 0xE6E6E6
        this.MineBg     := 0xFFB0B0
        this.FlagColor  := 0xCC0000
        this.TextColor  := 0x000000

		this.CustomCfg := { W: 9, H: 9, Mines: 10 } ; default custom
		
        this.Gui := Gui("", "JUMP - Minesweeper")
        this.Gui.SetFont("s10", "Segoe UI")

		this.MBar := MenuBar()
		this.Gui.MenuBar := this.MBar
		
		this.GameMenu := Menu()
		this.GameMenu.Add("New Game", (*) => this.NewGame("Beginner (9x9, 10)"))
		this.MBar.Add("Game", this.GameMenu)
		
		this.ScriptMenu := Menu()
		this.ScriptMenu.Add("Reload", reloadScript.Bind())

		; Add difficulty levels as submenu of script menu
		this.DifficultyMenu := Menu()
		this.DifficultyMenu.Add("Beginner (9x9, 10)", (*) => this.NewGame("Beginner (9x9, 10)"))
		this.DifficultyMenu.Add("Intermediate (16x16, 40)", (*) => this.NewGame("Intermediate (16x16, 40)"))
		this.DifficultyMenu.Add("Expert (30x16, 99)", (*) => this.NewGame("Expert (30x16, 99)"))
		this.DifficultyMenu.Add("Custom...", (*) => this.PromptCustomDifficulty())

		this.GameMenu.Add("Difficulty", this.DifficultyMenu)
		this.MBar.Add("Script", this.ScriptMenu)
		
        ; this.BtnNew := this.Gui.AddButton("x10 y10 w90 h24", "New Game")
        ; this.BtnNew.OnEvent("Click", (*) => this.NewGame(this.DDL.Text))
		
        ; this.DDL := this.Gui.AddDropDownList("x110 y10 w170", ["Beginner (9x9, 10)", "Intermediate (16x16, 40)", "Expert (30x16, 99)"])
        ; this.DDL.Choose(1)
        ; this.DDL.OnEvent("Change", (*) => this.NewGame(this.DDL.Text))

        this.TxtMines := this.Gui.AddText("x10 y5 w140", "Mines: 0")
        this.TxtTime  := this.Gui.AddText("x10 y+m w140", "Time: 0")
		
        this.TimerFn := ObjBindMethod(this, "Tick")

        this.Cells := []
        this.CellByHwnd := Map()

        ; hook mouse clicks globally
        OnMessage(0x0201, WM_LBUTTONDOWN) ; WM_LBUTTONDOWN
        OnMessage(0x0204, WM_RBUTTONDOWN) ; WM_RBUTTONDOWN

        this.NewGame("Beginner (9x9, 10)")
        this.Gui.Show("AutoSize Center")
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
        this.W := cfg.W, this.H := cfg.H, this.Mines := cfg.Mines
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

        this.BuildGrid()

        this.UpdateStatus()
        this.TxtTime.Text := "Time: 0"
        this.Gui.Show("AutoSize Center")
    }

	PromptCustomDifficulty() {
		; defaults (use last custom if available, else beginner)
		defW := 9, defH := 9, defM := 10
		if IsObject(this.CustomCfg) {
			defW := this.CustomCfg.W
			defH := this.CustomCfg.H
			defM := this.CustomCfg.Mines
		}

		; ranges (tweak if you want)
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

			; if user typed too many, tell them (don’t silently change unless you prefer)
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
		switch modeText {
			case "Beginner (9x9, 10)":
				return { W: 9, H: 9, Mines: 10 }
			case "Intermediate (16x16, 40)":
				return { W: 16, H: 16, Mines: 40 }
			case "Expert (30x16, 99)":
				return { W: 30, H: 16, Mines: 99 }
			case "Custom":
				; if user hasn't set one yet, fall back
				return IsObject(this.CustomCfg) ? this.CustomCfg : { W: 9, H: 9, Mines: 10 }
			default:
				return { W: 9, H: 9, Mines: 10 }
		}
	}

    DestroyGrid() {
        ; *** FIX: DestroyWindow each child control in the grid ***
        for ctrl in this.Cells {
            try {
                if IsObject(ctrl) && ctrl.Hwnd
                    DllCall("DestroyWindow", "ptr", ctrl.Hwnd)
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

            MsgBox "You win 🎉`nTime: " this.Elapsed "s", "JUMP - Minesweeper", "Iconi"
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

        MsgBox "Boom. You hit a mine.`nTime: " this.Elapsed "s", "JUMP - Minesweeper", "Iconx"
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