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
    if not cap.init():
        emit(ok=False, error="找不到游戏窗口")
        return
    mat.init()
    frame = cap.get_frame_gray()
    if frame is None:
        emit(ok=False, error="截图失败")
        return
    r = mat.find("health_bar_slash", frame)
    if r:
        emit(ok=True, in_team=True, pos_x=r[0], pos_y=r[1], pos_w=r[2], pos_h=r[3], score=r[4])
    else:
        emit(ok=True, in_team=False)


def cmd_check_interac(args):
    if not cap.init():
        emit(ok=False, error="找不到游戏窗口")
        return
    mat.init()
    frame = cap.get_frame_gray()
    if frame is None:
        emit(ok=False, error="截图失败")
        return
    r = mat.find("interactable", frame)
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
    """检测安全撤离面板（OCR 在屏幕指定区域查找'安全撤离'）"""
    if not cap.init():
        emit(ok=False, error="找不到游戏窗口")
        return
    import cv2
    img = cap.screenshot()
    arr = np.array(img)
    # 安全撤离面板的大致区域（相对 1920x1080）
    x1, y1 = int(0.260 * 1920), int(0.264 * 1080)
    x2, y2 = int(0.352 * 1920), int(0.326 * 1080)
    roi = arr[y1:y2, x1:x2]
    gray = cv2.cvtColor(roi, cv2.COLOR_RGB2GRAY)
    # 简单白色文字检测：看白色像素占比
    _, white = cv2.threshold(gray, 200, 255, cv2.THRESH_BINARY)
    ratio = np.sum(white == 255) / white.size
    # 粗略判断：白色像素多则可能有文字
    emit(ok=True, found=(ratio > 0.05), white_ratio=f"{ratio:.3f}")


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
    """检测副本面板是否出现（'挑战时间' 文字区域）"""
    if not cap.init():
        emit(ok=False, error="找不到游戏窗口")
        return
    import cv2
    img = cap.screenshot()
    arr = np.array(img)
    # 原项目 OCR 区域: (0.625, 0.483, 0.685, 0.525)
    x1, y1 = int(0.625 * 1920), int(0.483 * 1080)
    x2, y2 = int(0.685 * 1920), int(0.525 * 1080)
    roi = arr[y1:y2, x1:x2]
    gray = cv2.cvtColor(roi, cv2.COLOR_RGB2GRAY)
    _, white = cv2.threshold(gray, 180, 255, cv2.THRESH_BINARY)
    ratio = np.sum(white == 255) / white.size
    emit(ok=True, found=(ratio > 0.08), white_ratio=f"{ratio:.3f}")


def cmd_check_quit_dialog(args):
    """检测“确认退出”对话框（原项目区域: 0.4516, 0.3069, 0.5473, 0.3792）"""
    if not cap.init():
        emit(ok=False, error="找不到游戏窗口")
        return
    import cv2
    img = cap.screenshot()
    arr = np.array(img)
    x1, y1 = int(0.4516 * 1920), int(0.3069 * 1080)
    x2, y2 = int(0.5473 * 1920), int(0.3792 * 1080)
    roi = arr[y1:y2, x1:x2]
    gray = cv2.cvtColor(roi, cv2.COLOR_RGB2GRAY)
    _, white = cv2.threshold(gray, 180, 255, cv2.THRESH_BINARY)
    ratio = np.sum(white == 255) / white.size
    emit(ok=True, found=(ratio > 0.10), white_ratio=f"{ratio:.3f}")


def cmd_check_sum_panel(args):
    """检测结算面板（'退出'按钮区域: 0.4496, 0.8354, 0.5547, 0.8868）"""
    if not cap.init():
        emit(ok=False, error="找不到游戏窗口")
        return
    import cv2
    img = cap.screenshot()
    arr = np.array(img)
    x1, y1 = int(0.4496 * 1920), int(0.8354 * 1080)
    x2, y2 = int(0.5547 * 1920), int(0.8868 * 1080)
    roi = arr[y1:y2, x1:x2]
    gray = cv2.cvtColor(roi, cv2.COLOR_RGB2GRAY)
    _, white = cv2.threshold(gray, 180, 255, cv2.THRESH_BINARY)
    ratio = np.sum(white == 255) / white.size
    emit(ok=True, found=(ratio > 0.10), white_ratio=f"{ratio:.3f}")


def cmd_check_skip_btn(args):
    """检测右上角'跳过'按钮（大致区域: 0.87, 0.02, 0.97, 0.08）"""
    if not cap.init():
        emit(ok=False, error="找不到游戏窗口")
        return
    import cv2
    img = cap.screenshot()
    arr = np.array(img)
    x1, y1 = int(0.87 * 1920), int(0.02 * 1080)
    x2, y2 = int(0.97 * 1920), int(0.08 * 1080)
    roi = arr[y1:y2, x1:x2]
    gray = cv2.cvtColor(roi, cv2.COLOR_RGB2GRAY)
    _, white = cv2.threshold(gray, 180, 255, cv2.THRESH_BINARY)
    ratio = np.sum(white == 255) / white.size
    emit(ok=True, found=(ratio > 0.05), white_ratio=f"{ratio:.3f}")


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
