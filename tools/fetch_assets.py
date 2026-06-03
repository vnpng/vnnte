"""从原 ok-nte 仓库下载模板图（COCO 标注方式）并按 1920x1080 缩放后保存到 assets/"""
import json
import sys
from pathlib import Path

import cv2
import requests

ROOT = Path(__file__).parent.parent
ASSETS = ROOT / "assets"
TEMP = ROOT / "tools" / "_tmp"
TEMP.mkdir(exist_ok=True)
ASSETS.mkdir(exist_ok=True)

BASE = "https://raw.githubusercontent.com/BnanZ0/ok-nte/main/assets"
TARGET = (1920, 1080)
SOURCE = (2560, 1440)

WANTED = [
    "heist_timer", "heist_interac_lock_pick", "heist_lock_pick",
    "interactable", "health_bar_slash", "is_current_char",
    "box_char_1", "box_char_2", "box_char_3", "box_char_4",
    "char_1_text", "char_2_text", "char_3_text", "char_4_text",
]


def download(url, dest):
    if dest.exists():
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    print(f"  下载 {url}")
    r = requests.get(url, timeout=60)
    r.raise_for_status()
    dest.write_bytes(r.content)


def main():
    print("下载原项目资源...")
    coco_path = TEMP / "coco.json"
    download(f"{BASE}/coco_annotations.json", coco_path)
    with open(coco_path, encoding="utf-8") as f:
        coco = json.load(f)

    images = {}
    for img_meta in coco["images"]:
        fname = img_meta["file_name"]
        img_path = TEMP / fname
        download(f"{BASE}/{fname}", img_path)
        img = cv2.imread(str(img_path))
        if img is None:
            continue
        img = cv2.resize(img, TARGET)
        images[img_meta["id"]] = img

    cat_to_name = {c["id"]: c["name"] for c in coco["categories"]}
    sx = TARGET[0] / SOURCE[0]
    sy = TARGET[1] / SOURCE[1]
    count = 0
    for ann in coco["annotations"]:
        cname = cat_to_name.get(ann["category_id"])
        if cname not in WANTED:
            continue
        img = images.get(ann["image_id"])
        if img is None:
            continue
        x, y, w, h = ann["bbox"]
        x, y, w, h = int(x * sx), int(y * sy), int(w * sx), int(h * sy)
        crop = img[y:y + h, x:x + w]
        if crop.size == 0:
            continue
        out = ASSETS / f"{cname}.png"
        cv2.imwrite(str(out), crop)
        count += 1
        print(f"  已生成: {cname}.png")

    print()
    print(f"完成，共生成 {count} 个模板图到 assets/")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"失败: {e}")
        sys.exit(1)
