from PIL import Image, ImageDraw, ImageFont
import os

source_path = 'apps/web/public/brand/logo.png'
base_logo = Image.open(source_path).convert('RGBA')

sizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}

# 1. Customer Icon: Clean, vibrant, rounded brand icon
def create_customer_icon(size):
    icon = Image.new('RGBA', (size, size), (255, 255, 255, 0))
    # Draw rounded rectangle background with amber border
    draw = ImageDraw.Draw(icon)
    radius = int(size * 0.22)
    # Background fill: warm white
    draw.rounded_rectangle([0, 0, size, size], radius=radius, fill=(253, 251, 247, 255), outline=(245, 158, 11, 255), width=max(1, int(size * 0.03)))
    
    # Scale logo into center (80% of size)
    logo_size = int(size * 0.82)
    scaled_logo = base_logo.resize((logo_size, logo_size), Image.Resampling.LANCZOS)
    offset = (size - logo_size) // 2
    icon.alpha_composite(scaled_logo, (offset, offset))
    return icon

# 2. Provider Icon: With distinct 'KITCHEN' emerald badge on bottom
def create_provider_icon(size):
    icon = Image.new('RGBA', (size, size), (255, 255, 255, 0))
    draw = ImageDraw.Draw(icon)
    radius = int(size * 0.22)
    # Background: crisp white with emerald outline
    draw.rounded_rectangle([0, 0, size, size], radius=radius, fill=(255, 255, 255, 255), outline=(16, 185, 129, 255), width=max(1, int(size * 0.04)))
    
    # Logo in center (slightly higher to accommodate bottom banner)
    logo_size = int(size * 0.72)
    scaled_logo = base_logo.resize((logo_size, logo_size), Image.Resampling.LANCZOS)
    offset_x = (size - logo_size) // 2
    offset_y = int(size * 0.06)
    icon.alpha_composite(scaled_logo, (offset_x, offset_y))
    
    # Bottom banner for 'PARTNER'
    banner_h = int(size * 0.24)
    draw.rounded_rectangle([0, size - banner_h, size, size], radius=radius, fill=(16, 185, 129, 255))
    draw.rectangle([0, size - banner_h, size, size - banner_h + radius], fill=(16, 185, 129, 255))
    
    # Text on banner
    try:
        font_size = max(8, int(size * 0.14))
        font = ImageFont.load_default()
        # draw text
        draw.text((size // 2, size - banner_h // 2), "PARTNER", fill=(255, 255, 255, 255), anchor="mm")
    except Exception:
        pass
        
    return icon

# 3. Delivery Icon: With blue fleet banner
def create_delivery_icon(size):
    icon = Image.new('RGBA', (size, size), (255, 255, 255, 0))
    draw = ImageDraw.Draw(icon)
    radius = int(size * 0.22)
    draw.rounded_rectangle([0, 0, size, size], radius=radius, fill=(255, 255, 255, 255), outline=(2, 132, 199, 255), width=max(1, int(size * 0.04)))
    
    logo_size = int(size * 0.72)
    scaled_logo = base_logo.resize((logo_size, logo_size), Image.Resampling.LANCZOS)
    offset_x = (size - logo_size) // 2
    offset_y = int(size * 0.06)
    icon.alpha_composite(scaled_logo, (offset_x, offset_y))
    
    banner_h = int(size * 0.24)
    draw.rounded_rectangle([0, size - banner_h, size, size], radius=radius, fill=(2, 132, 199, 255))
    draw.rectangle([0, size - banner_h, size, size - banner_h + radius], fill=(2, 132, 199, 255))
    
    try:
        font = ImageFont.load_default()
        draw.text((size // 2, size - banner_h // 2), "RIDER", fill=(255, 255, 255, 255), anchor="mm")
    except Exception:
        pass
        
    return icon

apps = {
    'apps/mobile_customer': create_customer_icon,
    'apps/mobile_provider': create_provider_icon,
    'apps/mobile_delivery': create_delivery_icon,
}

for app_dir, generator in apps.items():
    res_dir = os.path.join(app_dir, 'android', 'app', 'src', 'main', 'res')
    for folder, size in sizes.items():
        target_dir = os.path.join(res_dir, folder)
        os.makedirs(target_dir, exist_ok=True)
        img = generator(size)
        target_path = os.path.join(target_dir, 'ic_launcher.png')
        img.save(target_path, 'PNG')
        print(f"Generated {target_path} ({size}x{size})")

print("All app icons customized and generated successfully!")
