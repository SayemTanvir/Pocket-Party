"""Generate original geometric store artwork and launcher icons with Pillow."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[1]
out = root / 'publishing' / 'itch'
out.mkdir(parents=True, exist_ok=True)
navy = '#101722'
colors = ['#68e0c2', '#ffbc73', '#ff83a5', '#b7a0ff', '#70bfff']
bold = r'C:\Windows\Fonts\segoeuib.ttf'
regular = r'C:\Windows\Fonts\segoeui.ttf'

def icon(size):
    image = Image.new('RGB', (512, 512), navy)
    draw = ImageDraw.Draw(image)
    for i, color in enumerate(colors[:4]):
        x, y = 116 + (i % 2) * 150, 116 + (i // 2) * 150
        draw.rounded_rectangle((x, y, x + 130, y + 130), radius=30, fill=color)
        for dx, dy in [(40, 40), (90, 90)] if i % 2 else [(65, 65)]:
            draw.ellipse((x+dx-11, y+dy-11, x+dx+11, y+dy+11), fill=navy)
    return image.resize((size, size), Image.Resampling.LANCZOS)

for size in (192, 512):
    for prefix in ('Icon-', 'Icon-maskable-'):
        icon(size).save(root / 'web' / 'icons' / f'{prefix}{size}.png')
icon(32).save(root / 'web' / 'favicon.png')
icon(512).save(out / 'icon.png')
for density, size in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
    icon(size).save(root / 'android' / 'app' / 'src' / 'main' / 'res' / f'mipmap-{density}' / 'ic_launcher.png')

image = Image.new('RGB', (1260, 1000), navy)
draw = ImageDraw.Draw(image)
def text(x, y, label, size, color='#eef5f2', heavy=False):
    draw.text((x,y), label, font=ImageFont.truetype(bold if heavy else regular,size), fill=color)

text(72, 56, 'FIVE GAMES. ONE PARTY.', 28, colors[0], True)
text(66, 108, 'Pocket Party', 118, heavy=True)
text(72, 258, 'Bring your friends. Pick your challenge.', 35, '#b9c5d0')

names = ['Dots & Boxes', 'Chess', 'Darts', 'Word Grid', 'Connect Four']
for i, name in enumerate(names):
    width = 348 if i < 3 else 534
    x = 72 + i * 384 if i < 3 else 72 + (i-3) * 570
    y = 354 if i < 3 else 624
    draw.rounded_rectangle((x,y,x+width,y+238), radius=32, fill='#1d2a3c')
    color = colors[i]
    if i == 0:
        for row in range(3):
            for col in range(3):
                cx, cy = x+50+col*44, y+48+row*44
                draw.ellipse((cx-6,cy-6,cx+6,cy+6),fill=color)
        draw.line((x+50,y+48,x+138,y+48,x+138,y+136),fill=color,width=5)
    elif i == 1:
        draw.rectangle((x+64,y+72,x+142,y+135),fill=color)
        for dx in [52,90,128]:
            draw.rectangle((x+dx,y+36,x+dx+28,y+77),fill=color)
        draw.rectangle((x+50,y+130,x+156,y+144),fill=color)
    elif i == 2:
        for radius in (62,40,17):
            draw.ellipse((x+104-radius,y+90-radius,x+104+radius,y+90+radius),outline=color,width=6)
        draw.line((x+104,y+90,x+174,y+30),fill='#eef5f2',width=6)
    elif i == 3:
        for col, letter in enumerate('WORD'):
            cx = x+32+col*86
            draw.rounded_rectangle((cx,y+38,cx+72,y+122),radius=12,fill=color)
            text(cx+15,y+48,letter,43,navy,True)
    else:
        for row in range(2):
            for col in range(4):
                cx,cy=x+56+col*66,y+55+row*64
                draw.ellipse((cx-22,cy-22,cx+22,cy+22),fill=color if row else '#ffbc73')
    text(x+28,y+164,name,35,heavy=True)
text(72, 910, 'LOCAL  /  BOT  /  PRIVATE ONLINE', 27, '#b9c5d0', True)
text(1028, 904, 'BETA', 32, colors[0], True)
image.save(out / 'cover.png')
print('Created cover, icon and launcher artwork.')
