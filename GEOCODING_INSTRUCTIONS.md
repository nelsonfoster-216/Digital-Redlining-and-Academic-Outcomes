# Geocoding Cleveland Schools - Instructions

This document explains how to use the geocoding script to update the Cleveland schools dataset with accurate coordinates based on school addresses.

## Overview

The current Cleveland schools dataset has a geocoding issue where all schools share the same coordinates (41.4993, -81.6944). The solution provided will:

1. Use the Google Maps API to find accurate addresses for each school
2. Geocode these addresses to get precise latitude/longitude coordinates
3. Update the dataset with the real coordinates
4. Create a new map visualization showing the schools in their actual locations

## Prerequisites

To use this solution, you'll need:

1. A Google Maps API key with access to the Geocoding API
2. The R packages: `dplyr`, `googleway`, `leaflet`, `htmlwidgets`, and `readxl`

## Step 1: Obtain a Google Maps API key

1. Go to the [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project (or select an existing one)
3. Enable the **Geocoding API** and **Places API** for your project
4. Create an API key from the Credentials page
5. (Optional but recommended) Restrict the API key to only the Geocoding and Places APIs
6. Make note of your API key - you'll need it for the script

Note: Google Maps API usage incurs charges after exceeding the free tier limits. Check [Google's pricing](https://cloud.google.com/maps-platform/pricing) for current rates.

## Step 2: Install required R packages

Run the following commands in R to install the required packages:

```r
install.packages(c("dplyr", "googleway", "leaflet", "htmlwidgets", "readxl"))
```

## Step 3: Configure and run the geocoding script

1. Open the `geocode_cleveland_schools.R` script
2. Replace `"YOUR_API_KEY_HERE"` with your actual Google Maps API key
3. Adjust the `max_schools_to_geocode` variable (default is 5 for demo purposes) to process more schools
   - Set it to a large number to process all schools, but be aware of API usage charges
4. Run the script to geocode the schools and generate the updated dataset

The script will:
- Load your existing Cleveland schools dataset
- Check for available address information
- Use Google Maps to find/verify addresses and geocode them
- Save a new dataset with updated coordinates as `cleveland_schools_geocoded.rds`
- Create a map visualization showing the geocoded schools

## Step 4: Update your R Markdown file

The script includes a helper function to automatically update your R Markdown file. To use it:

1. Uncomment the line `# update_rmd_dataset()` at the end of the script
2. Run that portion of the script

Alternatively, you can manually update your R Markdown file:

1. Open `digital_redlining_eda.Rmd`
2. Find the `enhanced_map` code chunk
3. Update the dataset loading code to look for the geocoded dataset first:

```r
# First try to load the geocoded dataset, falling back to alternatives
geocoded_path <- "~/digital_redlining/plot/output/cleveland_schools_geocoded.rds"
fixed_data_path <- "~/digital_redlining/plot/output/cleveland_schools_fixed.rds"
original_data_path <- "~/digital_redlining/plot/output/cleveland_schools_consolidated.rds"

if (file.exists(geocoded_path)) {
  cleveland_schools_data <- readRDS(geocoded_path)
  using_geocoded_data <- TRUE
  cat("Using the geocoded Cleveland schools dataset with actual coordinates\n")
} else if (file.exists(fixed_data_path)) {
  cleveland_schools_data <- readRDS(fixed_data_path)
  using_geocoded_data <- FALSE
  using_fixed_data <- TRUE
  cat("Using the fixed Cleveland schools dataset with synthetic coordinates\n")
} else {
  cleveland_schools_data <- readRDS(original_data_path)
  using_geocoded_data <- FALSE
  using_fixed_data <- FALSE
  cat("Using the original Cleveland schools dataset (note: geocoding may be inaccurate)\n")
}
```

## Step 5: Re-render your R Markdown document

Run your R Markdown document again to generate the updated visualization with accurate school locations:

```r
rmarkdown::render("digital_redlining_eda.Rmd", output_file="plot/output/digital_redlining_eda.html")
```

## Troubleshooting

### API Key Issues
- If you see errors like "API key not valid" or "Request denied", check that your API key is correct and has the necessary API access enabled.

### Rate Limiting
- Google Maps API has rate limits. If you hit these limits, the script will report errors for those schools.
- Consider adding longer delays between API calls (`Sys.sleep()`) or implementing a more robust batching strategy.

### Geocoding Accuracy
- Some schools may not geocode perfectly, especially if names are ambiguous or have changed.
- Review the results map to identify any misplaced schools.
- For problematic schools, you might need to manually adjust their coordinates or search queries.

## Notes on API Usage and Costs

The Google Maps Platform operates on a pay-as-you-go model:
- Geocoding API: $5 per 1,000 requests (0.005 per request)
- Places API: $17 per 1,000 requests (0.017 per request)

For a district with ~100-150 schools, the cost would be minimal (likely under $1), but be aware of the charges if running the script multiple times or with a larger dataset.

## Advanced: Using Alternative Geocoding Services

If you prefer not to use Google Maps API, consider these alternatives:
- **OpenStreetMap Nominatim**: Free but has strict usage limits and less accuracy
- **Census Geocoder**: Free for US addresses
- **Local geocoding libraries**: Some R packages offer offline geocoding with less precision

To use an alternative service, you would need to modify the geocoding portion of the script accordingly. 