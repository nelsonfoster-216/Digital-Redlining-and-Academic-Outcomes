#!/usr/bin/env Rscript

# Script to check the generated broadband polygons

# Load required packages
library(sf)
library(dplyr)

# Path to the GeoJSON file
geojson_path <- "broadband_cleveland.geojson"

# Function to check the GeoJSON file
check_geojson <- function(file_path) {
  # Check if file exists
  if (!file.exists(file_path)) {
    message("ERROR: GeoJSON file does not exist at ", file_path)
    return(FALSE)
  }
  
  # Try to read the file
  tryCatch({
    # Read the GeoJSON
    polygons <- sf::st_read(file_path, quiet = TRUE)
    
    # Check if we have any features
    if (nrow(polygons) == 0) {
      message("WARNING: GeoJSON file exists but contains no features")
      return(FALSE)
    }
    
    # Print summary
    cat("\nGeoJSON File Summary:\n")
    cat("====================\n")
    cat("File:", file_path, "\n")
    cat("Total polygons:", nrow(polygons), "\n")
    
    # Count by speed category
    if ("speed_category" %in% names(polygons)) {
      cat("\nPolygons by Speed Category:\n")
      speed_counts <- table(polygons$speed_category)
      for (speed in names(speed_counts)) {
        cat(sprintf("  %s: %d polygons\n", speed, speed_counts[speed]))
      }
    } else {
      cat("\nWARNING: No 'speed_category' attribute found in polygons\n")
    }
    
    # Calculate total area by speed category
    if ("speed_category" %in% names(polygons)) {
      cat("\nApproximate Area by Speed Category:\n")
      polygons$area <- sf::st_area(polygons)
      area_by_category <- aggregate(polygons$area, by=list(Category=polygons$speed_category), FUN=sum)
      for (i in 1:nrow(area_by_category)) {
        cat(sprintf("  %s: %.2f sq km\n", area_by_category$Category[i], as.numeric(area_by_category$x[i]) / 1000000))
      }
    }
    
    return(TRUE)
  }, error = function(e) {
    message("ERROR reading GeoJSON file: ", e$message)
    return(FALSE)
  })
}

# Check the GeoJSON file
check_geojson(geojson_path) 