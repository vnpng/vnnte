#Requires AutoHotkey v2.0
#Include HeistLoop.ahk

; === 全局状态 ===
global AppGUI := 0
global LogLV := 0
global IsRunning := false
global StartBtn := 0
global CurrentFunc := "pinkclaw"
global SidebarBtns := Map()
global PanelCtrls := Map()

; === Sidebar 功能列表 ===
FUNC_LIST := [
    {id: "combat",     name: "自动战斗"},
    {id: "dodge",      name: "自动闪避反击"},
    {id: "pinkclaw",   name: "自动粉爪"},
    {id: "fishing",    name: "自动钓鱼"},
    {id: "darkrace",   name: "黑暗赛车"},
    {id: "normalrace", name: "常规赛车"},
]
FUNC_PANEL := Map(
    "combat",     "placeholder",
    "dodge",      "placeholder",
    "pinkclaw",   "pinkclaw",
    "fishing",    "placeholder",
    "darkrace",   "placeholder",
    "normalrace", "placeholder",
)

; === 布局常量 ===
PANEL_X := 230
PANEL_W := 440          ; 原 650，缩小约 1/3
LINE_H := 30            ; 配置行间距

CreateMainGUI() {
    global AppGUI, CurrentFunc

    AppGUI := Gui("+Resize", "vnnte")
    AppGUI.SetFont("s10", "Microsoft YaHei UI")
    AppGUI.BackColor := "0xF0F0F0"

    CreateSidebar()
    CreatePinkClawPanel()
    CreatePlaceholderPanel()

    AppGUI.Show("w900 h720")
    InitLogLV()       ; Show 之后再初始化 ListView 数据（避免 Hidden 时 Add 无效）
    SwitchPanel(FUNC_PANEL[CurrentFunc], CurrentFunc)
    return AppGUI
}

CreateSidebar() {
    global AppGUI, SidebarBtns
    AppGUI.SetFont("s18 bold")
    AppGUI.Add("Text", "x10 y10 w200 h40 Center", "vnnte")
    AppGUI.SetFont("s10")
    loop FUNC_LIST.Length {
        i := A_Index
        y := 60 + (i - 1) * 32
        funcId := FUNC_LIST[i].id
        name := FUNC_LIST[i].name
        btn := AppGUI.Add("Button", "x10 y" y " w200 h28", name)
        btn.Tag := funcId
        btn.OnEvent("Click", SidebarClickHandler)
        SidebarBtns[funcId] := btn
    }
}

SidebarClickHandler(ctrl, *) {
    global CurrentFunc
    CurrentFunc := ctrl.Tag
    SwitchPanel(FUNC_PANEL[CurrentFunc], CurrentFunc)
}

CreatePinkClawPanel() {
    ; 自动粉爪 - 完整 flat layout（所有控件 Hidden，靠 SwitchPanel 启用）
    ; PANEL_W=440，行间距 30
    global AppGUI, PanelCtrls, LogLV, StartBtn
    global PANEL_X, PANEL_W, LINE_H
    ctrls := []

    ; === 顶部卡片（y=10-90）===
    ctrls.Push(AppGUI.Add("GroupBox", "x" PANEL_X " y10 w" PANEL_W " h80 Hidden", "自动粉爪大劫案"))
    ctrls.Push(AppGUI.Add("Text", "x" (PANEL_X+15) " y35 Hidden", "一小时方斯41万 / 粉爪币2500+"))
    btnReset := AppGUI.Add("Button", "x" (PANEL_X+240) " y20 w70 h25 Hidden", "重置配置")
    btnReset.OnEvent("Click", (*) => ResetConfig())
    ctrls.Push(btnReset)
    ctrls.Push(AppGUI.Add("Button", "x" (PANEL_X+315) " y20 w45 h25 Hidden", "说明"))
    StartBtn := AppGUI.Add("Button", "x" (PANEL_X+365) " y15 w65 h50 Default Hidden", "开始")
    StartBtn.OnEvent("Click", (*) => StartPinkClaw())
    ctrls.Push(StartBtn)
    txtF10 := AppGUI.Add("Text", "x" (PANEL_X+380) " y70 w35 h14 Center Hidden", "F10")
    txtF10.SetFont("s8")
    ctrls.Push(txtF10)

    ; === 配置区（y=100-360）===
    cy := 100
    ctrls.Push(AppGUI.Add("GroupBox", "x" PANEL_X " y" cy " w" PANEL_W " h260 Hidden", "配置"))
    cy += 20
    ; 路径
    ctrls.Push(AppGUI.Add("Text", "x" (PANEL_X+15) " y" cy " Hidden", "路径:"))
    ctrls.Push(AppGUI.Add("DropDownList", "x" (PANEL_X+65) " y" (cy-3) " w130 vPathDDL Hidden", ["路径A"]))
    ctrls.Push(AppGUI.Add("Button", "x" (PANEL_X+205) " y" (cy-3) " w40 h22 Hidden", "刷新"))
    cy += LINE_H
    ; 循环次数
    ctrls.Push(AppGUI.Add("Text", "x" (PANEL_X+15) " y" cy " Hidden", "循环次数 (0=无限):"))
    ctrls.Push(AppGUI.Add("Edit", "x" (PANEL_X+340) " y" (cy-3) " w60 Number vLoopCount Hidden", "0"))
    cy += 18
    t := AppGUI.Add("Text", "x" (PANEL_X+15) " y" cy " Hidden", "循环次数 设置为0则一直运行")
    t.SetFont("s8 c808080")
    ctrls.Push(t)
    cy += 18
    ; 连续失败停止
    ctrls.Push(AppGUI.Add("Text", "x" (PANEL_X+15) " y" cy " Hidden", "连续失败停止 (0=不停止):"))
    ctrls.Push(AppGUI.Add("Edit", "x" (PANEL_X+340) " y" (cy-3) " w60 Number vConsecFail Hidden", "10"))
    cy += 18
    t := AppGUI.Add("Text", "x" (PANEL_X+15) " y" cy " Hidden", "连续失败停止 0=不停止")
    t.SetFont("s8 c808080")
    ctrls.Push(t)
    cy += 18
    ; 战斗角色
    ctrls.Push(AppGUI.Add("Text", "x" (PANEL_X+15) " y" cy " Hidden", "战斗角色:"))
    ctrls.Push(AppGUI.Add("CheckBox", "x" (PANEL_X+80) " y" cy " vFighter1 Checked Hidden", "1"))
    ctrls.Push(AppGUI.Add("CheckBox", "x" (PANEL_X+115) " y" cy " vFighter2 Hidden", "2"))
    ctrls.Push(AppGUI.Add("CheckBox", "x" (PANEL_X+150) " y" cy " vFighter3 Hidden", "3"))
    ctrls.Push(AppGUI.Add("CheckBox", "x" (PANEL_X+185) " y" cy " vFighter4 Checked Hidden", "4"))
    cy += 18
    t := AppGUI.Add("Text", "x" (PANEL_X+15) " y" cy " Hidden", "选1~2个")
    t.SetFont("s8 c808080")
    ctrls.Push(t)
    cy += 18
    ; 跑图角色
    ctrls.Push(AppGUI.Add("Text", "x" (PANEL_X+15) " y" cy " Hidden", "跑图角色:"))
    ctrls.Push(AppGUI.Add("CheckBox", "x" (PANEL_X+80) " y" cy " vRunner1 Hidden", "1"))
    ctrls.Push(AppGUI.Add("CheckBox", "x" (PANEL_X+115) " y" cy " vRunner2 Hidden", "2"))
    ctrls.Push(AppGUI.Add("CheckBox", "x" (PANEL_X+150) " y" cy " vRunner3 Checked Hidden", "3"))
    ctrls.Push(AppGUI.Add("CheckBox", "x" (PANEL_X+185) " y" cy " vRunner4 Hidden", "4"))
    cy += 18
    t := AppGUI.Add("Text", "x" (PANEL_X+15) " y" cy " Hidden", "选1个")
    t.SetFont("s8 c808080")
    ctrls.Push(t)
    cy += 18
    ; 避战角色
    ctrls.Push(AppGUI.Add("Text", "x" (PANEL_X+15) " y" cy " Hidden", "避战角色:"))
    ctrls.Push(AppGUI.Add("CheckBox", "x" (PANEL_X+80) " y" cy " vAvoider1 Hidden", "1"))
    ctrls.Push(AppGUI.Add("CheckBox", "x" (PANEL_X+115) " y" cy " vAvoider2 Checked Hidden", "2"))
    ctrls.Push(AppGUI.Add("CheckBox", "x" (PANEL_X+150) " y" cy " vAvoider3 Hidden", "3"))
    ctrls.Push(AppGUI.Add("CheckBox", "x" (PANEL_X+185) " y" cy " vAvoider4 Hidden", "4"))
    cy += 18
    t := AppGUI.Add("Text", "x" (PANEL_X+15) " y" cy " Hidden", "选0~1个")
    t.SetFont("s8 c808080")
    ctrls.Push(t)
    cy += 18
    ; 避战方式
    ctrls.Push(AppGUI.Add("Text", "x" (PANEL_X+15) " y" cy " Hidden", "避战方式:"))
    ctrls.Push(AppGUI.Add("DropDownList", "x" (PANEL_X+340) " y" (cy-3) " w70 vAvoidMethod Hidden", ["长按Shift", "长按攻击"]))

    ; === 日志表（y=370-660）===
    logY := 370
    logH := 290
    ctrls.Push(AppGUI.Add("GroupBox", "x" PANEL_X " y" logY " w" PANEL_W " h" logH " Hidden", "运行信息"))
    LogLV := AppGUI.Add("ListView", "x" (PANEL_X+10) " y" (logY+25) " w" (PANEL_W-20) " h" (logH-35) " Grid Hidden", ["信息", "值"])
    ctrls.Push(LogLV)

    PanelCtrls["pinkclaw"] := ctrls
}

InitLogLV() {
    ; Show 之后再初始化 ListView 数据（Hidden 状态下 Add 行不生效）
    global LogLV, PANEL_W
    LogLV.ModifyCol(1, 140)
    LogLV.ModifyCol(2, PANEL_W - 160)
    LogLV.Add(, "Log", "")
    LogLV.Add(, "成功次数", "0")
    LogLV.Add(, "失败次数", "0")
    LogLV.Add(, "总方斯获取数", "0")
    LogLV.Add(, "总粉爪币获取数", "0")
    LogLV.Add(, "current task", "无")
    ResetConfig(true)
}

CreatePlaceholderPanel() {
    global AppGUI, PanelCtrls, PANEL_X, PANEL_W
    ctrls := []
    ctrls.Push(AppGUI.Add("GroupBox", "x" PANEL_X " y10 w" PANEL_W " h700 Hidden", ""))
    t1 := AppGUI.Add("Text", "x" PANEL_X " y300 w" PANEL_W " h40 Center Hidden", "即将开放")
    t1.SetFont("s20")
    ctrls.Push(t1)
    t2 := AppGUI.Add("Text", "x" PANEL_X " y360 w" PANEL_W " h20 Center Hidden", "该功能正在开发中")
    t2.SetFont("s10")
    ctrls.Push(t2)
    PanelCtrls["placeholder"] := ctrls
}

SwitchPanel(panelId, funcId) {
    global PanelCtrls, SidebarBtns

    for name, ctrls in PanelCtrls {
        show := (name = panelId)
        for _, c in ctrls {
            c.Visible := show
        }
    }

    for fid, btn in SidebarBtns {
        if (fid = funcId) {
            btn.Opt("+Background3B8EDB")
            btn.SetFont("cWhite bold")
        } else {
            btn.Opt("+BackgroundF0F0F0")
            btn.SetFont("c202020 norm")
        }
    }
}

; StartPinkClaw 在 HeistLoop.ahk 中定义

UpdateLog(name, value) {
    global LogLV
    if !LogLV
        return
    loop LogLV.GetCount() {
        if LogLV.GetText(A_Index, 1) = name {
            LogLV.Modify(A_Index, , , value)
            return
        }
    }
}

Log(msg) {
    UpdateLog("Log", msg)
}

ResetConfig(silent := false) {
    global AppGUI
    try {
        AppGUI["PathDDL"].Text := "路径A"
        AppGUI["LoopCount"].Text := "0"
        AppGUI["ConsecFail"].Text := "10"
        AppGUI["Fighter1"].Value := 1
        AppGUI["Fighter2"].Value := 0
        AppGUI["Fighter3"].Value := 0
        AppGUI["Fighter4"].Value := 1
        AppGUI["Runner1"].Value := 0
        AppGUI["Runner2"].Value := 0
        AppGUI["Runner3"].Value := 1
        AppGUI["Runner4"].Value := 0
        AppGUI["Avoider1"].Value := 0
        AppGUI["Avoider2"].Value := 1
        AppGUI["Avoider3"].Value := 0
        AppGUI["Avoider4"].Value := 0
        AppGUI["AvoidMethod"].Text := "长按Shift"
    }
    if !silent
        Log("已重置为默认配置")
}

RunSmokeTest() {
    global IsRunning, StartBtn
    Log("=== Phase 1 烟测开始 ===")

    result := RunPython("screenshot")
    if !result.ok {
        Log("[截图] 失败: " result.error)
    } else {
        Log("[截图] 已保存: " result.path)
        Log("[截图] 缩放后: " result.size_w "x" result.size_h "  物理: " result.phys_w "x" result.phys_h)
    }

    result := RunPython("check_in_team")
    if !result.ok {
        Log("[队伍] 失败: " result.error)
    } else if result.in_team {
        Log("[队伍] 在  (x=" result.pos_x ", y=" result.pos_y ")")
    } else {
        Log("[队伍] 不在")
    }

    result := RunPython("check_interac")
    if !result.ok {
        Log("[F提示] 失败: " result.error)
    } else if result.found {
        Log("[F提示] 找到  (x=" result.pos_x ", y=" result.pos_y ")")
    } else {
        Log("[F提示] 未找到")
    }

    result := RunPython("list_templates")
    if !result.ok {
        Log("[模板] 失败: " result.error)
    } else {
        tpls := StrSplit(result.templates, "|")
        Log("[模板] 已加载 " result.count " 个: " FormatList(tpls))
    }

    Log("=== 烟测结束 ===")
    IsRunning := false
    StartBtn.Text := "开始"
}

RunPython(cmd) {
    scriptPath := A_ScriptDir "\tools\one_shot.py"
    outFile := A_ScriptDir "\ipc\result.txt"
    DirCreate(A_ScriptDir "\ipc")
    try FileDelete(outFile)
    cmdline := A_ComSpec ' /c python "' scriptPath '" ' cmd ' > "' outFile '" 2>&1'
    try {
        RunWait(cmdline, A_ScriptDir, "Hide")
    } catch as e {
        return {ok: false, error: "启动 Python 失败: " e.Message}
    }
    if !FileExist(outFile)
        return {ok: false, error: "Python 执行无输出"}
    content := FileRead(outFile)
    content := Trim(content)
    if !content
        return {ok: false, error: "Python 输出为空"}
    result := {ok: false}
    loop parse, content, "`n", "`r" {
        line := Trim(A_LoopField)
        if !line
            continue
        eq := InStr(line, "=")
        if !eq
            continue
        k := SubStr(line, 1, eq - 1)
        v := SubStr(line, eq + 1)
        if (k = "ok") {
            result.ok := (v = "true")
        } else if (k = "in_team" || k = "found" || k = "in_heist") {
            result.%k% := (v = "true")
        } else {
            result.%k% := v
        }
    }
    if !result.ok && !result.HasOwnProp("error") {
        result.error := "Python 输出无 ok 字段"
    }
    return result
}

FormatList(arr) {
    out := ""
    for i, v in arr
        out .= (i > 1 ? ", " : "") v
    return out
}
