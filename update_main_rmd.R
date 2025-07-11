#!/usr/bin/env Rscript

# Update Main Rmd File to Include Broadband Layer
# This script will modify the main digital_redlining_eda_consolidated.Rmd file
# to include the broadband layer.

# Set paths
main_rmd_path <- "../digital_redlining_eda_consolidated.Rmd"
backup_rmd_path <- "../digital_redlining_eda_consolidated.Rmd.broadband_backup"

# Check if main Rmd file exists
if(!file.exists(main_rmd_path)) {
  stop("Main Rmd file not found at: ", main_rmd_path)
}

# Create a backup of the original file
message("Creating backup of original Rmd file...")
file.copy(main_rmd_path, backup_rmd_path, overwrite = TRUE)
message("Backup created at: ", backup_rmd_path)

# Read the main Rmd file
message("Reading main Rmd file...")
rmd_content <- readLines(main_rmd_path)

# Find the position to insert the broadband script
# Look for the Leaflet JavaScript CDN link
leaflet_cdn_pattern <- "unpkg.com/leaflet@"
insert_positions <- grep(leaflet_cdn_pattern, rmd_content)

if(length(insert_positions) == 0) {
  message("Could not find Leaflet CDN link. Looking for </script> tag...")
  insert_positions <- grep("</script>", rmd_content)
}

if(length(insert_positions) == 0) {
  stop("Could not find a suitable insertion point in the Rmd file.")
}

# Get the last script insertion point
insert_position <- max(insert_positions) + 1

# Create the broadband script tag to insert
broadband_script_tag <- '
<!-- Add Broadband Layer Script -->
<script src="broadband_redlining/broadband_layer.js"></script>'

# Insert the script tag
rmd_content <- c(
  rmd_content[1:insert_position],
  broadband_script_tag,
  rmd_content[(insert_position+1):length(rmd_content)]
)

# Find the map layer control section to add broadband layer to legend
layer_control_pattern <- "addLayersControl\\("
layer_control_positions <- grep(layer_control_pattern, rmd_content)

if(length(layer_control_positions) > 0) {
  message("Found layer control section. Adding broadband to layer names if needed.")
  
  # For each layer control, check if broadband is already included
  for(pos in layer_control_positions) {
    if(!grepl("Broadband", rmd_content[pos]) && !grepl("broadband", rmd_content[pos])) {
      # Find the closing parenthesis for this layer control
      # This is a simplified approach and might need manual checking
      end_pos <- pos
      while(end_pos < length(rmd_content) && !grepl("\\)$", rmd_content[end_pos])) {
        end_pos <- end_pos + 1
      }
      
      # If we found the end, insert the broadband layer before it
      if(end_pos < length(rmd_content)) {
        # Update the line with the layer control to include broadband
        # This is a simplistic approach - manual checking may be needed
        if(grepl("overlayGroups", rmd_content[pos])) {
          rmd_content[pos] <- gsub(
            "overlayGroups = c\\(", 
            "overlayGroups = c(\"Broadband Speeds (2021)\", ", 
            rmd_content[pos]
          )
        }
      }
    }
  }
}

# Write the modified content back to the file
message("Writing updated Rmd file...")
writeLines(rmd_content, main_rmd_path)

message("Main Rmd file updated successfully!")
message("\nNEXT STEPS:")
message("1. Make sure you've run the broadband_pdf_extractor.R script to extract and vectorize the broadband data")
message("2. Run add_broadband_to_main_map.R to generate the broadband GeoJSON and JavaScript")
message("3. Copy the generated files to the appropriate locations")
message("4. Knit the updated Rmd file to see the broadband layer in your map")
message("\nIMPORTANT: If you need to revert to the original file, your backup is at:")
message(backup_rmd_path) 