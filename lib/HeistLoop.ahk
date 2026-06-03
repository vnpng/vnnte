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

; === VK 码映射 ===
_VK := Map(
    "w", 0x57, "a", 0x41, "s", 0x53, "d", 0x44,
    "f", 0x46, "esc", 0x1B, "space", 0x20,
    "lshift", 0xA0, "1", 0x31, "2", 0x32, "3", 0x33, "4", 0x34,
    "lctrl", 0xA2, "e", 0x45, "q", 0x51, "tab", 0x09
)

_GetVK(key) {
    global _VK
    k := StrLower(key)
    return _VK.Has(k) ? _VK[k] : GetKeySC(key)
}

; === 坐标转换：原项目用 0~1 比例坐标，这里转成屏幕绝对像素 ===
GameClick(rx, ry) {
    global IsRunning
    if !IsRunning
        return
    ; 短暂激活窗口 → 点击 → 立即恢复前一窗口
    try {
        prev := WinGetID("A")
        ActivateGame()
        Sleep(30)
        hwnd := WinGetID("ahk_class " GAME_CLASS)
        coord := WinGetPos("ahk_id " hwnd)
        actualX := coord.X + Round(rx * coord.Width)
        actualY := coord.Y + Round(ry * coord.Height)
        Click(actualX, actualY)
        Sleep(30)
        try WinActivate("ahk_id " prev)
    } catch {
        Click(Round(rx * 1920), Round(ry * 1080))
    }
}

; === 按键辅助（PostMessage 后台发送，不需要激活窗口）===
Key(key, duration := 50) {
    global IsRunning
    if !IsRunning
        return
    try {
        hwnd := WinGetID("ahk_class " GAME_CLASS)
        vk := _GetVK(key)
        sc := GetKeySC(key) || 0
        lParamDown := 1 | (sc << 16)
        lParamUp := 1 | (sc << 16) | 0xC0000000
        PostMessage(0x100, vk, lParamDown, , "ahk_id " hwnd)
        Sleep(duration)
        PostMessage(0x101, vk, lParamUp, , "ahk_id " hwnd)
    } catch {
        ; 回退：SendInput 需要前台
        ActivateGame()
        SendInput("{" key " down}")
        Sleep(duration)
        SendInput("{" key " up}")
    }
}

KeyDown(key) {
    global IsRunning
    if !IsRunning
        return
    try {
        hwnd := WinGetID("ahk_class " GAME_CLASS)
        vk := _GetVK(key)
        sc := GetKeySC(key) || 0
        lParamDown := 1 | (sc << 16)
        PostMessage(0x100, vk, lParamDown, , "ahk_id " hwnd)
    } catch {
        ActivateGame()
        SendInput("{" key " down}")
    }
}

KeyUp(key) {
    try {
        hwnd := WinGetID("ahk_class " GAME_CLASS)
        vk := _GetVK(key)
        sc := GetKeySC(key) || 0
        lParamUp := 1 | (sc << 16) | 0xC0000000
        PostMessage(0x101, vk, lParamUp, , "ahk_id " hwnd)
    } catch {
        try SendInput("{" key " up}")
    }
}

ReleaseAllKeys() {
    try {
        hwnd := WinGetID("ahk_class " GAME_CLASS)
        for _, k in ["w","a","s","d","f","space","lshift","esc","1","2","3","4"] {
            try {
                vk := _GetVK(k)
                sc := GetKeySC(k) || 0
                lParamUp := 1 | (sc << 16) | 0xC0000000
                PostMessage(0x101, vk, lParamUp, , "ahk_id " hwnd)
            }
        }
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
    ; 期间不断检查跳过对话（照搬原项目 post_action=skip_dialog）
    if !WaitFor(InHeist, 600000, 2000, () => _skipDialogCheck()) {
        Log("加载超时 (step1)")
        return false
    }
    if !IsRunning
        return false

    ; step 2: 等 in_heist 变 false（加载画面闪过）
    ; 期间也检查跳过
    WaitFor(() => !InHeist(), 60000, 2000, () => _skipDialogCheck())
    if !IsRunning
        return false

    ; step 3: 再等 in_heist 变 true（正式进入副本）
    if !WaitFor(InHeist, 60000, 2000, () => _skipDialogCheck()) {
        Log("加载超时 (step3)")
        return false
    }
    if !IsRunning
        return false

    Log("副本加载完成")
    return true
}

; 跳过对话检查（照搬原项目 SkipDialogTask.check_skip）
; 原项目每 0.5s 触发一次，这里每次 WaitFor 间隔 2s 检查
_skipDialogCheck() {
    global IsRunning
    if !IsRunning
        return
    TrySkipDialog()
}

HasQuitDialog() {
    r := RunPython("check_quit_dialog")
    return r.HasOwnProp("found") && r.found
}

HasSumPanel() {
    r := RunPython("check_sum_panel")
    return r.HasOwnProp("found") && r.found
}

HasSkipBtn() {
    r := RunPython("check_skip_btn")
    if r.HasOwnProp("found") && r.found
        return r
    return false
}

HasConfirm() {
    r := RunPython("check_confirm")
    if r.HasOwnProp("found") && r.found
        return r
    return false
}

; === 跳过对话（照搬 SkipDialogTask）===
; 原项目流程:
;   1. find_skip() → 找到"跳过"按钮模板
;   2. operate_click(skip) → 点击跳过按钮位置
;   3. 弹出"确认跳过"对话框
;   4. find_confirm() → 找到确认按钮模板
;   5. click(0.4508, 0.5194) → 点击对话框区域
;   6. operate_click(confirm_btn) → 点击确认按钮
TrySkipDialog() {
    global IsRunning
    if !IsRunning
        return false

    ; 检测右上角"跳过"按钮（照搬原项目 find_skip 模板匹配）
    skipResult := HasSkipBtn()
    if skipResult {
        Log("点击跳过...")
        ; 原项目: operate_click(skip) = 点击模板匹配到的位置
        ; 计算中心点并转为相对坐标
        rx := (skipResult.pos_x + skipResult.pos_w / 2) / 1920
        ry := (skipResult.pos_y + skipResult.pos_h / 2) / 1080
        GameClick(rx, ry)
        Sleep(400)
        if !IsRunning
            return true

        ; 原项目 skip_confirm():
        ; 1. find_confirm() 查找确认按钮
        ; 2. click(0.4508, 0.5194) 点击对话框区域
        ; 3. operate_click(confirm_btn) 点击确认按钮
        confirmResult := HasConfirm()
        if confirmResult {
            GameClick(0.4508, 0.5194)
            Sleep(400)
            ; 点击确认按钮的实际位置
            crx := (confirmResult.pos_x + confirmResult.pos_w / 2) / 1920
            cry := (confirmResult.pos_y + confirmResult.pos_h / 2) / 1080
            GameClick(crx, cry)
            Sleep(500)
        } else {
            ; 找不到确认按钮模板，回退到固定坐标
            GameClick(0.4508, 0.5194)
            Sleep(500)
        }
        Log("已跳过对话")
        return true
    }

    ; 也检查"确认跳过"对话框（可能已经点过跳过按钮了）
    confirmResult := HasConfirm()
    if confirmResult {
        GameClick(0.4508, 0.5194)
        Sleep(300)
        return true
    }

    return false
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

; === 强制退出副本（完全照搬原项目 abort_heist）===
; 原项目流程：
;   1. wait_until(in_team_outside_heist || find_quit_dialog, pre_action=send_esc, time_out=60)
;   2. if already outside: return
;   3. wait_ocr "确认" 按钮 (0.50, 0.60, 0.70, 0.70)
;   4. wait_until(not find_quit_dialog, pre_action=click confirm, time_out=60)
;   5. wait_in_team(60)
AbortHeist() {
    global IsRunning, HeistFail
    Log("强制退出副本...")
    HeistFail++
    UpdateLog("失败次数", HeistFail)

    ; step 1: 按 ESC 直到退出对话框出现或已在队伍界面
    if !WaitFor(() => _isInTeamOutsideHeist() || HasQuitDialog(), 60000, 2000, () => Key("esc", 100)) {
        Log("ESC超时")
        return
    }
    if !IsRunning
        return

    ; step 2: 如果已在队伍界面且不在副本中，直接返回
    if _isInTeamOutsideHeist() {
        Log("已在队伍界面，跳过退出")
        return
    }

    ; step 3: 退出对话框出现了，点击"确认"按钮 (0.60, 0.65)
    ; 原项目: wait_ocr "确认" (0.50, 0.60, 0.70, 0.70)
    Log("点击确认退出...")
    Sleep(500)
    GameClick(0.60, 0.65)
    Sleep(1000)
    if !IsRunning
        return

    ; step 4: 等待对话框消失
    WaitFor(() => !HasQuitDialog(), 60000, 2000, () => GameClick(0.60, 0.65))
    if !IsRunning
        return

    ; step 5: 等待回到队伍界面
    Log("等待回到队伍界面...")
    WaitFor(InTeam, 60000, 2000)
    if !IsRunning
        return

    Log("已退出副本")
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

    ; 5. 退出副本（PathMin不走完整路径，用AbortHeist强制退出）
    AbortHeist()
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
