from PIL import Image, ImageDraw, ImageFont
import math

def create_fart_logo(size=512):
    # Create a new image with transparent background
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Colors
    yellow = (255, 255, 0, 255)  # Bright yellow for fart
    light_yellow = (255, 255, 150, 200)
    person_color = (100, 100, 100, 255)  # Gray for person
    background_color = (255, 255, 255, 255)  # White background

    # Draw white background circle
    draw.ellipse([0, 0, size, size], fill=background_color)

    # Calculate center
    center_x = size // 2
    center_y = size // 2

    # Draw person silhouette (simple stick figure from back)
    # Head
    head_radius = size // 8
    draw.ellipse([center_x - head_radius, center_y - size//3 - head_radius,
                  center_x + head_radius, center_y - size//3 + head_radius],
                 fill=person_color)

    # Body
    body_width = size // 6
    body_height = size // 3
    draw.rectangle([center_x - body_width//2, center_y - size//3,
                    center_x + body_width//2, center_y - size//3 + body_height],
                   fill=person_color)

    # Arms
    arm_length = size // 5
    draw.rectangle([center_x - body_width//2 - arm_length//4, center_y - size//4,
                    center_x - body_width//2, center_y - size//4 + arm_length//2],
                   fill=person_color)
    draw.rectangle([center_x + body_width//2, center_y - size//4,
                    center_x + body_width//2 + arm_length//4, center_y - size//4 + arm_length//2],
                   fill=person_color)

    # Legs
    leg_width = size // 8
    leg_height = size // 4
    draw.rectangle([center_x - body_width//3, center_y - size//3 + body_height,
                    center_x - body_width//6, center_y - size//3 + body_height + leg_height],
                   fill=person_color)
    draw.rectangle([center_x + body_width//6, center_y - size//3 + body_height,
                    center_x + body_width//3, center_y - size//3 + body_height + leg_height],
                   fill=person_color)

    # Fart clouds coming from back
    # Main fart cloud
    fart_center_x = center_x
    fart_center_y = center_y + size//6

    # Draw multiple overlapping circles for fart effect
    for i in range(8):
        angle = (i * 45) * math.pi / 180  # Spread in circle
        distance = size // 12 + (i % 3) * size // 24
        x = fart_center_x + int(math.cos(angle) * distance)
        y = fart_center_y + int(math.sin(angle) * distance)

        # Vary size and opacity
        radius = size // 16 + (i % 4) * size // 32
        opacity = 180 + (i % 3) * 20

        # Alternate between yellow shades
        if i % 2 == 0:
            cloud_color = (255, 255, 0, opacity)  # Bright yellow
        else:
            cloud_color = (255, 255, 100, opacity)  # Slightly darker yellow

        draw.ellipse([x - radius, y - radius, x + radius, y + radius], fill=cloud_color)

    # Add some smaller accent clouds
    for i in range(5):
        x = fart_center_x + (i - 2) * size // 20
        y = fart_center_y + size // 8 + (i % 2) * size // 16
        radius = size // 24
        draw.ellipse([x - radius, y - radius, x + radius, y + radius],
                     fill=(255, 255, 200, 150))

    return img

# Create the logo
logo = create_fart_logo(512)
logo.save('/workspaces/Fart-Flirter/assets/icon/fart_icon.png')
print("Fart logo created successfully!")