// Check if broadband layer is properly integrated
// Add this script to the bottom of the HTML file or run in browser console

(function() {
  console.log("Checking broadband layer integration...");
  
  // Check if map exists
  if (typeof map === 'undefined') {
    console.error("Map not found. The Leaflet map instance is not available.");
    return;
  } else {
    console.log("Map found:", map);
  }
  
  // Check if layerControl exists
  if (typeof layerControl === 'undefined') {
    console.warn("Layer control not found. The Leaflet layer control is not available.");
  } else {
    console.log("Layer control found:", layerControl);
    
    // Check if broadband layer is in the layer control
    if (layerControl._overlayMaps) {
      let hasBroadbandLayer = false;
      for (let key in layerControl._overlayMaps) {
        console.log("Overlay layer:", key);
        if (key.includes("Broadband")) {
          hasBroadbandLayer = true;
        }
      }
      console.log("Broadband layer in layer control:", hasBroadbandLayer);
    }
  }
  
  // Check if broadband.geojson is accessible
  fetch("broadband_cleveland.geojson")
    .then(response => {
      console.log("GeoJSON response status:", response.status);
      if (!response.ok) {
        throw new Error(`GeoJSON fetch failed: ${response.status} ${response.statusText}`);
      }
      return response.json();
    })
    .then(data => {
      console.log("GeoJSON data loaded successfully:", data);
      console.log("Number of features:", data.features.length);
    })
    .catch(error => {
      console.error("Error loading GeoJSON:", error);
    });
  
  // Check active layers on the map
  let foundBroadbandLayer = false;
  for (let id in map._layers) {
    const layer = map._layers[id];
    if (layer.feature && layer.feature.properties && layer.feature.properties.speed_category) {
      console.log("Found broadband layer on map:", layer);
      foundBroadbandLayer = true;
    }
  }
  console.log("Broadband layer found on map:", foundBroadbandLayer);
  
  // Check legends
  const legends = document.querySelectorAll('.info.legend');
  let foundBroadbandLegend = false;
  legends.forEach(legend => {
    if (legend.innerHTML.includes("Broadband")) {
      console.log("Found broadband legend:", legend);
      foundBroadbandLegend = true;
    }
  });
  console.log("Broadband legend found:", foundBroadbandLegend);
})(); 