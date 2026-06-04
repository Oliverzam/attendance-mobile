from PIL import Image, ImageDraw
import math

def generate_icon(output_path, size=1024):
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    navy = (12, 26, 58, 255)     # #0C1A3A
    blue = (24, 95, 165, 255)    # #185FA5
    white = (255, 255, 255, 255)

    # Background: rounded square
    corner_r = int(size * 0.16)
    draw.rounded_rectangle([(0, 0), (size - 1, size - 1)], radius=corner_r, fill=navy)

    # Hexagon (pointy-top, centered)
    cx, cy = size // 2, size // 2
    hex_r = int(size * 0.36)

    hex_points = []
    for i in range(6):
        angle = math.pi / 2 + i * math.pi / 3
        x = cx + hex_r * math.cos(angle)
        y = cy - hex_r * math.sin(angle)
        hex_points.append((x, y))
    draw.polygon(hex_points, fill=blue)

    # GPS pin — positioned slightly above center of hexagon
    pin_cx = cx
    pin_cy = cy - int(size * 0.04)  # 471

    # Circle outline (white ring)
    circle_r = int(size * 0.086)    # outer radius ~88px
    border_w = int(size * 0.014)    # border thickness ~14px
    inner_r  = circle_r - border_w

    draw.ellipse([pin_cx - circle_r, pin_cy - circle_r,
                  pin_cx + circle_r, pin_cy + circle_r], fill=white)
    draw.ellipse([pin_cx - inner_r, pin_cy - inner_r,
                  pin_cx + inner_r, pin_cy + inner_r], fill=blue)

    # Center dot (solid white)
    dot_r = int(size * 0.013)
    draw.ellipse([pin_cx - dot_r, pin_cy - dot_r,
                  pin_cx + dot_r, pin_cy + dot_r], fill=white)

    # Vertical stem going down
    stem_w   = border_w
    stem_y1  = pin_cy + circle_r
    stem_y2  = pin_cy + circle_r + int(size * 0.128)  # ~131px stem
    draw.rectangle([pin_cx - stem_w // 2, stem_y1,
                    pin_cx + stem_w // 2, stem_y2], fill=white)

    img.save(output_path, 'PNG')
    print(f"Saved: {output_path}  ({size}x{size}px)")

generate_icon(r'C:\Users\olive\Documents\Poyecto Pozo\hola\assets\icon\app_icon.png')
