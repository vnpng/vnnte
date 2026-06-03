#Requires AutoHotkey v2.0
; 自动粉爪大劫案 - 主循环框架
; 参考 ok-nte AutoHeistTask.py

#Include ..\paths\PathMin.ahk

; === 劫案状态 ===
global HeistCount := 0
global HeistSuccess := 0
global HeistFail := 0
global HeistTotalCash := 0
global HeistTotalCoin := 0

; === 游戏窗口 ===
GAME_CLASS := "UnrealWindow"

ActivateGame() {
    ; 激活游戏窗口，确保按键能发到游戏
    try WinActivate("ahk_class " GAME_CLASS)
    Sleep(100)
}

; === 按键辅助 ===
Key(key, duration := 50) {
    ; 短按：按下 duration ms 后松开
    ActivateGame()
    SendInput("{" key " down}")
    Sleep(duration)
    SendInput("{" key " up}")
}

KeyDown(key) {
    ActivateGame()
    SendInput("{" key " down}")
}

KeyUp(key) {
    SendInput("{" key " up}")
}

; === 图像检测封装（调 Python）===
CheckPython(cmd) {
    return RunPython(cmd)
}

FindInterac() {
    r := CheckPython("check_interac")
    return r.HasOwnProp("found") && r.found
}

InTeam() {
    r := CheckPython("check_in_team")
    return r.HasOwnProp("in_team") && r.in_team
}

InHeist() {
    r := CheckPython("check_heist")
    return r.HasOwnProp("in_heist") && r.in_heist
}

HasExtractPanel() {
    r := CheckPython("check_extract_panel")
    return r.HasOwnProp("found") && r.found
}

HasRedHealthBar() {
    r := CheckPython("check_red_health")
    return r.HasOwnProp("found") && r.found
}

; === 等待函数 ===
WaitFor(check_func, timeout := 10000, interval := 500, pre_action := "") {
    global IsRunning
    deadline := A_TickCount + timeout
    while A_TickCount < deadline {
        if !IsRunning
            return false
        if pre_action != "" {
            pre_action()
        }
        if check_func() {
            return true
        }
        Sleep(interval)
    }
    return false
}

; === 进入副本 ===
EnterHeist() {
    global IsRunning
    Log("进入副本...")
    Key("f", 100)
    Sleep(500)
    if !WaitFor(InHeist, 20000, 1000) {
        Log("进入副本超时")
        return false
    }
    Log("已进入副本")
    return true
}

; === 退出副本 ===
ExitHeist() {
    global IsRunning, HeistSuccess
    Log("退出副本...")
    if !WaitFor(() => InTeam() || HasExtractPanel(), 30000, 1000, () => Key("f", 100)) {
        Log("退出超时，强制退出")
        AbortHeist()
        return false
    }
    if InTeam() {
        Log("已在队伍界面")
        HeistSuccess++
        UpdateLog("成功次数", HeistSuccess)
        return true
    }
    ; 有安全撤离面板
    Sleep(1000)
    ActivateGame()
    Click(960, 760)
    Sleep(1000)
    if !WaitFor(InTeam, 60000, 1000) {
        Log("等待回到队伍界面超时")
        AbortHeist()
        return false
    }
    Log("已退出副本")
    HeistSuccess++
    UpdateLog("成功次数", HeistSuccess)
    return true
}

; === 强制退出副本（ESC 退出）===
AbortHeist() {
    global IsRunning, HeistFail
    Log("强制退出副本...")
    HeistFail++
    UpdateLog("失败次数", HeistFail)
    loop 10 {
        Key("esc", 100)
        Sleep(2000)
        if InTeam() && !InHeist() {
            Log("已退出")
            return
        }
    }
    Log("强制退出失败")
}

; === 单轮劫案 ===
RunHeistRound() {
    global IsRunning, HeistCount
    HeistCount++
    UpdateLog("轮次", HeistCount)
    Log("--- 第 " HeistCount " 轮 ---")

    ; 1. 等待交互点
    Log("等待交互点...")
    if !WaitFor(FindInterac, 15000, 1000) {
        if !IsRunning
            return
        Log("未找到交互点")
        return
    }
    Log("找到交互点")

    ; 2. 进入副本
    if !EnterHeist() {
        AbortHeist()
        return
    }

    ; 3. 等待加载完成
    Sleep(3000)
    if !WaitFor(InHeist, 60000, 2000) {
        Log("加载超时")
        AbortHeist()
        return
    }
    Log("副本加载完成")

    ; 4. 跑路径（最小版）
    Log("执行路径...")
    try {
        RunPathMin()
    } catch as e {
        Log("路径异常: " e.Message)
        AbortHeist()
        return
    }

    ; 5. 退出副本
    ExitHeist()
}

; === 劫案主循环 ===
RunHeistLoop() {
    global IsRunning, HeistCount, HeistSuccess, HeistFail, HeistTotalCash, HeistTotalCoin
    IsRunning := true
    StartBtn.Text := "停止"
    HeistCount := 0
    HeistSuccess := 0
    HeistFail := 0
    HeistTotalCash := 0
    HeistTotalCoin := 0
    UpdateLog("成功次数", 0)
    UpdateLog("失败次数", 0)
    UpdateLog("轮次", 0)
    Log("=== 自动粉爪开始 ===")

    loop {
        if !IsRunning
            break
        RunHeistRound()
        if !IsRunning
            break
        Sleep(2000)
    }

    Log("=== 已停止 ===")
    IsRunning := false
    StartBtn.Text := "开始"
}

; === 启动入口 ===
StartPinkClaw() {
    global IsRunning
    if IsRunning {
        IsRunning := false
        Log("正在停止...")
        return
    }
    SetTimer(RunHeistLoop, -100)
}
