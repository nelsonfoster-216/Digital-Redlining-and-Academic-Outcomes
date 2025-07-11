#!/usr/bin/env python3
"""
Script to extract just the map and legend from the broadband PDF
"""

import os
import cv2
import numpy as np
from pdf2image import convert_from_path
import matplotlib.pyplot as plt

def extract_map_and_legend(pdf_path, output_path="extracted_map.png"):
    """Extract just the map and legend from the PDF"""
    print(f"Extracting map from {pdf_path}...")
    
    # Convert PDF to image at high resolution
    images = convert_from_path(pdf_path, dpi=300)
    img = np.array(images[0])
    
    # Convert RGBA to RGB if needed
    if img.shape[2] == 4:
        img = cv2.cvtColor(img, cv2.COLOR_RGBA2RGB)
    
    height, width = img.shape[:2]
    
    # Hardcoded crop parameters specifically for this PDF
    # These are set to capture just the map and legend based on your screenshot
    crop_top = int(height * 0.25)       # Start below header
    crop_bottom = int(height * 0.88)    # End after legend
    crop_left = int(width * 0.08)       # Start at left edge of map
    crop_right = int(width * 0.70)      # End at right edge of map
    
    # Crop image
    map_image = img[crop_top:crop_bottom, crop_left:crop_right]
    
    # Show the result
    plt.figure(figsize=(12, 10))
    plt.imshow(map_image)
    plt.axis('off')
    plt.title('Extracted Map and Legend')
    plt.tight_layout()
    plt.show()
    
    # Save the extracted map
    cv2.imwrite(output_path, cv2.cvtColor(map_image, cv2.COLOR_RGB2BGR))
    print(f"Map saved to {output_path}")
    
    return map_image

if __name__ == "__main__":
    # Get PDF path from user
    pdf_path = input("Enter the path to your PDF file: ")
    
    # Check if file exists
    if not os.path.exists(pdf_path):
        print(f"Error: PDF file not found at {pdf_path}")
        exit(1)
    
    # Get output path
    output_path = input("Enter output path (or press Enter for 'extracted_map.png'): ") or "extracted_map.png"
    
    # Extract and save the map
    extract_map_and_legend(pdf_path, output_path) 