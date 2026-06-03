"""截图模块：使用 mss（WGC 后台截图）抓取游戏窗口
抓到后统一缩放到 1920x1080（按逻辑分辨率），这样所有模板匹配都在同一坐标系。
"""
import mss
import numpy as np
import cv2
import win32gui
from PIL import Image

WINDOW_CLASS = "UnrealWindow"
TARGET_W, TARGET_H = 1920, 1080

_sct = None
_hwnd = None


def init():
    """查找游戏窗口并初始化 mss。返回是否成功。"""
    global _sct, _hwnd
    _sct = mss.mss()
    _hwnd = _find_window()
    return _hwnd is not None


def _find_window():
    """枚举窗口找到 HTGame.exe 主窗口"""
    hwnd = None

    def cb(h, _):
        nonlocal hwnd
        try:
            if win32gui.GetClassName(h) == WINDOW_CLASS and win32gui.IsWindowVisible(h):
                hwnd = h
                return False
        except Exception:
            pass
        return True

    win32gui.EnumWindows(cb, None)
    return hwnd


def get_window_rect():
    """返回 (x1, y1, x2, y2)，未找到窗口返回 None"""
    if _hwnd is None:
        return None
    return win32gui.GetWindowRect(_hwnd)


def screenshot(path=None):
    """截取游戏窗口，返回 PIL Image（已缩放到 1920x1080），可选保存到 path"""
    if _hwnd is None or _sct is None:
        raise RuntimeError("未初始化或找不到游戏窗口")
    rect = win32gui.GetWindowRect(_hwnd)
    x, y, x2, y2 = rect
    w, h = x2 - x, y2 - y
    if w <= 0 or h <= 0:
        raise RuntimeError(f"窗口尺寸为 0: {w}x{h}")
    monitor = {"left": x, "top": y, "width": w, "height": h}
    sct_img = _sct.grab(monitor)
    img = Image.frombytes("RGB", sct_img.size, sct_img.bgra, "raw", "BGRX")
    if img.size != (TARGET_W, TARGET_H):
        img = img.resize((TARGET_W, TARGET_H), Image.LANCZOS)
    if path:
        img.save(path)
    return img


def get_frame_gray():
    """获取当前游戏画面，缩放到 1920x1080 后转灰度 numpy 数组（用于模板匹配）"""
    img = screenshot()
    arr = np.array(img)
    return cv2.cvtColor(arr, cv2.COLOR_RGB2GRAY)
