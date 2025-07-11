#!/usr/bin/env Rscript

# Digitize Broadband Data from PDF
# This script will help digitize broadband speed zones from the PDF map

# Load required packages
library(magick)  # For image processing
library(sf)      # For spatial data handling
library(leaflet) # For interactive mapping
library(mapedit) # For interactive map editing
library(dplyr)   # For data manipulation

# Disable S2 spherical geometry (which can be strict with geometry validity)
sf::sf_use_s2(FALSE)
message("Disabled S2 spherical geometry for more lenient geometry processing")

# Set paths
pdf_path <- "Cuyahoga County_BBOH.pdf"
output_path <- "cleveland_broadband_data.rds"

# Convert PDF to image for processing
message("Converting PDF to image...")
pdf_image <- magick::image_read_pdf(pdf_path, density = 300)
# Write temporary image file
temp_image_path <- "temp_broadband_map.png"
magick::image_write(pdf_image, path = temp_image_path)
message("PDF converted to image and saved as:", temp_image_path)

# Create Cleveland boundary
message("Creating a bounding box for the Cleveland area...")

# Cleveland approximate bounding box coordinates (WGS84)
# These coordinates encompass the greater Cleveland area
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
}, error = function(e) {
  message("Error creating Cleveland boundary: ", e$message)
  stop("Could not create Cleveland boundary. Please check the coordinates.")
})

# Interactive digitization function
digitize_broadband_zones <- function(cleveland_boundary) {
  library(mapedit)
  library(leaflet)
  
  # Create base map for digitization
  base_map <- leaflet() %>%
    addProviderTiles("CartoDB.Positron") %>%
    addPolygons(data = cleveland_boundary, 
                color = "red", weight = 2, fill = FALSE) %>%
    setView(lng = -81.7, lat = 41.5, zoom = 12)
  
  # Show the PDF image as a reference
  message("Opening the PDF image for reference...")
  system(paste("open", temp_image_path))
  
  message("\nINSTRUCTIONS:")
  message("1. Look at the opened PDF image to see the broadband zones")
  message("2. Use the drawing tools in the interactive map to digitize each zone")
  message("3. For each polygon you draw, add the speed category in the properties")
  message("4. Use these speed categories: '0-9 Mbps', '10-24 Mbps', '25-49 Mbps', '50-100 Mbps', '100+ Mbps'")
  message("5. Once you've digitized all zones, click 'Done' to save\n")
  
  # Interactive polygon creation
  cat("Starting interactive map editor... (this may take a moment)\n")
  broadband_polygons <- editMap(base_map)
  
  return(broadband_polygons)
}

# Process digitized data
process_broadband_data <- function(digitized_data) {
  # Extract the drawn features
  features <- digitized_data$finished
  
  # Check if we have data
  if(length(features) == 0) {
    stop("No polygons were digitized.")
  }
  
  # Extract properties from each feature
  extracted_props <- lapply(features$properties, function(props) {
    if(is.null(props$speed_category)) {
      return(list(speed_category = "Unknown"))
    } else {
      return(list(speed_category = props$speed_category))
    }
  })
  
  # Create a data frame with the properties
  props_df <- do.call(rbind.data.frame, extracted_props)
  
  # Add color codes based on speed category
  props_df$color_code <- case_when(
    props_df$speed_category == "0-9 Mbps" ~ "#d73027",
    props_df$speed_category == "10-24 Mbps" ~ "#f46d43",
    props_df$speed_category == "25-49 Mbps" ~ "#fdae61",
    props_df$speed_category == "50-100 Mbps" ~ "#abd9e9",
    props_df$speed_category == "100+ Mbps" ~ "#74add1",
    TRUE ~ "#999999"
  )
  
  # Convert features to SF object
  broadband_sf <- st_as_sf(features) %>%
    cbind(props_df)
  
  # Set proper CRS
  broadband_sf <- st_transform(broadband_sf, 4326)
  
  return(broadband_sf)
}

# Main execution
if(!file.exists(output_path)) {
  message("Starting broadband zone digitization...")
  # Run the digitization process
  digitized_data <- digitize_broadband_zones(cleveland_boundary)
  broadband_data <- process_broadband_data(digitized_data)
  
  # Save the result
  saveRDS(broadband_data, output_path)
  message(paste("Broadband data saved to", output_path))
} else {
  message(paste("Broadband data already exists at", output_path))
  message("To redigitize, delete the existing file and run this script again.")
}

# Cleanup
if(file.exists(temp_image_path)) {
  file.remove(temp_image_path)
}

message("Digitization script completed.") 