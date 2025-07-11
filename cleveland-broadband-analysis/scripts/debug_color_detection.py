#!/usr/bin/env python3
"""
Debug script for color detection in broadband map
"""

import os
import cv2
import numpy as np
from pdf2image import convert_from_path
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors

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

def sample_colors(image, num_points=5):
    """Sample colors from the map at different points"""
    height, width = image.shape[:2]
    samples = []
    
    # Plot the image
    plt.figure(figsize=(12, 10))
    plt.imshow(image)
    plt.title("Click on different color regions to sample")
    plt.axis('off')
    
    def onclick(event):
        if event.xdata is not None and event.ydata is not None:
            x, y = int(event.xdata), int(event.ydata)
            if 0 <= x < width and 0 <= y < height:
                color = image[y, x]
                hex_color = '#{:02x}{:02x}{:02x}'.format(color[0], color[1], color[2])
                samples.append((color, hex_color, (x, y)))
                
                # Draw a circle at the clicked point
                plt.plot(x, y, 'o', color='black', markersize=8)
                plt.plot(x, y, 'o', color='white', markersize=6)
                plt.text(x+10, y, f"RGB: {color}", color='white', 
                        bbox=dict(facecolor='black', alpha=0.7))
                plt.draw()
                
                print(f"Sampled color at ({x}, {y}): RGB {color}, HEX {hex_color}")
                
                if len(samples) >= num_points:
                    plt.close()
    
    cid = plt.gcf().canvas.mpl_connect('button_press_event', onclick)
    plt.show()
    
    return samples

def test_color_detection(image, samples, tolerance_values=[20, 40, 60]):
    """Test different tolerance values for color detection"""
    
    # Define a function to visualize masks
    def show_masks(masks, tolerance):
        fig, axes = plt.subplots(1, len(samples) + 1, figsize=(15, 8))
        
        # Show original image
        axes[0].imshow(image)
        axes[0].set_title("Original Image")
        axes[0].axis('off')
        
        # Show masks
        for i, ((color, hex_color, _), mask) in enumerate(zip(samples, masks)):
            axes[i+1].imshow(mask, cmap='gray')
            axes[i+1].set_title(f"Mask for {hex_color}\nRGB {color}")
            axes[i+1].axis('off')
        
        plt.suptitle(f"Color Detection with Tolerance = {tolerance}")
        plt.tight_layout()
        plt.show()
        
        # Ask to save masks
        save = input(f"Save masks for tolerance {tolerance}? (y/n): ")
        if save.lower() == 'y':
            # Create directory
            os.makedirs("mask_output", exist_ok=True)
            
            # Save combined mask visualization
            fig.savefig(f"mask_output/masks_tolerance_{tolerance}.png", dpi=300, bbox_inches='tight')
            
            # Save individual masks
            for i, ((color, hex_color, _), mask) in enumerate(zip(samples, masks)):
                hex_name = hex_color.replace('#', '')
                cv2.imwrite(f"mask_output/mask_{hex_name}_tolerance_{tolerance}.png", mask)
    
    # Test each tolerance value
    for tolerance in tolerance_values:
        masks = []
        
        for color, hex_color, _ in samples:
            # Define color range
            color_array = np.array(color)
            lower = np.maximum(0, color_array - tolerance)
            upper = np.minimum(255, color_array + tolerance)
            
            # Create mask
            mask = cv2.inRange(image, lower, upper)
            
            # Clean up mask with morphological operations
            kernel = np.ones((5, 5), np.uint8)
            
            # Close small gaps
            mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel)
            
            # Remove noise
            mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel)
            
            masks.append(mask)
        
        # Visualize masks
        show_masks(masks, tolerance)

def main():
    # Get PDF path
    pdf_path = input("Enter PDF path (or press Enter for default input/cuyahoga_broadband.pdf): ") or "input/cuyahoga_broadband.pdf"
    
    if not os.path.exists(pdf_path):
        print(f"Error: PDF not found at {pdf_path}")
        return
    
    # Extract map
    map_image = extract_map(pdf_path)
    
    # Sample colors
    print("Please click on 5 different colored areas on the map to sample colors")
    samples = sample_colors(map_image)
    
    # Test color detection with different tolerances
    test_color_detection(map_image, samples)

if __name__ == "__main__":
    main() 