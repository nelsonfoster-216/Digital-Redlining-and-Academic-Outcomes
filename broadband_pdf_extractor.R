#!/usr/bin/env Rscript

# Automated Broadband Map Extraction from PDF
# ----------------------------------------------
# This script:
# 1. Extracts map image from PDF
# 2. Identifies color regions from the legend
# 3. Segments the image by color to identify speed zones
# 4. Vectorizes these zones into polygons
# 5. Georeferences them to match existing spatial data
# 6. Outputs a GeoJSON file ready for integration

# Load required packages
library(magick)      # For image processing
library(sf)          # For spatial data handling
library(raster)      # For raster to vector conversion
library(dplyr)       # For data manipulation
library(pdftools)    # For PDF handling

# Set paths
pdf_path <- "Cuyahoga County_BBOH.pdf"
output_path <- "cleveland_broadband_data.rds"
geojson_path <- "cleveland_broadband_data.geojson"
temp_dir <- "temp_extraction"

# Create temp directory if needed
if(!dir.exists(temp_dir)) {
  dir.create(temp_dir)
}

# Disable S2 spherical geometry for more lenient processing
sf::sf_use_s2(FALSE)
message("Disabled S2 spherical geometry for more lenient geometry processing")

# Cleveland approximate bounding box coordinates (WGS84)
cleveland_bbox <- c(
  xmin = -81.968,  # Western boundary
  ymin = 41.184,   # Southern boundary 
  xmax = -81.484,  # Eastern boundary
  ymax = 41.627    # Northern boundary
)

# Define the known broadband speed categories and their colors
# These are standard colors from the map legend
speed_categories <- list(
  "0-9 Mbps" = list(
    name = "0-9 Mbps",
    color = "#d73027",
    rgb = c(215, 48, 39),  # Dark red
    tolerance = 30
  ),
  "10-24 Mbps" = list(
    name = "10-24 Mbps",
    color = "#f46d43", 
    rgb = c(244, 109, 67), # Orange
    tolerance = 30
  ),
  "25-49 Mbps" = list(
    name = "25-49 Mbps",
    color = "#fdae61",
    rgb = c(253, 174, 97), # Yellow/tan
    tolerance = 30
  ),
  "50-100 Mbps" = list(
    name = "50-100 Mbps",
    color = "#abd9e9",
    rgb = c(171, 217, 233), # Light blue
    tolerance = 35
  ),
  "100+ Mbps" = list(
    name = "100+ Mbps",
    color = "#74add1",
    rgb = c(116, 173, 209), # Darker blue
    tolerance = 30
  )
)

# Function to extract the map from PDF
extract_map_from_pdf <- function(pdf_path, output_dir) {
  message("Extracting map from PDF...")
  
  # Extract the first page as high-resolution image
  pdf_image <- magick::image_read_pdf(pdf_path, density = 300) 
  
  # Save original image for reference
  original_image_path <- file.path(output_dir, "original_pdf_image.png")
  magick::image_write(pdf_image[1], path = original_image_path)
  
  # Try to identify and crop just the map area
  # This is approximate - may need manual adjustment
  img <- pdf_image[1]
  
  # Enhance the image for better processing
  img <- magick::image_modulate(img, brightness = 105, saturation = 120)
  
  # Save the processed map image
  map_image_path <- file.path(output_dir, "broadband_map.png")
  magick::image_write(img, path = map_image_path)
  
  message("Map extracted and saved to ", map_image_path)
  return(map_image_path)
}

# Function to create color masks for each speed category
create_color_masks <- function(image_path, output_dir, speed_categories) {
  message("Creating color masks for each speed category...")
  
  # Load the map image
  img <- magick::image_read(image_path)
  
  # Create a mask for each speed category
  mask_paths <- list()
  
  for(cat_name in names(speed_categories)) {
    cat_info <- speed_categories[[cat_name]]
    message(paste("Processing category:", cat_name))
    
    # Convert RGB values to percentage of full range (0-255)
    rgb_values <- cat_info$rgb
    r_pct <- round(rgb_values[1] / 255 * 100)
    g_pct <- round(rgb_values[2] / 255 * 100)
    b_pct <- round(rgb_values[3] / 255 * 100)
    
    # Create mask by color similarity with tolerance
    # First create a solid color image of the target color
    target_color <- magick::image_blank(
      width = magick::image_info(img)$width,
      height = magick::image_info(img)$height,
      color = cat_info$color
    )
    
    # Compare the map with the target color image
    diff_img <- magick::image_compare(img, target_color, metric = "rmse", fuzz = cat_info$tolerance)
    
    # Threshold the difference image to create a binary mask
    mask <- magick::image_threshold(diff_img, "white", "20%")
    
    # Clean up the mask to remove noise and fill small gaps
    mask <- magick::image_morphology(mask, "close", "octagon:3")
    mask <- magick::image_morphology(mask, "open", "octagon:2")
    
    # Save the mask
    mask_path <- file.path(output_dir, paste0("mask_", gsub(" ", "_", cat_name), ".tif"))
    magick::image_write(mask, path = mask_path, format = "tiff")
    
    mask_paths[[cat_name]] <- mask_path
  }
  
  return(mask_paths)
}

# Function to vectorize color masks into polygons
vectorize_masks <- function(mask_paths, speed_categories) {
  message("Vectorizing masks into polygons...")
  
  all_polygons <- list()
  
  for(cat_name in names(mask_paths)) {
    mask_path <- mask_paths[[cat_name]]
    message(paste("Vectorizing", cat_name))
    
    # Read the mask as a raster
    r <- raster::raster(mask_path)
    
    # Set all values > 0 to 1 (binary mask)
    r[r > 0] <- 1
    
    # Convert the raster to polygons
    tryCatch({
      polys <- raster::rasterToPolygons(r, dissolve = TRUE)
      
      # Convert to sf object
      if(!is.null(polys) && length(polys) > 0) {
        polys_sf <- sf::st_as_sf(polys)
        
        # Filter out very small polygons (likely noise)
        polys_sf <- polys_sf %>%
          dplyr::mutate(area = sf::st_area(geometry)) %>%
          dplyr::filter(as.numeric(area) > 1000) %>%  # Area threshold in pixels
          dplyr::select(-area)
        
        # Add attributes
        if(nrow(polys_sf) > 0) {
          polys_sf$speed_category <- cat_name
          polys_sf$color_code <- speed_categories[[cat_name]]$color
          
          all_polygons[[cat_name]] <- polys_sf
          message(paste("Found", nrow(polys_sf), "polygons for", cat_name))
        } else {
          message(paste("No significant polygons found for", cat_name))
        }
      }
    }, error = function(e) {
      message(paste("Error vectorizing", cat_name, ":", e$message))
    })
  }
  
  # Combine all polygons if any were found
  if(length(all_polygons) > 0) {
    combined_polygons <- do.call(rbind, all_polygons)
    return(combined_polygons)
  } else {
    stop("No polygons were successfully vectorized.")
  }
}

# Function to georeference the vectorized polygons
georeference_polygons <- function(polygons, target_bbox) {
  message("Georeferencing polygons...")
  
  # Get the bounding box of the extracted polygons (in pixel coordinates)
  poly_bbox <- sf::st_bbox(polygons)
  
  # Calculate transformation parameters
  x_scale <- (target_bbox["xmax"] - target_bbox["xmin"]) / (poly_bbox["xmax"] - poly_bbox["xmin"])
  y_scale <- (target_bbox["ymax"] - target_bbox["ymin"]) / (poly_bbox["ymax"] - poly_bbox["ymin"])
  
  x_offset <- target_bbox["xmin"] - poly_bbox["xmin"] * x_scale
  y_offset <- target_bbox["ymin"] - poly_bbox["ymin"] * y_scale
  
  # Transform each polygon manually
  transformed_polygons <- polygons
  
  for (i in 1:nrow(transformed_polygons)) {
    # Extract coordinates
    coords <- sf::st_coordinates(transformed_polygons$geometry[i])
    
    # Transform coordinates
    coords[, "X"] <- coords[, "X"] * x_scale + x_offset
    coords[, "Y"] <- coords[, "Y"] * y_scale + y_offset
    
    # Reconstruct the geometry
    if(inherits(transformed_polygons$geometry[i], "POLYGON")) {
      transformed_polygons$geometry[i] <- sf::st_polygon(list(coords[, c("X", "Y")]))
    } else if(inherits(transformed_polygons$geometry[i], "MULTIPOLYGON")) {
      # Simplified approach: convert multipolygons to single polygons
      # For more complex cases, we'd need to handle the L1/L2 structure
      l1_values <- unique(coords[, "L1"])
      parts <- lapply(l1_values, function(l) {
        l_coords <- coords[coords[, "L1"] == l, c("X", "Y")]
        return(l_coords)
      })
      transformed_polygons$geometry[i] <- sf::st_multipolygon(list(parts))
    }
  }
  
  # Set CRS
  sf::st_crs(transformed_polygons) <- 4326
  
  return(transformed_polygons)
}

# Main execution
message("Starting automatic extraction of broadband data from PDF...")

# Extract map from PDF
map_image_path <- extract_map_from_pdf(pdf_path, temp_dir)

# Create color masks for each speed category
mask_paths <- create_color_masks(map_image_path, temp_dir, speed_categories)

# Vectorize the masks into polygons
broadband_polygons <- vectorize_masks(mask_paths, speed_categories)

# Georeference the polygons
georeferenced_polygons <- georeference_polygons(broadband_polygons, cleveland_bbox)

# Clean up the geometries
valid_polygons <- sf::st_make_valid(georeferenced_polygons)
simplified_polygons <- sf::st_simplify(valid_polygons, dTolerance = 0.0001)

# Save the result as RDS
saveRDS(simplified_polygons, output_path)
message(paste("Broadband data saved to", output_path))

# Save as GeoJSON for easier viewing/integration
sf::st_write(simplified_polygons, geojson_path, delete_dsn = TRUE)
message(paste("Broadband data saved as GeoJSON to", geojson_path))

message("Extraction and vectorization completed successfully!")

# Optionally clean up temporary files
# unlink(temp_dir, recursive = TRUE) 