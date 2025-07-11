#!/usr/bin/env python3
"""
Script to adjust the yellow color detection for the broadband map
"""

import os
import cv2
import numpy as np
from pdf2image import convert_from_path
import matplotlib.pyplot as plt
import geopandas as gpd
from shapely.geometry import Polygon

# Copy the configuration from the main script
SPEED_CATEGORIES = {
    '0-9 Mbps': {'color': [204, 0, 0], 'hex': '#CC0000'},        # Red
    '10-24 Mbps': {'color': [255, 127, 0], 'hex': '#FF7F00'},    # Orange
    '25-49 Mbps': {'color': [255, 255, 0], 'hex': '#FFFF00'},    # Yellow
    '50-100 Mbps': {'color': [127, 201, 127], 'hex': '#7FC97F'}, # Light green
    '100+ Mbps': {'color': [0, 114, 0], 'hex': '#007200'}        # Dark green
}

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
    
    # Optimized crop parameters
    crop_top = int(height * 0.25)
    crop_bottom = int(height * 0.88)
    crop_left = int(width * 0.08)
    crop_right = int(width * 0.70)
    
    # Crop image
    return img[crop_top:crop_bottom, crop_left:crop_right]

def test_yellow_detection(image, yellow_colors, tolerance_values=[40, 60, 80]):
    """Test different yellow colors and tolerance values"""
    results = []
    
    for yellow_color in yellow_colors:
        for tolerance in tolerance_values:
            # Define color range
            color = np.array(yellow_color)
            lower = np.maximum(0, color - tolerance)
            upper = np.minimum(255, color + tolerance)
            
            # Create mask
            mask = cv2.inRange(image, lower, upper)
            
            # Clean up mask with morphological operations
            kernel = np.ones((5, 5), np.uint8)
            
            # Close small gaps
            mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel)
            
            # Remove noise
            mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel)
            
            # Count white pixels
            white_pixels = np.sum(mask > 0)
            
            # Store result
            results.append({
                'color': yellow_color,
                'hex': '#{:02x}{:02x}{:02x}'.format(*yellow_color),
                'tolerance': tolerance,
                'white_pixels': white_pixels
            })
            
            # Find contours for polygon count
            contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
            polygon_count = 0
            for contour in contours:
                if cv2.contourArea(contour) >= 100:  # Skip tiny areas
                    polygon_count += 1
            
            results[-1]['polygon_count'] = polygon_count
            
            # Visualize
            fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 6))
            
            # Original image with color sample
            ax1.imshow(image)
            color_sample = np.ones((50, 50, 3), dtype=np.uint8)
            color_sample[:] = yellow_color
            ax1.imshow(color_sample, extent=(10, 60, 10, 60))
            ax1.set_title(f"RGB: {yellow_color}, HEX: #{yellow_color[0]:02x}{yellow_color[1]:02x}{yellow_color[2]:02x}")
            ax1.axis('off')
            
            # Mask
            ax2.imshow(mask, cmap='gray')
            ax2.set_title(f"Tolerance: {tolerance}, Pixels: {white_pixels}, Polygons: {polygon_count}")
            ax2.axis('off')
            
            plt.suptitle(f"Yellow Detection Test")
            plt.tight_layout()
            plt.show()
            
            # Ask to save this mask
            save = input(f"Save this mask configuration? (y/n): ")
            if save.lower() == 'y':
                # Create directory
                os.makedirs("yellow_masks", exist_ok=True)
                
                # Save visualization
                fig.savefig(f"yellow_masks/yellow_{yellow_color[0]}_{yellow_color[1]}_{yellow_color[2]}_tol_{tolerance}.png", 
                           dpi=300, bbox_inches='tight')
                
                # Save mask
                cv2.imwrite(f"yellow_masks/mask_{yellow_color[0]}_{yellow_color[1]}_{yellow_color[2]}_tol_{tolerance}.png", mask)
    
    # Print sorted results
    print("\nResults sorted by polygon count:")
    for result in sorted(results, key=lambda x: x['polygon_count'], reverse=True)[:5]:
        print(f"Color: {result['color']}, HEX: {result['hex']}, Tolerance: {result['tolerance']}, "
              f"Polygons: {result['polygon_count']}, Pixels: {result['white_pixels']}")
    
    # Return best result
    best_result = max(results, key=lambda x: x['polygon_count'])
    return best_result

def main():
    # Get PDF path
    pdf_path = input("Enter PDF path (or press Enter for default input/cuyahoga_broadband.pdf): ") or "input/cuyahoga_broadband.pdf"
    
    if not os.path.exists(pdf_path):
        print(f"Error: PDF not found at {pdf_path}")
        return
    
    # Extract map
    map_image = extract_map(pdf_path)
    
    # Different yellow colors to test
    yellow_colors = [
        [255, 255, 0],    # Pure yellow
        [255, 240, 0],    # Slightly orange yellow
        [240, 240, 0],    # Darker yellow
        [255, 255, 100],  # Lighter yellow
        [250, 250, 110],  # Goldenrod-ish
    ]
    
    # Test yellow detection
    best_yellow = test_yellow_detection(map_image, yellow_colors)
    
    print(f"\nBest yellow configuration:")
    print(f"Color: {best_yellow['color']}, HEX: {best_yellow['hex']}")
    print(f"Tolerance: {best_yellow['tolerance']}")
    print(f"Polygon count: {best_yellow['polygon_count']}")
    
    # Suggest update to main script
    print("\nTo update your main script, change the yellow color to:")
    print(f"'25-49 Mbps': {{'color': {best_yellow['color'].tolist()}, 'hex': '{best_yellow['hex']}'}},")

if __name__ == "__main__":
    main() 