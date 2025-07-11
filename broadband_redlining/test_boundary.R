#!/usr/bin/env Rscript

# Simple script to test Cleveland boundary creation
message("Starting simple test script...")

# Load required packages
library(sf)

# Disable S2 spherical geometry 
sf::sf_use_s2(FALSE)
message("Disabled S2 spherical geometry")

# Cleveland approximate bounding box coordinates (WGS84)
message("Creating a bounding box for the Cleveland area...")
cleveland_bbox <- c(
  xmin = -81.968,  # Western boundary
  ymin = 41.184,   # Southern boundary 
  xmax = -81.484,  # Eastern boundary
  ymax = 41.627    # Northern boundary
)

# Create a simple rectangular boundary for Cleveland
tryCatch({
  # Create a polygon from the bounding box
  cleveland_boundary <- sf::st_as_sfc(sf::st_bbox(cleveland_bbox, crs = 4326))
  message("Cleveland boundary created successfully.")
  message("Boundary bounding box: ", paste(sf::st_bbox(cleveland_boundary), collapse=", "))
}, error = function(e) {
  message("Error creating Cleveland boundary: ", e$message)
})

message("Test script completed.") 