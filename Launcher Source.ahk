#Requires AutoHotkey v2.0
#SingleInstance Force

global ProjectName := "JUMP"

; -------------------------------
; Simplified Launcher for GitHub-updated AHK Script
; -------------------------------

; Define local script path
A_LocalAppData := EnvGet("LOCALAPPDATA")
localScriptPath := A_LocalAppData "\" ProjectName "\" ProjectName ".ahk"

; Check for an existing local script & extract its version
if FileExist(localScriptPath) {
    scriptContent := FileRead(localScriptPath)
    ; Look for: version := "X.X.X"
    if RegExMatch(scriptContent, 'version\s*:=\s*"(\d+\.\d+\.\d+)"', &m)
        localVersion := m[1]
    else
        localVersion := "0.0.0"
} else {
    localVersion := ""
}

; Get the latest release tag from GitHub
latestVersion := GetGitHubReleaseInfo("WoahItsJeebus", "" ProjectName "")["tag"]

if (latestVersion = "") {
    MsgBox "Failed to retrieve the latest version information. Please check your connection."
    ExitApp()
}

; Compare Versions
IsVersionNewer(localversion, latest) {
    localParts := StrSplit(localversion, ".")
    latestParts := StrSplit(latest, ".")
    for index, part in latestParts {
        localPart := (index <= localParts.Length) ? localParts[index] : 0
        if (part + 0 > localPart + 0)
            return true
        else if (part + 0 < localPart + 0)
            return false
    }
    return false
}

if (localVersion = "" or IsVersionNewer(localVersion, latestVersion)) {
    ; Download the updated script
    newScriptURL := "https://github.com/WoahItsJeebus/" ProjectName "/releases/latest/download/" ProjectName ".ahk"
    tempFilePath := A_Temp "\temp_script.ahk"
    
    try {
        Download(newScriptURL, tempFilePath)
    } catch {
        MsgBox "Failed to download the updated script. Please check your connection."
        ExitApp()
    }
    
    if !FileExist(A_LocalAppData "\" ProjectName "")
        DirCreate(A_LocalAppData "\" ProjectName "")

    FileCopy(tempFilePath, localScriptPath, true)
    FileDelete(tempFilePath)
}

GetGitHubReleaseInfo(owner, repo, release:="latest") {
    req := ComObject("Msxml2.XMLHTTP")
    req.open("GET", "https://api.github.com/repos/" owner "/" repo "/releases/" release, false)
    req.send()

    if req.status != 200
        Error(req.status " - " req.statusText, -1)

    res := JSON_parse(req.responseText)

    try {
        return Map( 
            "title", res.name,     ; The release title (name)
            "tag", res.tag_name,   ; The release version/tag
            "body", StripMarkdown(res.body)       ; The release body
		)
    }
    catch PropertyError {
        (Error(res.message, -1))
    }

}

JSON_parse(str) {
	htmlfile := ComObject("htmlfile")
	htmlfile.write('<meta http-equiv="X-UA-Compatible" content="IE=edge">')
	return htmlfile.parentWindow.JSON.parse(str)
}

StripMarkdown(text) {
    ; Remove HTML tags (like <ins>, <del>, <mark>)
    text := RegExReplace(text, "<(ins|del|mark)>(.*?)<\/\1>", "$2")

    ; Remove full URLs (http/https links)
    text := RegExReplace(text, "https?://[^\s]+", "")

    ; Remove Markdown-style headings
    text := RegExReplace(text, "m)^#+\s*", "")

    ; Format common Markdown symbols
    text := RegExReplace(text, "\*\*(.*?)\*\*", "$1")  ; Bold
    text := RegExReplace(text, "\*(.*?)\*", "$1")      ; Italics
    text := RegExReplace(text, "``(.*?)``", "'$1'")    ; Inline code → 'code'
    text := RegExReplace(text, "~~(.*?)~~", "[$1]")    ; Strikethrough → [text]
    text := RegExReplace(text, ">\s?", "")             ; Blockquotes
    text := RegExReplace(text, "\[(.*?)\]\(.*?\)", "$1")  ; Remove hyperlinks but keep text

    ; Handle lists correctly
    text := RegExReplace(text, "-\s?", "• ")           ; Convert Markdown lists to bullet points
    text := RegExReplace(text, "\n\s*-", "\n•")        ; Ensure list continuity

    return text
}

; --- Step 5: Launch the script ---
Run(localScriptPath)
ExitApp()
