# Digital Redlining and Educational Outcomes in Cleveland

A comprehensive spatial analysis project investigating the intersection of historical redlining practices, modern broadband access, and educational outcomes in Cleveland, Ohio.

## Project Overview

This research project examines the phenomenon of "digital redlining" - where historically redlined districts continue to experience poorer broadband service quality. The analysis integrates historical Home Owners' Loan Corporation (HOLC) redlining data with modern broadband speed maps and Cleveland Municipal School District (CMSD) performance data to reveal patterns of digital equity and educational disparities.

### Key Research Questions

- How do historical redlining boundaries correlate with modern broadband access patterns?
- What is the relationship between broadband availability and educational outcomes in Cleveland schools?
- Can we identify specific areas where digital equity interventions would have the greatest impact?

## Data Sources

### Historical Redlining Data
- **Source**: Home Owners' Loan Corporation (HOLC) maps from the 1930s
- **Coverage**: Cleveland metropolitan area redlining boundaries
- **Grades**: A (Best), B (Still Desirable), C (Declining), D (Hazardous)
- **Format**: GeoJSON with polygon geometries and HOLC grades

### Broadband Speed Data
- **Source**: BroadbandOhio Cuyahoga County broadband profile map
- **Speed Categories**: 0-9 Mbps, 10-24 Mbps, 25-49 Mbps, 50-100 Mbps, 100+ Mbps
- **Granularity**: Census block level
- **Processing**: Programmatic vectorization from PDF maps using computer vision

### Educational Data
- **Source**: Ohio Department of Education School Report Cards (2022-23, 2023-24)
- **Scope**: Cleveland Municipal School District (CMSD)
- **Metrics**: Performance Index scores, chronic absenteeism rates, demographic data
- **Processing**: Geocoded school locations with address validation

## Technical Stack

### R Environment
- **Core Analysis**: R with RMarkdown for reproducible research
- **Spatial Analysis**: `sf`, `terra`, `leaflet` for GIS operations
- **Visualization**: `ggplot2`, `plotly`, `leaflet` for interactive maps
- **Data Processing**: `dplyr`, `tidyr` for data manipulation
- **Web Output**: Shiny dashboards and HTML reports

### Python Environment
- **Image Processing**: OpenCV for map digitization
- **Geospatial**: GeoPandas, Rasterio for spatial data processing
- **PDF Processing**: pdf2image, Pillow for map extraction
- **Dependencies**: See `cleveland-broadband-analysis/requirements.txt`

### Key Dependencies
```r
# R packages
library(sf)          # Spatial data
library(leaflet)     # Interactive maps
library(dplyr)       # Data manipulation
library(ggplot2)     # Visualization
library(shiny)       # Web applications
library(terra)       # Raster processing
library(htmlwidgets) # Web widgets
```

## Project Structure

```
digital_redlining/
├── broadband_redlining/          # Broadband analysis workflows
├── cleveland-broadband-analysis/  # Python map processing
├── redlining_map_data/           # Historical HOLC data
├── state_reports/                # Educational data sources
├── *.Rmd                        # R Markdown analysis files
├── *.html                       # Generated reports
└── README.md                    # This file
```

## Key Outputs

### Interactive Dashboards
- **Digital Redlining EDA**: Comprehensive exploratory data analysis
- **Broadband Integration Map**: Multi-layer visualization with toggleable overlays
- **Schools Performance Map**: Geocoded schools with performance metrics

### Analysis Reports
- Historical redlining pattern analysis
- Broadband access distribution studies
- Educational outcome correlations
- Spatial overlay analysis between all datasets

## Getting Started

### Prerequisites
- R (>= 4.0.0) with RStudio
- Python (>= 3.8) for map processing
- Google Maps API key for geocoding (optional)

### Installation

1. **Clone the repository**
   ```bash
   git clone [repository-url]
   cd digital_redlining
   ```

2. **Install R dependencies**
   ```r
   install.packages(c("sf", "leaflet", "dplyr", "ggplot2", "shiny", 
                      "terra", "magick", "htmlwidgets", "plotly"))
   ```

3. **Install Python dependencies**
   ```bash
   cd cleveland-broadband-analysis
   pip install -r requirements.txt
   ```

### Running the Analysis

1. **Start with the main EDA report**
   ```r
   rmarkdown::render("digital_redlining_eda_consolidated.Rmd")
   ```

2. **Generate broadband integration analysis**
   ```r
   rmarkdown::render("broadband_map_integration.Rmd")
   ```

3. **View interactive outputs**
   - Open generated HTML files in your browser
   - Look for files like `digital_redlining_eda_consolidated.html`

## Data Processing Workflows

### Broadband Map Digitization
The project includes sophisticated computer vision techniques to extract broadband speed polygons from PDF maps:

1. **PDF to Image Conversion**: Extract high-resolution map images
2. **Color Classification**: Identify speed categories by color
3. **Polygon Vectorization**: Convert raster regions to vector polygons
4. **Spatial Referencing**: Georeference extracted polygons to real-world coordinates

### School Data Geocoding
Accurate geocoding of Cleveland schools using:
- Address validation and normalization
- Google Maps API integration
- Coordinate verification and quality checks
- Fallback strategies for problematic addresses

### Spatial Analysis
- **Overlay Analysis**: Intersect redlining boundaries with broadband coverage
- **Correlation Studies**: Statistical analysis of spatial relationships
- **Visualization**: Interactive maps with multiple data layers

## Key Findings

The analysis reveals several important patterns:

1. **Digital Redlining Persistence**: Areas with historical D-grade (Hazardous) HOLC ratings show significantly lower broadband speeds
2. **Educational Disparities**: Schools in historically redlined areas demonstrate different performance patterns
3. **Spatial Clustering**: Both broadband access and school performance show strong spatial autocorrelation
4. **Intervention Opportunities**: Specific geographic areas identified for targeted digital equity programs

## Usage Examples

### Generate Interactive Map
```r
# Load required libraries
library(leaflet)
library(sf)
library(dplyr)

# Create multi-layer map
map <- leaflet() %>%
  addProviderTiles("CartoDB.Positron") %>%
  addPolygons(data = redlining_data, 
              color = ~holc_colors(grade),
              group = "Historical Redlining") %>%
  addPolygons(data = broadband_data,
              color = ~speed_colors(speed_category),
              group = "Broadband Speeds") %>%
  addLayersControl(overlayGroups = c("Historical Redlining", "Broadband Speeds"))
```

### Spatial Analysis
```r
# Analyze broadband coverage by HOLC grade
redlining_broadband <- st_intersection(redlining_data, broadband_data)
summary_stats <- redlining_broadband %>%
  group_by(holc_grade, speed_category) %>%
  summarise(area = sum(st_area(.)), .groups = "drop")
```

## Contributing

This project is part of ongoing research into digital equity and educational outcomes. Contributions are welcome in the following areas:

- Data validation and quality improvements
- Additional spatial analysis techniques
- Visualization enhancements
- Documentation improvements
- Code optimization

## Data Privacy and Ethics

This research uses publicly available data sources and follows best practices for educational data analysis:
- No personally identifiable student information is used
- School-level data is aggregated and anonymized where appropriate
- All data sources are properly cited and attributed

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Digital Scholarship Lab at University of Richmond for Mapping Inequality data
- BroadbandOhio for broadband coverage maps
- Ohio Department of Education for school performance data
- Cleveland Municipal School District for educational data

## Contact

For questions about this research or collaboration opportunities, please contact:
- **Author**: ProKofa Solutions, LLP
- **Project**: Digital Redlining and Educational Outcomes Research

---

**Note**: This project represents ongoing research into digital equity and educational outcomes. Results should be interpreted within the context of broader socioeconomic factors affecting educational achievement. 