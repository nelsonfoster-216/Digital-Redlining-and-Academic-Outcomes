# Cleveland Schools Map - Detailed Version
# This script creates a detailed map to verify geocoding and saves it as an HTML file

# Load required libraries
library(leaflet)
library(dplyr)
library(htmlwidgets)

# Load the consolidated dataset
cleveland_schools <- readRDS("~/digital_redlining/plot/output/cleveland_schools_consolidated.rds")

# Print information about the dataset
print(paste("Number of schools in dataset:", nrow(cleveland_schools)))

# Examine the data to determine if we have the expected number of schools
# Cleveland typically has around 100-150 schools, not 93,600
if (nrow(cleveland_schools) > 200) {
  print("WARNING: Dataset appears to contain too many schools (93,600).")
  print("This likely indicates a data issue. Attempting to filter or sample the data...")
  
  # Check if we can filter to just Cleveland schools
  if ("DistrictIRN" %in% colnames(cleveland_schools) && "DistrictName" %in% colnames(cleveland_schools)) {
    print("Filtering to only keep Cleveland Municipal School District records...")
    cleveland_schools <- cleveland_schools %>%
      filter(DistrictIRN == "043786" | 
             DistrictName == "Cleveland Municipal School District")
    
    print(paste("After filtering, number of schools:", nrow(cleveland_schools)))
  }
  
  # If still too many, take a reasonable sample
  if (nrow(cleveland_schools) > 200) {
    print("Still too many schools, sampling first 150 records...")
    cleveland_schools <- head(cleveland_schools, 150)
  }
}

# Check for geocoding pattern issues
default_coords <- cleveland_schools %>%
  summarize(
    default_count = sum(Latitude == 41.4993 & Longitude == -81.6944, na.rm = TRUE),
    unique_lat_count = n_distinct(Latitude, na.rm = TRUE),
    unique_lon_count = n_distinct(Longitude, na.rm = TRUE)
  )

print(paste("Schools with default coordinates:", default_coords$default_count))
print(paste("Number of unique latitude values:", default_coords$unique_lat_count))
print(paste("Number of unique longitude values:", default_coords$unique_lon_count))

# If all schools have the same coordinates, there's a problem
if (default_coords$unique_lat_count <= 1 || default_coords$unique_lon_count <= 1) {
  print("ERROR: All schools have identical coordinates. Geocoding has not been properly applied.")
  
  # Let's create some synthetic coordinates for demonstration purposes
  print("Creating synthetic coordinates for demonstration...")
  set.seed(42)  # For reproducibility
  
  # Create a random spread of points around Cleveland
  cleveland_schools <- cleveland_schools %>%
    mutate(
      # Add small random offsets to create a spread of points
      Latitude = 41.4993 + runif(n(), -0.07, 0.07),
      Longitude = -81.6944 + runif(n(), -0.07, 0.07),
      # Flag to indicate these are synthetic coordinates
      is_synthetic = TRUE
    )
  
  print("Created synthetic coordinates centered on Cleveland.")
} else {
  # Add a flag for schools with default coordinates
  cleveland_schools <- cleveland_schools %>%
    mutate(
      is_default_coords = (Latitude == 41.4993 & Longitude == -81.6944),
      is_synthetic = FALSE
    )
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

# Create popup content
if(!is.null(school_name_col) && !is.null(school_irn_col)) {
  cleveland_schools$popup_content <- paste0(
    "<strong>", cleveland_schools[[school_name_col]], "</strong><br>",
    "IRN: ", cleveland_schools[[school_irn_col]], "<br>",
    ifelse(cleveland_schools$is_synthetic, 
           "<span style='color:red;'><b>SYNTHETIC COORDINATES</b></span>", 
           ifelse(cleveland_schools$is_default_coords, 
                  "<span style='color:orange;'><b>DEFAULT COORDINATES</b></span>", 
                  "<span style='color:green;'><b>UNIQUE COORDINATES</b></span>"))
  )
} else {
  cleveland_schools$popup_content <- paste0(
    "School #", 1:nrow(cleveland_schools), "<br>",
    ifelse(cleveland_schools$is_synthetic, 
           "<span style='color:red;'><b>SYNTHETIC COORDINATES</b></span>", 
           ifelse(cleveland_schools$is_default_coords, 
                  "<span style='color:orange;'><b>DEFAULT COORDINATES</b></span>", 
                  "<span style='color:green;'><b>UNIQUE COORDINATES</b></span>"))
  )
}

# Create the map
map <- leaflet(cleveland_schools) %>%
  addProviderTiles(providers$CartoDB.Positron) %>%  # Nice, clean basemap
  addCircleMarkers(
    lng = ~Longitude,
    lat = ~Latitude,
    radius = 8,
    color = ~ifelse(is_synthetic, "red", 
                  ifelse(is_default_coords, "orange", "green")),
    fillColor = ~ifelse(is_synthetic, "pink", 
                      ifelse(is_default_coords, "yellow", "lightgreen")),
    fillOpacity = 0.7,
    popup = ~popup_content,
    label = ~if(!is.null(school_name_col)) get(school_name_col) else paste("School", 1:n())
  ) %>%
  addLegend(
    position = "bottomright",
    colors = c("green", "orange", "red"),
    labels = c("Unique Coordinates", "Default Coordinates", "Synthetic Coordinates"),
    title = "Geocoding Status"
  ) %>%
  addControl(
    html = paste(
      "<strong>Cleveland Schools Map</strong><br>",
      "Total schools:", nrow(cleveland_schools), "<br>"
    ),
    position = "topright"
  )

# Save the map as an HTML file
output_path <- "~/digital_redlining/plot/output/cleveland_schools_map.html"
saveWidget(map, output_path, selfcontained = TRUE)

print(paste("Map saved to:", output_path))

# Return the map object
map 