#!/usr/bin/env Rscript

# Automated Broadband Map Image Processing
# This script extracts broadband speed zones from an image of the map
# using color-based segmentation

# Load required packages
library(magick)      # For image processing
library(sf)          # For spatial data handling
library(raster)      # For raster to vector conversion
library(dplyr)       # For data manipulation

# Disable S2 spherical geometry for more lenient processing
sf::sf_use_s2(FALSE)
message("Disabled S2 spherical geometry for more lenient geometry processing")

# Set paths
input_image <- "broadband_map.png"      # The screenshot of the broadband map
output_path <- "cleveland_broadband_data.rds"  # Output RDS file

# Cleveland approximate bounding box coordinates (WGS84)
cleveland_bbox <- c(
  xmin = -81.968,  # Western boundary
  ymin = 41.184,   # Southern boundary 
  xmax = -81.484,  # Eastern boundary
  ymax = 41.627    # Northern boundary
)

# Define the color-to-speed mapping based on the broadband map in the screenshot
# These ranges need to be calibrated for the specific screenshot
speed_colors <- list(
  "0-9 Mbps" = list(
    color = "#d73027",
    rgb_range = list(
      r = c(180, 255),
      g = c(20, 80),
      b = c(20, 80)
    )
  ),
  "10-24 Mbps" = list(
    color = "#f46d43",
    rgb_range = list(
      r = c(200, 255),
      g = c(80, 130),
      b = c(30, 80)
    )
  ),
  "25-49 Mbps" = list(
    color = "#fdae61",
    rgb_range = list(
      r = c(200, 255),
      g = c(150, 200),
      b = c(60, 120)
    )
  ),
  "50-100 Mbps" = list(
    color = "#abd9e9",
    rgb_range = list(
      r = c(120, 200),
      g = c(190, 240),
      b = c(190, 240)
    )
  ),
  "100+ Mbps" = list(
    color = "#74add1",
    rgb_range = list(
      r = c(80, 150),
      g = c(150, 200),
      b = c(170, 230)
    )
  )
)

# Function to preprocess the image before extraction
preprocess_image <- function(img) {
  # Resize to a reasonable size if needed
  img <- image_resize(img, "1200x")
  
  # Enhance contrast
  img <- image_contrast(img, sharpen = 1.2)
  
  # Remove roads (black lines) by replacing them with nearby colors
  # This is a simplification - actual road removal would be more complex
  roads_mask <- image_threshold(img, "black", type = "black")
  
  # Dilate to capture all road pixels
  roads_mask <- image_morphology(roads_mask, "dilate", "diamond:1")
  
  # Create a version with roads filled
  img_no_roads <- image_fill(img, color = "none", fuzz = 20, 
                             x_off = 0, y_off = 0, refcolor = "black")
  
  return(img_no_roads)
}

# Function to extract polygons for a specific speed category
extract_speed_polygons <- function(img, speed_category, rgb_range) {
  message(paste("Extracting polygons for", speed_category, "..."))
  
  # Create a mask for the specified color range
  mask <- image_threshold(img, 
                         threshold = paste0(
                           rgb_range$r[1], ",", rgb_range$r[2], ",",
                           rgb_range$g[1], ",", rgb_range$g[2], ",",
                           rgb_range$b[1], ",", rgb_range$b[2]
                         ), 
                         type = "range")
  
  # Clean up the mask - remove small noise areas
  mask <- image_morphology(mask, "close", "octagon:3")
  mask <- image_morphology(mask, "open", "octagon:2")
  
  # Save the mask temporarily
  mask_file <- paste0("temp_mask_", gsub(" ", "_", speed_category), ".tif")
  image_write(mask, path = mask_file, format = "tiff")
  
  # Read the mask as a raster
  r <- raster(mask_file)
  
  # Convert the binary raster to polygons with simplification
  polys <- rasterToPolygons(r, dissolve = TRUE)
  
  # Convert to sf object
  polys_sf <- st_as_sf(polys)
  
  # Filter out very small polygons (likely noise)
  polys_sf <- polys_sf %>%
    mutate(area = st_area(geometry)) %>%
    filter(as.numeric(area) > 100) %>%
    select(-area)
  
  # If no polygons remain, return empty sf object
  if(nrow(polys_sf) == 0) {
    message(paste("No significant polygons found for", speed_category))
    return(NULL)
  }
  
  # Add speed category and color
  polys_sf$speed_category <- speed_category
  polys_sf$color_code <- speed_colors[[speed_category]]$color
  
  # Remove temporary file
  file.remove(mask_file)
  
  return(polys_sf)
}

# Function to georeference the extracted polygons
georeference_polygons <- function(polygons_sf) {
  message("Georeferencing polygons...")
  
  # Get the extent of the polygons
  poly_bbox <- st_bbox(polygons_sf)
  
  # Calculate transformation parameters
  x_scale <- (cleveland_bbox["xmax"] - cleveland_bbox["xmin"]) / (poly_bbox["xmax"] - poly_bbox["xmin"])
  y_scale <- (cleveland_bbox["ymax"] - cleveland_bbox["ymin"]) / (poly_bbox["ymax"] - poly_bbox["ymin"])
  
  x_offset <- cleveland_bbox["xmin"] - poly_bbox["xmin"] * x_scale
  y_offset <- cleveland_bbox["ymin"] - poly_bbox["ymin"] * y_scale
  
  # Transform each polygon using standard sf operations
  transformed_polygons <- polygons_sf
  
  # Apply manual transformation to each geometry
  for (i in 1:nrow(transformed_polygons)) {
    # Extract coordinates
    coords <- st_coordinates(transformed_polygons$geometry[i])
    
    # Transform coordinates
    coords[, "X"] <- coords[, "X"] * x_scale + x_offset
    coords[, "Y"] <- coords[, "Y"] * y_scale + y_offset
    
    # Reconstruct the geometry
    if (inherits(transformed_polygons$geometry[i], "POLYGON")) {
      transformed_polygons$geometry[i] <- st_polygon(list(coords[, c("X", "Y")]))
    } else if (inherits(transformed_polygons$geometry[i], "MULTIPOLYGON")) {
      # Handle multipolygons by splitting by L1 value
      l1_values <- unique(coords[, "L1"])
      parts <- lapply(l1_values, function(l) {
        l_coords <- coords[coords[, "L1"] == l, c("X", "Y")]
        return(l_coords)
      })
      transformed_polygons$geometry[i] <- st_multipolygon(list(parts))
    }
  }
  
  # Set the CRS
  st_crs(transformed_polygons) <- 4326
  
  return(transformed_polygons)
}

# Main execution
if(!file.exists(output_path)) {
  # Check if the input image exists
  if(!file.exists(input_image)) {
    stop("Input image not found. Please provide a screenshot of the broadband map.")
  }
  
  message("Loading the broadband map image...")
  img <- image_read(input_image)
  
  # Preprocess the image
  img_no_roads <- preprocess_image(img)
  
  # Extract polygons for each speed category
  all_polygons <- list()
  
  for(speed_cat in names(speed_colors)) {
    speed_polygons <- extract_speed_polygons(
      img_no_roads, 
      speed_cat, 
      speed_colors[[speed_cat]]$rgb_range
    )
    
    # Only add to list if polygons were found
    if(!is.null(speed_polygons) && nrow(speed_polygons) > 0) {
      all_polygons[[speed_cat]] <- speed_polygons
    }
  }
  
  # Check if we found any polygons
  if(length(all_polygons) == 0) {
    stop("No polygons were extracted. Please check the image and color ranges.")
  }
  
  # Combine all polygons
  broadband_data <- do.call(rbind, all_polygons)
  
  # Georeference the polygons
  broadband_data <- georeference_polygons(broadband_data)
  
  # Clean up polygons (simplify, fix topology issues)
  broadband_data <- st_make_valid(broadband_data)
  broadband_data <- st_simplify(broadband_data, dTolerance = 0.0001)
  
  # Save the result
  saveRDS(broadband_data, output_path)
  message(paste("Broadband data saved to", output_path))
  
  # Also save as GeoJSON for easier viewing
  geojson_path <- "cleveland_broadband_data.geojson"
  st_write(broadband_data, geojson_path, delete_dsn = TRUE)
  message(paste("Broadband data also saved as GeoJSON to", geojson_path))
} else {
  message(paste("Broadband data already exists at", output_path))
  message("To reprocess, delete the existing file and run this script again.")
}

message("Image processing script completed.") 