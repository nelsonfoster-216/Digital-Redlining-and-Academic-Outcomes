# Test script for geocoding schools
library(dplyr)
library(googleway)
library(leaflet)

# API key
api_key <- "AIzaSyB_ip5GH1NY6QDon-CE3CJOthgsOX3HB04"
set_key(key = api_key)

# Load the fixed dataset
schools_file <- "~/digital_redlining/plot/output/cleveland_schools_fixed.rds"
if(file.exists(schools_file)) {
  schools <- readRDS(schools_file)
  print(paste("Loaded", nrow(schools), "schools"))
  
  # Get the school name column
  name_col <- grep("School.*Name|SchoolName", colnames(schools), value = TRUE)[1]
  print(paste("School name column:", name_col))
  
  # Create a new dataset to store geocoded results
  geocoded_schools <- schools[1:5, ]
  
  # Add geocoding columns
  geocoded_schools$geo_lat <- NA_real_
  geocoded_schools$geo_lng <- NA_real_
  geocoded_schools$geo_address <- NA_character_
  geocoded_schools$SyntheticCoords <- TRUE
  
  # Cleveland coordinates
  cleveland_lat <- 41.49932
  cleveland_lng <- -81.69436
  
  # Try geocoding the first 5 schools
  for(i in 1:nrow(geocoded_schools)) {
    school_name <- geocoded_schools[[name_col]][i]
    print(paste("Geocoding school:", school_name))
    
    # Clean the name
    search_name <- gsub(" School$", "", school_name)
    search_query <- paste(search_name, "School, Cleveland, OH")
    
    # Call the Places API
    print(paste("Search query:", search_query))
    tryCatch({
      # First try searching for the school by name
      places_result <- google_places(
        search_string = search_query,
        location = c(cleveland_lat, cleveland_lng),
        radius = 50000
      )
      
      print("Places API response:")
      print(places_result$status)
      
      if(places_result$status == "OK" && nrow(places_result$results) > 0) {
        print(paste("Found", nrow(places_result$results), "places"))
        
        # Get the first result
        place <- places_result$results[1,]
        
        # The location is in a nested data frame, we need to extract it properly
        location_df <- place$geometry$location
        
        # Print the location data frame
        print("Location data frame:")
        print(location_df)
        
        # Extract coordinates directly from the nested data frame
        lat <- as.numeric(location_df[1, "lat"])
        lng <- as.numeric(location_df[1, "lng"])
        address <- as.character(place$formatted_address)
        
        print(paste("Coordinates:", lat, lng))
        print(paste("Address:", address))
        
        # Store the geocoded data
        geocoded_schools$geo_lat[i] <- lat
        geocoded_schools$geo_lng[i] <- lng
        geocoded_schools$geo_address[i] <- address
        geocoded_schools$SyntheticCoords[i] <- FALSE
      } else {
        print("No results found or invalid response")
      }
    }, error = function(e) {
      print(paste("Error:", e$message))
    })
    
    # Add a delay between API calls
    Sys.sleep(1)
  }
  
  # Update coordinates in the dataset
  geocoded_schools <- geocoded_schools %>%
    mutate(
      Latitude = ifelse(!is.na(geo_lat), geo_lat, Latitude),
      Longitude = ifelse(!is.na(geo_lng), geo_lng, Longitude)
    )
  
  # Create a simple map
  map <- leaflet(geocoded_schools) %>%
    addProviderTiles(providers$CartoDB.Positron) %>%
    addCircleMarkers(
      lng = ~Longitude,
      lat = ~Latitude,
      radius = 6,
      color = ~ifelse(SyntheticCoords, "red", "green"),
      popup = ~paste0(
        "<strong>", geocoded_schools[[name_col]], "</strong><br>",
        "Coordinates: ", round(Latitude, 4), ", ", round(Longitude, 4)
      )
    )
  
  # Save the map and geocoded data
  htmlwidgets::saveWidget(map, "test_geocoded_map.html", selfcontained = TRUE)
  saveRDS(geocoded_schools, "test_geocoded_schools.rds")
  
  print("Test completed. Map saved to test_geocoded_map.html")
} else {
  print("Could not find the schools dataset")
} 