"""模板匹配模块：加载 assets/ 下的模板图，对当前帧做 matchTemplate"""
import cv2
from pathlib import Path

ASSETS = Path(__file__).parent.parent / "assets"

_templates = {}


def init():
    """加载 assets/ 下所有 png 作为模板，返回加载数量"""
    global _templates
    _templates.clear()
    if not ASSETS.exists():
        return 0
    count = 0
    for png in ASSETS.glob("*.png"):
        img = cv2.imread(str(png), cv2.IMREAD_GRAYSCALE)
        if img is not None:
            _templates[png.stem] = img
            count += 1
    return count


def list_templates():
    return list(_templates.keys())


def find(name, frame, threshold=0.7):
    """在 frame 中查找 name 模板。返回 (x, y, w, h, score) 或 None"""
    if name not in _templates or frame is None:
        return None
    template = _templates[name]
    if frame.shape[0] < template.shape[0] or frame.shape[1] < template.shape[1]:
        return None
    result = cv2.matchTemplate(frame, template, cv2.TM_CCOEFF_NORMED)
    _, max_val, _, max_loc = cv2.minMaxLoc(result)
    if max_val >= threshold:
        h, w = template.shape
        return (max_loc[0], max_loc[1], w, h, float(max_val))
    return None
