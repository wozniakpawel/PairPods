#!/usr/bin/env python3

from PIL import Image
import os
import sys

def generate_icons(icon_dir):
    # Define the sizes for macOS app icons
    sizes = [16, 32, 64, 128, 180, 192, 256, 512, 1024]

    # Path to the original 1024x1024 icon
    input_path = os.path.join(icon_dir, "icon.png")

    if not os.path.exists(input_path):
        sys.exit(f"Error: The icon.png does not exist in {icon_dir}")

    # Load the original 1024x1024 icon
    icon = Image.open(input_path)

    # Generate and save the resized icons
    for size in sizes:
        resized_icon = icon.resize((size, size), Image.LANCZOS)
        output_path = os.path.join(icon_dir, f"icon_{size}x{size}.png")
        resized_icon.save(output_path)
        print(f"Generated {output_path}")

    output_path = os.path.join(icon_dir, f"favicon.ico")
    icon.save(output_path, sizes=[(48, 48)])
    print(f"Generated {output_path}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit("Error: Please provide the icon directory as the first argument.")

    icon_dir = sys.argv[1]

    generate_icons(icon_dir)
