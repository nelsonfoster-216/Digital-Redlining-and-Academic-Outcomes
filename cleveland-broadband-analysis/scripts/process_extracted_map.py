#!/usr/bin/env python3
"""
Script to process the already extracted map image with corrected colors
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
    'west': -81.82,
    'east': -81.55,
    'south': 41.39,
    'north': 41.60
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
    # Default colors if needed
    color_map = {
        '0-9 Mbps': '#FF0000',
        '10-24 Mbps': '#FFA500',
        '25-49 Mbps': '#FFFF00',
        '50-100 Mbps': '#90EE90',
        '100+ Mbps': '#008000'
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
    if reference_geojson and os.path.exists(reference_geojson):
        ref_gdf = gpd.read_file(reference_geojson)
        ref_gdf.boundary.plot(ax=ax, color='black', linewidth=1, alpha=0.5)
    
    ax.set_xlabel('Longitude')
    ax.set_ylabel('Latitude')
    ax.set_title('Extracted Broadband Speed Polygons - Cleveland, OH')
    
    plt.tight_layout()
    plt.show()

def main():
    try:
        # Get paths
        print("This script processes an already extracted map image using the correct colors")
        
        # Get image path
        image_path = input("Enter path to extracted map image (default: extracted_map.png): ") or "extracted_map.png"
        
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
                '0-9 Mbps': {'color': [204, 0, 0], 'hex': '#CC0000'},
                '10-24 Mbps': {'color': [255, 127, 0], 'hex': '#FF7F00'},
                '25-49 Mbps': {'color': [255, 255, 0], 'hex': '#FFFF00'},
                '50-100 Mbps': {'color': [127, 201, 127], 'hex': '#7FC97F'},
                '100+ Mbps': {'color': [0, 114, 0], 'hex': '#007200'}
            }
        else:
            # Load color config
            color_config = load_color_config(config_path)
        
        # Get output path
        output_path = input("Enter output GeoJSON path (default: cleveland_broadband_speeds.geojson): ") or "cleveland_broadband_speeds.geojson"
        
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