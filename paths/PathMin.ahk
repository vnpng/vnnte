#Requires AutoHotkey v2.0
; 最小可运行路径 - 用于验证自动化框架
; 只做：切跑图角色 → 向前走一段 → 直接退出副本
;
; 完整路径（HeistPathA.py 有 1200 行）后续再实现

; === 角色切换 ===
SwitchToRunner() {
    ; 切到跑图角色（3号位，配置中 Runner3 默认选中）
    Log("切换到跑图角色 (3)")
    Key("3", 100)
    Sleep(500)
}

SwitchToFighter() {
    ; 切到战斗角色（4号位，配置中 Fighter4 默认选中）
    Log("切换到战斗角色 (4)")
    Key("4", 100)
    Sleep(500)
}

; === 最小路径：goto_lg1 简化版 ===
RunPathMin() {
    Log("PathMin: 开始")
    
    ; 1. 切跑图角色
    SwitchToRunner()
    Sleep(300)
    
    ; 2. 向前走（goto_lg1 的前半段）
    Log("PathMin: 前进")
    KeyDown("w")
    Sleep(3000)  ; 走 3 秒
    
    ; 3. 短冲刺
    Log("PathMin: 冲刺")
    KeyDown("lshift")
    Sleep(200)
    KeyUp("lshift")
    Sleep(2000)
    KeyUp("w")
    Sleep(500)
    
    ; 4. 直接退出（不走完整路径）
    Log("PathMin: 准备退出")
    
    ; 等待出现安全撤离面板（或者直接退出）
    Sleep(2000)
    Log("PathMin: 完成")
}
