#!/usr/bin/env Rscript

# Simplified Broadband Map Image Processing
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
speed_colors <- list(
  "0-9 Mbps" = list(
    color = "#d73027",
    r_range = c(180, 255),
    g_range = c(20, 80),
    b_range = c(20, 80)
  ),
  "10-24 Mbps" = list(
    color = "#f46d43",
    r_range = c(200, 255),
    g_range = c(80, 130),
    b_range = c(30, 80)
  ),
  "25-49 Mbps" = list(
    color = "#fdae61",
    r_range = c(200, 255),
    g_range = c(150, 200),
    b_range = c(60, 120)
  ),
  "50-100 Mbps" = list(
    color = "#abd9e9",
    r_range = c(120, 200),
    g_range = c(190, 240),
    b_range = c(190, 240)
  ),
  "100+ Mbps" = list(
    color = "#74add1",
    r_range = c(80, 150),
    g_range = c(150, 200),
    b_range = c(170, 230)
  )
)

# Check if the input image exists
if(!file.exists(input_image)) {
  stop("Input image not found. Please provide a screenshot of the broadband map.")
}

message("Loading the broadband map image...")
img <- image_read(input_image)

# Resize to a reasonable size if needed
img <- image_resize(img, "1200x")

# Extract polygons for each speed category
all_polygons <- list()

for(speed_cat in names(speed_colors)) {
  message(paste("Extracting polygons for", speed_cat, "..."))
  
  # Convert percentage ranges to absolute values (0-255)
  r_range <- speed_colors[[speed_cat]]$r_range
  g_range <- speed_colors[[speed_cat]]$g_range
  b_range <- speed_colors[[speed_cat]]$b_range
  
  # Create a colored mask image
  color_mask <- image_blank(width = image_width(img), 
                           height = image_height(img), 
                           color = "black")
  
  # Draw on the color mask for comparison
  color_mask <- image_colorize(color_mask, opacity = 100, 
                             color = speed_colors[[speed_cat]]$color)
  
  # Use image comparison to find similar colors
  # Note: this is a simplified approach - in a real implementation you might
  # need more sophisticated color matching
  mask <- image_compare(img, color_mask, metric = "rmse", fuzz = 30)
  
  # Threshold the comparison result - using type=black here
  mask <- image_threshold(mask, threshold = "50%", type = "black")
  
  # Clean up the mask to remove noise
  mask <- image_morphology(mask, "close", "octagon:3")
  mask <- image_morphology(mask, "open", "octagon:2")
  
  # Save the mask temporarily
  mask_file <- paste0("temp_mask_", gsub(" ", "_", speed_cat), ".tif")
  image_write(mask, path = mask_file, format = "tiff")
  
  # Read the mask as a raster
  r <- raster(mask_file)
  
  # Convert the binary raster to polygons
  polys <- try(rasterToPolygons(r, dissolve = TRUE))
  
  if(!inherits(polys, "try-error") && !is.null(polys)) {
    # Convert to sf object
    polys_sf <- st_as_sf(polys)
    
    # Add speed category and color
    polys_sf$speed_category <- speed_cat
    polys_sf$color_code <- speed_colors[[speed_cat]]$color
    
    # Add to the list
    all_polygons[[speed_cat]] <- polys_sf
    
    message(paste("Found", nrow(polys_sf), "polygons for", speed_cat))
  } else {
    message(paste("No polygons found for", speed_cat))
  }
  
  # Remove temporary file
  if(file.exists(mask_file)) {
    file.remove(mask_file)
  }
}

# Check if we found any polygons
if(length(all_polygons) == 0) {
  stop("No polygons were extracted. Please check the image and color ranges.")
}

# Combine all polygons
broadband_data <- do.call(rbind, all_polygons)

# Transform to geographic coordinates
message("Transforming to geographic coordinates...")
# Get the extent of the polygons
poly_bbox <- st_bbox(broadband_data)

# Calculate transformation parameters
x_scale <- (cleveland_bbox["xmax"] - cleveland_bbox["xmin"]) / (poly_bbox["xmax"] - poly_bbox["xmin"])
y_scale <- (cleveland_bbox["ymax"] - cleveland_bbox["ymin"]) / (poly_bbox["ymax"] - poly_bbox["ymin"])

x_offset <- cleveland_bbox["xmin"] - poly_bbox["xmin"] * x_scale
y_offset <- cleveland_bbox["ymin"] - poly_bbox["ymin"] * y_scale

# Transform each polygon manually
transformed_polygons <- broadband_data
for (i in 1:nrow(transformed_polygons)) {
  # Get coordinates
  coords <- st_coordinates(transformed_polygons$geometry[i])
  
  # Transform coordinates
  coords[, "X"] <- coords[, "X"] * x_scale + x_offset
  coords[, "Y"] <- coords[, "Y"] * y_scale + y_offset
  
  # Reconstruct the geometry
  if (inherits(transformed_polygons$geometry[i], "POLYGON")) {
    transformed_polygons$geometry[i] <- st_polygon(list(coords[, c("X", "Y")]))
  } else {
    # Handle multipolygons - simplify by taking the first part
    transformed_polygons$geometry[i] <- st_polygon(list(coords[, c("X", "Y")]))
  }
}

# Set CRS
st_crs(transformed_polygons) <- 4326

# Save the result
saveRDS(transformed_polygons, output_path)
message(paste("Broadband data saved to", output_path))

# Also save as GeoJSON for easier viewing
geojson_path <- "cleveland_broadband_data.geojson"
st_write(transformed_polygons, geojson_path, delete_dsn = TRUE)
message(paste("Broadband data also saved as GeoJSON to", geojson_path))

message("Image processing completed successfully!") 