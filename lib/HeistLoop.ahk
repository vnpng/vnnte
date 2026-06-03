#Requires AutoHotkey v2.0
; 自动粉爪大劫案 - 主循环框架
; 完全参考 ok-nte AutoHeistTask.py

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
    try WinActivate("ahk_class " GAME_CLASS)
}

; === 坐标转换：原项目用 0~1 比例坐标，这里转成屏幕绝对像素 ===
GameClick(rx, ry) {
    ; rx, ry 是 0~1 的比例坐标（基于 1920x1080）
    ; 需要根据游戏窗口的实际位置和尺寸转换
    ActivateGame()
    try {
        hwnd := WinGetID("ahk_class " GAME_CLASS)
        coord := WinGetPos("ahk_id " hwnd)
        ; coord 返回 {X, Y, Width, Height}
        actualX := coord.X + Round(rx * coord.Width)
        actualY := coord.Y + Round(ry * coord.Height)
        Click(actualX, actualY)
    } catch {
        ; 窗口找不到就用 1920x1080 的绝对坐标
        Click(Round(rx * 1920), Round(ry * 1080))
    }
}

; === 按键辅助 ===
Key(key, duration := 50) {
    global IsRunning
    if !IsRunning
        return
    ActivateGame()
    SendInput("{" key " down}")
    Sleep(duration)
    SendInput("{" key " up}")
}

KeyDown(key) {
    global IsRunning
    if !IsRunning
        return
    ActivateGame()
    SendInput("{" key " down}")
}

KeyUp(key) {
    SendInput("{" key " up}")
}

ReleaseAllKeys() {
    for _, k in ["w","a","s","d","f","space","lshift","esc","1","2","3","4"] {
        try SendInput("{" k " up}")
    }
}

; === 图像检测封装 ===
FindInterac() {
    r := RunPython("check_interac")
    return r.HasOwnProp("found") && r.found
}

InTeam() {
    r := RunPython("check_in_team")
    return r.HasOwnProp("in_team") && r.in_team
}

InHeist() {
    r := RunPython("check_heist")
    return r.HasOwnProp("in_heist") && r.in_heist
}

HasHeistPanel() {
    r := RunPython("check_heist_panel")
    return r.HasOwnProp("found") && r.found
}

HasExtractPanel() {
    r := RunPython("check_extract_panel")
    return r.HasOwnProp("found") && r.found
}

HasRedHealthBar() {
    r := RunPython("check_red_health")
    return r.HasOwnProp("found") && r.found
}

; === 等待函数 ===
WaitFor(check_func, timeout := 10000, interval := 500, pre_action := "") {
    global IsRunning
    deadline := A_TickCount + timeout
    while A_TickCount < deadline {
        if !IsRunning
            return false
        if pre_action != ""
            pre_action()
        if check_func()
            return true
        Sleep(interval)
    }
    return false
}

; === 进入副本（完全照搬原项目 enter_heist）===
EnterHeist() {
    global IsRunning

    Log("进入副本...")

    ; --- step 1: 直接按F触发交互（站在NPC旁边，一定在队伍界面）---
    Log("按F交互...")
    Key("f", 100)
    Sleep(200)
    if !IsRunning
        return false

    ; --- step 2: 等待 "挑战时间" 面板出现 ---
    ; pre_action: 每隔2秒重新按F（不在队伍界面则点击NPC）
    Log("等待副本面板...")
    global _lastPreAction := 0
    if !WaitFor(HasHeistPanel, 20000, 500, () => _enterHeistPreAction()) {
        Log("副本面板未出现")
        return false
    }
    if !IsRunning
        return false

    ; --- step 3: 面板出现了，sleep(0.5) ---
    Sleep(500)
    if !IsRunning
        return false

    ; --- step 4: 点击"开始"按钮 (0.7734, 0.8824)，等待面板消失 ---
    Log("点击开始按钮...")
    if !WaitFor(() => !HasHeistPanel(), 20000, 1000, () => GameClick(0.7734, 0.8824)) {
        Log("开始按钮点击超时")
        return false
    }
    if !IsRunning
        return false

    ; --- step 5: sleep(0.5) ---
    Sleep(500)
    Log("副本进入中...")
    return true
}

; pre_action：每2秒重发一次F（节流，避免频繁启动 Python）
_enterHeistPreAction() {
    global IsRunning, _lastPreAction
    if !IsRunning
        return
    now := A_TickCount
    if now - _lastPreAction < 2000
        return
    _lastPreAction := now
    Key("f", 100)
}

; === 等待副本加载完成（照搬 _wait_until_heist_loaded）===
; 原项目流程：
;   1. wait_until(in_heist, post_action=skip_dialog, time_out=600)
;   2. wait_until(lambda: not in_heist(), time_out=60)  ← 加载画面闪一下
;   3. wait_until(in_heist, time_out=60)
WaitHeistLoaded() {
    global IsRunning

    Log("等待副本加载...")
    ; step 1: 等 in_heist 变 true（最长 600s，因为有加载+跳过对话）
    ; 期间不断检查跳过对话
    if !WaitFor(InHeist, 600000, 2000, () => _skipDialogCheck()) {
        Log("加载超时 (step1)")
        return false
    }
    if !IsRunning
        return false

    ; step 2: 等 in_heist 变 false（加载画面闪过）
    WaitFor(() => !InHeist(), 60000, 2000)
    if !IsRunning
        return false

    ; step 3: 再等 in_heist 变 true（正式进入副本）
    if !WaitFor(InHeist, 60000, 2000) {
        Log("加载超时 (step3)")
        return false
    }
    if !IsRunning
        return false

    Log("副本加载完成")
    return true
}

; 跳过对话检查（简化版 SkipDialogTask）
_skipDialogCheck() {
    global IsRunning
    if !IsRunning
        return
    ; 点击屏幕中央偏下尝试跳过对话
    ; 原项目用 SkipDialogTask 检测特定 UI 元素，这里简化为偶尔点击
    ; 不做任何操作，让游戏自己处理
}

; === 退出副本（照搬 exit_heist）===
; 原项目流程：
;   1. wait_until(in_team_outside_heist || has_extract_panel, pre_action=send_key("f"))
;   2. if already outside: return
;   3. sleep(1), get_rewards
;   4. click(0.604, 0.701) = 安全撤离按钮, 等面板消失
;   5. sleep(1), wait_until(in_sum_panel) = 结算面板
;   6. sleep(1), click(0.501, 0.864) = 退出按钮, 等面板消失
;   7. sleep(1), wait_in_team(600)
ExitHeist() {
    global IsRunning, HeistSuccess

    Log("退出副本...")

    ; step 1: 等待安全撤离面板或已在队伍界面
    if !WaitFor(() => _isInTeamOutsideHeist() || HasExtractPanel(), 30000, 1000, () => Key("f", 100)) {
        Log("未找到撤离点")
        AbortHeist()
        return false
    }
    if !IsRunning
        return false

    ; step 2: 如果已在队伍界面且不在副本中，直接返回
    if _isInTeamOutsideHeist() {
        Log("已在队伍界面")
        HeistSuccess++
        UpdateLog("成功次数", HeistSuccess)
        return true
    }

    ; step 3: 有安全撤离面板
    Sleep(1000)
    if !IsRunning
        return false

    ; step 4: 点击"安全撤离"按钮 (0.604, 0.701)
    Log("点击安全撤离...")
    GameClick(0.604, 0.701)

    ; 等待面板消失
    WaitFor(() => !HasExtractPanel(), 30000, 1000)
    if !IsRunning
        return false

    ; step 5: 等待结算面板
    Sleep(1000)
    if !IsRunning
        return false

    ; step 6: 点击"退出"按钮 (0.501, 0.864)
    Log("点击退出结算...")
    GameClick(0.501, 0.864)
    Sleep(1000)
    if !IsRunning
        return false

    ; 等结算面板消失
    WaitFor(InTeam, 60000, 2000)
    if !IsRunning
        return false

    Sleep(1000)
    Log("已退出副本")
    HeistSuccess++
    UpdateLog("成功次数", HeistSuccess)
    return true
}

_isInTeamOutsideHeist() {
    return InTeam() && !InHeist()
}

; === 强制退出副本（ESC）===
AbortHeist() {
    global IsRunning, HeistFail
    Log("强制退出副本...")
    HeistFail++
    UpdateLog("失败次数", HeistFail)
    loop 10 {
        if !IsRunning {
            ReleaseAllKeys()
            return
        }
        Key("esc", 100)
        Sleep(2000)
        if _isInTeamOutsideHeist() {
            Log("已退出")
            return
        }
    }
    Log("强制退出失败")
}

; === 单轮劫案（照搬 _run_heist_round）===
RunHeistRound() {
    global IsRunning, HeistCount
    HeistCount++
    UpdateLog("轮次", HeistCount)
    Log("--- 第 " HeistCount " 轮 ---")

    ; 1. 等待交互点
    Log("等待交互点...")
    if !WaitFor(FindInterac, 20000, 1000) {
        if !IsRunning
            return
        Log("未找到交互点")
        return
    }
    if !IsRunning
        return
    Log("找到交互点")

    ; 2. 进入副本
    if !EnterHeist() {
        if !IsRunning
            return
        AbortHeist()
        return
    }
    if !IsRunning
        return

    ; 3. 等待加载完成
    if !WaitHeistLoaded() {
        if !IsRunning
            return
        AbortHeist()
        return
    }
    if !IsRunning
        return

    ; 4. 跑路径
    Log("执行路径...")
    try {
        RunPathMin()
    } catch as e {
        Log("路径异常: " e.Message)
        if IsRunning
            AbortHeist()
        return
    }
    if !IsRunning
        return

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

    ReleaseAllKeys()
    Log("=== 已停止 ===")
    IsRunning := false
    StartBtn.Text := "开始"
}

; === 启动入口 ===
StartPinkClaw() {
    global IsRunning
    if IsRunning {
        ; 立即停止：设 flag + 释放所有按键
        IsRunning := false
        ReleaseAllKeys()
        Log("正在停止...")
        return
    }
    SetTimer(RunHeistLoop, -100)
}
