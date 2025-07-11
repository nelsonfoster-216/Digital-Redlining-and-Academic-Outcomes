# Spatial Analysis Project: Digital Redlining, Broadband Access, and Education Outcomes in Cleveland

## 1. Project Premise and Objective

**Premise:** This research aims to investigate the intersection of historical redlining practices, school locations, and education outcomes in the Cleveland Metropolitan School District (CMSD)[cite: 2]. The project extends this research by incorporating the nuance of "digital redlining," a phenomenon where historically redlined districts experience poorer broadband service[cite: 2]. This has significant implications for education outcomes, particularly in the post-COVID era with the increase in virtual education[cite: 2].

**Objective:** To integrate a high-resolution map layer of broadband speeds for the Cleveland metropolitan area with existing spatial data (redlining boundaries and geocoded school locations with outcome data)[cite: 2]. The goal is to programmatically vectorize the broadband speed polygons from a PDF map at a high level of granularity, avoiding manual digitization[cite: 2]. This new layer will then be used to analyze the relationship between broadband access, historical redlining, and educational disparities.

## 2. Current Status and Challenges

* **Existing Data:**
    * Redlining boundaries (spatial data).
    * School geocoded locations (spatial data).
    * Education outcomes data for CMSD.
* **Broadband Map:** A PDF map of color-coded broadband speeds for Cuyahoga County is available[cite: 1].
    * **Problem:** The GeoJSON or shapefiles for this map are not publicly available[cite: 2].
    * **Challenge:** Manual vectorization is not feasible due to time constraints[cite: 2].
    * **Solution Need:** A programmatic method to vectorize the polygons at the exact granularity of the PDF[cite: 2].

## 3. Broadband Map Details

* **Source:** "CUYAHOGA COUNTY broadband profile" map from BroadbandOhio[cite: 1, 3].
* **Color Legend and Speed Categories:** The map uses distinct colors to represent different broadband speed categories[cite: 1].
    * **0-9 Mbps:** Red [cite: 7]
    * **10-24 Mbps:** Orange [cite: 7]
    * **25-49 Mbps:** Yellow [cite: 7]
    * **50-100 Mbps:** Light Green [cite: 7]
    * **100+ Mbps:** Dark Green [cite: 7]
* **Granularity:** The map is color-coded at the census block level[cite: 6].
* **Data Sources (for original map):** Ookla Speedtest Intelligence data (Feb 2020 - Aug 2021), FCC Form 477, USAC HUBB deployments, RDOF Phase 1 eligibility, E-911/LBRS household locations[cite: 2, 5].

## 4. Spatial Reference Information

* **Coordinate Reference System (CRS):** EPSG:4326 (WGS84 geographic coordinates)[cite: 2].
    * `terra::crs(img) <- "EPSG:4326"`
* **Approximate Bounding Box for Cleveland Area:**
    * Longitude: -81.82 (west) to -81.55 (east)
    * Latitude: 41.39 (south) to 41.60 (north)
    * A tighter box for core Cleveland CMSD is approximately:
        * South-West: `c(-81.80, 41.40)`
        * South-East: `c(-81.53, 41.40)`
        * North-East: `c(-81.53, 41.58)`
        * North-West: `c(-81.80, 41.58)`

## 5. Model Context Protocol / R Codebase

This section outlines the steps and R code for extracting, georeferencing, classifying, and vectorizing the broadband speed data from the provided image.

### Phase 1: Preparation, Georeferencing, and Cropping

**Objective:** Load the broadband map image, assign its spatial reference, and crop it to the Cleveland study area.

```R
# Install necessary packages if you haven't already
# install.packages(c("magick", "terra", "sf", "dplyr", "ggplot2"))

library(magick)
library(terra)
library(sf)
library(dplyr)
library(ggplot2)

# --- Define File Paths ---
# IMPORTANT: Replace with the actual path to your image file
image_path <- "path/to/image_56a235.jpg"
# IMPORTANT: Replace with the actual paths to your existing spatial data
redlining_geojson_path <- "path/to/your/redlining.geojson"
schools_geojson_path <- "path/to/your/schools.geojson"
output_broadband_geojson_path <- "path/to/output/broadband_speed_zones_cleveland.geojson"

# 1. Load the image using magick
broadband_img_magick <- image_read(image_path)

# Display the image (optional, for verification)
plot(broadband_img_magick)

# 2. Convert magick image to a terra raster (will have 3 bands for RGB)
# `as.integer(broadband_img_magick[[1]])` extracts the raw pixel data as an array.
broadband_array <- as.integer(broadband_img_magick[[1]])
broadband_rast_rgb <- rast(broadband_array)

# Assign the CRS and extent based on your provided information
# The image itself is not "georeferenced" in terms of having spatial metadata.
# We are manually assigning its extent and CRS, assuming the image covers that extent.

# Your provided extent for Cuyahoga County:
x_min_county <- -81.82
y_min_county <- 41.39
x_max_county <- -81.55
y_max_county <- 41.60

# Set the extent for the raster
ext(broadband_rast_rgb) <- c(x_min_county, x_max_county, y_min_county, y_max_county)
crs(broadband_rast_rgb) <- "EPSG:4326" # WGS84 [cite: 2]

# Verify the CRS and extent
print("CRS of broadband raster:")
print(crs(broadband_rast_rgb))
print("Extent of broadband raster:")
print(ext(broadband_rast_rgb))

# 3. Crop the raster to the Cleveland area
# Create an sf polygon for Cleveland's approximate bounding box
cleveland_coords <- rbind(
  c(-81.80, 41.40),  # SW [cite: 2]
  c(-81.53, 41.40),  # SE [cite: 2]
  c(-81.53, 41.58),  # NE [cite: 2]
  c(-81.80, 41.58),  # NW [cite: 2]
  c(-81.80, 41.40)   # Close polygon [cite: 2]
)

cleveland_bbox_sf <- st_polygon(list(cleveland_coords)) %>%
  st_sfc(crs = "EPSG:4326")

# Crop the raster to this bounding box
broadband_rast_cropped <- crop(broadband_rast_rgb, vect(cleveland_bbox_sf))

# Optional: If you have a precise CMSD boundary shapefile, you can mask the raster
# cmsd_boundary_sf <- st_read("path/to/your/cmsd_boundary.geojson") %>% st_transform("EPSG:4326")
# broadband_rast_masked <- mask(broadband_rast_cropped, vect(cmsd_boundary_sf))
# Use `broadband_rast_masked` for subsequent steps if you implement this masking.
# Otherwise, proceed with `broadband_rast_cropped`.

# Plot to check georeferencing and cropping (requires 3 bands for plotRGB)
plotRGB(broadband_rast_cropped, main = "Cropped Broadband Map (RGB)")

# Load your existing spatial data (redlining and schools) for plotting verification
# Ensure they are also in EPSG:4326 or transform them here.
redlining_sf <- st_read(redlining_geojson_path) %>% st_transform("EPSG:4326")
schools_sf <- st_read(schools_geojson_path) %>% st_transform("EPSG:4326")

# Add existing layers to the plot
plot(st_geometry(redlining_sf), add = TRUE, border = "red", lwd = 2)
plot(st_geometry(schools_sf), add = TRUE, col = "blue", pch = 16, cex = 0.8)

# 1. Define the RGB values for each broadband speed category
# IMPORTANT: REPLACE THESE WITH YOUR ACTUAL SAMPLED RGB VALUES from the image legend!
# These are EXAMPLE RGB values and will not be accurate without your specific sampling.
color_red_0_9 <- c(237, 28, 36)      # Example RGB for 0-9 Mbps (Red)
color_orange_10_24 <- c(255, 127, 39) # Example RGB for 10-24 Mbps (Orange)
color_yellow_25_49 <- c(255, 242, 0) # Example RGB for 25-49 Mbps (Yellow)
color_light_green_50_100 <- c(181, 230, 29) # Example RGB for 50-100 Mbps (Light Green)
color_dark_green_100_plus <- c(34, 177, 76) # Example RGB for 100+ Mbps (Dark Green)

# Combine colors into a matrix for easier iteration
color_palette_matrix <- rbind(
  color_red_0_9,
  color_orange_10_24,
  color_yellow_25_49,
  color_light_green_50_100,
  color_dark_green_100_plus
)

# 2. Create a function to classify pixels based on color distance
# `tolerance` determines how strictly a pixel's color must match a target color.
# Adjust this value based on visual inspection of the classified output.
# A higher tolerance (e.g., 50) means more variation is allowed,
# a lower tolerance (e.g., 20) means a closer match is required.
classify_broadband_color <- function(r_val, g_val, b_val, color_palette, tolerance = 40) { # Initial tolerance set to 40
  pixel_color <- c(r_val, g_val, b_val)
  distances <- apply(color_palette, 1, function(target_color) {
    sqrt(sum((pixel_color - target_color)^2)) # Euclidean distance in RGB space
  })

  # Find the closest color category
  min_dist_idx <- which.min(distances)

  # Check if the closest color is within the tolerance threshold
  if (distances[min_dist_idx] < tolerance) {
    return(min_dist_idx) # Return the category ID (1 to 5)
  } else {
    return(NA) # Unclassified pixel (e.g., roads, water, or background)
  }
}

# 3. Apply the classification function to the RGB raster
# `broadband_rast_cropped` should have 3 bands (R, G, B)
broadband_classified_rast <- app(broadband_rast_cropped, fun = function(x) {
  # Apply the classification function row-wise (pixel by pixel across bands)
  apply(x, 1, function(pixel_rgb) {
    classify_broadband_color(pixel_rgb[1], pixel_rgb[2], pixel_rgb[3], color_palette_matrix)
  })
})

# Rename the band for clarity
names(broadband_classified_rast) <- "broadband_category_id"

# Plot the classified raster to visually check the result
# Use a custom color palette for plotting to match your legend
classified_colors <- c("red", "orange", "yellow", "lightgreen", "darkgreen")
plot(broadband_classified_rast, col = classified_colors,
     main = "Classified Broadband Speeds Raster")

# 4. Raster to Vector Conversion
# `dissolve = TRUE` merges adjacent cells with the same value into single polygons.
# `values = TRUE` ensures the category ID is included as an attribute.
broadband_polygons_terra <- as.polygons(broadband_classified_rast, dissolve = TRUE, values = TRUE)

# Convert to sf object for easier manipulation and plotting with existing sf data
broadband_polygons_sf <- st_as_sf(broadband_polygons_terra)

# Rename the column with category IDs and assign meaningful speed category names
broadband_polygons_sf <- broadband_polygons_sf %>%
  rename(broadband_category_id = broadband_category_id) %>% # Ensure correct column name
  mutate(broadband_speed_category = case_when(
    broadband_category_id == 1 ~ "0-9 Mbps",
    broadband_category_id == 2 ~ "10-24 Mbps",
    broadband_category_id == 3 ~ "25-49 Mbps",
    broadband_category_id == 4 ~ "50-100 Mbps",
    broadband_category_id == 5 ~ "100+ Mbps",
    TRUE ~ "Unclassified" # Catch any NAs or other unexpected values
  ))

# Inspect the result (optional, for debugging)
print(table(broadband_polygons_sf$broadband_speed_category))

# Plot the vectorized polygons for visual verification
# Use the same color palette as for the raster plot
ggplot() +
  geom_sf(data = broadband_polygons_sf, aes(fill = broadband_speed_category), alpha = 0.7) +
  scale_fill_manual(values = c("0-9 Mbps" = "red", "10-24 Mbps" = "orange",
                               "25-49 Mbps" = "yellow", "50-100 Mbps" = "lightgreen",
                               "100+ Mbps" = "darkgreen", "Unclassified" = "grey")) +
  labs(title = "Vectorized Broadband Zones (Initial Result)", fill = "Broadband Speed") +
  theme_minimal()
  
# 1. Clean up polygons
# Filter out 'Unclassified' polygons if they represent irrelevant areas (e.g., roads, water outside county)
broadband_polygons_sf_filtered <- broadband_polygons_sf %>%
  filter(broadband_speed_category != "Unclassified")

# Simplify geometries to reduce vertex count and smooth edges
# dTolerance is in the units of the CRS (degrees for WGS84).
# A smaller value (e.g., 0.00001) for finer detail, larger for more aggressive simplification.
# Experiment with this value to find the right balance.
broadband_polygons_sf_simplified <- st_simplify(broadband_polygons_sf_filtered,
                                                 preserveTopology = TRUE,
                                                 dTolerance = 0.00005) # Example: ~5-10 meters tolerance at this latitude

# Ensure valid geometries
# This helps prevent issues in subsequent spatial operations.
broadband_polygons_sf_final <- st_make_valid(broadband_polygons_sf_simplified)

# 2. Save the new broadband layer as GeoJSON
st_write(broadband_polygons_sf_final, output_broadband_geojson_path, delete_layer = TRUE)
message(paste("Broadband speed zones saved to:", output_broadband_geojson_path))

# 3. Integrate with your existing redlining and school maps
# (Redlining and schools_sf should already be loaded and transformed to EPSG:4326)

# Example Overlay Analysis: Intersect redlining zones with broadband zones
# This will create new polygons where redlining and broadband zones overlap,
# inheriting attributes from both. This is powerful for spatial joins of attributes.
redlining_broadband_intersect <- st_intersection(redlining_sf, broadband_polygons_sf_final)
message("Redlining and broadband intersection computed.")

# Example Spatial Join: Find the broadband speed category for each school
# Assumes schools are points. It will add broadband attributes to school points
# based on which polygon they fall within.
schools_with_broadband <- st_join(schools_sf, broadband_polygons_sf_final)
message("Schools joined with broadband categories.")

# 4. Final Visualization
ggplot() +
  geom_sf(data = broadband_polygons_sf_final, aes(fill = broadband_speed_category), alpha = 0.7) +
  geom_sf(data = redlining_sf, fill = NA, color = "red", size = 1, linetype = "solid") + # Redlining boundaries
  geom_sf(data = schools_sf, color = "blue", size = 2, shape = 16) + # School points
  scale_fill_manual(values = c("0-9 Mbps" = "red", "10-24 Mbps" = "orange",
                               "25-49 Mbps" = "yellow", "50-100 Mbps" = "lightgreen",
                               "100+ Mbps" = "darkgreen")) +
  labs(title = "Broadband Speeds, Redlining, and Schools in Cleveland",
       subtitle = "Data Source: Cuyahoga County Broadband Profile (2020-2021) [cite: 1, 5]",
       fill = "Broadband Speed Category") +
  theme_minimal() +
  coord_sf(datum = st_crs(broadband_polygons_sf_final)) # Ensure correct coordinate system display

