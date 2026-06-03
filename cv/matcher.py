"""
模板匹配模块 - 照搬 ok-script FeatureSet 实现
从 assets/coco_annotations.json 加载模板，用 cv2.matchTemplate 做匹配
"""
import json
import os

import cv2
import numpy as np
from pathlib import Path

ASSETS = Path(__file__).parent.parent / "assets"

# 目标分辨率（原项目截图是 2560x1440，我们目标是 1920x1080）
TARGET_W = 1920
TARGET_H = 1080

_templates = {}  # name -> {"mat": ndarray, "x": int, "y": int, "w": int, "h": int, "scale": float}
_boxes = {}  # name -> {"x": int, "y": int, "w": int, "h": int}
_loaded = False


def _scale_by_anchor(val, image_dim, screen_dim, scale, center=False):
    """照搬 ok-script FeatureSet.scale_by_anchor"""
    if center:
        return round(screen_dim * 0.5 + (val - image_dim * 0.5) * scale)
    if val > image_dim / 2:
        return screen_dim - round((image_dim - val) * scale)
    return round(val * scale)


def _adjust_coordinates(x, y, w, h, screen_w, screen_h, img_w, img_h, hcenter=False, vcenter=False):
    """照搬 ok-script FeatureSet.adjust_coordinates"""
    if screen_w != img_w or screen_h != img_h:
        scale_x = screen_w / img_w
        scale_y = screen_h / img_h
        scale = min(scale_x, scale_y)
    else:
        scale = 1

    new_w = max(1, round(w * scale))
    new_h = max(1, round(h * scale))
    new_x = _scale_by_anchor(x, img_w, screen_w, scale, center=hcenter)
    new_y = _scale_by_anchor(y, img_h, screen_h, scale, center=vcenter)

    return new_x, new_y, new_w, new_h, scale


def init():
    """从 COCO JSON 加载所有模板，返回加载数量"""
    global _templates, _boxes, _loaded

    if _loaded:
        return len(_templates)

    coco_path = ASSETS / "coco_annotations.json"
    if not coco_path.exists():
        print(f"ERROR: coco_annotations.json not found at {coco_path}")
        return 0

    with open(coco_path, "r", encoding="utf-8") as f:
        coco_data = json.load(f)

    image_map = {img["id"]: img for img in coco_data["images"]}
    category_map = {cat["id"]: cat["name"] for cat in coco_data["categories"]}

    source_images = {}
    _templates = {}
    _boxes = {}

    for ann in coco_data["annotations"]:
        img_info = image_map.get(ann["image_id"])
        if img_info is None:
            continue

        cat_name = category_map.get(ann["category_id"], "")
        if not cat_name:
            continue

        img_id = ann["image_id"]
        if img_id not in source_images:
            img_path = ASSETS / img_info["file_name"]
            if not img_path.exists():
                continue
            source_images[img_id] = cv2.imread(str(img_path))
            if source_images[img_id] is None:
                continue

        src_img = source_images[img_id]
        img_h, img_w = src_img.shape[:2]

        # 裁剪模板
        bx, by, bw, bh = [round(v) for v in ann["bbox"]]
        template = src_img[by:by + bh, bx:bx + bw, :3]

        if template.shape[0] == 0 or template.shape[1] == 0:
            continue

        hcenter = "hcenter" in cat_name
        vcenter = "vcenter" in cat_name

        adj_x, adj_y, adj_w, adj_h, scale = _adjust_coordinates(
            bx, by, bw, bh, TARGET_W, TARGET_H, img_w, img_h,
            hcenter=hcenter, vcenter=vcenter
        )

        if scale != 1:
            scaled_template = cv2.resize(template, (adj_w, adj_h), interpolation=cv2.INTER_AREA)
        else:
            scaled_template = template

        if cat_name.startswith("box_"):
            _boxes[cat_name] = {"x": adj_x, "y": adj_y, "w": adj_w, "h": adj_h}
        else:
            _templates[cat_name] = {
                "mat": scaled_template,
                "x": adj_x,
                "y": adj_y,
                "w": adj_w,
                "h": adj_h,
                "scale": scale,
            }

    _loaded = True
    return len(_templates)


def list_templates():
    return list(_templates.keys())


def get_box(name):
    """获取搜索区域 box"""
    return _boxes.get(name)


def find(name, frame, threshold=0.7, use_gray_scale=False,
         horizontal_variance=0, vertical_variance=0, box=None,
         mask_function=None, match_method=cv2.TM_CCOEFF_NORMED):
    """
    在 frame 中查找模板。
    照搬 ok-script FeatureSet.find_one_feature 核心逻辑。

    Args:
        name: 模板名称
        frame: 截图 (numpy array, BGR 或 gray)
        threshold: 匹配阈值
        use_gray_scale: 是否转灰度匹配
        horizontal_variance: 水平搜索区域扩展比例
        vertical_variance: 垂直搜索区域扩展比例
        box: 搜索区域 dict {"x","y","w","h"}
        mask_function: 掩码函数
        match_method: OpenCV 匹配方法

    Returns:
        (x, y, w, h, score) 或 None
    """
    if name not in _templates or frame is None:
        return None

    tpl = _templates[name]
    template = tpl["mat"]
    tpl_h, tpl_w = template.shape[:2]

    # frame 尺寸
    if len(frame.shape) == 2:
        screen_h, screen_w = frame.shape[:2]
    else:
        screen_h, screen_w = frame.shape[:2]

    # 计算搜索区域
    if box is not None:
        sx1 = max(0, box["x"])
        sy1 = max(0, box["y"])
        sx2 = min(screen_w, box["x"] + box["w"])
        sy2 = min(screen_h, box["y"] + box["h"])
    elif horizontal_variance > 0 or vertical_variance > 0:
        x_off = screen_w * horizontal_variance
        y_off = screen_h * vertical_variance
        sx1 = max(0, round(tpl["x"] - x_off))
        sy1 = max(0, round(tpl["y"] - y_off))
        sx2 = min(screen_w, round(tpl["x"] + tpl_w + x_off))
        sy2 = min(screen_h, round(tpl["y"] + tpl_h + y_off))
    else:
        sx1, sy1 = 0, 0
        sx2, sy2 = screen_w, screen_h

    search_area = frame[sy1:sy2, sx1:sx2]
    if len(search_area.shape) == 3:
        search_area = search_area[:, :, :3]

    if search_area.shape[0] < tpl_h or search_area.shape[1] < tpl_w:
        return None

    # 灰度转换
    search_for_match = search_area
    template_for_match = template
    if use_gray_scale:
        if len(search_area.shape) != 2:
            search_for_match = cv2.cvtColor(search_area, cv2.COLOR_BGR2GRAY)
        if len(template.shape) != 2:
            template_for_match = cv2.cvtColor(template, cv2.COLOR_BGR2GRAY)

    # 掩码
    mask = None
    if mask_function is not None:
        tpl_mat = template if len(template.shape) != 2 else cv2.cvtColor(template, cv2.COLOR_GRAY2BGR)
        mask = mask_function(tpl_mat)

    # 模板匹配
    if mask is not None:
        result = cv2.matchTemplate(search_for_match, template_for_match, match_method, mask=mask)
    else:
        result = cv2.matchTemplate(search_for_match, template_for_match, match_method)

    result[np.isinf(result)] = 0
    result[np.isnan(result)] = 0

    _, max_val, _, max_loc = cv2.minMaxLoc(result)

    if max_val >= threshold:
        return (max_loc[0] + sx1, max_loc[1] + sy1, tpl_w, tpl_h, float(max_val))

    return None


def find_all(name, frame, threshold=0.8, box=None, use_gray_scale=False):
    """查找多个匹配。返回 [(x, y, w, h, score), ...]"""
    if name not in _templates or frame is None:
        return []

    tpl = _templates[name]
    template = tpl["mat"]
    tpl_h, tpl_w = template.shape[:2]

    if len(frame.shape) == 2:
        screen_h, screen_w = frame.shape[:2]
    else:
        screen_h, screen_w = frame.shape[:2]

    if box is not None:
        sx1 = max(0, box["x"])
        sy1 = max(0, box["y"])
        sx2 = min(screen_w, box["x"] + box["w"])
        sy2 = min(screen_h, box["y"] + box["h"])
    else:
        sx1, sy1 = 0, 0
        sx2, sy2 = screen_w, screen_h

    search_area = frame[sy1:sy2, sx1:sx2]
    if len(search_area.shape) == 3:
        search_area = search_area[:, :, :3]

    if search_area.shape[0] < tpl_h or search_area.shape[1] < tpl_w:
        return []

    if use_gray_scale:
        if len(search_area.shape) != 2:
            search_area = cv2.cvtColor(search_area, cv2.COLOR_BGR2GRAY)
        if len(template.shape) != 2:
            template = cv2.cvtColor(template, cv2.COLOR_BGR2GRAY)

    result = cv2.matchTemplate(search_area, template, cv2.TM_CCOEFF_NORMED)
    result[np.isinf(result)] = 0
    result[np.isnan(result)] = 0

    locations = np.where(result >= threshold)
    matches = list(zip(*locations[::-1]))
    confidences = result[result >= threshold]

    sorted_matches = sorted(zip(matches, confidences), key=lambda x: x[1], reverse=True)
    selected = []
    for (mx, my), conf in sorted_matches:
        overlap = False
        for sx, sy, _ in selected:
            if mx < sx + tpl_w and mx + tpl_w > sx and my < sy + tpl_h and my + tpl_h > sy:
                overlap = True
                break
        if not overlap:
            selected.append((mx, my, float(conf)))

    return [(mx + sx1, my + sy1, tpl_w, tpl_h, conf) for mx, my, conf in selected]
