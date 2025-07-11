# Model Context Protocol: Cleveland Digital Redlining Dashboard

## Project Context

**Objective**: Integrate broadband connectivity data with existing historical redlining analysis dashboard to reveal patterns of digital redlining in Cleveland, Ohio.

**Current State**: 
- Existing R Shiny dashboard with leaflet mapping
- Historical HOLC redlining data (GeoJSON) - 179 polygons with grades A-D
- School location and performance data (geocoded)
- Broadband speed map (PDF) - needs digitization and integration

**Target Outcome**: Multi-layer interactive map with toggleable layers for spatial analysis of digital equity patterns.

## Data Specifications

### Existing Redlining GeoJSON Structure
```json
{
  "type": "FeatureCollection",
  "features": [{
    "type": "Feature",
    "geometry": {"type": "MultiPolygon", "coordinates": [...]},
    "properties": {
      "area_id": 457,
      "city_id": 115,
      "grade": "A",           // HOLC grades: A, B, C, D
      "fill": "#76a865",      // Grade colors: A=#76a865, B=#7cb5bd, C=#ffff00, D=#d9838d
      "label": "A1",
      "category_id": 1,
      "bounds": [[lat_min, lon_min], [lat_max, lon_max]],
      "residential": true,
      "commercial": false,
      "industrial": false
    }
  }]
}
```

### Broadband Data Requirements (from PDF analysis)
```r
# Target broadband data structure to create
broadband_data <- sf::st_sf(
  speed_category = c("0-9 Mbps", "10-24 Mbps", "25-49 Mbps", "50-100 Mbps", "100+ Mbps"),
  color_code = c("#d73027", "#f46d43", "#fdae61", "#abd9e9", "#74add1"),
  geometry = list_of_polygons  # To be digitized from PDF
)
```

**Geographic Bounds**: 
- Latitude: 41.484 to 41.627
- Longitude: -81.968 to -81.484
- CRS: EPSG:4326 (WGS84)

## Technical Stack Requirements

```r
# Required R packages
required_packages <- c(
  "shiny",           # Dashboard framework
  "shinydashboard",  # Dashboard UI components
  "leaflet",         # Interactive mapping
  "sf",              # Spatial data handling
  "dplyr",           # Data manipulation
  "DT",              # Data tables
  "plotly",          # Interactive plots
  "htmltools",       # HTML generation
  "magick",          # Image processing (for PDF)
  "mapedit",         # Interactive map editing
  "corrplot",        # Correlation visualization
  "RColorBrewer"     # Color palettes
)

# Installation check
install_if_missing <- function(packages) {
  new_packages <- packages[!(packages %in% installed.packages()[,"Package"])]
  if(length(new_packages)) install.packages(new_packages)
}
```

## Implementation Priority Queue

### PRIORITY 1: Data Digitization Functions
```r
# Function to extract Cleveland boundary from existing redlining data
extract_cleveland_boundary <- function(redlining_geojson_path) {
  redlining_data <- sf::st_read(redlining_geojson_path)
  cleveland_boundary <- sf::st_union(redlining_data)
  return(cleveland_boundary)
}

# Interactive digitization function for broadband zones
digitize_broadband_zones <- function(cleveland_boundary) {
  library(mapedit)
  library(leaflet)
  
  # Create base map for digitization
  base_map <- leaflet() %>%
    addProviderTiles(providers$CartoDB.Positron) %>%
    addPolygons(data = cleveland_boundary, 
                color = "red", weight = 2, fill = FALSE) %>%
    setView(lng = -81.7, lat = 41.5, zoom = 12)
  
  # Interactive polygon creation
  broadband_polygons <- editMap(base_map)
  return(broadband_polygons)
}
```

### PRIORITY 2: Layer Management System
```r
# Layer control structure
layer_config <- list(
  redlining = list(
    name = "Historical Redlining",
    colors = c("A" = "#76a865", "B" = "#7cb5bd", "C" = "#ffff00", "D" = "#d9838d"),
    opacity = 0.6,
    group = "redlining"
  ),
  broadband = list(
    name = "Broadband Speed", 
    colors = c("0-9 Mbps" = "#d73027", "10-24 Mbps" = "#f46d43", 
               "25-49 Mbps" = "#fdae61", "50-100 Mbps" = "#abd9e9", "100+ Mbps" = "#74add1"),
    opacity = 0.7,
    group = "broadband"
  ),
  schools = list(
    name = "School Locations",
    marker_color = "#FF0000",
    group = "schools"
  )
)

# Dynamic layer addition function
add_layer_to_map <- function(leaflet_proxy, layer_type, data, config) {
  switch(layer_type,
    "redlining" = add_redlining_layer(leaflet_proxy, data, config),
    "broadband" = add_broadband_layer(leaflet_proxy, data, config),
    "schools" = add_schools_layer(leaflet_proxy, data, config)
  )
}
```

### PRIORITY 3: Spatial Analysis Functions
```r
# Core analysis function template
perform_spatial_analysis <- function(redlining_data, broadband_data, analysis_type) {
  
  # Ensure same CRS
  redlining_data <- sf::st_transform(redlining_data, crs = 4326)
  broadband_data <- sf::st_transform(broadband_data, crs = 4326)
  
  switch(analysis_type,
    "overlay" = {
      # Spatial intersection analysis
      intersection <- sf::st_intersection(redlining_data, broadband_data)
      intersection$area_sqm <- as.numeric(sf::st_area(intersection))
      
      # Summary statistics
      summary_stats <- intersection %>%
        sf::st_drop_geometry() %>%
        group_by(grade, speed_category) %>%
        summarise(
          total_area = sum(area_sqm),
          polygon_count = n(),
          .groups = "drop"
        )
      
      return(summary_stats)
    },
    
    "correlation" = {
      # Convert grades to numeric for correlation
      redlining_numeric <- redlining_data %>%
        mutate(grade_numeric = case_when(
          grade == "A" ~ 4, grade == "B" ~ 3, 
          grade == "C" ~ 2, grade == "D" ~ 1
        ))
      
      # Spatial join and correlation analysis
      joined_data <- sf::st_join(redlining_numeric, broadband_data)
      # Return correlation results
    }
  )
}
```

## UI/UX Specifications

### Dashboard Layout Structure
```r
# Main UI layout
ui <- dashboardPage(
  dashboardHeader(title = "Cleveland Digital Redlining Analysis"),
  
  dashboardSidebar(
    width = 250,
    sidebarMenu(
      menuItem("Interactive Map", tabName = "map"),
      menuItem("Analysis Results", tabName = "analysis"),
      menuItem("Data Export", tabName = "export")
    ),
    
    # Layer toggle controls
    h4("Map Layers", style = "margin-left: 15px;"),
    div(style = "margin-left: 15px;",
      checkboxGroupInput("active_layers",
        label = NULL,
        choices = list(
          "Historical Redlining (1935)" = "redlining",
          "Broadband Speed (2021)" = "broadband", 
          "School Locations" = "schools"
        ),
        selected = "redlining"
      )
    ),
    
    # Analysis controls
    h4("Analysis Tools", style = "margin-left: 15px;"),
    div(style = "margin-left: 15px;",
      selectInput("analysis_type", "Analysis Type:",
        choices = c("Spatial Overlay" = "overlay", 
                   "Correlation Analysis" = "correlation")),
      actionButton("run_analysis", "Run Analysis", 
                  class = "btn-primary btn-sm")
    )
  ),
  
  dashboardBody(
    # Map container with specific dimensions
    fluidRow(
      column(width = 8,
        box(width = NULL, height = "600px", status = "primary",
          leafletOutput("main_map", height = "580px")
        )
      ),
      column(width = 4,
        box(title = "Layer Information", width = NULL, status = "info",
          verbatimTextOutput("layer_summary")
        ),
        box(title = "Selection Details", width = NULL, status = "warning",
          DT::dataTableOutput("selection_details", height = "200px")
        )
      )
    )
  )
)
```

### Map Event Handling
```r
# Click event handler for map interactions
observeEvent(input$main_map_shape_click, {
  click_info <- input$main_map_shape_click
  
  # Determine which layer was clicked
  clicked_layer <- identify_clicked_layer(click_info)
  
  # Update selection details based on layer
  output$selection_details <- DT::renderDataTable({
    get_layer_details(clicked_layer, click_info)
  }, options = list(pageLength = 5, searching = FALSE))
})

# Layer toggle observer
observeEvent(input$active_layers, {
  leafletProxy("main_map") %>%
    clearGroup(c("redlining", "broadband", "schools"))
  
  # Re-add selected layers
  for(layer in input$active_layers) {
    add_layer_to_map(leafletProxy("main_map"), layer, 
                    get_layer_data(layer), layer_config[[layer]])
  }
})
```

## Data Processing Pipeline

### Step 1: Data Loading and Validation
```r
load_and_validate_data <- function() {
  # Load existing redlining data
  redlining_data <- sf::st_read("path/to/geojson.json")
  
  # Validate geometry
  redlining_data <- sf::st_make_valid(redlining_data)
  
  # Load or create broadband data
  if(file.exists("data/broadband_zones.rds")) {
    broadband_data <- readRDS("data/broadband_zones.rds")
  } else {
    stop("Broadband data not digitized. Run digitize_broadband_zones() first.")
  }
  
  # Ensure consistent CRS
  redlining_data <- sf::st_transform(redlining_data, 4326)
  broadband_data <- sf::st_transform(broadband_data, 4326)
  
  return(list(redlining = redlining_data, broadband = broadband_data))
}
```

### Step 2: Spatial Alignment
```r
align_spatial_data <- function(redlining_data, broadband_data) {
  # Clip broadband data to redlining boundary
  cleveland_boundary <- sf::st_union(redlining_data)
  broadband_clipped <- sf::st_intersection(broadband_data, cleveland_boundary)
  
  # Remove any invalid geometries
  broadband_clipped <- broadband_clipped[sf::st_is_valid(broadband_clipped), ]
  
  return(list(
    redlining = redlining_data,
    broadband = broadband_clipped,
    boundary = cleveland_boundary
  ))
}
```

## Error Handling and Validation

### Data Validation Checks
```r
validate_data_integrity <- function(data_list) {
  validation_report <- list()
  
  for(layer_name in names(data_list)) {
    layer_data <- data_list[[layer_name]]
    
    validation_report[[layer_name]] <- list(
      has_data = nrow(layer_data) > 0,
      geometry_valid = all(sf::st_is_valid(layer_data)),
      crs_correct = sf::st_crs(layer_data)$epsg == 4326,
      required_columns = check_required_columns(layer_data, layer_name)
    )
  }
  
  return(validation_report)
}

check_required_columns <- function(data, layer_type) {
  required_cols <- switch(layer_type,
    "redlining" = c("grade", "area_id", "residential", "commercial", "industrial"),
    "broadband" = c("speed_category"),
    "schools" = c("school_name", "performance_score")
  )
  
  return(all(required_cols %in% names(data)))
}
```

## Performance Optimization Context

### Data Simplification for Web Display
```r
optimize_for_web <- function(sf_data, tolerance = 10) {
  # Simplify geometries to reduce file size
  simplified <- sf::st_simplify(sf_data, dTolerance = tolerance)
  
  # Remove unnecessary columns for web display
  essential_cols <- c("geometry", get_essential_columns(sf_data))
  simplified <- simplified[, essential_cols]
  
  return(simplified)
}

# Caching strategy for expensive operations
cache_analysis_results <- function(analysis_func, cache_key, ...) {
  cache_file <- paste0("cache/", cache_key, ".rds")
  
  if(file.exists(cache_file)) {
    return(readRDS(cache_file))
  } else {
    result <- analysis_func(...)
    dir.create("cache", showWarnings = FALSE)
    saveRDS(result, cache_file)
    return(result)
  }
}
```

## Debugging and Development Context

### Development Helpers
```r
# Debug information display
show_debug_info <- function(data_list) {
  for(layer_name in names(data_list)) {
    cat("\n=== ", toupper(layer_name), " LAYER ===\n")
    cat("Rows:", nrow(data_list[[layer_name]]), "\n")
    cat("CRS:", sf::st_crs(data_list[[layer_name]])$input, "\n")
    cat("Extent:", paste(as.numeric(sf::st_bbox(data_list[[layer_name]])), collapse = ", "), "\n")
    if("grade" %in% names(data_list[[layer_name]])) {
      cat("Grade distribution:", table(data_list[[layer_name]]$grade), "\n")
    }
  }
}

# Test data generator for development
create_test_data <- function() {
  # Create minimal test polygons within Cleveland bounds
  test_redlining <- sf::st_as_sf(data.frame(
    grade = c("A", "B", "C", "D"),
    area_id = 1:4,
    geometry = sf::st_sfc(
      sf::st_polygon(list(cbind(c(-81.7, -81.69, -81.69, -81.7, -81.7), 
                                c(41.5, 41.5, 41.51, 41.51, 41.5)))),
      sf::st_polygon(list(cbind(c(-81.69, -81.68, -81.68, -81.69, -81.69), 
                                c(41.5, 41.5, 41.51, 41.51, 41.5)))),
      sf::st_polygon(list(cbind(c(-81.68, -81.67, -81.67, -81.68, -81.68), 
                                c(41.5, 41.5, 41.51, 41.51, 41.5)))),
      sf::st_polygon(list(cbind(c(-81.67, -81.66, -81.66, -81.67, -81.67), 
                                c(41.5, 41.5, 41.51, 41.51, 41.5))))
    ),
    crs = 4326
  ))
  
  return(list(redlining = test_redlining))
}
```

## File Structure Context

```
project_root/
├── app.R                 # Main Shiny application
├── R/
│   ├── data_processing.R # Data loading and processing functions
│   ├── mapping_functions.R # Leaflet layer functions  
│   ├── analysis_functions.R # Spatial analysis functions
│   └── ui_components.R   # UI helper functions
├── data/
│   ├── geojson.json     # Existing redlining data
│   ├── broadband_zones.rds # Digitized broadband data (to create)
│   └── schools.csv      # School location data
├── cache/               # Cached analysis results
├── www/                 # Static web assets
└── docs/                # Documentation
```

## Immediate Next Steps for Cursor

1. **Start with broadband digitization**: Use `mapedit` package to trace broadband zones from PDF
2. **Implement basic layer system**: Get redlining layer displaying first
3. **Add broadband layer**: Once digitized, add as toggleable layer
4. **Build analysis functions**: Start with simple spatial overlay
5. **Add UI controls**: Layer toggles and analysis triggers

This protocol gives Cursor the complete context needed to build the digital redlining dashboard incrementally, with specific code patterns, data structures, and implementation priorities.