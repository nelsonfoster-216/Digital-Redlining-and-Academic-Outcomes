#!/usr/bin/env python3
"""
Quick Start Script for Broadband Map Vectorization
This script provides a streamlined approach to extract broadband speed polygons
from the Cuyahoga County PDF map.
"""

import cv2
import numpy as np
import geopandas as gpd
from shapely.geometry import Polygon
from shapely.ops import unary_union
import json
from pdf2image import convert_from_path
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
import os

# Configuration
SPEED_CATEGORIES = {
    '0-9 Mbps': {'color': [187, 17, 34], 'hex': '#bb1122'},
    '10-24 Mbps': {'color': [103, 58, 21], 'hex': '#673a15'},
    '25-49 Mbps': {'color': [221, 221, 85], 'hex': '#dddd55'},
    '50-100 Mbps': {'color': [89, 144, 59], 'hex': '#59903b'},
    '100+ Mbps': {'color': [84, 173, 89], 'hex': '#54ad59'},
}

# Cleveland bounding box
CLEVELAND_BBOX = {
    'west': -81.82,
    'east': -81.55,
    'south': 41.39,
    'north': 41.60
}

def extract_map_from_pdf(pdf_path, preview=True):
    """Extract and crop the map from PDF"""
    print("Extracting map from PDF...")
    
    # Convert PDF to image at high resolution
    images = convert_from_path(pdf_path, dpi=300)
    img = np.array(images[0])
    
    # Convert RGBA to RGB if needed
    if img.shape[2] == 4:
        img = cv2.cvtColor(img, cv2.COLOR_RGBA2RGB)
    
    # Define crop area (optimized for the Cuyahoga County broadband profile)
    height, width = img.shape[:2]
    crop_top = int(height * 0.25)       # Start below header
    crop_bottom = int(height * 0.88)    # End after legend
    crop_left = int(width * 0.08)       # Start at left edge of map
    crop_right = int(width * 0.70)      # End at right edge of map
    
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
            print("Please adjust the crop values in the code.")
            return None
    
    return cropped

def detect_broadband_regions(image, tolerance=50):
    """Detect regions by color matching"""
    print("Detecting broadband speed regions...")
    
    masks = {}
    
    for category, info in SPEED_CATEGORIES.items():
        print(f"  Processing {category}...")
        
        # Define color range
        color = np.array(info['color'])
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
        
        # Fill holes
        contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        mask_filled = np.zeros_like(mask)
        cv2.drawContours(mask_filled, contours, -1, 255, -1)
        
        masks[category] = mask_filled
    
    # Visualize masks for debugging
    debug_masks = True
    if debug_masks:
        fig, axes = plt.subplots(2, 3, figsize=(15, 10))
        axes = axes.flatten()
        
        # Show original image
        axes[0].imshow(image)
        axes[0].set_title("Original Image")
        axes[0].axis('off')
        
        # Show each mask
        for i, (category, mask) in enumerate(masks.items()):
            if i >= 5:  # We only have 5 categories
                break
            axes[i+1].imshow(mask, cmap='gray')
            axes[i+1].set_title(f"Mask: {category}")
            axes[i+1].axis('off')
        
        plt.tight_layout()
        plt.show()
        
        # Check if any masks have content
        has_content = False
        for mask in masks.values():
            if np.sum(mask) > 0:
                has_content = True
                break
        
        if not has_content:
            print("WARNING: No regions detected in any mask! Adjust color values or tolerance.")
    
    return masks

def masks_to_polygons(masks, image_shape):
    """Convert binary masks to polygons"""
    print("Converting masks to polygons...")
    
    height, width = image_shape[:2]
    all_polygons = []
    
    for category, mask in masks.items():
        # Find contours
        contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        for contour in contours:
            # Skip small contours
            if cv2.contourArea(contour) < 100:
                continue
            
            # Simplify contour
            epsilon = 0.002 * cv2.arcLength(contour, True)
            approx = cv2.approxPolyDP(contour, epsilon, True)
            
            if len(approx) >= 3:
                # Normalize coordinates to [0, 1]
                coords = approx.reshape(-1, 2).astype(float)
                coords[:, 0] /= width
                coords[:, 1] /= height
                
                # Create polygon
                polygon = Polygon(coords)
                
                if polygon.is_valid and polygon.area > 0:
                    all_polygons.append({
                        'geometry': polygon,
                        'speed_category': category,
                        'color': SPEED_CATEGORIES[category]['hex']
                    })
    
    return all_polygons

def georeference_polygons(polygons, bbox):
    """Convert normalized coordinates to geographic coordinates"""
    print("Georeferencing polygons...")
    
    georeferenced = []
    
    for poly_dict in polygons:
        polygon = poly_dict['geometry']
        coords = list(polygon.exterior.coords)
        
        # Transform to geographic coordinates
        geo_coords = []
        for x, y in coords:
            lon = bbox['west'] + x * (bbox['east'] - bbox['west'])
            lat = bbox['north'] - y * (bbox['north'] - bbox['south'])
            geo_coords.append((lon, lat))
        
        geo_polygon = Polygon(geo_coords)
        
        georeferenced.append({
            'geometry': geo_polygon,
            'speed_category': poly_dict['speed_category'],
            'color': poly_dict['color']
        })
    
    return georeferenced

def create_geojson(polygons, output_path):
    """Create GeoJSON file from polygons"""
    print(f"Creating GeoJSON: {output_path}")
    
    # Create GeoDataFrame
    gdf = gpd.GeoDataFrame(polygons, crs='EPSG:4326')
    
    # Merge adjacent polygons of the same category
    merged_polygons = []
    for category in SPEED_CATEGORIES.keys():
        category_polys = gdf[gdf['speed_category'] == category]
        if len(category_polys) > 0:
            # Union all polygons of this category
            merged = unary_union(category_polys.geometry)
            
            # Handle both Polygon and MultiPolygon results
            if merged.geom_type == 'Polygon':
                merged_polygons.append({
                    'geometry': merged,
                    'speed_category': category,
                    'color': SPEED_CATEGORIES[category]['hex']
                })
            elif merged.geom_type == 'MultiPolygon':
                for poly in merged.geoms:
                    merged_polygons.append({
                        'geometry': poly,
                        'speed_category': category,
                        'color': SPEED_CATEGORIES[category]['hex']
                    })
    
    # Create final GeoDataFrame
    final_gdf = gpd.GeoDataFrame(merged_polygons, crs='EPSG:4326')
    
    # Simplify geometries
    final_gdf['geometry'] = final_gdf['geometry'].simplify(0.0001)
    
    # Save to file
    final_gdf.to_file(output_path, driver='GeoJSON')
    
    return final_gdf

def visualize_results(gdf, reference_geojson=None):
    """Visualize the extracted broadband polygons"""
    fig, ax = plt.subplots(figsize=(12, 10))
    
    # Plot broadband speeds
    gdf.plot(column='speed_category', 
             categorical=True,
             legend=True,
             ax=ax,
             alpha=0.7,
             edgecolor='black',
             linewidth=0.5)
    
    # Plot reference data if provided
    if reference_geojson:
        ref_gdf = gpd.read_file(reference_geojson)
        ref_gdf.boundary.plot(ax=ax, color='black', linewidth=1, alpha=0.5)
    
    ax.set_xlabel('Longitude')
    ax.set_ylabel('Latitude')
    ax.set_title('Extracted Broadband Speed Polygons - Cleveland, OH')
    
    plt.tight_layout()
    plt.show()

def main():
    """Main execution function"""
    
    # File paths
    pdf_path = 'input/cuyahoga_broadband.pdf'  # Updated path to reflect likely location
    output_path = 'cleveland_broadband_speeds.geojson'
    reference_path = 'geojson.json'  # Your redlining data
    
    # Check if PDF exists
    if not os.path.exists(pdf_path):
        print(f"Error: PDF file not found: {pdf_path}")
        pdf_path = input("Please enter the correct path to the PDF file: ")
        if not os.path.exists(pdf_path):
            print(f"Error: PDF file still not found: {pdf_path}")
            return
    
    # Step 1: Extract map from PDF
    map_image = extract_map_from_pdf(pdf_path, preview=True)
    if map_image is None:
        return
    
    # Step 2: Detect broadband regions
    masks = detect_broadband_regions(map_image)
    
    # Step 3: Convert to polygons
    polygons = masks_to_polygons(masks, map_image.shape)
    print(f"  Found {len(polygons)} polygons")
    
    # Step 4: Georeference
    geo_polygons = georeference_polygons(polygons, CLEVELAND_BBOX)
    
    # Step 5: Create GeoJSON
    gdf = create_geojson(geo_polygons, output_path)
    
    # Step 6: Print summary
    print("\nSummary:")
    print(f"Total polygons: {len(gdf)}")
    for category in SPEED_CATEGORIES.keys():
        count = len(gdf[gdf['speed_category'] == category])
        print(f"  {category}: {count} polygons")
    
    # Step 7: Visualize results
    visualize_results(gdf, reference_path if os.path.exists(reference_path) else None)
    
    print(f"\nBroadband speed polygons saved to: {output_path}")
    print("You can now load this file in QGIS or any GIS software.")

if __name__ == "__main__":
    main()