"""单次命令：screenshot / check_in_team / check_interac / list_templates
                check_heist / check_extract_panel / check_red_health
供 AHK 通过 RunWait 调用，结果以 key=value 纯文本输出到 stdout。

每行一个键值对：
  ok=true|false
  key=value
  list_key=item1|item2|item3   (列表用 | 分隔)
"""
import sys
import argparse
import numpy as np
from pathlib import Path

ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(ROOT))

import cv.capture as cap
import cv.matcher as mat
import cv.ocr as ocr_mod
import cv2

# === 照搬原项目 BaseNTETask 的颜色掩码工具 ===
def _color_range_to_bound(color_range):
    """照搬 ok-script color_range_to_bound"""
    import numpy as np
    lower = np.array([color_range['b'][0], color_range['g'][0], color_range['r'][0]], dtype="uint8")
    upper = np.array([color_range['b'][1], color_range['g'][1], color_range['r'][1]], dtype="uint8")
    return lower, upper


def _create_color_mask(image, color_range, to_bgr=True):
    """照搬原项目 image_utils.create_color_mask"""
    lower, upper = _color_range_to_bound(color_range)
    match_mask = cv2.inRange(image, lower, upper)
    if not to_bgr:
        return match_mask
    return cv2.cvtColor(match_mask, cv2.COLOR_GRAY2BGR)


def _morphology_mask(mask, kernel_size=3, to_bgr=True):
    """照搬原项目 image_utils.morphology_mask"""
    import numpy as np
    kernel = np.ones((kernel_size, kernel_size), np.uint8)
    result = cv2.dilate(mask, kernel, iterations=1)
    if to_bgr and len(result.shape) == 2:
        result = cv2.cvtColor(result, cv2.COLOR_GRAY2BGR)
    return result


# 照搬原项目 interac_pink_color
_INTERAC_PINK = {"r": (197, 221), "g": (71, 78), "b": (119, 133)}


def _interac_mask(image):
    """照搬原项目 BaseNTETask.interac_mask"""
    mask = _create_color_mask(image, _INTERAC_PINK, to_bgr=False)
    return _morphology_mask(mask, kernel_size=5, to_bgr=True)


def _mask_corners(image, ratio_w=0.5555, ratio_h=0.8571, to_bgr=True):
    """照搬原项目 image_utils.mask_corners
    将左上角和右下角三角形涂黑，其余白色"""
    import numpy as np
    h, w = image.shape[:2]
    x_left = int(w * ratio_w)
    x_right = int(w * (1 - ratio_w))
    y_top = int(h * ratio_h)
    y_bottom = int(h * (1 - ratio_h))
    contours = [
        np.array([[0, 0], [x_left, 0], [0, y_top]], dtype=np.int32),
        np.array([[w, h], [x_right, h], [w, y_bottom]], dtype=np.int32),
    ]
    mask_shape = image.shape if to_bgr else image.shape[:2]
    white = np.ones(mask_shape, dtype=np.uint8) * 255
    fill_color = (0, 0, 0) if to_bgr else 0
    return cv2.fillPoly(white, contours, fill_color)


def emit(**kw):
    """把 dict 输出为 key=value 格式"""
    for k, v in kw.items():
        if v is None:
            print(f"{k}=")
        elif isinstance(v, bool):
            print(f"{k}={'true' if v else 'false'}")
        elif isinstance(v, (list, tuple)):
            print(f"{k}=" + "|".join(str(x) for x in v))
        else:
            print(f"{k}={v}")


def cmd_screenshot(args):
    if not cap.init():
        emit(ok=False, error="找不到游戏窗口 (HTGame.exe)")
        return
    out = ROOT / "logs" / "screenshot.png"
    out.parent.mkdir(exist_ok=True)
    img = cap.screenshot(str(out))
    rect = cap.get_window_rect()
    emit(
        ok=True,
        path=str(out),
        size_w=img.size[0],
        size_h=img.size[1],
        phys_w=rect[2] - rect[0],
        phys_h=rect[3] - rect[1],
    )


def cmd_check_in_team(args):
    """检测是否在队伍中 - 照搬原项目 is_in_team():
    find_one(health_bar_slash, mask_function=mask_corners,
             horizontal_variance=0.01, vertical_variance=0.005)
    """
    if not cap.init():
        emit(ok=False, error="找不到游戏窗口")
        return
    mat.init()
    frame = cap.get_frame_bgr()
    if frame is None:
        emit(ok=False, error="截图失败")
        return
    r = mat.find("health_bar_slash", frame,
                 horizontal_variance=0.01, vertical_variance=0.005,
                 mask_function=_mask_corners)
    if r:
        emit(ok=True, in_team=True, pos_x=r[0], pos_y=r[1], pos_w=r[2], pos_h=r[3], score=r[4])
    else:
        emit(ok=True, in_team=False)


def cmd_check_interac(args):
    """检测交互图标 - 照搬原项目 find_interac():
    find_one(interactable, box=interac_box, threshold=0.7,
             mask_function=interac_mask, use_gray_scale=True)
    """
    if not cap.init():
        emit(ok=False, error="找不到游戏窗口")
        return
    mat.init()
    frame = cap.get_frame_bgr()
    if frame is None:
        emit(ok=False, error="截图失败")
        return

    # 照搬原项目 interac_box: 从模板位置扩展搜索区域
    tpl_info = mat._templates.get("interactable")
    search_box = None
    if tpl_info:
        bx, by, bw, bh = tpl_info["x"], tpl_info["y"], tpl_info["w"], tpl_info["h"]
        search_box = {
            "x": max(0, round(bx - bw * 0.3)),
            "y": max(0, round(by - bh * 2.5)),
            "w": round(bw * 1.6),
            "h": round(bh * 5),
        }

    r = mat.find("interactable", frame, threshold=0.7,
                 box=search_box, mask_function=_interac_mask,
                 use_gray_scale=True)
    if r:
        emit(ok=True, found=True, pos_x=r[0], pos_y=r[1], pos_w=r[2], pos_h=r[3], score=r[4])
    else:
        emit(ok=True, found=False)


def cmd_list_templates(args):
    mat.init()
    tpls = mat.list_templates()
    emit(ok=True, count=len(tpls), templates=tpls)


def cmd_check_heist(args):
    """检测是否在副本内（左上角有 heist_timer 模板）"""
    if not cap.init():
        emit(ok=False, error="找不到游戏窗口")
        return
    mat.init()
    frame = cap.get_frame_gray()
    if frame is None:
        emit(ok=False, error="截图失败")
        return
    r = mat.find("heist_timer", frame, threshold=0.6)
    if r:
        emit(ok=True, in_heist=True, pos_x=r[0], pos_y=r[1], score=r[4])
    else:
        emit(ok=True, in_heist=False)


def cmd_check_extract_panel(args):
    """检测安全撤离面板 - 照搬原项目: ocr(0.2602, 0.2639, 0.3520, 0.3257, match='安全撤离')"""
    if not cap.init():
        emit(ok=False, error="找不到游戏窗口")
        return
    frame = cap.get_frame_bgr()
    if frame is None:
        emit(ok=False, error="截图失败")
        return
    region = ocr_mod.crop_region(frame, 0.2602, 0.2639, 0.3520, 0.3257)
    found = ocr_mod.ocr(region, match="安全撤离")
    texts = ocr_mod.ocr_texts(region)
    emit(ok=True, found=found, texts=texts)


def cmd_check_red_health(args):
    """检测红色血条（health_bar_slash 模板）"""
    if not cap.init():
        emit(ok=False, error="找不到游戏窗口")
        return
    mat.init()
    frame = cap.get_frame_gray()
    if frame is None:
        emit(ok=False, error="截图失败")
        return
    r = mat.find("health_bar_slash", frame, threshold=0.5)
    if r:
        emit(ok=True, found=True, pos_x=r[0], pos_y=r[1], score=r[4])
    else:
        emit(ok=True, found=False)


def cmd_check_heist_panel(args):
    """检测副本面板 - 照搬原项目: ocr(0.625, 0.483, 0.685, 0.525, match='挑战时间')"""
    if not cap.init():
        emit(ok=False, error="找不到游戏窗口")
        return
    frame = cap.get_frame_bgr()
    if frame is None:
        emit(ok=False, error="截图失败")
        return
    region = ocr_mod.crop_region(frame, 0.625, 0.483, 0.685, 0.525)
    found = ocr_mod.ocr(region, match="挑战时间")
    texts = ocr_mod.ocr_texts(region)
    emit(ok=True, found=found, texts=texts)


def cmd_check_quit_dialog(args):
    """检测“确认退出”对话框 - 照搬原项目: ocr(0.4516, 0.3069, 0.5473, 0.3792, match='确认退出')"""
    if not cap.init():
        emit(ok=False, error="找不到游戏窗口")
        return
    frame = cap.get_frame_bgr()
    if frame is None:
        emit(ok=False, error="截图失败")
        return
    region = ocr_mod.crop_region(frame, 0.4516, 0.3069, 0.5473, 0.3792)
    found = ocr_mod.ocr(region, match="确认退出")
    texts = ocr_mod.ocr_texts(region)
    emit(ok=True, found=found, texts=texts)


def cmd_check_sum_panel(args):
    """检测结算面板 - 照搬原项目: ocr(0.4496, 0.8354, 0.5547, 0.8868, match='退出')"""
    if not cap.init():
        emit(ok=False, error="找不到游戏窗口")
        return
    frame = cap.get_frame_bgr()
    if frame is None:
        emit(ok=False, error="截图失败")
        return
    region = ocr_mod.crop_region(frame, 0.4496, 0.8354, 0.5547, 0.8868)
    found = ocr_mod.ocr(region, match="退出")
    texts = ocr_mod.ocr_texts(region)
    emit(ok=True, found=found, texts=texts)


def cmd_check_skip_btn(args):
    """检测跳过按钮 - 照搬原项目: find_one(skip_dialog, horizontal_variance=0.02, threshold=0.75)"""
    if not cap.init():
        emit(ok=False, error="找不到游戏窗口")
        return
    mat.init()
    frame = cap.get_frame_gray()
    if frame is None:
        emit(ok=False, error="截图失败")
        return
    r = mat.find("skip_dialog", frame, horizontal_variance=0.02, threshold=0.75)
    if r:
        emit(ok=True, found=True, pos_x=r[0], pos_y=r[1], pos_w=r[2], pos_h=r[3], score=r[4])
    else:
        emit(ok=True, found=False)


def cmd_check_confirm(args):
    """检测确认按钮 - 照搬原项目: find_confirm() = find_best_match_in_box(confirm_btn_1, confirm_btn_2)"""
    if not cap.init():
        emit(ok=False, error="找不到游戏窗口")
        return
    mat.init()
    frame = cap.get_frame_gray()
    if frame is None:
        emit(ok=False, error="截图失败")
        return
    # 原项目 find_confirm: 在 main_viewport 中查找 confirm_btn_1 或 confirm_btn_2
    # main_viewport 大约是整个游戏画面
    r1 = mat.find("confirm_btn_1", frame, threshold=0.8)
    r2 = mat.find("confirm_btn_2", frame, threshold=0.8)
    # 取分数最高的
    best = None
    if r1 and r2:
        best = r1 if r1[4] >= r2[4] else r2
    elif r1:
        best = r1
    elif r2:
        best = r2
    if best:
        emit(ok=True, found=True, pos_x=best[0], pos_y=best[1], pos_w=best[2], pos_h=best[3], score=best[4])
    else:
        emit(ok=True, found=False)


def main():
    p = argparse.ArgumentParser()
    s = p.add_subparsers(dest="cmd")
    s.add_parser("screenshot")
    s.add_parser("check_in_team")
    s.add_parser("check_interac")
    s.add_parser("list_templates")
    s.add_parser("check_heist")
    s.add_parser("check_extract_panel")
    s.add_parser("check_red_health")
    s.add_parser("check_heist_panel")
    s.add_parser("check_quit_dialog")
    s.add_parser("check_sum_panel")
    s.add_parser("check_skip_btn")
    s.add_parser("check_confirm")
    args = p.parse_args()
    handlers = {
        "screenshot": cmd_screenshot,
        "check_in_team": cmd_check_in_team,
        "check_interac": cmd_check_interac,
        "list_templates": cmd_list_templates,
        "check_heist": cmd_check_heist,
        "check_extract_panel": cmd_check_extract_panel,
        "check_red_health": cmd_check_red_health,
        "check_heist_panel": cmd_check_heist_panel,
        "check_quit_dialog": cmd_check_quit_dialog,
        "check_sum_panel": cmd_check_sum_panel,
        "check_skip_btn": cmd_check_skip_btn,
        "check_confirm": cmd_check_confirm,
    }
    h = handlers.get(args.cmd)
    if h:
        try:
            h(args)
        except Exception as e:
            emit(ok=False, error=str(e))
    else:
        p.print_help()


if __name__ == "__main__":
    main()
