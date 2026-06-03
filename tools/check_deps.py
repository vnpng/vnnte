"""检查 Python 依赖是否齐全"""
import sys
import importlib

REQUIRED = {
    "mss": "mss",
    "cv2": "opencv-python",
    "numpy": "numpy",
    "PIL": "Pillow",
    "win32gui": "pywin32",
    "requests": "requests",
}

print("检查 Python 依赖...")
print(f"Python 版本: {sys.version}")
print()
missing = []
for mod, pkg in REQUIRED.items():
    try:
        importlib.import_module(mod)
        print(f"  [OK] {pkg}")
    except ImportError:
        print(f"  [缺失] {pkg}")
        missing.append(pkg)

print()
if missing:
    print(f"缺少 {len(missing)} 个依赖:")
    for p in missing:
        print(f"  - {p}")
    print("请双击 install.bat 安装")
    sys.exit(1)
else:
    print("所有依赖都已安装")
    sys.exit(0)
