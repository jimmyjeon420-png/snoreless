#!/usr/bin/env python3
"""App Store 마케팅 스크린샷 생성 (6.7인치 iPhone: 1290x2796)"""

from PIL import Image, ImageDraw, ImageFont
import math
import os

# 경로
OUTPUT_DIR = "/Users/nicenoodle/snoreless/screenshots"
FONT_DIR = "/Users/nicenoodle/baln-ops/fonts"
os.makedirs(OUTPUT_DIR, exist_ok=True)

# 폰트
font_bold = lambda size: ImageFont.truetype(f"{FONT_DIR}/Pretendard-Bold.ttf", size)
font_semi = lambda size: ImageFont.truetype(f"{FONT_DIR}/Pretendard-SemiBold.ttf", size)
font_regular = lambda size: ImageFont.truetype(f"{FONT_DIR}/Pretendard-Regular.ttf", size)
font_light = lambda size: ImageFont.truetype(f"{FONT_DIR}/Pretendard-Light.ttf", size)

# 색상
BG_DARK = (10, 10, 15)
CYAN = (0, 210, 255)
CYAN_DIM = (0, 150, 200)
RED = (255, 70, 70)
ORANGE = (255, 160, 50)
GREEN = (80, 200, 120)
WHITE = (255, 255, 255)
GRAY = (120, 120, 130)
DARK_CARD = (25, 25, 35)

W, H = 1290, 2796


def new_canvas(bg=BG_DARK):
    img = Image.new("RGB", (W, H), bg)
    return img, ImageDraw.Draw(img)


def draw_rounded_rect(draw, xy, fill, radius=30):
    x0, y0, x1, y1 = xy
    draw.rounded_rectangle(xy, radius=radius, fill=fill)


def draw_circle(draw, cx, cy, r, fill):
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill)


def draw_text_center(draw, y, text, font, fill=WHITE):
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    draw.text(((W - tw) // 2, y), text, font=font, fill=fill)


def save(img, name):
    path = f"{OUTPUT_DIR}/{name}"
    img.save(path, "PNG")
    print(f"  Saved: {path}")


# ===== 스크린샷 1: 히어로 (핵심 가치) =====
def screenshot_01_hero():
    img, draw = new_canvas()

    # 상단 마케팅 텍스트
    draw_text_center(draw, 300, "옆 사람 깨우지 않고", font_bold(72), WHITE)
    draw_text_center(draw, 400, "코골이를 멈추세요", font_bold(72), CYAN)

    # 중앙 워치 모의 화면
    cx, cy = W // 2, 1100
    # 워치 외형 (원형)
    draw_circle(draw, cx, cy, 340, (30, 30, 40))
    draw_circle(draw, cx, cy, 310, (15, 15, 22))

    # 워치 화면 내용 - 시간
    draw_text_center(draw, cy - 200, "02:34", font_light(140), WHITE)

    # 초록 점 + 텍스트
    draw_circle(draw, cx - 100, cy + 10, 10, GREEN)
    draw.text((cx - 75, cy - 8), "조용한 수면 중", font=font_semi(42), fill=(80, 200, 120, 180))

    # 경과 시간
    draw_text_center(draw, cy + 80, "03:21:47", font_regular(32), GRAY)

    # 하단 설명
    draw_text_center(draw, 1650, "Apple Watch가 코골이를 감지하면", font_regular(42), GRAY)
    draw_text_center(draw, 1720, "부드러운 진동으로 자세를 바꿔줍니다", font_regular(42), GRAY)

    # 3단계 아이콘
    y_icons = 1950
    gap = 350

    # Stage 1
    x1 = W // 2 - gap
    draw_circle(draw, x1, y_icons, 60, (0, 60, 80))
    draw_circle(draw, x1, y_icons, 45, CYAN_DIM)
    draw.text((x1 - 15, y_icons - 18), "1", font=font_bold(40), fill=WHITE)
    draw_text_center(draw, y_icons + 80, "약한 진동", font_regular(32), GRAY)

    # Stage 2
    x2 = W // 2
    draw_circle(draw, x2, y_icons, 60, (60, 50, 0))
    draw_circle(draw, x2, y_icons, 45, ORANGE)
    draw.text((x2 - 15, y_icons - 18), "2", font=font_bold(40), fill=WHITE)

    # Stage 3
    x3 = W // 2 + gap
    draw_circle(draw, x3, y_icons, 60, (80, 20, 20))
    draw_circle(draw, x3, y_icons, 45, RED)
    draw.text((x3 - 15, y_icons - 18), "3", font=font_bold(40), fill=WHITE)

    # 라벨 재배치
    draw.text((x1 - 60, y_icons + 80), "약한 진동", font=font_regular(30), fill=GRAY)
    draw.text((x2 - 60, y_icons + 80), "강한 진동", font=font_regular(30), fill=GRAY)
    draw.text((x3 - 75, y_icons + 80), "아이폰 진동", font=font_regular(30), fill=GRAY)

    # 하단 카피
    draw_text_center(draw, 2350, "대부분 1단계에서 자세를 바꾸고", font_regular(38), (180, 180, 190))
    draw_text_center(draw, 2410, "코골이가 멈춥니다", font_regular(38), (180, 180, 190))

    # 앱 이름
    draw_text_center(draw, 2580, "SnoreLess", font_bold(48), CYAN)

    save(img, "store_01_hero.png")


# ===== 스크린샷 2: 코골이 감지 화면 =====
def screenshot_02_detection():
    img, draw = new_canvas()

    draw_text_center(draw, 300, "코골이가 감지되면", font_bold(72), WHITE)
    draw_text_center(draw, 400, "즉시 진동으로 알려줍니다", font_bold(72), RED)

    # 워치 모의 - 감지 상태
    cx, cy = W // 2, 1100
    draw_circle(draw, cx, cy, 340, (30, 30, 40))
    draw_circle(draw, cx, cy, 310, (15, 15, 22))

    # 빨간 펄스 링
    for r, a in [(200, 0.08), (160, 0.15), (120, 0.25)]:
        draw_circle(draw, cx, cy - 40, r, (int(255 * a), 0, 0))

    # 파형 아이콘 (간단한 바 그래프로 표현)
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

    draw_text_center(draw, cy + 100, "코골이 감지", font_bold(52), RED)
    draw_text_center(draw, cy + 170, "총 3회", font_semi(40), ORANGE)

    # 하단 설명
    draw_text_center(draw, 1650, "감지 즉시 워치가 손목에 진동을 보내", font_regular(40), GRAY)
    draw_text_center(draw, 1720, "자연스럽게 자세를 바꾸도록 유도합니다", font_regular(40), GRAY)

    # 타임라인
    y_tl = 2000
    draw.line([(200, y_tl), (W - 200, y_tl)], fill=(40, 40, 50), width=4)

    events = [
        (300, "01:23", "감지", CYAN),
        (520, "02:15", "감지+진동", ORANGE),
        (740, "03:41", "감지+진동", ORANGE),
        (960, "04:50", "조용", GREEN),
    ]
    for x, time, label, color in events:
        draw_circle(draw, x, y_tl, 12, color)
        draw.text((x - 30, y_tl + 25), time, font=font_regular(26), fill=GRAY)
        draw.text((x - 40, y_tl - 50), label, font=font_regular(24), fill=color)

    draw_text_center(draw, 2350, "수면 중 코골이 이벤트를", font_regular(38), (180, 180, 190))
    draw_text_center(draw, 2410, "타임라인으로 기록합니다", font_regular(38), (180, 180, 190))

    draw_text_center(draw, 2580, "SnoreLess", font_bold(48), CYAN)

    save(img, "store_02_detection.png")


# ===== 스크린샷 3: 아침 리포트 =====
def screenshot_03_morning_report():
    img, draw = new_canvas()

    draw_text_center(draw, 300, "아침에 확인하는", font_bold(72), WHITE)
    draw_text_center(draw, 400, "코골이 리포트", font_bold(72), CYAN)

    # 아이폰 모의 화면 (카드 스타일)
    card_x = 100
    card_w = W - 200
    card_y = 600

    # 히어로 카드
    draw_rounded_rect(draw, [card_x, card_y, card_x + card_w, card_y + 500], (20, 25, 35), 30)

    # 날짜
    draw.text((card_x + 50, card_y + 40), "오늘 아침", font=font_regular(34), fill=GRAY)
    draw.text((card_x + 50, card_y + 85), "어젯밤 수면 리포트", font=font_bold(46), fill=WHITE)

    # 큰 숫자
    draw.text((card_x + 50, card_y + 180), "3", font=font_bold(120), fill=CYAN)
    draw.text((card_x + 120, card_y + 240), "회 코골이", font=font_semi(46), fill=WHITE)

    # 성공률 바
    bar_x = card_x + 50
    bar_y2 = card_y + 370
    bar_w2 = card_w - 100
    draw.text((bar_x, bar_y2 - 40), "진동 후 멈춤", font=font_regular(30), fill=GRAY)
    draw.text((bar_x + bar_w2 - 80, bar_y2 - 40), "67%", font=font_bold(30), fill=GREEN)
    draw_rounded_rect(draw, [bar_x, bar_y2, bar_x + bar_w2, bar_y2 + 16], (40, 40, 50), 8)
    draw_rounded_rect(draw, [bar_x, bar_y2, bar_x + int(bar_w2 * 0.67), bar_y2 + 16], GREEN, 8)

    # AI 코멘트
    draw.text((bar_x, bar_y2 + 50), "\"어젯밤 술 마신 날은 코골이가 2배 늘어나요\"", font=font_regular(28), fill=(200, 200, 210))

    # 주간 차트
    chart_y = card_y + 580
    draw_rounded_rect(draw, [card_x, chart_y, card_x + card_w, chart_y + 450], (20, 25, 35), 30)
    draw.text((card_x + 50, chart_y + 40), "이번 주 코골이 추이", font=font_semi(38), fill=WHITE)

    days = ["월", "화", "수", "목", "금", "토", "일"]
    values = [5, 3, 7, 2, 4, 8, 3]
    max_val = max(values)
    chart_base = chart_y + 380
    bar_gap = card_w // 8

    for i, (day, val) in enumerate(zip(days, values)):
        bx = card_x + 80 + i * bar_gap
        bh = int((val / max_val) * 220)
        color = RED if val >= 6 else (ORANGE if val >= 4 else GREEN)
        draw_rounded_rect(draw, [bx, chart_base - bh, bx + 40, chart_base], color, 8)
        draw.text((bx + 8, chart_base + 15), day, font=font_regular(26), fill=GRAY)
        draw.text((bx + 10, chart_base - bh - 35), str(val), font=font_semi(24), fill=color)

    # 하단 설명
    draw_text_center(draw, 1750, "코골이 녹음도 들어보세요", font_regular(40), GRAY)

    # 녹음 카드
    rec_y = 1850
    draw_rounded_rect(draw, [card_x, rec_y, card_x + card_w, rec_y + 140], (20, 25, 35), 24)
    draw_circle(draw, card_x + 80, rec_y + 70, 30, CYAN_DIM)
    draw.text((card_x + 60, rec_y + 52), "▶", font=font_bold(36), fill=WHITE)
    draw.text((card_x + 130, rec_y + 35), "02:15 코골이 녹음", font=font_semi(34), fill=WHITE)
    draw.text((card_x + 130, rec_y + 80), "5초 클립", font=font_regular(28), fill=GRAY)

    draw_rounded_rect(draw, [card_x, rec_y + 160, card_x + card_w, rec_y + 300], (20, 25, 35), 24)
    draw_circle(draw, card_x + 80, rec_y + 230, 30, CYAN_DIM)
    draw.text((card_x + 60, rec_y + 212), "▶", font=font_bold(36), fill=WHITE)
    draw.text((card_x + 130, rec_y + 195), "03:41 코골이 녹음", font=font_semi(34), fill=WHITE)
    draw.text((card_x + 130, rec_y + 240), "5초 클립", font=font_regular(28), fill=GRAY)

    draw_text_center(draw, 2580, "SnoreLess", font_bold(48), CYAN)

    save(img, "store_03_report.png")


# ===== 스크린샷 4: 스마트 알람 =====
def screenshot_04_smart_alarm():
    img, draw = new_canvas()

    draw_text_center(draw, 300, "얕은 잠일 때", font_bold(72), WHITE)
    draw_text_center(draw, 400, "가장 개운하게 깨워줍니다", font_bold(72), CYAN)

    # 알람 시계 비주얼
    cx, cy = W // 2, 950
    # 글로우
    for r, a in [(280, 0.03), (240, 0.05), (200, 0.08)]:
        draw_circle(draw, cx, cy, r, (0, int(210 * a), int(255 * a)))

    draw_circle(draw, cx, cy, 160, (20, 30, 40))

    # 시간
    draw_text_center(draw, cy - 60, "7:00", font_light(100), WHITE)
    draw_text_center(draw, cy + 50, "스마트 알람", font_regular(34), CYAN)

    # 수면 곡선
    curve_y = 1450
    draw.text((120, curve_y - 60), "수면 깊이", font=font_regular(28), fill=GRAY)

    # 간단한 수면 곡선 (바 형태)
    points_depth = [0.3, 0.5, 0.8, 0.9, 0.7, 0.95, 0.6, 0.4, 0.3, 0.15, 0.2, 0.1]
    seg_w = (W - 240) // len(points_depth)
    for i, d in enumerate(points_depth):
        x = 120 + i * seg_w
        h = int(d * 200)
        color = (30, 50, 80) if i < 10 else (0, 150, 200)
        draw_rounded_rect(draw, [x, curve_y, x + seg_w - 8, curve_y + h], color, 6)

    # 얕은 수면 구간 표시
    arrow_x = 120 + 10 * seg_w + seg_w // 2
    draw.text((arrow_x - 50, curve_y + 220), "여기서 깨움!", font=font_bold(30), fill=CYAN)
    # 화살표
    draw.polygon([(arrow_x, curve_y + 210), (arrow_x - 15, curve_y + 195), (arrow_x + 15, curve_y + 195)], fill=CYAN)

    # 시간 레이블
    times_label = ["23:00", "", "01:00", "", "03:00", "", "05:00", "", "06:30", "", "07:00", ""]
    for i, t in enumerate(times_label):
        if t:
            x = 120 + i * seg_w
            draw.text((x - 20, curve_y - 90), t, font=font_regular(22), fill=(80, 80, 90))

    # 설명 카드
    card_y = 1900
    draw_rounded_rect(draw, [100, card_y, W - 100, card_y + 300], DARK_CARD, 30)
    draw.text((160, card_y + 40), "일반 알람", font=font_semi(36), fill=GRAY)
    draw.text((160, card_y + 90), "정해진 시간에 깊은 잠에서 억지로 깨움", font=font_regular(30), fill=(150, 150, 160))
    draw.line([(160, card_y + 150), (W - 160, card_y + 150)], fill=(40, 40, 50), width=2)
    draw.text((160, card_y + 170), "스마트 알람", font=font_semi(36), fill=CYAN)
    draw.text((160, card_y + 220), "설정 시간 30분 전부터 얕은 잠을 감지해 깨움", font=font_regular(30), fill=(200, 200, 210))

    draw_text_center(draw, 2400, "코골이 모니터링 데이터를 활용해", font_regular(38), (180, 180, 190))
    draw_text_center(draw, 2460, "최적의 기상 타이밍을 찾아줍니다", font_regular(38), (180, 180, 190))

    draw_text_center(draw, 2580, "SnoreLess", font_bold(48), CYAN)

    save(img, "store_04_alarm.png")


# ===== 스크린샷 5: 프라이버시 =====
def screenshot_05_privacy():
    img, draw = new_canvas()

    draw_text_center(draw, 300, "모든 데이터는", font_bold(72), WHITE)
    draw_text_center(draw, 400, "내 기기 안에만", font_bold(72), CYAN)

    # 큰 자물쇠 아이콘
    cx, cy = W // 2, 900
    draw_circle(draw, cx, cy, 120, (0, 60, 80))
    # 자물쇠 몸통
    draw_rounded_rect(draw, [cx - 60, cy - 10, cx + 60, cy + 70], CYAN, 15)
    # 자물쇠 고리
    draw.arc([cx - 40, cy - 80, cx + 40, cy], start=0, end=180, fill=CYAN, width=10)

    # 체크리스트
    items = [
        ("외부 서버 전송 없음", "100% 온디바이스 처리"),
        ("계정 가입 없음", "로그인, 이메일 수집 없음"),
        ("광고 없음", "광고 SDK, 분석 추적 없음"),
        ("앱 삭제 = 데이터 삭제", "완전한 데이터 통제권"),
    ]

    y_start = 1200
    for i, (title, desc) in enumerate(items):
        y = y_start + i * 200
        # 체크 원
        draw_circle(draw, 200, y + 30, 28, (0, 60, 40))
        draw.text((187, y + 10), "✓", font=font_bold(36), fill=GREEN)
        # 텍스트
        draw.text((260, y + 5), title, font=font_semi(40), fill=WHITE)
        draw.text((260, y + 55), desc, font=font_regular(30), fill=GRAY)

    # 하단
    draw_text_center(draw, 2200, "Apple Watch + iPhone", font_regular(36), GRAY)
    draw_text_center(draw, 2260, "두 기기 사이도 Apple 자체 통신만 사용", font_regular(36), GRAY)

    draw_text_center(draw, 2580, "SnoreLess", font_bold(48), CYAN)

    save(img, "store_05_privacy.png")


# ===== 스크린샷 6: 파트너 공유 =====
def screenshot_06_partner():
    img, draw = new_canvas()

    draw_text_center(draw, 300, "파트너에게 보여주세요", font_bold(72), WHITE)
    draw_text_center(draw, 400, "\"나 진짜 좋아지고 있어\"", font_bold(60), CYAN)

    # 공유 카드 모의
    card_x, card_y = 150, 620
    card_w, card_h = W - 300, 1200

    # 카드 배경 (약간 기울어진 느낌)
    draw_rounded_rect(draw, [card_x, card_y, card_x + card_w, card_y + card_h], (22, 28, 38), 40)

    # 카드 내용
    inner_x = card_x + 60
    draw.text((inner_x, card_y + 60), "SnoreLess 주간 리포트", font=font_semi(36), fill=CYAN)
    draw.text((inner_x, card_y + 115), "2026년 3월 1주차", font=font_regular(30), fill=GRAY)

    # 큰 수치
    draw.text((inner_x, card_y + 200), "67%", font=font_bold(120), fill=GREEN)
    draw.text((inner_x, card_y + 340), "진동 후 코골이 멈춤 비율", font=font_regular(34), fill=(180, 180, 190))

    # 비교
    draw.line([(inner_x, card_y + 420), (inner_x + card_w - 120, card_y + 420)], fill=(40, 40, 50), width=2)

    draw.text((inner_x, card_y + 450), "이번 주", font=font_regular(30), fill=GRAY)
    draw.text((inner_x, card_y + 500), "평균 3.2회/밤", font=font_semi(40), fill=WHITE)

    draw.text((inner_x + 450, card_y + 450), "지난 주", font=font_regular(30), fill=GRAY)
    draw.text((inner_x + 450, card_y + 500), "평균 5.7회/밤", font=font_semi(40), fill=GRAY)

    # 개선 화살표
    draw.text((inner_x, card_y + 590), "44% 개선", font=font_bold(48), fill=GREEN)

    # 미니 바 차트
    chart_y2 = card_y + 720
    days2 = ["월", "화", "수", "목", "금", "토", "일"]
    this_week = [4, 3, 5, 2, 3, 2, 3]
    last_week = [6, 5, 8, 4, 6, 7, 4]
    max_v = 8
    bw = 30
    gap2 = (card_w - 120) // 7

    for i in range(7):
        bx = inner_x + i * gap2
        # 지난주 (회색)
        h1 = int((last_week[i] / max_v) * 160)
        draw_rounded_rect(draw, [bx, chart_y2 + 200 - h1, bx + bw, chart_y2 + 200], (50, 50, 60), 6)
        # 이번주 (시안)
        h2 = int((this_week[i] / max_v) * 160)
        draw_rounded_rect(draw, [bx + bw + 6, chart_y2 + 200 - h2, bx + bw * 2 + 6, chart_y2 + 200], CYAN_DIM, 6)
        draw.text((bx + 10, chart_y2 + 215), days2[i], font=font_regular(24), fill=GRAY)

    # 범례
    draw_circle(draw, inner_x + 20, chart_y2 + 270, 8, (50, 50, 60))
    draw.text((inner_x + 40, chart_y2 + 258), "지난주", font=font_regular(24), fill=GRAY)
    draw_circle(draw, inner_x + 170, chart_y2 + 270, 8, CYAN_DIM)
    draw.text((inner_x + 190, chart_y2 + 258), "이번주", font=font_regular(24), fill=GRAY)

    # 공유 버튼 표시
    btn_y = 2050
    draw_rounded_rect(draw, [200, btn_y, W - 200, btn_y + 100], CYAN, 50)
    draw_text_center(draw, btn_y + 22, "카카오톡으로 공유하기", font_bold(40), BG_DARK)

    draw_text_center(draw, 2350, "숫자로 보여주면", font_regular(38), (180, 180, 190))
    draw_text_center(draw, 2410, "설득력이 다릅니다", font_regular(38), (180, 180, 190))

    draw_text_center(draw, 2580, "SnoreLess", font_bold(48), CYAN)

    save(img, "store_06_partner.png")


if __name__ == "__main__":
    print("App Store 스크린샷 생성 중...")
    screenshot_01_hero()
    screenshot_02_detection()
    screenshot_03_morning_report()
    screenshot_04_smart_alarm()
    screenshot_05_privacy()
    screenshot_06_partner()
    print(f"\n완료! {OUTPUT_DIR}/ 에 6장 생성됨")
