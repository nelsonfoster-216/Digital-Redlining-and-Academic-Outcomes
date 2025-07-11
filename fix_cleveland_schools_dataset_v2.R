# Fix Cleveland Schools Dataset (Version 2)
# This script fixes the consolidated dataset issues with duplicate records and geocoding

# Load required libraries
library(dplyr)
library(readxl)
library(leaflet)
library(htmlwidgets)

# Function to safely extract matching column names
safe_grep <- function(pattern, column_names, default = NULL) {
  matches <- grep(pattern, column_names, ignore.case = TRUE, value = TRUE)
  if(length(matches) > 0) {
    return(matches[1])  # Return the first match
  } else {
    return(default)  # Return the default value if no match
  }
}

# Step 1: Load the original Building Details dataset
print("Loading original datasets...")
try({
  Building_Details_Report_23_24 <- read_excel("~/digital_redlining/plot/datasets/23-24 Building Details Report.xlsx", 
                                            sheet = "Building_Details")
})

# Step 2: Filter to Cleveland schools only
print("Filtering to Cleveland schools only...")
try({
  # Check column names to find the District IRN column
  print("Column names in dataset:")
  print(colnames(Building_Details_Report_23_24))
  
  # Find IRN columns (with fallbacks)
  district_irn_col <- safe_grep("District.*IRN|DistrictIRN", colnames(Building_Details_Report_23_24), "District IRN")
  school_irn_col <- safe_grep("School.*IRN|SchoolIRN|Building.*IRN", colnames(Building_Details_Report_23_24), "Building IRN")
  
  print(paste("Using District IRN column:", district_irn_col))
  print(paste("Using School IRN column:", school_irn_col))
  
  # Filter to Cleveland (IRN = 043786)
  Cleveland_Schools <- Building_Details_Report_23_24 %>%
    filter(get(district_irn_col) == "043786")
  
  print(paste("Found", nrow(Cleveland_Schools), "Cleveland schools in dataset"))
  
  # Filter to unique school records if needed
  if(nrow(Cleveland_Schools) > 200) {
    print("Too many schools found, likely due to duplicate records. Filtering to unique schools...")
    Cleveland_Schools <- Cleveland_Schools %>%
      distinct(!!sym(school_irn_col), .keep_all = TRUE)
    
    print(paste("After removing duplicates, found", nrow(Cleveland_Schools), "unique Cleveland schools"))
  }
})

# Step 3: Create a proper dataset with synthetic geocoding (since real geocoding is unavailable)
print("Creating properly geocoded dataset...")
try({
  # Find school name column
  school_name_col <- safe_grep("School.*Name|SchoolName|Building.*Name", colnames(Cleveland_Schools), "Building Name")
  district_name_col <- safe_grep("District.*Name|DistrictName", colnames(Cleveland_Schools), "District Name")
  
  print(paste("Using School Name column:", school_name_col))
  print(paste("Using District Name column:", district_name_col))
  
  # Create a minimal dataset with the columns we know we have
  fixed_cleveland_schools <- Cleveland_Schools %>%
    select(all_of(c(school_irn_col, school_name_col, district_irn_col, district_name_col)))
  
  # Rename to standardized column names
  fixed_cleveland_schools <- fixed_cleveland_schools %>%
    rename(
      SchoolIRN = !!school_irn_col,
      SchoolName = !!school_name_col,
      DistrictIRN = !!district_irn_col,
      DistrictName = !!district_name_col
    )
  
  # Create synthetic geocoding in a grid pattern
  print("Creating synthetic coordinates in a grid pattern around Cleveland...")
  set.seed(123)  # For reproducibility
  
  # Calculate a grid layout
  n_schools <- nrow(fixed_cleveland_schools)
  grid_size <- ceiling(sqrt(n_schools))
  
  # Create row and column indices to position schools in a grid
  row_indices <- rep(1:grid_size, each = grid_size)[1:n_schools]
  col_indices <- rep(1:grid_size, times = grid_size)[1:n_schools]
  
  # Create the coordinates with spacing
  fixed_cleveland_schools <- fixed_cleveland_schools %>%
    mutate(
      # Center the grid on Cleveland's coordinates
      Latitude = 41.4993 + (row_indices - grid_size/2) * 0.003,  # Spread schools out a bit more
      Longitude = -81.6944 + (col_indices - grid_size/2) * 0.004, # Slightly wider spread east-west
      SyntheticCoords = TRUE  # Flag to indicate these are synthetic
    )
  
  print("Added synthetic coordinates to all schools")
})

# Step 4: Save the fixed dataset
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

# Step 5: Create a map of the fixed dataset
print("Creating map of fixed dataset...")
try({
  # Create a nice map
  map <- leaflet(fixed_cleveland_schools) %>%
    addProviderTiles(providers$CartoDB.Positron) %>%
    addCircleMarkers(
      lng = ~Longitude,
      lat = ~Latitude,
      radius = 6,
      color = "red",  # All points are synthetic
      fillColor = "pink",
      fillOpacity = 0.7,
      weight = 1,
      popup = paste0(
        "<strong>", fixed_cleveland_schools$SchoolName, "</strong><br>",
        "IRN: ", fixed_cleveland_schools$SchoolIRN, "<br>",
        "<span style='color:red;'><b>SYNTHETIC COORDINATES</b></span> (actual geocoding unavailable)"
      ),
      label = ~SchoolName
    ) %>%
    addControl(
      html = paste(
        "<strong>Cleveland Schools Map</strong><br>",
        "Total schools:", nrow(fixed_cleveland_schools), "<br>",
        "<span style='color:red;'>All coordinates are synthetic</span><br>",
        "(Actual geocoding data unavailable)"
      ),
      position = "topright"
    )
  
  # Save the map
  saveWidget(map, "~/digital_redlining/plot/output/cleveland_schools_fixed_map.html", selfcontained = TRUE)
  
  print("Fixed map saved to ~/digital_redlining/plot/output/cleveland_schools_fixed_map.html")
}) 