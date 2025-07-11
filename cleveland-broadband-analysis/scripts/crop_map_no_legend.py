#!/usr/bin/env python3
"""
Script to crop the map image excluding the legend area
"""

import os
import cv2
import numpy as np
from pdf2image import convert_from_path
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
import matplotlib.widgets as widgets

class CropSelector:
    def __init__(self, image):
        self.image = image
        self.height, self.width = image.shape[:2]
        
        # Initial crop parameters as percentages
        self.crop_top = 0.25      # Default top (25% from top)
        self.crop_bottom = 0.80   # Default bottom (80% from top) - above legend
        self.crop_left = 0.08     # Default left (8% from left)
        self.crop_right = 0.70    # Default right (70% from left)
        
        # Convert to pixel coordinates
        self.top = int(self.height * self.crop_top)
        self.bottom = int(self.height * self.crop_bottom)
        self.left = int(self.width * self.crop_left)
        self.right = int(self.width * self.crop_right)
        
        self.fig, self.axes = plt.subplots(1, 2, figsize=(15, 8))
        self.rect = None
        self.cropped_img = None
        self.setup_plot()
    
    def setup_plot(self):
        # Original image with rectangle
        self.axes[0].imshow(self.image)
        self.axes[0].set_title('Adjust Crop Area (drag sliders)')
        self.rect = Rectangle((self.left, self.top), 
                             self.right - self.left, 
                             self.bottom - self.top,
                             linewidth=2, edgecolor='red', facecolor='none')
        self.axes[0].add_patch(self.rect)
        self.axes[0].axis('off')
        
        # Cropped image
        self.update_crop()
        self.axes[1].set_title('Preview of Cropped Image')
        self.axes[1].axis('off')
        
        # Add sliders
        plt.subplots_adjust(bottom=0.3)
        
        ax_top = plt.axes([0.2, 0.2, 0.65, 0.03])
        ax_bottom = plt.axes([0.2, 0.15, 0.65, 0.03])
        ax_left = plt.axes([0.2, 0.1, 0.65, 0.03])
        ax_right = plt.axes([0.2, 0.05, 0.65, 0.03])
        
        self.s_top = widgets.Slider(ax_top, 'Top', 0.0, 0.5, valinit=self.crop_top)
        self.s_bottom = widgets.Slider(ax_bottom, 'Bottom', 0.5, 1.0, valinit=self.crop_bottom)
        self.s_left = widgets.Slider(ax_left, 'Left', 0.0, 0.5, valinit=self.crop_left)
        self.s_right = widgets.Slider(ax_right, 'Right', 0.5, 1.0, valinit=self.crop_right)
        
        self.s_top.on_changed(self.update)
        self.s_bottom.on_changed(self.update)
        self.s_left.on_changed(self.update)
        self.s_right.on_changed(self.update)
        
        # Add save button
        ax_save = plt.axes([0.45, 0.01, 0.1, 0.03])
        self.b_save = widgets.Button(ax_save, 'Save Crop')
        self.b_save.on_clicked(self.save_crop)
    
    def update(self, val):
        # Get values from sliders
        self.crop_top = self.s_top.val
        self.crop_bottom = self.s_bottom.val
        self.crop_left = self.s_left.val
        self.crop_right = self.s_right.val
        
        # Convert to pixel coordinates
        self.top = int(self.height * self.crop_top)
        self.bottom = int(self.height * self.crop_bottom)
        self.left = int(self.width * self.crop_left)
        self.right = int(self.width * self.crop_right)
        
        # Update rectangle
        self.rect.set_xy((self.left, self.top))
        self.rect.set_width(self.right - self.left)
        self.rect.set_height(self.bottom - self.top)
        
        # Update cropped image
        self.update_crop()
        
        # Redraw
        self.fig.canvas.draw_idle()
    
    def update_crop(self):
        # Get cropped image
        self.cropped_img = self.image[self.top:self.bottom, self.left:self.right]
        
        # Update display
        self.axes[1].clear()
        self.axes[1].imshow(self.cropped_img)
        self.axes[1].set_title('Preview of Cropped Image')
        self.axes[1].axis('off')
    
    def save_crop(self, event):
        # Get crop parameters
        crop_params = {
            'top': self.crop_top,
            'bottom': self.crop_bottom,
            'left': self.crop_left,
            'right': self.crop_right,
            'pixel_top': self.top,
            'pixel_bottom': self.bottom,
            'pixel_left': self.left,
            'pixel_right': self.right
        }
        
        plt.close(self.fig)
        self.crop_result = crop_params
        
    def show(self):
        plt.show()
        return self.cropped_img, self.crop_result

def extract_map_from_pdf(pdf_path, preview=True):
    """Extract the map from PDF"""
    print(f"Extracting map from {pdf_path}...")
    
    # Convert PDF to image at high resolution
    images = convert_from_path(pdf_path, dpi=300)
    img = np.array(images[0])
    
    # Convert RGBA to RGB if needed
    if img.shape[2] == 4:
        img = cv2.cvtColor(img, cv2.COLOR_RGBA2RGB)
    
    return img

def save_crop_params(crop_params, output_path='crop_params.txt'):
    """Save crop parameters to a file"""
    with open(output_path, 'w') as f:
        for key, value in crop_params.items():
            f.write(f"{key}: {value}\n")
    print(f"Crop parameters saved to {output_path}")

def main():
    try:
        # Get PDF path
        pdf_path = input("Enter PDF path (or press Enter for default input/cuyahoga_broadband.pdf): ") or "input/cuyahoga_broadband.pdf"
        
        if not os.path.exists(pdf_path):
            print(f"Error: PDF not found at {pdf_path}")
            return
        
        # Extract map from PDF
        full_image = extract_map_from_pdf(pdf_path)
        
        # Interactive cropping
        print("Use the sliders to adjust the crop area to exclude the legend")
        print("When satisfied, click 'Save Crop' to proceed")
        
        selector = CropSelector(full_image)
        cropped_img, crop_params = selector.show()
        
        if cropped_img is None:
            print("Cropping cancelled")
            return
        
        # Save cropped image
        output_path = input("Enter output path for cropped image (or press Enter for 'map_no_legend.png'): ") or "map_no_legend.png"
        cv2.imwrite(output_path, cv2.cvtColor(cropped_img, cv2.COLOR_RGB2BGR))
        print(f"Cropped map saved to {output_path}")
        
        # Save crop parameters
        save_crop_params(crop_params)
        
        # Show summary
        print("\nCrop Summary:")
        print(f"Original image size: {full_image.shape[1]}x{full_image.shape[0]}")
        print(f"Cropped image size: {cropped_img.shape[1]}x{cropped_img.shape[0]}")
        print(f"Top: {crop_params['crop_top']:.2f} ({crop_params['pixel_top']} pixels)")
        print(f"Bottom: {crop_params['crop_bottom']:.2f} ({crop_params['pixel_bottom']} pixels)")
        print(f"Left: {crop_params['crop_left']:.2f} ({crop_params['pixel_left']} pixels)")
        print(f"Right: {crop_params['crop_right']:.2f} ({crop_params['pixel_right']} pixels)")
        
        # Suggest how to update the main script
        print("\nTo update your main script with these crop parameters, change the following lines:")
        print("height, width = img.shape[:2]")
        print(f"crop_top = int(height * {crop_params['crop_top']:.4f})    # Exclude header")
        print(f"crop_bottom = int(height * {crop_params['crop_bottom']:.4f})  # Exclude legend")
        print(f"crop_left = int(width * {crop_params['crop_left']:.4f})     # Start at left edge of map")
        print(f"crop_right = int(width * {crop_params['crop_right']:.4f})    # End at right edge of map")
    
    except Exception as e:
        print(f"An error occurred: {str(e)}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main() 