#!/usr/bin/env Rscript

# Add Broadband Layer to Main Digital Redlining Map
# This script will integrate broadband speed data into the main digital_redlining_eda_consolidated.Rmd

# Load required packages
library(sf)
library(dplyr)
library(jsonlite)

# ----------------------
# Step 1: Check if digitized broadband data exists
# ----------------------
broadband_data_path <- "cleveland_broadband_data.rds"

if(!file.exists(broadband_data_path)) {
  stop("Broadband data not found. Please run the digitize_broadband.R script first.")
}

# Load the broadband data
message("Loading broadband data...")
broadband_data <- readRDS(broadband_data_path)

# ----------------------
# Step 2: Prepare broadband data for the main map
# ----------------------
message("Preparing broadband data for map integration...")

# Create a leaflet-compatible GeoJSON representation
broadband_json <- st_transform(broadband_data, 4326)

# Convert to GeoJSON for the main map
broadband_geojson <- st_as_sf(broadband_json) %>%
  st_transform(4326) %>%
  sf::st_write("broadband_cleveland.geojson", delete_dsn = TRUE)

message("Created GeoJSON file for broadband data: broadband_cleveland.geojson")

# ----------------------
# Step 3: Create the JavaScript code to add to the main Rmd file
# ----------------------
message("Creating broadband layer JavaScript code snippet...")

broadband_js <- '
// Add broadband layer
var broadbandLayerColors = {
  "0-9 Mbps": "#d73027",
  "10-24 Mbps": "#f46d43",
  "25-49 Mbps": "#fdae61",
  "50-100 Mbps": "#abd9e9",
  "100+ Mbps": "#74add1"
};

// Add broadband speed layer
fetch("broadband_redlining/broadband_cleveland.geojson")
  .then(response => response.json())
  .then(data => {
    var broadbandLayer = L.geoJSON(data, {
      style: function(feature) {
        return {
          fillColor: feature.properties.color_code,
          weight: 1,
          opacity: 1,
          color: "#000000",
          fillOpacity: 0.7
        };
      },
      onEachFeature: function(feature, layer) {
        layer.bindTooltip("Broadband Speed: " + feature.properties.speed_category);
      }
    });

    // Add to the map
    broadbandLayer.addTo(map);
    
    // Add to layer control
    layerControl.addOverlay(broadbandLayer, "Broadband Speeds (2021)");
    
    // Add legend for broadband speeds
    var broadbandLegend = L.control({position: "bottomright"});
    broadbandLegend.onAdd = function(map) {
      var div = L.DomUtil.create("div", "info legend");
      div.innerHTML += "<h4>Broadband Speeds</h4>";
      
      var speeds = ["0-9 Mbps", "10-24 Mbps", "25-49 Mbps", "50-100 Mbps", "100+ Mbps"];
      
      for (var i = 0; i < speeds.length; i++) {
        div.innerHTML += 
          "<i style=\'background:" + broadbandLayerColors[speeds[i]] + "; width: 18px; height: 18px; float: left; margin-right: 8px; opacity: 0.7\'></i> " +
          speeds[i] + "<br>";
      }
      
      return div;
    };
    
    broadbandLegend.addTo(map);
  });
'

# Write the JavaScript code to a file
js_file_path <- "broadband_layer.js"
writeLines(broadband_js, js_file_path)

message("JavaScript code written to: ", js_file_path)
message("\nTo add this broadband layer to your main map:")
message("1. Copy the broadband_cleveland.geojson file to your main project directory")
message("2. Add the following line to your HTML section in the Rmd file:")
message('   <script src="broadband_redlining/broadband_layer.js"></script>')
message("3. Ensure the JavaScript runs after your main map is initialized")

message("\nBroadband layer integration complete!") 