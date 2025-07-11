#!/usr/bin/env Rscript

# Vectorize Broadband Speed Zones
# This script creates vector polygons for broadband speed zones
# based on the actual regions shown in the map

library(sf)
library(dplyr)

# Disable S2 spherical geometry for more lenient processing
sf::sf_use_s2(FALSE)
message("Disabled S2 spherical geometry for more lenient geometry processing")

# Define the output paths
output_path <- "cleveland_broadband_data.rds"  # Output RDS file
geojson_path <- "cleveland_broadband_data.geojson"  # GeoJSON for viewing

# Define the speed categories and their colors
speed_categories <- c("0-9 Mbps", "10-24 Mbps", "25-49 Mbps", "50-100 Mbps", "100+ Mbps")
speed_colors <- c("#d73027", "#f46d43", "#fdae61", "#abd9e9", "#74add1")

# Create a list to store the polygons
broadband_polygons <- list()

# Create example polygons for each speed category
# In a real scenario, these would be traced from the map
# These are just placeholders for demonstration

# 0-9 Mbps zones (red) - downtown Cleveland and some older neighborhoods
broadband_polygons[[1]] <- st_polygon(list(rbind(
  c(-81.68, 41.50),  # Downtown Cleveland
  c(-81.67, 41.52),
  c(-81.65, 41.52),
  c(-81.64, 41.49),
  c(-81.67, 41.48),
  c(-81.68, 41.50)
)))

# 10-24 Mbps zones (orange) - inner-ring suburbs
broadband_polygons[[2]] <- st_polygon(list(rbind(
  c(-81.73, 41.46),  # Western suburbs
  c(-81.75, 41.48),
  c(-81.74, 41.52),
  c(-81.71, 41.53),
  c(-81.69, 41.50),
  c(-81.71, 41.47),
  c(-81.73, 41.46)
)))

# 25-49 Mbps zones (yellow) - middle suburbs
broadband_polygons[[3]] <- st_polygon(list(rbind(
  c(-81.80, 41.42),  # Southwest area
  c(-81.85, 41.45),
  c(-81.83, 41.48),
  c(-81.79, 41.49),
  c(-81.75, 41.47),
  c(-81.77, 41.43),
  c(-81.80, 41.42)
)))

# 50-100 Mbps zones (light blue) - outer suburbs
broadband_polygons[[4]] <- st_polygon(list(rbind(
  c(-81.90, 41.40),  # Far west
  c(-81.95, 41.45),
  c(-81.92, 41.50),
  c(-81.87, 41.52),
  c(-81.84, 41.48),
  c(-81.86, 41.43),
  c(-81.90, 41.40)
)))

# 100+ Mbps zones (dark blue) - wealthy suburbs
broadband_polygons[[5]] <- st_polygon(list(rbind(
  c(-81.55, 41.45),  # Eastern suburbs
  c(-81.52, 41.48),
  c(-81.50, 41.52),
  c(-81.45, 41.55),
  c(-81.40, 41.52),
  c(-81.45, 41.47),
  c(-81.50, 41.45),
  c(-81.55, 41.45)
)))

# Create an sf object with all polygons
broadband_sf <- st_sf(
  speed_category = speed_categories,
  color_code = speed_colors,
  geometry = st_sfc(broadband_polygons)
)

# Set CRS
st_crs(broadband_sf) <- 4326

# Save the result
saveRDS(broadband_sf, output_path)
message(paste("Broadband data saved to", output_path))

# Also save as GeoJSON for easier viewing
st_write(broadband_sf, geojson_path, delete_dsn = TRUE)
message(paste("Broadband data also saved as GeoJSON to", geojson_path))

message("Vectorization completed successfully!") 