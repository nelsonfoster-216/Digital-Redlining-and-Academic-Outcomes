library(shiny)
library(leaflet)
library(sf)
library(dplyr)

# Set path to data file
redlining_file <- file.path(gsub("^~", Sys.getenv("HOME"), "~/digital_redlining/redlining_map_data/geojson.json"))

# Define colors for HOLC grades
holc_colors <- c(
  "A" = "#76a865",  # Green - "Best"
  "B" = "#7cb5bd",  # Blue - "Still Desirable" 
  "C" = "#ffff00",  # Yellow - "Definitely Declining"
  "D" = "#d9533c"   # Red - "Hazardous"
)

# Prepare data (outside the server function to load only once)
redlining_data <- NULL
if (file.exists(redlining_file)) {
  redlining_data <- sf::st_read(redlining_file, quiet = TRUE)
  message("Successfully loaded redlining data with ", nrow(redlining_data), " features")
} else {
  message("WARNING: Redlining GeoJSON file not found at: ", redlining_file)
}

# Define UI
ui <- fluidPage(
  titlePanel("Cleveland Redlining Map Test"),
  
  # Add CSS for proper map display
  tags$head(
    tags$style(HTML("
      .leaflet-container {
        height: 600px !important;
        width: 100% !important;
      }
    "))
  ),
  
  # Add a simple status indicator
  wellPanel(
    textOutput("status")
  ),
  
  # Map output
  leafletOutput("map", height = "600px"),
  
  # Debug controls
  hr(),
  actionButton("refresh", "Force Refresh Map"),
  verbatimTextOutput("debug")
)

# Define server logic
server <- function(input, output, session) {
  # Status output
  output$status <- renderText({
    if (is.null(redlining_data)) {
      "ERROR: Redlining data could not be loaded."
    } else {
      paste("Redlining data loaded with", nrow(redlining_data), "features")
    }
  })
  
  # Render map
  output$map <- renderLeaflet({
    leaflet() %>%
      addProviderTiles(providers$CartoDB.Positron) %>%
      setView(lng = -81.6944, lat = 41.4993, zoom = 11)
  })
  
  # Add redlining data after the map is rendered
  observe({
    if (!is.null(redlining_data)) {
      leafletProxy("map") %>%
        clearShapes() %>%
        addPolygons(
          data = redlining_data,
          fillColor = ~ifelse(grade %in% names(holc_colors), 
                             holc_colors[grade], 
                             "#CCCCCC"),
          fillOpacity = 0.7,
          color = "#444444",
          weight = 1,
          label = ~paste("Grade:", grade),
          group = "Redlining Districts"
        ) %>%
        addLegend(
          position = "bottomleft",
          colors = unname(holc_colors),
          labels = paste("Grade", names(holc_colors)),
          title = "HOLC Grades (1930s)",
          opacity = 0.7
        )
    }
  })
  
  # Force map refresh
  observeEvent(input$refresh, {
    session$sendCustomMessage(type = "mapRedraw", message = list())
    output$debug <- renderPrint({
      "Map refresh triggered"
    })
  })
}

# Add JavaScript to force map redraws
addResourcePath("js", ".")
jsCode <- "
Shiny.addCustomMessageHandler('mapRedraw', function(message) {
  // Force map redraw
  window.dispatchEvent(new Event('resize'));
  console.log('Map redraw triggered via Shiny');
});
"

# Create a file with the JavaScript code
writeLines(jsCode, "js/mapRedraw.js")

ui <- tagList(
  ui,
  tags$script(src = "js/mapRedraw.js")
)

# Run the app
shinyApp(ui, server) 