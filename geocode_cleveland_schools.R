# Simplified Geocoding Script for Cleveland Schools
# This script uses the Google Places API to find schools in Cleveland
# and saves their coordinates to a geocoded dataset

# Load required libraries
library(dplyr)
library(googleway) # For Google Maps API
library(leaflet)   # For mapping
library(htmlwidgets)

# Set your Google Maps API key
api_key <- "AIzaSyB_ip5GH1NY6QDon-CE3CJOthgsOX3HB04"

# Register the API key with googleway
set_key(key = api_key)

# Check if API key is valid
if(api_key == "AIzaSyB_ip5GH1NY6QDon-CE3CJOthgsOX3HB04") {
  stop("Please set your Google Maps API key before running this script.")
}

# Step 1: Load the existing Cleveland schools dataset
print("Loading existing Cleveland schools dataset...")
try({
  # Try loading the fixed dataset if it exists
  if(file.exists("~/digital_redlining/plot/output/cleveland_schools_fixed.rds")) {
    schools_data <- readRDS("~/digital_redlining/plot/output/cleveland_schools_fixed.rds")
    print("Loaded the fixed dataset.")
  } else {
    # Fall back to the original consolidated dataset
    schools_data <- readRDS("~/digital_redlining/plot/output/cleveland_schools_consolidated.rds")
    print("Loaded the original dataset.")
  }
  
  print(paste("Working with", nrow(schools_data), "schools."))
})

# Ensure we have the school name column
name_col <- grep("School.*Name|SchoolName", colnames(schools_data), value = TRUE)[1]

if(is.na(name_col)) {
  stop("Could not find a school name column in the dataset.")
}

# Add geocoding columns if they don't exist
if(!"geo_lat" %in% colnames(schools_data)) {
  schools_data$geo_lat <- NA_real_
}
if(!"geo_lng" %in% colnames(schools_data)) {
  schools_data$geo_lng <- NA_real_
}
if(!"geo_address" %in% colnames(schools_data)) {
  schools_data$geo_address <- NA_character_
}
if(!"SyntheticCoords" %in% colnames(schools_data)) {
  schools_data$SyntheticCoords <- TRUE
}

# Step 2: Use Google Places API to find schools in Cleveland
print("Using Google Places API to find schools in Cleveland...")
# Cleveland coordinates (center of the city)
cleveland_lat <- 41.49932
cleveland_lng <- -81.69436

# Limit how many schools to process (adjust as needed)
max_schools <- 105  # Changed from 20 to 105 to process all schools
schools_to_process <- min(nrow(schools_data), max_schools)

print(paste("Will process", schools_to_process, "schools for demonstration purposes."))

# Process each school
geocoded_count <- 0
for(i in 1:schools_to_process) {
  # Get the school name
  school_name <- schools_data[[name_col]][i]
  print(paste("Geocoding school", i, "of", schools_to_process, ":", school_name))
  
  # Clean the name (remove "School" if it's already in the name)
  search_name <- gsub(" School$", "", school_name)
  search_query <- paste(search_name, "School, Cleveland, OH")
  
  # Search for the school
  tryCatch({
    # Call the Places API
    places_result <- google_places(
      search_string = search_query,
      location = c(cleveland_lat, cleveland_lng),
      radius = 50000  # 50km radius
    )
    
    # Check if we got valid results
    if(places_result$status == "OK" && nrow(places_result$results) > 0) {
      # Get the first result
      place <- places_result$results[1,]
      
      # The location is in a nested data frame, we need to extract it properly
      location_df <- place$geometry$location
      
      # Extract coordinates directly from the nested data frame
      lat <- as.numeric(location_df[1, "lat"])
      lng <- as.numeric(location_df[1, "lng"])
      address <- as.character(place$formatted_address)
      
      print(paste("Found:", 
                 "lat =", lat, 
                 "lng =", lng, 
                 "address =", address))
      
      # Store the geocoded data
      schools_data$geo_lat[i] <- lat
      schools_data$geo_lng[i] <- lng
      schools_data$geo_address[i] <- address
      schools_data$SyntheticCoords[i] <- FALSE
      geocoded_count <- geocoded_count + 1
    } else {
      print(paste("No valid results for:", search_query))
    }
  }, error = function(e) {
    print(paste("Error searching for", school_name, ":", e$message))
  })
  
  # Add a delay to avoid hitting API rate limits
  Sys.sleep(0.5)
}

print(paste("Successfully geocoded", geocoded_count, "of", schools_to_process, "schools."))

# Step 3: Update the dataset with the new geocoded coordinates
print("Updating dataset with geocoded coordinates...")
schools_data <- schools_data %>%
  mutate(
    # Only update coordinates where geocoding succeeded
    Latitude = ifelse(!is.na(geo_lat), geo_lat, Latitude),
    Longitude = ifelse(!is.na(geo_lng), geo_lng, Longitude),
    # Update address if we got a better one from Google
    Address = ifelse(!is.na(geo_address), geo_address, 
                     ifelse("Address" %in% colnames(schools_data), Address, NA))
  )

# Step 4: Save the updated dataset
print("Saving updated dataset...")
saveRDS(schools_data, "~/digital_redlining/plot/output/cleveland_schools_geocoded.rds")

# Step 5: Create a map to visualize the geocoded schools
print("Creating map to visualize geocoded schools...")
# Create a map highlighting which schools were successfully geocoded
map <- leaflet(schools_data) %>%
  addProviderTiles(providers$CartoDB.Positron) %>%
  addCircleMarkers(
    lng = ~Longitude,
    lat = ~Latitude,
    radius = 6,
    color = ~ifelse(SyntheticCoords, "red", "green"),
    fillColor = ~ifelse(SyntheticCoords, "pink", "lightgreen"),
    fillOpacity = 0.8,
    popup = ~paste0(
      "<strong>", schools_data[[name_col]], "</strong><br>",
      ifelse(!is.na(Address), paste0("Address: ", Address, "<br>"), ""),
      "Coordinates: ", round(Latitude, 4), ", ", round(Longitude, 4), "<br>",
      ifelse(SyntheticCoords, 
             "<span style='color:red;'><b>SYNTHETIC COORDINATES</b></span>", 
             "<span style='color:green;'><b>GEOCODED COORDINATES</b></span>")
    ),
    label = ~schools_data[[name_col]]
  ) %>%
  addLegend(
    position = "bottomright",
    colors = c("green", "red"),
    labels = c("Geocoded Coordinates", "Synthetic Coordinates"),
    title = "Coordinate Source"
  ) %>%
  addControl(
    html = paste(
      "<strong>Cleveland Schools Map</strong><br>",
      "Total schools:", nrow(schools_data), "<br>",
      "Geocoded schools:", sum(!schools_data$SyntheticCoords, na.rm = TRUE), "<br>",
      "<span style='color:red;'>NOTE: This is a demo with limited API calls.</span>"
    ),
    position = "topright"
  )

# Save the map
saveWidget(map, "~/digital_redlining/plot/output/cleveland_schools_geocoded_map.html", selfcontained = TRUE)

print("Map saved to ~/digital_redlining/plot/output/cleveland_schools_geocoded_map.html")
print("Geocoding process complete!")

# Automatically update the R Markdown file
update_rmd_dataset <- function() {
  rmd_file <- "~/digital_redlining/digital_redlining_eda.Rmd"
  
  if(!file.exists(rmd_file)) {
    stop("R Markdown file not found at:", rmd_file)
  }
  
  # Read the R Markdown file
  rmd_lines <- readLines(rmd_file)
  
  # Find the enhanced_map code chunk
  map_chunk_start <- grep("```\\{r enhanced_map", rmd_lines)
  
  if(length(map_chunk_start) > 0) {
    # Find where the dataset is loaded
    load_dataset_line <- grep("cleveland_schools_data <-", rmd_lines)
    
    # Update the dataset loading code
    if(length(load_dataset_line) > 0) {
      # Find the data loading section
      dataset_section_start <- load_dataset_line[1]
      dataset_section_end <- dataset_section_start
      
      # Find where this section ends
      while(dataset_section_end < length(rmd_lines) && 
            !grepl("^```", rmd_lines[dataset_section_end])) {
        dataset_section_end <- dataset_section_end + 1
      }
      
      # Create the new code to load datasets
      new_code <- c(
        "# First try to load the geocoded dataset, falling back to alternatives",
        "geocoded_path <- \"~/digital_redlining/plot/output/cleveland_schools_geocoded.rds\"",
        "fixed_data_path <- \"~/digital_redlining/plot/output/cleveland_schools_fixed.rds\"",
        "original_data_path <- \"~/digital_redlining/plot/output/cleveland_schools_consolidated.rds\"",
        "",
        "if (file.exists(geocoded_path)) {",
        "  cleveland_schools_data <- readRDS(geocoded_path)",
        "  using_geocoded_data <- TRUE",
        "  cat(\"Using the geocoded Cleveland schools dataset with actual coordinates\\n\")",
        "} else if (file.exists(fixed_data_path)) {",
        "  cleveland_schools_data <- readRDS(fixed_data_path)",
        "  using_geocoded_data <- FALSE",
        "  using_fixed_data <- TRUE",
        "  cat(\"Using the fixed Cleveland schools dataset with synthetic coordinates\\n\")",
        "} else {",
        "  cleveland_schools_data <- readRDS(original_data_path)",
        "  using_geocoded_data <- FALSE",
        "  using_fixed_data <- FALSE",
        "  cat(\"Using the original Cleveland schools dataset (note: geocoding may be inaccurate)\\n\")",
        "}"
      )
      
      # Replace the section with our new code
      rmd_lines <- c(
        rmd_lines[1:(dataset_section_start-1)],
        new_code,
        rmd_lines[dataset_section_end:length(rmd_lines)]
      )
      
      # Write the updated file
      writeLines(rmd_lines, rmd_file)
      print("Updated R Markdown file to use the geocoded dataset.")
    } else {
      print("Could not find the dataset loading code in the R Markdown file.")
    }
  } else {
    print("Could not find the enhanced_map chunk in the R Markdown file.")
  }
}

# Run the update function
update_rmd_dataset()

print("R Markdown file has been updated to use the geocoded dataset.")
print("Now you can render the R Markdown file to use the geocoded data.") 