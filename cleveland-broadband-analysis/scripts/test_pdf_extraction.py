#!/usr/bin/env python3
"""
Test script for PDF extraction
"""

import os
import cv2
import numpy as np
from pdf2image import convert_from_path
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle

def extract_map_from_pdf(pdf_path, preview=True, crop_params=None):
    """Extract and crop the map from PDF"""
    print("Extracting map from PDF...")
    
    # Convert PDF to image at high resolution
    images = convert_from_path(pdf_path, dpi=300)
    img = np.array(images[0])
    
    # Convert RGBA to RGB if needed
    if img.shape[2] == 4:
        img = cv2.cvtColor(img, cv2.COLOR_RGBA2RGB)
    
    height, width = img.shape[:2]
    
    # Define default crop area if not provided
    if crop_params is None:
        # Default crop parameters
        crop_top = int(height * 0.20)      # Start below header
        crop_bottom = int(height * 0.90)   # Extended further to include the legend
        crop_left = int(width * 0.15)      # Start after left margin
        crop_right = int(width * 0.68)     # End before text on right side
    else:
        crop_top, crop_bottom, crop_left, crop_right = crop_params
    
    # Crop image
    cropped = img[crop_top:crop_bottom, crop_left:crop_right]
    
    if preview:
        # Show crop preview
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(15, 8))
        
        ax1.imshow(img)
        rect = Rectangle((crop_left, crop_top), 
                        crop_right - crop_left, 
                        crop_bottom - crop_top,
                        linewidth=2, edgecolor='red', facecolor='none')
        ax1.add_patch(rect)
        ax1.set_title('Original PDF with Crop Area')
        ax1.axis('off')
        
        ax2.imshow(cropped)
        ax2.set_title('Cropped Map')
        ax2.axis('off')
        
        plt.tight_layout()
        plt.show()
        
        # Ask user to confirm
        response = input("Is the crop area correct? (y/n): ")
        if response.lower() != 'y':
            adjust = input("Do you want to adjust the crop parameters? (y/n): ")
            if adjust.lower() == 'y':
                try:
                    print(f"Current parameters: top={crop_top}, bottom={crop_bottom}, left={crop_left}, right={crop_right}")
                    crop_top = int(input(f"Enter new top value (0-{height}): ") or crop_top)
                    crop_bottom = int(input(f"Enter new bottom value (0-{height}): ") or crop_bottom)
                    crop_left = int(input(f"Enter new left value (0-{width}): ") or crop_left)
                    crop_right = int(input(f"Enter new right value (0-{width}): ") or crop_right)
                    
                    # Recursive call with new parameters
                    return extract_map_from_pdf(pdf_path, preview, (crop_top, crop_bottom, crop_left, crop_right))
                except ValueError:
                    print("Invalid input. Using default values.")
            else:
                print("Please adjust the crop values in the code.")
                return None
    
    return cropped

def test_extraction():
    # Get PDF path from user
    pdf_path = input("Enter the path to your PDF file: ")
    
    # Check if file exists
    if not os.path.exists(pdf_path):
        print(f"Error: PDF file not found at {pdf_path}")
        return
    
    # Extract map from PDF with preview
    print(f"Attempting to extract map from {pdf_path}...")
    map_image = extract_map_from_pdf(pdf_path, preview=True)
    
    if map_image is not None:
        print("Extraction successful!")
        print(f"Extracted image shape: {map_image.shape}")
        
        # Save image option
        save = input("Would you like to save the extracted map? (y/n): ")
        if save.lower() == 'y':
            output_path = input("Enter output path (or press Enter for 'extracted_map.png'): ") or "extracted_map.png"
            cv2.imwrite(output_path, cv2.cvtColor(map_image, cv2.COLOR_RGB2BGR))
            print(f"Map saved to {output_path}")
    else:
        print("Extraction failed or was cancelled by user.")

if __name__ == "__main__":
    test_extraction() 