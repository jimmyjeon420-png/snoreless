#!/usr/bin/env python3
"""App Store marketing screenshots for English & Japanese (6.7" iPhone: 1290x2796)"""

from PIL import Image, ImageDraw, ImageFont
import os

# Paths
BASE_DIR = "/Users/nicenoodle/snoreless/screenshots"
FONT_DIR = "/Users/nicenoodle/baln-ops/fonts"

# Fonts — Pretendard for English, Hiragino Sans for Japanese
JA_FONT_DIR = "/System/Library/Fonts"

# Weight mapping for Hiragino Sans (W3=Regular, W4=Light→use W3, W5=Semi, W6=Bold)
_font_cache = {}

def _get_font(lang, weight, size):
    """Get font for language. Pretendard for en, Hiragino for ja."""
    key = (lang, weight, size)
    if key not in _font_cache:
        if lang == "ja":
            w_map = {"bold": "W6", "semi": "W5", "regular": "W3", "light": "W2"}
            path = f"{JA_FONT_DIR}/ヒラギノ角ゴシック {w_map[weight]}.ttc"
            _font_cache[key] = ImageFont.truetype(path, size)
        else:
            w_map = {"bold": "Bold", "semi": "SemiBold", "regular": "Regular", "light": "Light"}
            path = f"{FONT_DIR}/Pretendard-{w_map[weight]}.ttf"
            _font_cache[key] = ImageFont.truetype(path, size)
    return _font_cache[key]

# Default font lambdas (used for non-localized text like numbers, "SnoreLess")
font_bold = lambda size: ImageFont.truetype(f"{FONT_DIR}/Pretendard-Bold.ttf", size)
font_semi = lambda size: ImageFont.truetype(f"{FONT_DIR}/Pretendard-SemiBold.ttf", size)
font_regular = lambda size: ImageFont.truetype(f"{FONT_DIR}/Pretendard-Regular.ttf", size)
font_light = lambda size: ImageFont.truetype(f"{FONT_DIR}/Pretendard-Light.ttf", size)

# Localized font helpers
def lfont_bold(lang, size): return _get_font(lang, "bold", size)
def lfont_semi(lang, size): return _get_font(lang, "semi", size)
def lfont_regular(lang, size): return _get_font(lang, "regular", size)
def lfont_light(lang, size): return _get_font(lang, "light", size)

# Colors
BG_DARK = (10, 10, 15)
CYAN = (0, 210, 255)
CYAN_DIM = (0, 150, 200)
RED = (255, 70, 70)
ORANGE = (255, 160, 50)
GREEN = (80, 200, 120)
WHITE = (255, 255, 255)
GRAY = (120, 120, 130)
DARK_CARD = (25, 25, 35)
LIGHT_GRAY = (180, 180, 190)
MID_GRAY = (150, 150, 160)
SOFT_WHITE = (200, 200, 210)

W, H = 1290, 2796


# ── Localization tables ──────────────────────────────────────────

TEXT = {
    "en": {
        # Screenshot 1 - Hero
        "hero_line1": "Stop snoring",
        "hero_line2": "without waking your partner",
        "quiet_sleep": "Quiet sleep",
        "hero_desc1": "When Apple Watch detects snoring,",
        "hero_desc2": "gentle vibration nudges you to shift position",
        "stage1": "Gentle tap",
        "stage2": "Strong tap",
        "stage3": "iPhone buzz",
        "hero_bottom1": "Most people shift position at stage 1",
        "hero_bottom2": "and stop snoring",

        # Screenshot 2 - Detection
        "detect_line1": "When snoring is detected",
        "detect_line2": "instant haptic alert",
        "snoring_detected": "Snoring Detected",
        "total_count": "3 times",
        "detect_desc1": "Instant wrist vibration on detection,",
        "detect_desc2": "gently nudging a position change",
        "tl_detect": "Detect",
        "tl_detect_vib": "Detect+Vibe",
        "tl_quiet": "Quiet",
        "detect_bottom1": "Every snoring event",
        "detect_bottom2": "recorded on a timeline",

        # Screenshot 3 - Morning Report
        "report_line1": "Check your",
        "report_line2": "snoring report each morning",
        "this_morning": "This morning",
        "last_night_report": "Last Night's Sleep Report",
        "times_snoring": " snoring events",
        "stopped_after_vib": "Stopped after vibration",
        "ai_comment": "\"You snore twice as much on nights you drink\"",
        "weekly_trend": "This Week's Snoring Trend",
        "days": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
        "listen_recordings": "Listen to your snoring recordings",
        "snoring_recording": "Snoring recording",
        "sec_clip": "5-sec clip",

        # Screenshot 4 - Smart Alarm
        "alarm_line1": "Wake up refreshed",
        "alarm_line2": "during light sleep",
        "smart_alarm": "Smart Alarm",
        "sleep_depth": "Sleep depth",
        "wake_here": "Wake here!",
        "normal_alarm": "Normal alarm",
        "normal_desc": "Forces you awake from deep sleep at a fixed time",
        "smart_alarm_label": "Smart Alarm",
        "smart_desc": "Detects light sleep within 30 min before alarm",
        "alarm_bottom1": "Using snoring monitoring data",
        "alarm_bottom2": "to find the optimal wake-up moment",

        # Screenshot 5 - Privacy
        "privacy_line1": "All data stays",
        "privacy_line2": "on your device",
        "priv_items": [
            ("No server uploads", "100% on-device processing"),
            ("No sign-up required", "No login, no email collection"),
            ("No ads", "No ad SDK, no analytics tracking"),
            ("Delete app = delete data", "Complete data control"),
        ],
        "priv_desc1": "Apple Watch + iPhone",
        "priv_desc2": "Only Apple's native communication between devices",

        # Screenshot 6 - Partner Share
        "partner_line1": "Show your partner",
        "partner_line2": "\"I'm really getting better\"",
        "weekly_report": "SnoreLess Weekly Report",
        "week_label": "Week 1, March 2026",
        "stop_ratio": "Snoring stopped after vibration",
        "this_week": "This Week",
        "last_week": "Last Week",
        "avg_per_night": "/night avg",
        "improvement": "44% improved",
        "share_btn": "Share via Message",
        "partner_bottom1": "When you show the numbers,",
        "partner_bottom2": "the proof speaks for itself",
        "legend_last": "Last week",
        "legend_this": "This week",
    },
    "ja": {
        # Screenshot 1 - Hero
        "hero_line1": "隣の人を起こさずに",
        "hero_line2": "いびきを止めます",
        "quiet_sleep": "静かな睡眠中",
        "hero_desc1": "Apple Watchがいびきを検知すると",
        "hero_desc2": "優しい振動で姿勢を変えます",
        "stage1": "弱い振動",
        "stage2": "強い振動",
        "stage3": "iPhone振動",
        "hero_bottom1": "ほとんどの人が1段階で姿勢を変え",
        "hero_bottom2": "いびきが止まります",

        # Screenshot 2 - Detection
        "detect_line1": "いびきを検知したら",
        "detect_line2": "すぐに振動でお知らせ",
        "snoring_detected": "いびき検知",
        "total_count": "計3回",
        "detect_desc1": "検知と同時にウォッチが手首に振動を送り",
        "detect_desc2": "自然に姿勢を変えるよう促します",
        "tl_detect": "検知",
        "tl_detect_vib": "検知+振動",
        "tl_quiet": "静か",
        "detect_bottom1": "睡眠中のいびきイベントを",
        "detect_bottom2": "タイムラインで記録します",

        # Screenshot 3 - Morning Report
        "report_line1": "毎朝確認する",
        "report_line2": "いびきレポート",
        "this_morning": "今朝",
        "last_night_report": "昨夜の睡眠レポート",
        "times_snoring": "回いびき",
        "stopped_after_vib": "振動後に停止",
        "ai_comment": "「お酒を飲んだ夜はいびきが2倍に」",
        "weekly_trend": "今週のいびき推移",
        "days": ["月", "火", "水", "木", "金", "土", "日"],
        "listen_recordings": "いびきの録音も聞いてみましょう",
        "snoring_recording": "いびき録音",
        "sec_clip": "5秒クリップ",

        # Screenshot 4 - Smart Alarm
        "alarm_line1": "浅い眠りの時に",
        "alarm_line2": "すっきり目覚めます",
        "smart_alarm": "スマートアラーム",
        "sleep_depth": "睡眠の深さ",
        "wake_here": "ここで起こす!",
        "normal_alarm": "普通のアラーム",
        "normal_desc": "決まった時間に深い眠りから無理やり起こす",
        "smart_alarm_label": "スマートアラーム",
        "smart_desc": "設定時刻の30分前から浅い眠りを検知して起こす",
        "alarm_bottom1": "いびきモニタリングデータを活用して",
        "alarm_bottom2": "最適な起床タイミングを見つけます",

        # Screenshot 5 - Privacy
        "privacy_line1": "すべてのデータは",
        "privacy_line2": "端末の中だけに",
        "priv_items": [
            ("外部サーバー送信なし", "100%オンデバイス処理"),
            ("アカウント登録不要", "ログイン、メール収集なし"),
            ("広告なし", "広告SDK、分析追跡なし"),
            ("アプリ削除=データ削除", "完全なデータ管理"),
        ],
        "priv_desc1": "Apple Watch + iPhone",
        "priv_desc2": "2台の間もApple自体の通信のみ使用",

        # Screenshot 6 - Partner Share
        "partner_line1": "パートナーに見せましょう",
        "partner_line2": "「本当に良くなってるよ」",
        "weekly_report": "SnoreLess 週間レポート",
        "week_label": "2026年3月 第1週",
        "stop_ratio": "振動後にいびき停止した割合",
        "this_week": "今週",
        "last_week": "先週",
        "avg_per_night": "回/夜 平均",
        "improvement": "44% 改善",
        "share_btn": "LINEで共有する",
        "partner_bottom1": "数字で見せれば",
        "partner_bottom2": "説得力が違います",
        "legend_last": "先週",
        "legend_this": "今週",
    },
}


# ── Drawing helpers ──────────────────────────────────────────────

def new_canvas(bg=BG_DARK):
    img = Image.new("RGB", (W, H), bg)
    return img, ImageDraw.Draw(img)


def draw_rounded_rect(draw, xy, fill, radius=30):
    draw.rounded_rectangle(xy, radius=radius, fill=fill)


def draw_circle(draw, cx, cy, r, fill):
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill)


def draw_text_center(draw, y, text, font, fill=WHITE):
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    draw.text(((W - tw) // 2, y), text, font=font, fill=fill)


def draw_text_center_l(draw, y, text, lang, weight, size, fill=WHITE):
    """draw_text_center with localized font."""
    f = _get_font(lang, weight, size)
    draw_text_center(draw, y, text, f, fill)


def save(img, lang, name):
    out_dir = f"{BASE_DIR}/{lang}"
    os.makedirs(out_dir, exist_ok=True)
    path = f"{out_dir}/{name}"
    img.save(path, "PNG")
    print(f"  Saved: {path}")


# ── Screenshot generators ────────────────────────────────────────

def screenshot_01_hero(lang):
    t = TEXT[lang]
    img, draw = new_canvas()
    fb = lambda s: lfont_bold(lang, s)
    fs = lambda s: lfont_semi(lang, s)
    fr = lambda s: lfont_regular(lang, s)

    draw_text_center(draw, 300, t["hero_line1"], fb(72), WHITE)
    draw_text_center(draw, 400, t["hero_line2"], fb(72), CYAN)

    cx, cy = W // 2, 1100
    draw_circle(draw, cx, cy, 340, (30, 30, 40))
    draw_circle(draw, cx, cy, 310, (15, 15, 22))

    draw_text_center(draw, cy - 200, "02:34", font_light(140), WHITE)

    draw_circle(draw, cx - 100, cy + 10, 10, GREEN)
    draw.text((cx - 75, cy - 8), t["quiet_sleep"], font=fs(42), fill=(80, 200, 120, 180))

    draw_text_center(draw, cy + 80, "03:21:47", font_regular(32), GRAY)

    draw_text_center(draw, 1650, t["hero_desc1"], fr(42), GRAY)
    draw_text_center(draw, 1720, t["hero_desc2"], fr(42), GRAY)

    y_icons = 1950
    gap = 350

    x1 = W // 2 - gap
    draw_circle(draw, x1, y_icons, 60, (0, 60, 80))
    draw_circle(draw, x1, y_icons, 45, CYAN_DIM)
    draw.text((x1 - 15, y_icons - 18), "1", font=font_bold(40), fill=WHITE)

    x2 = W // 2
    draw_circle(draw, x2, y_icons, 60, (60, 50, 0))
    draw_circle(draw, x2, y_icons, 45, ORANGE)
    draw.text((x2 - 15, y_icons - 18), "2", font=font_bold(40), fill=WHITE)

    x3 = W // 2 + gap
    draw_circle(draw, x3, y_icons, 60, (80, 20, 20))
    draw_circle(draw, x3, y_icons, 45, RED)
    draw.text((x3 - 15, y_icons - 18), "3", font=font_bold(40), fill=WHITE)

    for x, label in [(x1, t["stage1"]), (x2, t["stage2"]), (x3, t["stage3"])]:
        bbox = draw.textbbox((0, 0), label, font=fr(30))
        lw = bbox[2] - bbox[0]
        draw.text((x - lw // 2, y_icons + 80), label, font=fr(30), fill=GRAY)

    draw_text_center(draw, 2350, t["hero_bottom1"], fr(38), LIGHT_GRAY)
    draw_text_center(draw, 2410, t["hero_bottom2"], fr(38), LIGHT_GRAY)

    draw_text_center(draw, 2580, "SnoreLess", font_bold(48), CYAN)
    save(img, lang, "store_01_hero.png")


def screenshot_02_detection(lang):
    t = TEXT[lang]
    img, draw = new_canvas()
    fb = lambda s: lfont_bold(lang, s)
    fs = lambda s: lfont_semi(lang, s)
    fr = lambda s: lfont_regular(lang, s)

    draw_text_center(draw, 300, t["detect_line1"], fb(72), WHITE)
    draw_text_center(draw, 400, t["detect_line2"], fb(72), RED)

    cx, cy = W // 2, 1100
    draw_circle(draw, cx, cy, 340, (30, 30, 40))
    draw_circle(draw, cx, cy, 310, (15, 15, 22))

    for r, a in [(200, 0.08), (160, 0.15), (120, 0.25)]:
        draw_circle(draw, cx, cy - 40, r, (int(255 * a), 0, 0))

    bar_y = cy - 40
    bars = [40, 60, 80, 60, 40, 70, 90, 70, 50, 30]
    bar_w = 12
    total_w = len(bars) * (bar_w + 8)
    start_x = cx - total_w // 2
    for i, h in enumerate(bars):
        x = start_x + i * (bar_w + 8)
        draw.rounded_rectangle(
            [x, bar_y - h // 2, x + bar_w, bar_y + h // 2],
            radius=4, fill=WHITE
        )

    draw_text_center(draw, cy + 100, t["snoring_detected"], fb(52), RED)
    draw_text_center(draw, cy + 170, t["total_count"], fs(40), ORANGE)

    draw_text_center(draw, 1650, t["detect_desc1"], fr(40), GRAY)
    draw_text_center(draw, 1720, t["detect_desc2"], fr(40), GRAY)

    y_tl = 2000
    draw.line([(200, y_tl), (W - 200, y_tl)], fill=(40, 40, 50), width=4)

    events = [
        (300, "01:23", t["tl_detect"], CYAN),
        (520, "02:15", t["tl_detect_vib"], ORANGE),
        (740, "03:41", t["tl_detect_vib"], ORANGE),
        (960, "04:50", t["tl_quiet"], GREEN),
    ]
    for x, time, label, color in events:
        draw_circle(draw, x, y_tl, 12, color)
        draw.text((x - 30, y_tl + 25), time, font=font_regular(26), fill=GRAY)
        draw.text((x - 40, y_tl - 50), label, font=fr(24), fill=color)

    draw_text_center(draw, 2350, t["detect_bottom1"], fr(38), LIGHT_GRAY)
    draw_text_center(draw, 2410, t["detect_bottom2"], fr(38), LIGHT_GRAY)

    draw_text_center(draw, 2580, "SnoreLess", font_bold(48), CYAN)
    save(img, lang, "store_02_detection.png")


def screenshot_03_morning_report(lang):
    t = TEXT[lang]
    img, draw = new_canvas()
    fb = lambda s: lfont_bold(lang, s)
    fs = lambda s: lfont_semi(lang, s)
    fr = lambda s: lfont_regular(lang, s)

    draw_text_center(draw, 300, t["report_line1"], fb(72), WHITE)
    draw_text_center(draw, 400, t["report_line2"], fb(72), CYAN)

    card_x = 100
    card_w = W - 200
    card_y = 600

    draw_rounded_rect(draw, [card_x, card_y, card_x + card_w, card_y + 500], (20, 25, 35), 30)

    draw.text((card_x + 50, card_y + 40), t["this_morning"], font=fr(34), fill=GRAY)
    draw.text((card_x + 50, card_y + 85), t["last_night_report"], font=fb(46), fill=WHITE)

    draw.text((card_x + 50, card_y + 180), "3", font=font_bold(120), fill=CYAN)
    draw.text((card_x + 120, card_y + 240), t["times_snoring"], font=fs(46), fill=WHITE)

    bar_x = card_x + 50
    bar_y2 = card_y + 370
    bar_w2 = card_w - 100
    draw.text((bar_x, bar_y2 - 40), t["stopped_after_vib"], font=fr(30), fill=GRAY)
    draw.text((bar_x + bar_w2 - 80, bar_y2 - 40), "67%", font=font_bold(30), fill=GREEN)
    draw_rounded_rect(draw, [bar_x, bar_y2, bar_x + bar_w2, bar_y2 + 16], (40, 40, 50), 8)
    draw_rounded_rect(draw, [bar_x, bar_y2, bar_x + int(bar_w2 * 0.67), bar_y2 + 16], GREEN, 8)

    draw.text((bar_x, bar_y2 + 50), t["ai_comment"], font=fr(28), fill=SOFT_WHITE)

    chart_y = card_y + 580
    draw_rounded_rect(draw, [card_x, chart_y, card_x + card_w, chart_y + 450], (20, 25, 35), 30)
    draw.text((card_x + 50, chart_y + 40), t["weekly_trend"], font=fs(38), fill=WHITE)

    days = t["days"]
    values = [5, 3, 7, 2, 4, 8, 3]
    max_val = max(values)
    chart_base = chart_y + 380
    bar_gap = card_w // 8

    for i, (day, val) in enumerate(zip(days, values)):
        bx = card_x + 80 + i * bar_gap
        bh = int((val / max_val) * 220)
        color = RED if val >= 6 else (ORANGE if val >= 4 else GREEN)
        draw_rounded_rect(draw, [bx, chart_base - bh, bx + 40, chart_base], color, 8)
        draw.text((bx + 8, chart_base + 15), day, font=fr(26), fill=GRAY)
        draw.text((bx + 10, chart_base - bh - 35), str(val), font=font_semi(24), fill=color)

    draw_text_center(draw, 1750, t["listen_recordings"], fr(40), GRAY)

    rec_y = 1850
    draw_rounded_rect(draw, [card_x, rec_y, card_x + card_w, rec_y + 140], (20, 25, 35), 24)
    draw_circle(draw, card_x + 80, rec_y + 70, 30, CYAN_DIM)
    draw.text((card_x + 60, rec_y + 52), "▶", font=font_bold(36), fill=WHITE)
    draw.text((card_x + 130, rec_y + 35), f"02:15 {t['snoring_recording']}", font=fs(34), fill=WHITE)
    draw.text((card_x + 130, rec_y + 80), t["sec_clip"], font=fr(28), fill=GRAY)

    draw_rounded_rect(draw, [card_x, rec_y + 160, card_x + card_w, rec_y + 300], (20, 25, 35), 24)
    draw_circle(draw, card_x + 80, rec_y + 230, 30, CYAN_DIM)
    draw.text((card_x + 60, rec_y + 212), "▶", font=font_bold(36), fill=WHITE)
    draw.text((card_x + 130, rec_y + 195), f"03:41 {t['snoring_recording']}", font=fs(34), fill=WHITE)
    draw.text((card_x + 130, rec_y + 240), t["sec_clip"], font=fr(28), fill=GRAY)

    draw_text_center(draw, 2580, "SnoreLess", font_bold(48), CYAN)
    save(img, lang, "store_03_report.png")


def screenshot_04_smart_alarm(lang):
    t = TEXT[lang]
    img, draw = new_canvas()
    fb = lambda s: lfont_bold(lang, s)
    fs = lambda s: lfont_semi(lang, s)
    fr = lambda s: lfont_regular(lang, s)

    draw_text_center(draw, 300, t["alarm_line1"], fb(72), WHITE)
    draw_text_center(draw, 400, t["alarm_line2"], fb(72), CYAN)

    cx, cy = W // 2, 950
    for r, a in [(280, 0.03), (240, 0.05), (200, 0.08)]:
        draw_circle(draw, cx, cy, r, (0, int(210 * a), int(255 * a)))

    draw_circle(draw, cx, cy, 160, (20, 30, 40))

    draw_text_center(draw, cy - 60, "7:00", font_light(100), WHITE)
    draw_text_center(draw, cy + 50, t["smart_alarm"], fr(34), CYAN)

    curve_y = 1450
    draw.text((120, curve_y - 60), t["sleep_depth"], font=fr(28), fill=GRAY)

    points_depth = [0.3, 0.5, 0.8, 0.9, 0.7, 0.95, 0.6, 0.4, 0.3, 0.15, 0.2, 0.1]
    seg_w = (W - 240) // len(points_depth)
    for i, d in enumerate(points_depth):
        x = 120 + i * seg_w
        h = int(d * 200)
        color = (30, 50, 80) if i < 10 else (0, 150, 200)
        draw_rounded_rect(draw, [x, curve_y, x + seg_w - 8, curve_y + h], color, 6)

    arrow_x = 120 + 10 * seg_w + seg_w // 2
    draw.text((arrow_x - 50, curve_y + 220), t["wake_here"], font=fb(30), fill=CYAN)
    draw.polygon([(arrow_x, curve_y + 210), (arrow_x - 15, curve_y + 195), (arrow_x + 15, curve_y + 195)], fill=CYAN)

    times_label = ["23:00", "", "01:00", "", "03:00", "", "05:00", "", "06:30", "", "07:00", ""]
    for i, tl in enumerate(times_label):
        if tl:
            x = 120 + i * seg_w
            draw.text((x - 20, curve_y - 90), tl, font=font_regular(22), fill=(80, 80, 90))

    card_y = 1900
    draw_rounded_rect(draw, [100, card_y, W - 100, card_y + 300], DARK_CARD, 30)
    draw.text((160, card_y + 40), t["normal_alarm"], font=fs(36), fill=GRAY)
    draw.text((160, card_y + 90), t["normal_desc"], font=fr(30), fill=MID_GRAY)
    draw.line([(160, card_y + 150), (W - 160, card_y + 150)], fill=(40, 40, 50), width=2)
    draw.text((160, card_y + 170), t["smart_alarm_label"], font=fs(36), fill=CYAN)
    draw.text((160, card_y + 220), t["smart_desc"], font=fr(30), fill=SOFT_WHITE)

    draw_text_center(draw, 2400, t["alarm_bottom1"], fr(38), LIGHT_GRAY)
    draw_text_center(draw, 2460, t["alarm_bottom2"], fr(38), LIGHT_GRAY)

    draw_text_center(draw, 2580, "SnoreLess", font_bold(48), CYAN)
    save(img, lang, "store_04_alarm.png")


def screenshot_05_privacy(lang):
    t = TEXT[lang]
    img, draw = new_canvas()

    draw_text_center(draw, 300, t["privacy_line1"], font_bold(72), WHITE)
    draw_text_center(draw, 400, t["privacy_line2"], font_bold(72), CYAN)

    cx, cy = W // 2, 900
    draw_circle(draw, cx, cy, 120, (0, 60, 80))
    draw_rounded_rect(draw, [cx - 60, cy - 10, cx + 60, cy + 70], CYAN, 15)
    draw.arc([cx - 40, cy - 80, cx + 40, cy], start=0, end=180, fill=CYAN, width=10)

    items = t["priv_items"]
    y_start = 1200
    for i, (title, desc) in enumerate(items):
        y = y_start + i * 200
        draw_circle(draw, 200, y + 30, 28, (0, 60, 40))
        draw.text((187, y + 10), "✓", font=font_bold(36), fill=GREEN)
        draw.text((260, y + 5), title, font=font_semi(40), fill=WHITE)
        draw.text((260, y + 55), desc, font=font_regular(30), fill=GRAY)

    draw_text_center(draw, 2200, t["priv_desc1"], font_regular(36), GRAY)
    draw_text_center(draw, 2260, t["priv_desc2"], font_regular(36), GRAY)

    draw_text_center(draw, 2580, "SnoreLess", font_bold(48), CYAN)
    save(img, lang, "store_05_privacy.png")


def screenshot_06_partner(lang):
    t = TEXT[lang]
    img, draw = new_canvas()

    draw_text_center(draw, 300, t["partner_line1"], font_bold(72), WHITE)
    draw_text_center(draw, 400, t["partner_line2"], font_bold(60), CYAN)

    card_x, card_y = 150, 620
    card_w, card_h = W - 300, 1200

    draw_rounded_rect(draw, [card_x, card_y, card_x + card_w, card_y + card_h], (22, 28, 38), 40)

    inner_x = card_x + 60
    draw.text((inner_x, card_y + 60), t["weekly_report"], font=font_semi(36), fill=CYAN)
    draw.text((inner_x, card_y + 115), t["week_label"], font=font_regular(30), fill=GRAY)

    draw.text((inner_x, card_y + 200), "67%", font=font_bold(120), fill=GREEN)
    draw.text((inner_x, card_y + 340), t["stop_ratio"], font=font_regular(34), fill=LIGHT_GRAY)

    draw.line([(inner_x, card_y + 420), (inner_x + card_w - 120, card_y + 420)], fill=(40, 40, 50), width=2)

    draw.text((inner_x, card_y + 450), t["this_week"], font=font_regular(30), fill=GRAY)
    draw.text((inner_x, card_y + 500), f"3.2{t['avg_per_night']}", font=font_semi(40), fill=WHITE)

    draw.text((inner_x + 450, card_y + 450), t["last_week"], font=font_regular(30), fill=GRAY)
    draw.text((inner_x + 450, card_y + 500), f"5.7{t['avg_per_night']}", font=font_semi(40), fill=GRAY)

    draw.text((inner_x, card_y + 590), t["improvement"], font=font_bold(48), fill=GREEN)

    chart_y2 = card_y + 720
    days2 = t["days"]
    this_week_data = [4, 3, 5, 2, 3, 2, 3]
    last_week_data = [6, 5, 8, 4, 6, 7, 4]
    max_v = 8
    bw = 30
    gap2 = (card_w - 120) // 7

    for i in range(7):
        bx = inner_x + i * gap2
        h1 = int((last_week_data[i] / max_v) * 160)
        draw_rounded_rect(draw, [bx, chart_y2 + 200 - h1, bx + bw, chart_y2 + 200], (50, 50, 60), 6)
        h2 = int((this_week_data[i] / max_v) * 160)
        draw_rounded_rect(draw, [bx + bw + 6, chart_y2 + 200 - h2, bx + bw * 2 + 6, chart_y2 + 200], CYAN_DIM, 6)
        draw.text((bx + 10, chart_y2 + 215), days2[i], font=font_regular(24), fill=GRAY)

    draw_circle(draw, inner_x + 20, chart_y2 + 270, 8, (50, 50, 60))
    draw.text((inner_x + 40, chart_y2 + 258), t["legend_last"], font=font_regular(24), fill=GRAY)
    draw_circle(draw, inner_x + 170, chart_y2 + 270, 8, CYAN_DIM)
    draw.text((inner_x + 190, chart_y2 + 258), t["legend_this"], font=font_regular(24), fill=GRAY)

    btn_y = 2050
    draw_rounded_rect(draw, [200, btn_y, W - 200, btn_y + 100], CYAN, 50)
    draw_text_center(draw, btn_y + 22, t["share_btn"], font_bold(40), BG_DARK)

    draw_text_center(draw, 2350, t["partner_bottom1"], font_regular(38), LIGHT_GRAY)
    draw_text_center(draw, 2410, t["partner_bottom2"], font_regular(38), LIGHT_GRAY)

    draw_text_center(draw, 2580, "SnoreLess", font_bold(48), CYAN)
    save(img, lang, "store_06_partner.png")


# ── Main ─────────────────────────────────────────────────────────

if __name__ == "__main__":
    for lang in ("en", "ja"):
        label = {"en": "English", "ja": "Japanese"}[lang]
        print(f"\nGenerating {label} screenshots...")
        screenshot_01_hero(lang)
        screenshot_02_detection(lang)
        screenshot_03_morning_report(lang)
        screenshot_04_smart_alarm(lang)
        screenshot_05_privacy(lang)
        screenshot_06_partner(lang)
        print(f"{label}: 6 screenshots done -> {BASE_DIR}/{lang}/")

    print("\nAll done!")
