from __future__ import annotations

import hashlib
import json
import math
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "data" / "content.json"
FONT_DIR = ROOT / "assets" / "fonts"
ICON_DIR = ROOT / "assets" / "icons"
BUILD_DIR = ROOT / ".build"
EMOJI_FONT = Path(r"C:\Windows\Fonts\seguiemj.ttf")
UI_FONT = Path(r"C:\Windows\Fonts\Deng.ttf")
# DengXian has no IPA extensions or U+2726; phonetics and the spark use this face.
IPA_FONT = Path(r"C:\Windows\Fonts\DejaVuSansMono_0.ttf")

UI_TEXT = """
Magic English Buddy SPROUT FOREST 萌芽之森 MAGIC 魔力 LEVEL 等级
按住 A 孵化你的学习伙伴 HOLD A TO HATCH 伙伴正在苏醒 孵化成功
开始学习 继续学习 单词复习 我的词库 设置 返回首页 退出
课程地图 故事 奖励 挑战 Boss 已完成 未完成 锁定 继续
上一课 下一课 阅读故事 开始练习 跟读录音暂未开放
播放 暂停 重播 翻译 段落 查词 收藏 取消收藏 关闭
朗读中 播放完毕 点击单词或按 A 查词 左右键选词
选择题 组词题 听一听 提示 正确答案 你的答案 答对啦 再接再厉
提交 下一题 查看结果 重新练习 回到首页 通过 未通过
本次正确 魔法奖励 复习单词 到期复习 暂无到期单词 学习新词后再来
中文释义 英文释义 词性 例句 音标 收藏夹 生词本
显示中文翻译 声音 开 关 清除学习记录 确定清除 取消 操作说明
十字键/左摇杆 移动 A 确认/查词 B 返回 X 重播 Y 翻译/提示 L/R 翻页
Select 学习菜单 Start 退出 第一版 离线版 本地自动保存
你的学习记录只保存在这台设备 上 不联网 不需要账号
蛋 萌芽伙伴 星光伙伴 成长值 连胜 天 完成课程获得奖励
"""


def collect_text(value) -> str:
    if isinstance(value, str):
        return value
    if isinstance(value, list):
        return "".join(collect_text(item) for item in value)
    if isinstance(value, dict):
        return "".join(collect_text(item) for item in value.values())
    return ""


def subset_font(text: str) -> None:
    FONT_DIR.mkdir(parents=True, exist_ok=True)
    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    glyphs = BUILD_DIR / "font-glyphs.txt"
    glyphs.write_text(text + "".join(chr(code) for code in range(32, 127)), encoding="utf-8")
    subprocess.run(
        [
            sys.executable,
            "-m",
            "fontTools.subset",
            str(UI_FONT),
            f"--text-file={glyphs}",
            f"--output-file={FONT_DIR / 'ui.ttf'}",
            "--layout-features=*",
            "--name-IDs=*",
            "--name-languages=*",
        ],
        check=True,
    )


def prepare_ipa_font() -> None:
    """Ship the IPA-capable face alongside the CJK subset."""
    if not IPA_FONT.exists():
        print(f"WARNING: IPA source font missing: {IPA_FONT}")
        return
    target = FONT_DIR / "ipa.ttf"
    if not target.exists() or target.stat().st_size != IPA_FONT.stat().st_size:
        shutil.copyfile(IPA_FONT, target)


def render_emoji(emoji: str) -> str:
    key = hashlib.sha1(emoji.encode("utf-8")).hexdigest()[:12]
    name = f"emoji_{key}.png"
    target = ICON_DIR / name
    if target.exists():
        return name
    size = 128
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    font = ImageFont.truetype(str(EMOJI_FONT), 92)
    try:
        draw.text((size / 2, size / 2), emoji, font=font, anchor="mm", embedded_color=True)
    except Exception:
        draw.text((size / 2, size / 2), emoji[0], font=font, anchor="mm")
    image.save(target, optimize=True)
    return name


def buddy_image(stage: int) -> str:
    names = ["egg.png", "buddy.png", "star_buddy.png"]
    scale = 3
    size = 256
    image = Image.new("RGBA", (size * scale, size * scale), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    def box(values):
        return tuple(int(value * scale) for value in values)

    if stage == 0:
        draw.ellipse(box((48, 28, 208, 232)), fill=(244, 225, 164, 255), outline=(128, 92, 52, 255), width=7 * scale)
        draw.ellipse(box((76, 56, 126, 104)), fill=(255, 248, 216, 210))
        draw.ellipse(box((92, 137, 112, 157)), fill=(83, 66, 50, 255))
        draw.ellipse(box((144, 137, 164, 157)), fill=(83, 66, 50, 255))
        draw.arc(box((108, 148, 148, 178)), 0, 180, fill=(83, 66, 50, 255), width=4 * scale)
        draw.polygon([box((120, 30))[0:2], box((92, 12))[0:2], box((96, 48))[0:2]], fill=(104, 170, 91, 255))
        draw.polygon([box((124, 30))[0:2], box((158, 10))[0:2], box((150, 52))[0:2]], fill=(82, 145, 76, 255))
    else:
        body = (116, 201, 139, 255) if stage == 1 else (126, 178, 244, 255)
        shade = (61, 133, 86, 255) if stage == 1 else (74, 113, 187, 255)
        draw.ellipse(box((40, 42, 216, 238)), fill=body, outline=shade, width=6 * scale)
        draw.ellipse(box((20, 118, 70, 182)), fill=body, outline=shade, width=5 * scale)
        draw.ellipse(box((186, 118, 236, 182)), fill=body, outline=shade, width=5 * scale)
        draw.ellipse(box((78, 106, 104, 134)), fill=(35, 49, 42, 255))
        draw.ellipse(box((152, 106, 178, 134)), fill=(35, 49, 42, 255))
        draw.ellipse(box((86, 110, 94, 118)), fill=(255, 255, 255, 255))
        draw.ellipse(box((160, 110, 168, 118)), fill=(255, 255, 255, 255))
        draw.arc(box((104, 132, 152, 170)), 0, 180, fill=(35, 49, 42, 255), width=5 * scale)
        draw.ellipse(box((65, 143, 91, 157)), fill=(244, 151, 151, 150))
        draw.ellipse(box((165, 143, 191, 157)), fill=(244, 151, 151, 150))
        draw.polygon([box((112, 44))[0:2], box((90, 10))[0:2], box((100, 58))[0:2]], fill=(87, 163, 88, 255))
        draw.polygon([box((126, 44))[0:2], box((166, 8))[0:2], box((148, 62))[0:2]], fill=(70, 143, 75, 255))
        if stage == 2:
            for angle in range(0, 360, 45):
                radians = math.radians(angle)
                x = 128 + math.cos(radians) * 102
                y = 136 + math.sin(radians) * 102
                draw.line(box((128, 136, x, y)), fill=(255, 224, 115, 255), width=4 * scale)
                draw.ellipse(box((x - 6, y - 6, x + 6, y + 6)), fill=(255, 235, 150, 255))
    image = image.resize((size, size), Image.Resampling.LANCZOS)
    image.save(ICON_DIR / names[stage], optimize=True)
    return names[stage]


def background_image() -> str:
    image = Image.new("RGB", (640, 480))
    pixels = image.load()
    for y in range(480):
        for x in range(640):
            glow = max(0.0, 1.0 - math.hypot(x - 500, y - 80) / 520)
            pixels[x, y] = (
                int(12 + 5 * glow),
                int(22 + 13 * glow),
                int(25 + 10 * glow),
            )
    draw = ImageDraw.Draw(image, "RGBA")
    for index in range(34):
        x = (index * 173 + 41) % 640
        y = (index * 97 + 83) % 480
        radius = 2 + index % 3
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=(169, 221, 157, 70))
    for x, y, flip in [(20, 410, False), (596, 260, True), (72, 54, True)]:
        direction = -1 if flip else 1
        x2 = x + direction * 54
        draw.ellipse((min(x, x2), y, max(x, x2), y + 22), fill=(54, 105, 72, 65))
    target = ICON_DIR / "forest_bg.png"
    image.save(target, optimize=True)
    return target.name


def main() -> None:
    content = json.loads(CONTENT.read_text(encoding="utf-8"))
    ICON_DIR.mkdir(parents=True, exist_ok=True)
    subset_font(UI_TEXT + collect_text(content) + "\n".join(path.read_text(encoding="utf-8") for path in (ROOT / "scripts").glob("*.gd")))
    prepare_ipa_font()
    content["emojiIcons"] = {emoji: render_emoji(emoji) for emoji in content["emojis"]}
    content["buddyIcons"] = [buddy_image(stage) for stage in range(3)]
    content["backgroundImage"] = background_image()
    CONTENT.write_text(json.dumps(content, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(
        json.dumps(
            {
                "fontBytes": (FONT_DIR / "ui.ttf").stat().st_size,
                "emojiIcons": len(content["emojiIcons"]),
                "courses": len(content["courses"]),
                "audioClips": content["source"]["audioClips"],
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
