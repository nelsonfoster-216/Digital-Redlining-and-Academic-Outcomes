# Cleveland Schools Map
# Simple map to verify geocoding is working

# Load required libraries
library(leaflet)
library(dplyr)

# Load the consolidated dataset
cleveland_schools <- readRDS("~/digital_redlining/plot/output/cleveland_schools_consolidated.rds")

# Display the first few rows and column names to verify data is loaded
print("Column names in the dataset:")
print(colnames(cleveland_schools))
print(paste("Number of schools:", nrow(cleveland_schools)))

# Check if we have geocoding data
has_lat_long <- all(c("Latitude", "Longitude") %in% colnames(cleveland_schools))
print(paste("Has Latitude/Longitude columns:", has_lat_long))

# Summary of latitude and longitude values
if(has_lat_long) {
  print("Latitude summary:")
  print(summary(cleveland_schools$Latitude))
  print("Longitude summary:")
  print(summary(cleveland_schools$Longitude))
  
  # Count how many schools have the default Cleveland coordinates
  default_coords <- sum(cleveland_schools$Latitude == 41.4993 & 
                       cleveland_schools$Longitude == -81.6944, na.rm = TRUE)
  print(paste("Schools with default Cleveland coordinates:", default_coords))
}

# Function to find a valid column name in the dataset
find_column <- function(possible_names) {
  for(name in possible_names) {
    if(name %in% colnames(cleveland_schools)) {
      return(name)
    }
  }
  return(NULL)
}

# Find school name and IRN columns
school_name_col <- find_column(c("SchoolName", "School_Name", "Name"))
school_irn_col <- find_column(c("SchoolIRN", "School_IRN", "IRN"))

# Create a simple leaflet map
if(has_lat_long) {
  # Create popup content with school name and IRN
  if(!is.null(school_name_col) && !is.null(school_irn_col)) {
    popup_content <- paste0(
      "<strong>", cleveland_schools[[school_name_col]], "</strong><br>",
      "IRN: ", cleveland_schools[[school_irn_col]]
    )
  } else {
    # Simple row number as label if no name/IRN found
    popup_content <- paste0("School #", 1:nrow(cleveland_schools))
  }
  
  # Create the map
  map <- leaflet(cleveland_schools) %>%
    addTiles() %>%  # Add default OpenStreetMap tiles
    addCircleMarkers(
      lng = ~Longitude,
      lat = ~Latitude,
      radius = 8,
      color = "blue",
      fillColor = "lightblue",
      fillOpacity = 0.7,
      popup = popup_content,
      label = ~if(!is.null(school_name_col)) get(school_name_col) else as.character(1:nrow(cleveland_schools))
    ) %>%
    addControl(
      html = paste(
        "Total schools:", nrow(cleveland_schools), "<br>",
        "Schools with default coordinates:", default_coords
      ),
      position = "bottomright"
    )
  
  # Print message about map
  print("Map created successfully. View it by running 'map'")
  
  # Return the map object
  map
} else {
  print("ERROR: Latitude and Longitude columns not found in the dataset.")
} 