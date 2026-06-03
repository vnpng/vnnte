"""单次命令：screenshot / check_in_team / check_interac / list_templates
供 AHK 通过 RunWait 调用，结果以 key=value 纯文本输出到 stdout。

每行一个键值对：
  ok=true|false
  key=value
  list_key=item1|item2|item3   (列表用 | 分隔)
"""
import sys
import argparse
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


def main():
    p = argparse.ArgumentParser()
    s = p.add_subparsers(dest="cmd")
    s.add_parser("screenshot")
    s.add_parser("check_in_team")
    s.add_parser("check_interac")
    s.add_parser("list_templates")
    args = p.parse_args()
    handlers = {
        "screenshot": cmd_screenshot,
        "check_in_team": cmd_check_in_team,
        "check_interac": cmd_check_interac,
        "list_templates": cmd_list_templates,
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
