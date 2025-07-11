#!/usr/bin/env python3
"""
Simple script to sample colors directly from the legend and update the main script
"""

import os
import cv2
import numpy as np
from pdf2image import convert_from_path
import matplotlib.pyplot as plt
import json

def extract_map(pdf_path):
    """Extract the map from PDF using optimized parameters"""
    print(f"Extracting map from {pdf_path}...")
    
    # Convert PDF to image at high resolution
    images = convert_from_path(pdf_path, dpi=300)
    img = np.array(images[0])
    
    # Convert RGBA to RGB if needed
    if img.shape[2] == 4:
        img = cv2.cvtColor(img, cv2.COLOR_RGBA2RGB)
    
    height, width = img.shape[:2]
    
    # Optimized crop parameters - focus on just the legend area
    crop_top = int(height * 0.80)    # Start at bottom where legend is
    crop_bottom = int(height * 0.90) # End after legend
    crop_left = int(width * 0.10)    # Left edge
    crop_right = int(width * 0.90)   # Right edge
    
    # Crop image to get just the legend area
    return img[crop_top:crop_bottom, crop_left:crop_right]

def sample_from_legend(legend_image):
    """Sample colors directly from the legend boxes"""
    height, width = legend_image.shape[:2]
    
    # Display the legend
    plt.figure(figsize=(12, 6))
    plt.imshow(legend_image)
    plt.title("Click on each colored box in the legend to sample colors")
    plt.axis('off')
    
    # Categories in order
    categories = [
        '0-9 Mbps',
        '10-24 Mbps', 
        '25-49 Mbps', 
        '50-100 Mbps', 
        '100+ Mbps'
    ]
    
    colors = {}
    current_category = 0
    
    def onclick(event):
        nonlocal current_category
        if current_category >= len(categories):
            plt.close()
            return
        
        if event.xdata is not None and event.ydata is not None:
            x, y = int(event.xdata), int(event.ydata)
            if 0 <= x < width and 0 <= y < height:
                # Sample a 5x5 area around the click and take the average color
                x_min = max(0, x-2)
                x_max = min(width, x+3)
                y_min = max(0, y-2)
                y_max = min(height, y+3)
                
                sample_area = legend_image[y_min:y_max, x_min:x_max]
                avg_color = np.mean(sample_area, axis=(0, 1)).astype(int)
                
                hex_color = '#{:02x}{:02x}{:02x}'.format(avg_color[0], avg_color[1], avg_color[2])
                
                category = categories[current_category]
                colors[category] = {
                    'color': avg_color.tolist(),
                    'hex': hex_color
                }
                
                # Draw a circle at the clicked point
                plt.plot(x, y, 'o', color='white', markersize=10)
                plt.text(x+10, y, f"{category}: {avg_color}", color='white', 
                        bbox=dict(facecolor='black', alpha=0.7))
                plt.draw()
                
                print(f"Sampled {category}: RGB {avg_color}, HEX {hex_color}")
                
                current_category += 1
                
                if current_category >= len(categories):
                    plt.close()
    
    cid = plt.gcf().canvas.mpl_connect('button_press_event', onclick)
    plt.show()
    
    return colors

def generate_config_snippet(colors):
    """Generate configuration snippet for the main script"""
    config = "SPEED_CATEGORIES = {\n"
    
    for category, values in colors.items():
        config += f"    '{category}': {{'color': {values['color']}, 'hex': '{values['hex']}'}},\n"
    
    config += "}"
    
    return config

def main():
    try:
        # Get PDF path
        pdf_path = input("Enter PDF path (or press Enter for default input/cuyahoga_broadband.pdf): ") or "input/cuyahoga_broadband.pdf"
        
        if not os.path.exists(pdf_path):
            print(f"Error: PDF not found at {pdf_path}")
            return
        
        # Extract legend from map
        legend_image = extract_map(pdf_path)
        
        # Sample colors from legend
        print("Please click on each colored box in the legend, in order from left to right:")
        print("1. 0-9 Mbps (Red)")
        print("2. 10-24 Mbps (Orange)")
        print("3. 25-49 Mbps (Yellow-Green)")
        print("4. 50-100 Mbps (Light Green)")
        print("5. 100+ Mbps (Dark Green)")
        
        colors = sample_from_legend(legend_image)
        
        # Save colors to file
        with open('sampled_colors.json', 'w') as f:
            json.dump(colors, f, indent=4)
        
        print(f"\nColor configuration saved to sampled_colors.json")
        
        # Generate config snippet for main script
        config = generate_config_snippet(colors)
        print("\nTo update your main script, replace the SPEED_CATEGORIES with:")
        print(config)
        
        # Option to update main script directly
        update = input("\nWould you like to update broadband_quickstart.py directly? (y/n): ")
        if update.lower() == 'y':
            with open('scripts/broadband_quickstart.py', 'r') as f:
                script = f.read()
            
            # Find the SPEED_CATEGORIES section and replace it
            import re
            pattern = r"SPEED_CATEGORIES = \{[^}]*\}"
            updated_script = re.sub(pattern, config, script, flags=re.DOTALL)
            
            with open('scripts/broadband_quickstart.py', 'w') as f:
                f.write(updated_script)
            
            print("Main script updated successfully!")
    
    except Exception as e:
        print(f"An error occurred: {str(e)}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main() 