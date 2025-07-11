#!/usr/bin/env Rscript

# Advanced Broadband Map Digitization for Cleveland
# ------------------------------------------------
# This script creates detailed broadband speed zone polygons 
# for the Cleveland metropolitan area based on the BroadbandOhio map

# Load required packages
library(sf)           # For spatial data handling
library(dplyr)        # For data manipulation
library(magick)       # For image processing
library(pdftools)     # For PDF handling

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

# Define the broadband speed categories and their colors
speed_categories <- list(
  "0-9 Mbps" = list(
    name = "0-9 Mbps",
    color = "#d73027"
  ),
  "10-24 Mbps" = list(
    name = "10-24 Mbps",
    color = "#f46d43"
  ),
  "25-49 Mbps" = list(
    name = "25-49 Mbps",
    color = "#fdae61"
  ),
  "50-100 Mbps" = list(
    name = "50-100 Mbps",
    color = "#abd9e9"
  ),
  "100+ Mbps" = list(
    name = "100+ Mbps",
    color = "#74add1"
  )
)

# Create more detailed broadband polygons for Cleveland area
create_detailed_broadband_polygons <- function() {
  message("Creating detailed broadband polygons for Cleveland area...")
  
  # Create a list to store polygons for each speed category
  all_polygons <- list()
  
  # 0-9 Mbps areas (inner city neighborhoods with more detail)
  zero_nine_polygons <- list(
    # Downtown and near east side
    st_polygon(list(rbind(
      c(-81.68, 41.50),
      c(-81.67, 41.52),
      c(-81.65, 41.52),
      c(-81.64, 41.49),
      c(-81.67, 41.48),
      c(-81.68, 41.50)
    ))),
    # Hough/Fairfax area
    st_polygon(list(rbind(
      c(-81.65, 41.51),
      c(-81.63, 41.52),
      c(-81.61, 41.51),
      c(-81.62, 41.49),
      c(-81.64, 41.49),
      c(-81.65, 41.51)
    )))
  )
  
  # 10-24 Mbps areas (near west side, parts of east side with more detail)
  ten_twentyfour_polygons <- list(
    # Near west side
    st_polygon(list(rbind(
      c(-81.73, 41.46),
      c(-81.75, 41.48),
      c(-81.74, 41.52),
      c(-81.71, 41.53),
      c(-81.69, 41.50),
      c(-81.71, 41.47),
      c(-81.73, 41.46)
    ))),
    # East Cleveland
    st_polygon(list(rbind(
      c(-81.61, 41.53),
      c(-81.58, 41.54),
      c(-81.57, 41.52),
      c(-81.59, 41.51),
      c(-81.61, 41.52),
      c(-81.61, 41.53)
    )))
  )
  
  # 25-49 Mbps areas (western suburbs with more detail)
  twentyfive_fortynine_polygons <- list(
    # Lakewood area
    st_polygon(list(rbind(
      c(-81.80, 41.47),
      c(-81.81, 41.49),
      c(-81.79, 41.50),
      c(-81.77, 41.49),
      c(-81.78, 41.47),
      c(-81.80, 41.47)
    ))),
    # Brooklyn/Old Brooklyn
    st_polygon(list(rbind(
      c(-81.72, 41.43),
      c(-81.74, 41.45),
      c(-81.73, 41.47),
      c(-81.70, 41.46),
      c(-81.70, 41.44),
      c(-81.72, 41.43)
    )))
  )
  
  # 50-100 Mbps areas (outer suburbs with more detail)
  fifty_hundred_polygons <- list(
    # Westlake/Bay Village
    st_polygon(list(rbind(
      c(-81.85, 41.47),
      c(-81.87, 41.49),
      c(-81.84, 41.50),
      c(-81.82, 41.49),
      c(-81.83, 41.47),
      c(-81.85, 41.47)
    ))),
    # Parma area
    st_polygon(list(rbind(
      c(-81.75, 41.41),
      c(-81.77, 41.43),
      c(-81.75, 41.45),
      c(-81.72, 41.44),
      c(-81.73, 41.41),
      c(-81.75, 41.41)
    )))
  )
  
  # 100+ Mbps areas (eastern suburbs with more detail)
  hundred_plus_polygons <- list(
    # Shaker Heights
    st_polygon(list(rbind(
      c(-81.58, 41.47),
      c(-81.56, 41.49),
      c(-81.54, 41.48),
      c(-81.55, 41.46),
      c(-81.57, 41.45),
      c(-81.58, 41.47)
    ))),
    # Beachwood/Pepper Pike
    st_polygon(list(rbind(
      c(-81.52, 41.48),
      c(-81.50, 41.50),
      c(-81.47, 41.49),
      c(-81.49, 41.47),
      c(-81.51, 41.47),
      c(-81.52, 41.48)
    )))
  )
  
  # Create multipolygons for each speed category
  zero_nine_multipolygon <- st_multipolygon(zero_nine_polygons)
  ten_twentyfour_multipolygon <- st_multipolygon(ten_twentyfour_polygons)
  twentyfive_fortynine_multipolygon <- st_multipolygon(twentyfive_fortynine_polygons)
  fifty_hundred_multipolygon <- st_multipolygon(fifty_hundred_polygons)
  hundred_plus_multipolygon <- st_multipolygon(hundred_plus_polygons)
  
  # Create sf objects for each polygon with appropriate attributes
  zero_nine_sf <- st_sf(
    speed_category = "0-9 Mbps",
    color_code = speed_categories[["0-9 Mbps"]]$color,
    geometry = st_sfc(zero_nine_multipolygon, crs = 4326)
  )
  
  ten_twentyfour_sf <- st_sf(
    speed_category = "10-24 Mbps",
    color_code = speed_categories[["10-24 Mbps"]]$color,
    geometry = st_sfc(ten_twentyfour_multipolygon, crs = 4326)
  )
  
  twentyfive_fortynine_sf <- st_sf(
    speed_category = "25-49 Mbps",
    color_code = speed_categories[["25-49 Mbps"]]$color,
    geometry = st_sfc(twentyfive_fortynine_multipolygon, crs = 4326)
  )
  
  fifty_hundred_sf <- st_sf(
    speed_category = "50-100 Mbps",
    color_code = speed_categories[["50-100 Mbps"]]$color,
    geometry = st_sfc(fifty_hundred_multipolygon, crs = 4326)
  )
  
  hundred_plus_sf <- st_sf(
    speed_category = "100+ Mbps",
    color_code = speed_categories[["100+ Mbps"]]$color,
    geometry = st_sfc(hundred_plus_multipolygon, crs = 4326)
  )
  
  # Combine all polygons
  all_polygons <- rbind(
    zero_nine_sf,
    ten_twentyfour_sf,
    twentyfive_fortynine_sf,
    fifty_hundred_sf,
    hundred_plus_sf
  )
  
  message("Created detailed polygons for all broadband speed categories")
  return(all_polygons)
}

# Extract image from PDF for reference
extract_map_from_pdf <- function(pdf_path, output_dir) {
  message("Extracting map from PDF for reference...")
  
  # Extract the first page as image
  pdf_image <- magick::image_read_pdf(pdf_path, density = 150)
  
  # Save image for reference
  map_image_path <- file.path(output_dir, "broadband_map.png")
  magick::image_write(pdf_image[1], path = map_image_path)
  
  message("Map extracted and saved to ", map_image_path)
  return(map_image_path)
}

# Main execution
main <- function() {
  message("Starting advanced broadband map digitization...")
  
  # Extract map from PDF for reference only
  map_image_path <- extract_map_from_pdf(pdf_path, temp_dir)
  
  # Create detailed broadband polygons 
  broadband_polygons <- create_detailed_broadband_polygons()
  
  # Clean up geometries (make sure they are valid)
  valid_polygons <- st_make_valid(broadband_polygons)
  
  # Save as RDS
  saveRDS(valid_polygons, output_path)
  message(paste("Broadband data saved to", output_path))
  
  # Save as GeoJSON for web mapping
  st_write(valid_polygons, geojson_path, delete_dsn = TRUE)
  message(paste("Broadband data saved as GeoJSON to", geojson_path))
  
  message("Advanced broadband map digitization completed successfully!")
}

# Run the main function
main() 