"""
OCR 模块 - 照搬 ok-script task.ocr() 的核心逻辑
用 RapidOCR（底层是 PaddleOCR ONNX 模型）做中文文字识别
"""
import re
import cv2
import numpy as np

from rapidocr_onnxruntime import RapidOCR

_engine = None


def _get_engine():
    global _engine
    if _engine is None:
        _engine = RapidOCR()
    return _engine


def ocr(region, match=None, threshold=0.5):
    """
    在截图的指定区域做 OCR，返回是否匹配到目标文字。

    照搬原项目:
        self.ocr(x, y, to_x, to_y, match=re.compile("..."))

    Args:
        region: numpy array, 已裁剪好的 BGR 图片区域
        match: 正则表达式 pattern 或字符串
        threshold: OCR 置信度阈值

    Returns:
        bool: 是否匹配到
    """
    if region is None or region.size == 0:
        return False

    engine = _get_engine()
    result, _ = engine(region)

    if result is None or len(result) == 0:
        return False

    if match is None:
        return len(result) > 0

    # 编译正则（如果传的是字符串）
    if isinstance(match, str):
        pattern = re.compile(match)
    elif isinstance(match, re.Pattern):
        pattern = match
    else:
        pattern = re.compile(str(match))

    for item in result:
        # RapidOCR 返回格式: [box_coords, text, score]
        txt = item[1].strip()
        score = float(item[2])
        if score < threshold:
            continue
        if pattern.search(txt):
            return True

    return False


def ocr_texts(region, threshold=0.5):
    """
    返回区域内所有识别到的文字列表。
    用于调试。
    """
    if region is None or region.size == 0:
        return []

    engine = _get_engine()
    result, _ = engine(region)

    texts = []
    if result is not None:
        for item in result:
            txt = item[1].strip()
            score = float(item[2])
            if score >= threshold:
                texts.append(f"{txt}({score:.2f})")
    return texts


def crop_region(frame, x, y, to_x, to_y):
    """
    按相对坐标裁剪 frame 区域。

    Args:
        frame: numpy array (BGR)
        x, y: 左上角相对坐标 (0~1)
        to_x, to_y: 右下角相对坐标 (0~1)

    Returns:
        裁剪后的 numpy array
    """
    h, w = frame.shape[:2]
    x1 = int(x * w)
    y1 = int(y * h)
    x2 = int(to_x * w)
    y2 = int(to_y * h)
    return frame[y1:y2, x1:x2]
