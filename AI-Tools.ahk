; ai-tools-ahk - AutoHotkey scripts for AI tools
; MIT License

#Requires AutoHotkey v2.0
#singleInstance force
#Include "_jxon.ahk"
#include "_Cursor.ahk"
#Include "_MD2HTML.ahk"

Persistent
SendMode "Input"

if not (FileExist("settings.ini")) {
    api_key := InputBox("Enter your OpenAI API key", "AI-Tools-AHK : Setup", "W400 H100").value
    if (api_key == "") {
        MsgBox("To use this script, you need to enter an OpenAI key. Please restart the script and try again.")
        ExitApp
    }
    FileCopy("settings.ini.default", "settings.ini")
    IniWrite(api_key, ".\settings.ini", "settings", "default_api_key")
}

; ── first‑run spelling preference ──────────────────────────────
prefEng := IniRead(".\\settings.ini", "settings", "preferred_english", "")
if (prefEng = "") {
   ; ask user once
res := MsgBox("Would you like to use US or UK English spelling?`nYes = US English`nNo  = UK English"
    , "English spelling", "YesNo")
if (res = "Yes")
    prefEng := "US"
else
    prefEng := "UK"
    IniWrite(prefEng, ".\\settings.ini", "settings", "preferred_english")
}

RestoreCursor()

;# globals
_running := false
_settingsCache := Map()
_lastModified := fileGetTime("./settings.ini")
_displayResponse := false
_activeWin := ""
_oldClipboard := ""
_debug := GetSetting("settings", "debug", false)
_reload_on_change := GetSetting("settings", "reload_on_change", false)

;#
CheckSettings()

;# menu
InitPopupMenu()
InitTrayMenu()

;# hotkeys

HotKey GetSetting("settings", "hotkey_1"), (*) => (
    SelectText()
    PromptHandler(GetSetting("settings", "hotkey_1_prompt")))

HotKey GetSetting("settings", "hotkey_2"), (*) => (
    SelectText()
    ShowPopupMenu())

HotKey GetSetting("settings", "menu_hotkey"), (*) => (
    ShowPopupMenu())

;###

ShowPopupMenu() {
    _iMenu.Show()
}

PromptHandler(promptName, append := false) {
    try {
        if (_running) {
            Reload
            return
        }

        global _running := true
        global _startTime := A_TickCount

        ShowWaitTooltip()
        SetSystemCursor(GetSetting("settings", "cursor_wait_file", "wait"))

        prompt := GetSetting(promptName, "prompt")
        promptEnd := GetSetting(promptName, "prompt_end")
        mode := GetSetting(promptName, "mode", GetSetting("settings", "default_mode"))
        
        try {
            input := GetTextFromClip()
        } catch {
            global _running := false
            RestoreCursor()
            return
        }

        CallAPI(mode, promptName, prompt, input, promptEnd)

    } catch as err {
        global _running := false
        RestoreCursor()
        MsgBox Format("{1}: {2}.`n`nFile:`t{3}`nLine:`t{4}`nWhat:`t{5}", type(err), err.Message, err.File, err.Line, err.What), , 16
    }
}

SelectText() {
    global _oldClipboard := A_Clipboard

    A_Clipboard := ""
    Send "^c"
    ClipWait(2)
    text := A_Clipboard
    
    if WinActive("ahk_exe WINWORD.EXE") or WinActive("ahk_exe OUTLOOK.EXE") {
        Send "^{Up}^+{Down}+{Left}"
    } else if WinActive("ahk_exe notepad++.exe") or WinActive("ahk_exe Code.exe") {
        Send "{End}{End}+{Home}+{Home}"
    } else {
        if StrLen(text) < 1 {
            Send "^a"
        }
    }
    sleep 50
}

GetTextFromClip() {
    global _activeWin := WinGetTitle("A")
    if _oldClipboard == "" {
        global _oldClipboard := A_Clipboard
    }

    A_Clipboard := ""
    Send "^c"
    ClipWait(2)
    text := A_Clipboard

    if StrLen(text) < 1 {
        throw ValueError("No text selected", -1)
    } else if StrLen(text) > 16000 {
        throw ValueError("Text is too long", -1)
    }

    return text
}

ShowWarning(message) {
    MsgBox message
}

GetSetting(section, key, defaultValue := "") {
    global _settingsCache
    if (_settingsCache.Has(section . key . defaultValue)) {
        return _settingsCache.Get(section . key . defaultValue)
    } else {
        value := IniRead(".\settings.ini", section, key, defaultValue)
        if IsNumber(value) {
            value := Number(value)
        } else {
            value := UnescapeSetting(value)
        }
        _settingsCache.Set(section . key . defaultValue, value)
        return value
    }
}

GetBody(mode, promptName, prompt, input, promptEnd) {
    body := Map()

    ; Load mode defaults
    model := GetSetting(mode, "model")
    max_tokens := GetSetting(mode, "max_tokens")
    temperature := GetSetting(mode, "temperature")
    frequency_penalty := GetSetting(mode, "frequency_penalty")
    presence_penalty := GetSetting(mode, "presence_penalty")
    top_p := GetSetting(mode, "top_p")
    best_of := GetSetting(mode, "best_of")
    stop := GetSetting(mode, "stop", "")

    ; Load prompt overrides
    model := GetSetting(promptName, "model", model)
    max_tokens := GetSetting(promptName, "max_tokens", max_tokens)
    temperature := GetSetting(promptName, "temperature", temperature)
    frequency_penalty := GetSetting(promptName, "frequency_penalty", frequency_penalty)
    presence_penalty := GetSetting(promptName, "presence_penalty", presence_penalty)
    top_p := GetSetting(promptName, "top_p", top_p)
    best_of := GetSetting(promptName, "best_of", best_of)
    stop := GetSetting(promptName, "stop", stop)

    ; Combine prompt, input, and promptEnd
    content := ApplyLangNote(prompt . input . promptEnd)
    prompt_system := GetSetting(promptName, "prompt_system", "")

    ; Construct messages array
    messages := []
    if (prompt_system != "") {
        ; Prepend system instructions to user content
        content := prompt_system . "`n`n" . content
    }
    messages.Push(Map("role", "user", "content", content))
    body["messages"] := messages

    ; Convert max_tokens to max_completion_tokens if required by model
    max_completion_tokens := GetSetting(promptName, "max_tokens", max_tokens)
    body["max_completion_tokens"] := max_completion_tokens

    ; If temperature is restricted, adjust accordingly
    body["temperature"] := temperature
    body["frequency_penalty"] := frequency_penalty
    body["presence_penalty"] := presence_penalty
    body["top_p"] := top_p
    body["model"] := model

    return body
}

CallAPI(mode, promptName, prompt, input, promptEnd) {
    body := GetBody(mode, promptName, prompt, input, promptEnd)
    bodyJson := Jxon_dump(body, 4)
    LogDebug "bodyJson ->`n" bodyJson

    endpoint := GetSetting(mode, "endpoint")
    apiKey := GetSetting(mode, "api_key", GetSetting("settings", "default_api_key"))
    model := body["model"]

    req := ComObject("Msxml2.ServerXMLHTTP")

    req.open("POST", endpoint, true)
    req.SetRequestHeader("Content-Type", "application/json")
    req.SetRequestHeader("Authorization", "Bearer " apiKey)
    req.SetRequestHeader("api-key", apiKey)
    req.SetRequestHeader('Content-Length', StrLen(bodyJson))
    req.SetRequestHeader("If-Modified-Since", "Sat, 1 Jan 2000 00:00:00 GMT")
    req.SetTimeouts(0, 0, 0, GetSetting("settings", "timeout", 120) * 1000)

    try {
        req.send(bodyJson)
        req.WaitForResponse()

        if (req.status == 0) {
            RestoreCursor()
            global _running := false
            MsgBox "Error: Unable to connect to the API. Please check your internet connection and try again.", , 16
            return
        } else if (req.status == 200) {
            data := req.responseText
            HandleResponse(data, mode, promptName, input, model)
        } else {
            RestoreCursor()
            global _running := false
            MsgBox "Error: Status " req.status " - " req.responseText, , 16
            return
        }
    } catch as e {
        RestoreCursor()
        global _running := false
        MsgBox "Error: Exception thrown!`n`nwhat: " e.what "`nfile: " e.file "`nline: " e.line "`nmessage: " e.message "`nextra: " e.extra, , 16
        return
    }
}

HandleResponse(data, mode, promptName, input, model) {
    global _oldClipboard

    Gui_Size(MyGui, MinMax, Width, Height) {
        if MinMax = -1
            return
        ogcActiveXWBC.Move(,, Width-30, Height-55)
        xClose.Move(Width/2 - 40,Height-40,,)
    }

    try {
        LogDebug "API Response: " data
        var := Jxon_Load(&data)

        ; Verify the 'choices' key exists and has content
        if !var.Has("choices") {
            MsgBox "Error: 'choices' not found in the response."
            return
        }

        choices := var.Get("choices")
        if choices.Length < 1 {
            MsgBox "Error: No choices returned by the API."
            return
        }

        firstChoice := choices[1]

        ; Handle different response structures
        if firstChoice.Has("text") {
            text := firstChoice.Get("text")
        } else if firstChoice.Has("message") {
            msg := firstChoice.Get("message")
            if msg.Has("content") {
                text := msg.Get("content")
            } else {
                MsgBox "Error: The 'message' does not contain 'content'."
                return
            }
        } else {
            MsgBox "Error: Neither 'text' nor 'message->content' found in the response."
            return
        }

        if text == "" {
            MsgBox "No text was generated. Consider modifying your input."
            return
        }

        text := StrReplace(text, '`r', "")
        replaceSelected := GetSetting(promptName, "replace_selected")

        if StrLower(replaceSelected) == "false" {
            responseStart := GetSetting(promptName, "response_start", "")
            responseEnd := GetSetting(promptName, "response_end", "")
            text := input . responseStart . text . responseEnd
        } else {
            ; Remove leading newlines
            while SubStr(text, 1, 1) == '`n' {
                text := SubStr(text, 2)
            }
            text := Trim(text)
            ; Remove enclosing quotes if any
            if SubStr(text, 1, 1) == '"' and SubStr(text, -1) == '"' {
                text := SubStr(text, 2, -1)
            }
        }

        response_type := GetSetting(promptName, "response_type", "")
        if _displayResponse or response_type == "popup" {
            MyGui := Gui(, "Response")
            MyGui.SetFont("s13")
            MyGui.Opt("+AlwaysOnTop +Owner +Resize")
            
            ogcActiveXWBC := MyGui.Add("ActiveX", "xm w800 h480 vIE", "Shell.Explorer")
            WB := ogcActiveXWBC.Value
            WB.Navigate("about:blank")
            css := FileRead("style.css")
            options := {css:css
                        , font_name:"Segoe UI"
                        , font_size:16
                        , font_weight:400
                        , line_height:"1.6"}
            html := make_html(text, options, false)
            WB.document.write(html)

            xClose := MyGui.Add("Button", "Default w80", "Close")
            xClose.OnEvent("Click", (*) => WinClose())

            MyGui.Show("NoActivate AutoSize Center")
            MyGui.GetPos(&x,&y,&w,&h)
            xClose.Move(w/2 - 40,,,)
            MyGui.OnEvent("Size", Gui_Size)
        } else {
            WinActivate _activeWin
            A_Clipboard := text
            send "^v"
        }

        global _running := false
        Sleep 500
    } finally {
        global _running := false
        A_Clipboard := _oldClipboard
        global _oldClipboard := ""
        RestoreCursor()
    }
}

InitPopupMenu() {
    global _iMenu := Menu()
    iMenuItemParms := Map()

    _iMenu.add "&`` - Display response in new window", NewWindowCheckHandler
    _iMenu.Add  ; Add a separator line.

    ; Add existing menu items from settings.ini
    menu_items := IniRead("./settings.ini", "popup_menu")
    id := 1
    loop parse menu_items, "`n" {
        v_promptName := A_LoopField
        if (v_promptName != "" and SubStr(v_promptName, 1, 1) != "#") {
            if (v_promptName = "-") {
                _iMenu.Add  ; Add a separator line.
            } else {
                menu_text := GetSetting(v_promptName, "menu_text", v_promptName)
                if (RegExMatch(menu_text, "^[^&]*&[^&]*$") == 0) {
                    if (id == 10)
                        keyboard_shortcut := "&0 - "
                    else if (id > 10)
                        keyboard_shortcut := "&" Chr(id + 86) " - "
                    else
                        keyboard_shortcut := "&" id " - "
                    menu_text := keyboard_shortcut menu_text
                    id++
                }
                _iMenu.Add menu_text, MenuHandler
                item_count := DllCall("GetMenuItemCount", "ptr", _iMenu.Handle)
                iMenuItemParms[item_count] := v_promptName
            }
        }
    }

    ; Add custom hardcoded item for Netropolitan Academy
    _iMenu.Add  ; Add a separator line.
    _iMenu.Add "Go to Netropolitan Academy", (*) => Run("https://www.netropolitan.xyz/")

    MenuHandler(ItemName, ItemPos, MyMenu) {
        PromptHandler(iMenuItemParms[ItemPos])
    }

    NewWindowCheckHandler(*) {
        _iMenu.ToggleCheck "&`` - Display response in new window"
        global _displayResponse := !_displayResponse
        _iMenu.Show()
    }
}

InitTrayMenu() {
    tray := A_TrayMenu
    tray.add
    tray.add "Open settings", OpenSettings
    tray.add "Reload settings", ReloadSettings
    tray.add
    tray.add "Github readme", OpenGithub
    TrayAddStartWithWindows(tray)
}

TrayAddStartWithWindows(tray) {
    tray.add "Start with Windows", StartWithWindowsAction
    SplitPath a_scriptFullPath, , , , &script_name
    _sww_shortcut := a_startup "\" script_name ".lnk"
    if FileExist(_sww_shortcut) {
        fileGetShortcut _sww_shortcut, &target
        if (target != a_scriptFullPath) {
            fileCreateShortcut a_scriptFullPath, _sww_shortcut
        }
        tray.Check("Start with Windows")
    } else {
        tray.Uncheck("Start with Windows")
    }
    StartWithWindowsAction(*) {
        if FileExist(_sww_shortcut) {
            fileDelete(_sww_shortcut)
            tray.Uncheck("Start with Windows")
            trayTip("Start With Windows", "Shortcut removed", 5)
        } else {
            fileCreateShortcut(a_scriptFullPath, _sww_shortcut)
            tray.Check("Start with Windows")
            trayTip("Start With Windows", "Shortcut created", 5)
        }
    }
}

OpenGithub(*) {
    Run "https://github.com/ecornell/ai-tools-ahk#usage"
}

OpenSettings(*) {
    Run A_ScriptDir . "\settings.ini"
}

ReloadSettings(*) {
    TrayTip("Reload Settings", "Reloading settings...", 5)
    _settingsCache.Clear()
    InitPopupMenu()
}

UnescapeSetting(obj) {
    obj := StrReplace(obj, "\n", "`n")
    return obj
}

ShowWaitTooltip() {
    if (_running) {
        elapsedTime := (A_TickCount - _startTime) / 1000
        ToolTip "Generating response... " Format("{:0.2f}", elapsedTime) "s"
        SetTimer () => ShowWaitTooltip(), -50
    } else {
        ToolTip()
    }
}

CheckSettings() {
    if (_reload_on_change and FileExist("./settings.ini")) {
        lastModified := fileGetTime("./settings.ini")
        if (lastModified != _lastModified) {
            global _lastModified := lastModified
            TrayTip("Settings Updated", "Restarting...", 5)
            Sleep 2000
            Reload
        }
        SetTimer () => CheckSettings(), -10000
    }
}

LogDebug(msg) {
    if (_debug != false) {
        now := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
        logMsg := "[" . now . "] " . msg . "`n"
        FileAppend(logMsg, "./debug.log")
    }
}

; Adds the UK‑spelling note only if the user chose UK
ApplyLangNote(text) {
    pref := IniRead(".\\settings.ini", "settings", "preferred_english", "US")
    if (pref = "UK")
        return "Use UK English spelling, but avoid British‑specific content or slang.`n" . text
    return text
}
