# vnnte - 复刻 ok-nte 自动粉爪大劫案

## 第一阶段（当前）：烟测

只验证：找到游戏窗口 -> 截图 -> 模板匹配 -> GUI 显示。

## 安装步骤

1. 打开 PowerShell，cd 到项目目录：
   ```
   cd D:\Gamesss\NTEEEEEEEEE\vnnte
   ```

2. 验证 Python 依赖：
   ```
   python tools\check_deps.py
   ```

3. 如果有缺失，双击 `install.bat` 安装。

4. 下载模板图（从原项目仓库）：
   ```
   python tools\fetch_assets.py
   ```

5. 打开异环游戏（窗口化 1920x1080）。

6. 双击 `vnnte.ahk`，GUI 会出现。

7. 在 GUI 里点 "开始" 或按 F10，触发烟测。

## 烟测结果怎么看

- 成功的话，日志表会显示：
  - "截图已保存" + 窗口尺寸
  - "队伍界面: 在" 或 "不在"
  - "F 互动提示: 找到" 或 "未找到"
- 截图保存在 `logs/screenshot.png`，可以打开看是不是游戏画面。

## 目录结构

```
vnnte/
├── vnnte.ahk              主入口
├── config.ini             配置
├── requirements.txt       Python 依赖
├── install.bat            一键安装
├── README.md              本文件
├── lib/
│   └── GUI.ahk            界面
├── paths/
│   ├── PathA.ahk          路径 A（占位）
│   └── _template.ahk      新路径模板（占位）
├── cv/
│   ├── capture.py         截图
│   └── matcher.py         模板匹配
├── tools/
│   ├── check_deps.py      依赖检查
│   ├── fetch_assets.py    下载模板
│   └── one_shot.py        一键命令
├── assets/                模板图（运行 fetch_assets.py 后生成）
└── logs/                  截图和日志
```

## 常见问题

- 提示 "找不到游戏窗口 (HTGame.exe)"：游戏没开，或不是窗口化，或窗口类不是 UnrealWindow
- 截图是黑屏：游戏可能锁了画面，试试把游戏切到前台
