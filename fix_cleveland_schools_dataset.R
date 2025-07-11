# Fix Cleveland Schools Dataset
# This script fixes the consolidated dataset issues with duplicate records and geocoding

# Load required libraries
library(dplyr)
library(readxl)

# Step 1: Load the original Building Details datasets which should contain school info
print("Loading original datasets...")
try({
  Building_Details_Report_23_24 <- read_excel("~/digital_redlining/plot/datasets/23-24 Building Details Report.xlsx", 
                                            sheet = "Building_Details")
  
  Building_Details_Report_22_23 <- read_excel("~/digital_redlining/plot/datasets/22-23 Building Details Report.xlsx", 
                                            sheet = "Building_Details")
})

# Step 2: Filter to Cleveland schools only
print("Filtering to Cleveland schools only...")
try({
  # Check column names to find the District IRN column
  print("Column names in 23-24 dataset:")
  print(colnames(Building_Details_Report_23_24))
  
  # Find IRN columns
  district_irn_col <- grep("District.*IRN|DistrictIRN", colnames(Building_Details_Report_23_24), value = TRUE)[1]
  school_irn_col <- grep("School.*IRN|SchoolIRN|Building.*IRN", colnames(Building_Details_Report_23_24), value = TRUE)[1]
  
  # Filter to Cleveland (IRN = 043786)
  Cleveland_Schools_23_24 <- Building_Details_Report_23_24 %>%
    filter(get(district_irn_col) == "043786")
  
  print(paste("Found", nrow(Cleveland_Schools_23_24), "Cleveland schools in 23-24 dataset"))
})

# Step 3: Check if there are geocoding columns
print("Checking for geocoding columns...")
try({
  # Look for latitude/longitude columns
  lat_cols <- grep("lat|Lat", colnames(Cleveland_Schools_23_24), ignore.case = TRUE, value = TRUE)
  lon_cols <- grep("lon|Long", colnames(Cleveland_Schools_23_24), ignore.case = TRUE, value = TRUE)
  
  print("Potential latitude columns:")
  print(lat_cols)
  print("Potential longitude columns:")
  print(lon_cols)
  
  # Check if we have address columns for geocoding
  address_cols <- grep("Address|Street", colnames(Cleveland_Schools_23_24), ignore.case = TRUE, value = TRUE)
  city_cols <- grep("City", colnames(Cleveland_Schools_23_24), ignore.case = TRUE, value = TRUE)
  state_cols <- grep("State", colnames(Cleveland_Schools_23_24), ignore.case = TRUE, value = TRUE)
  zip_cols <- grep("Zip|Postal", colnames(Cleveland_Schools_23_24), ignore.case = TRUE, value = TRUE)
  
  print("Address columns:")
  print(c(address_cols, city_cols, state_cols, zip_cols))
})

# Step 4: Create a proper consolidated dataset
print("Creating properly consolidated dataset...")
try({
  # Select relevant columns - adjust these based on available columns
  selected_cols <- c(
    school_irn_col,  # School IRN
    grep("School.*Name|SchoolName", colnames(Cleveland_Schools_23_24), value = TRUE)[1],  # School Name
    district_irn_col,  # District IRN
    grep("District.*Name|DistrictName", colnames(Cleveland_Schools_23_24), value = TRUE)[1],  # District Name
    grep("Type", colnames(Cleveland_Schools_23_24), value = TRUE)[1]  # School Type if available
  )
  
  # Add address columns if available
  if(length(address_cols) > 0) selected_cols <- c(selected_cols, address_cols[1])
  if(length(city_cols) > 0) selected_cols <- c(selected_cols, city_cols[1])
  if(length(state_cols) > 0) selected_cols <- c(selected_cols, state_cols[1])
  if(length(zip_cols) > 0) selected_cols <- c(selected_cols, zip_cols[1])
  
  # Add geocoding columns if available
  has_geocoding <- FALSE
  if(length(lat_cols) > 0 && length(lon_cols) > 0) {
    selected_cols <- c(selected_cols, lat_cols[1], lon_cols[1])
    has_geocoding <- TRUE
  }
  
  # Create base dataset
  fixed_cleveland_schools <- Cleveland_Schools_23_24 %>%
    select(all_of(selected_cols))
  
  # Rename columns for consistency
  renamed_cols <- c(
    "SchoolIRN" = school_irn_col,
    "SchoolName" = grep("School.*Name|SchoolName", colnames(Cleveland_Schools_23_24), value = TRUE)[1],
    "DistrictIRN" = district_irn_col,
    "DistrictName" = grep("District.*Name|DistrictName", colnames(Cleveland_Schools_23_24), value = TRUE)[1]
  )
  
  # Add type column if found
  if(length(grep("Type", colnames(Cleveland_Schools_23_24), value = TRUE)) > 0) {
    renamed_cols <- c(renamed_cols, 
                     "SchoolType" = grep("Type", colnames(Cleveland_Schools_23_24), value = TRUE)[1])
  }
  
  # Add geocoding columns if found
  if(has_geocoding) {
    renamed_cols <- c(renamed_cols, 
                     "Latitude" = lat_cols[1],
                     "Longitude" = lon_cols[1])
  }
  
  # Rename the columns
  fixed_cleveland_schools <- fixed_cleveland_schools %>%
    rename(!!!renamed_cols)
  
  # Add missing geocoding with generated coordinates
  if(!has_geocoding) {
    print("No geocoding columns found. Creating synthetic coordinates...")
    set.seed(123)  # For reproducibility
    
    # Create a grid pattern centered on Cleveland
    n_schools <- nrow(fixed_cleveland_schools)
    grid_size <- ceiling(sqrt(n_schools))
    
    # Create the grid indices
    row_indices <- rep(1:grid_size, each = grid_size)[1:n_schools]
    col_indices <- rep(1:grid_size, times = grid_size)[1:n_schools]
    
    # Create coordinates with small spacing between schools
    fixed_cleveland_schools <- fixed_cleveland_schools %>%
      mutate(
        Latitude = 41.4993 + (row_indices - grid_size/2) * 0.002,
        Longitude = -81.6944 + (col_indices - grid_size/2) * 0.002,
        SyntheticCoords = TRUE
      )
  } else {
    fixed_cleveland_schools <- fixed_cleveland_schools %>%
      mutate(SyntheticCoords = FALSE)
  }
})

# Step 5: Save the fixed dataset
print("Saving fixed dataset...")
try({
  # Create directory if it doesn't exist
  dir.create("~/digital_redlining/plot/output", recursive = TRUE, showWarnings = FALSE)
  
  # Save the fixed dataset
  saveRDS(fixed_cleveland_schools, "~/digital_redlining/plot/output/cleveland_schools_fixed.rds")
  
  print(paste("Fixed dataset saved with", nrow(fixed_cleveland_schools), "Cleveland schools"))
  print("Column names in fixed dataset:")
  print(colnames(fixed_cleveland_schools))
})

# Step 6: Create a simple map of the fixed dataset
print("Creating map of fixed dataset...")
try({
  library(leaflet)
  library(htmlwidgets)
  
  # Create a simple map
  map <- leaflet(fixed_cleveland_schools) %>%
    addProviderTiles(providers$CartoDB.Positron) %>%
    addCircleMarkers(
      lng = ~Longitude,
      lat = ~Latitude,
      radius = 8,
      color = ifelse(fixed_cleveland_schools$SyntheticCoords, "red", "green"),
      fillColor = ifelse(fixed_cleveland_schools$SyntheticCoords, "pink", "lightgreen"),
      fillOpacity = 0.7,
      popup = paste0(
        "<strong>", fixed_cleveland_schools$SchoolName, "</strong><br>",
        "IRN: ", fixed_cleveland_schools$SchoolIRN, "<br>",
        ifelse(fixed_cleveland_schools$SyntheticCoords, 
               "<span style='color:red;'><b>SYNTHETIC COORDINATES</b></span>", 
               "<span style='color:green;'><b>ACTUAL COORDINATES</b></span>")
      ),
      label = ~SchoolName
    ) %>%
    addLegend(
      position = "bottomright",
      colors = c("green", "red"),
      labels = c("Actual Coordinates", "Synthetic Coordinates"),
      title = "Geocoding Status"
    )
  
  # Save the map
  saveWidget(map, "~/digital_redlining/plot/output/cleveland_schools_fixed_map.html", selfcontained = TRUE)
  
  print("Fixed map saved to ~/digital_redlining/plot/output/cleveland_schools_fixed_map.html")
}) 