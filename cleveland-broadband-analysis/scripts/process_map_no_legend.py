#!/usr/bin/env python3
"""
Script to process the map image excluding the legend
"""

import os
import cv2
import numpy as np
import matplotlib.pyplot as plt
import json
import geopandas as gpd
from shapely.geometry import Polygon
from shapely.ops import unary_union

# Cleveland bounding box
CLEVELAND_BBOX = {
    'west': -81.80,
    'east': -81.53,
    'south': 41.40,
    'north': 41.58
}

def load_image(image_path):
    """Load an image from file"""
    if not os.path.exists(image_path):
        print(f"Error: Image not found at {image_path}")
        return None
    
    # Load image with OpenCV (BGR)
    img = cv2.imread(image_path)
    
    # Convert to RGB
    if img is not None:
        img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    
    return img

def load_color_config(config_path):
    """Load color configuration from JSON file"""
    if not os.path.exists(config_path):
        print(f"Error: Config file not found at {config_path}")
        return None
    
    with open(config_path, 'r') as f:
        return json.load(f)

def detect_broadband_regions(image, color_config, tolerance=50, debug=True):
    """Detect regions by color matching using the provided configuration"""
    print("Detecting broadband speed regions...")
    
    masks = {}
    
    for category, info in color_config.items():
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
    if debug:
        fig, axes = plt.subplots(2, 3, figsize=(15, 10))
        axes = axes.flatten()
        
        # Show original image
        axes[0].imshow(image)
        axes[0].set_title("Original Image")
        axes[0].axis('off')
        
        # Show each mask
        i = 1
        for category, mask in masks.items():
            if i >= len(axes):
                break
            axes[i].imshow(mask, cmap='gray')
            axes[i].set_title(f"Mask: {category}")
            axes[i].axis('off')
            i += 1
        
        plt.tight_layout()
        plt.show()
        
        # Check if any masks have content
        has_content = False
        for category, mask in masks.items():
            white_pixels = np.sum(mask > 0)
            if white_pixels > 0:
                has_content = True
                print(f"  {category}: {white_pixels} pixels detected")
        
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
        
        # Count polygons for this category
        category_polygons = 0
        
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
                    hex_color = mask_category_to_hex(category)
                    all_polygons.append({
                        'geometry': polygon,
                        'speed_category': category,
                        'color': hex_color
                    })
                    category_polygons += 1
        
        print(f"  {category}: {category_polygons} polygons")
    
    print(f"  Total: {len(all_polygons)} polygons")
    return all_polygons

def mask_category_to_hex(category):
    """Convert a mask category to a hex color code"""
    # Colors matching the legend (red=slow, green=fast)
    color_map = {
        '0-9 Mbps': '#bb1122',      # Red for slowest
        '10-24 Mbps': '#ff7b00',    # Orange
        '25-49 Mbps': '#dddd55',    # Yellow-green
        '50-100 Mbps': '#59903b',   # Light green
        '100+ Mbps': '#0e8c0e'      # Dark green for fastest
    }
    
    return color_map.get(category, '#FFFFFF')

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
    categories = set(gdf['speed_category'])
    
    for category in categories:
        category_polys = gdf[gdf['speed_category'] == category]
        if len(category_polys) > 0:
            # Union all polygons of this category
            merged = unary_union(category_polys.geometry)
            
            # Handle both Polygon and MultiPolygon results
            if merged.geom_type == 'Polygon':
                merged_polygons.append({
                    'geometry': merged,
                    'speed_category': category,
                    'color': mask_category_to_hex(category)
                })
            elif merged.geom_type == 'MultiPolygon':
                for poly in merged.geoms:
                    merged_polygons.append({
                        'geometry': poly,
                        'speed_category': category,
                        'color': mask_category_to_hex(category)
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
    # Create figure for full view
    fig, ax = plt.subplots(figsize=(12, 10))
    
    # Define a proper color map following the legend (red=slow, green=fast)
    speed_color_map = {
        '0-9 Mbps': '#bb1122',      # Red for slowest
        '10-24 Mbps': '#ff7b00',    # Orange
        '25-49 Mbps': '#dddd55',    # Yellow-green
        '50-100 Mbps': '#59903b',   # Light green
        '100+ Mbps': '#0e8c0e'      # Dark green for fastest
    }
    
    # Create category order for legend (from slowest to fastest)
    category_order = ['0-9 Mbps', '10-24 Mbps', '25-49 Mbps', '50-100 Mbps', '100+ Mbps']
    
    # Make sure all categories in gdf are in our color map
    categories = sorted(gdf['speed_category'].unique(), 
                       key=lambda x: category_order.index(x) if x in category_order else 999)
    
    # Plot each category with its proper color
    for category in categories:
        cat_data = gdf[gdf['speed_category'] == category]
        color = speed_color_map.get(category, '#FFFFFF')
        cat_data.plot(ax=ax, color=color, alpha=0.7, edgecolor='black', linewidth=0.5, label=category)
    
    # Plot reference data if provided
    if reference_geojson and os.path.exists(reference_geojson):
        ref_gdf = gpd.read_file(reference_geojson)
        ref_gdf.boundary.plot(ax=ax, color='black', linewidth=1, alpha=0.5)
    
    ax.set_xlabel('Longitude')
    ax.set_ylabel('Latitude')
    ax.set_title('Extracted Broadband Speed Polygons - Cleveland, OH')
    ax.legend(title='Broadband Speed')
    
    plt.tight_layout()
    plt.savefig('cleveland_broadband_full.png', dpi=300, bbox_inches='tight')
    
    # Create a zoomed-in view specifically for Cleveland research area
    fig2, ax2 = plt.subplots(figsize=(15, 12))
    
    # Plot each category with its proper color
    for category in categories:
        cat_data = gdf[gdf['speed_category'] == category]
        color = speed_color_map.get(category, '#FFFFFF')
        cat_data.plot(ax=ax2, color=color, alpha=0.7, edgecolor='black', linewidth=0.5, label=category)
    
    # Plot reference data if provided
    if reference_geojson and os.path.exists(reference_geojson):
        ref_gdf = gpd.read_file(reference_geojson)
        ref_gdf.boundary.plot(ax=ax2, color='black', linewidth=1, alpha=0.5)
    
    # Set limits to Cleveland research area
    ax2.set_xlim(CLEVELAND_BBOX['west'], CLEVELAND_BBOX['east'])
    ax2.set_ylim(CLEVELAND_BBOX['south'], CLEVELAND_BBOX['north'])
    
    # Add grid for better reference
    ax2.grid(True, linestyle='--', alpha=0.6)
    
    ax2.set_xlabel('Longitude')
    ax2.set_ylabel('Latitude')
    ax2.set_title('Cleveland Research Area - Broadband Speeds')
    ax2.legend(title='Broadband Speed', loc='upper right')
    
    plt.tight_layout()
    plt.savefig('cleveland_research_area.png', dpi=300, bbox_inches='tight')
    
    # Display both figures
    plt.show()

def main():
    try:
        # Get paths
        print("This script processes a map image without the legend")
        
        # Option to generate the cropped image first
        generate_crop = input("Do you want to crop the map first? (y/n, default: n): ").lower() or "n"
        if generate_crop == "y":
            import subprocess
            subprocess.run(["python", "scripts/crop_map_no_legend.py"])
            print("\nContinuing with the newly cropped map...\n")
        
        # Get image path
        image_path = input("Enter path to cropped map image (default: map_no_legend.png): ") or "map_no_legend.png"
        
        # Check if the image exists
        if not os.path.exists(image_path):
            print(f"Error: Image not found at {image_path}")
            return
        
        # Get color config
        config_path = input("Enter path to color config (default: sampled_colors.json): ") or "sampled_colors.json"
        
        # If color config doesn't exist, use default
        if not os.path.exists(config_path):
            print(f"Warning: Config not found at {config_path}, using default colors")
            color_config = {
                '0-9 Mbps': {'color': [187, 17, 34], 'hex': '#bb1122'},      # Red
                '10-24 Mbps': {'color': [255, 123, 0], 'hex': '#ff7b00'},    # Orange
                '25-49 Mbps': {'color': [221, 221, 85], 'hex': '#dddd55'},   # Yellow-green
                '50-100 Mbps': {'color': [89, 144, 59], 'hex': '#59903b'},   # Light green
                '100+ Mbps': {'color': [14, 140, 14], 'hex': '#0e8c0e'}      # Dark green
            }
        else:
            # Load color config
            color_config = load_color_config(config_path)
        
        # Get output path
        output_path = input("Enter output GeoJSON path (default: cleveland_broadband_speeds_no_legend.geojson): ") or "cleveland_broadband_speeds_no_legend.geojson"
        
        # Get reference path
        reference_path = input("Enter reference GeoJSON path (optional, press Enter to skip): ")
        
        # Load the image
        image = load_image(image_path)
        if image is None:
            return
        
        # Get tolerance
        tolerance_str = input("Enter color tolerance (default: 50): ") or "50"
        tolerance = int(tolerance_str)
        
        # Process the image
        masks = detect_broadband_regions(image, color_config, tolerance)
        
        # Convert to polygons
        polygons = masks_to_polygons(masks, image.shape)
        
        if not polygons:
            print("No polygons were detected. Try adjusting the tolerance or color values.")
            return
        
        # Georeference
        geo_polygons = georeference_polygons(polygons, CLEVELAND_BBOX)
        
        # Create GeoJSON
        gdf = create_geojson(geo_polygons, output_path)
        
        # Print summary
        print("\nSummary:")
        print(f"Total polygons: {len(gdf)}")
        
        categories = set(gdf['speed_category'])
        for category in categories:
            count = len(gdf[gdf['speed_category'] == category])
            print(f"  {category}: {count} polygons")
        
        # Visualize results
        visualize_results(gdf, reference_path if reference_path else None)
        
        print(f"\nBroadband speed polygons saved to: {output_path}")
        print("You can now load this file in QGIS or any GIS software.")
    
    except Exception as e:
        print(f"An error occurred: {str(e)}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main() 