// Add broadband layer
// This script adds a broadband speed layer to an existing Leaflet map
// It needs the global 'map' variable to exist

// Create the broadband layer when the page is fully loaded
window.addEventListener('load', function() {
    console.log('Broadband layer script executing on window load...');
    
    // First, ensure the map exists
    if (typeof map === 'undefined') {
        console.error('ERROR: Map not found! Broadband layer cannot be added.');
        return;
    }
    
    console.log('Map found, loading broadband data...');
    
    var broadbandLayerColors = {
        "0-9 Mbps": "#d73027",
        "10-24 Mbps": "#ff7b00", 
        "25-49 Mbps": "#fdae61",
        "50-100 Mbps": "#abd9e9",
        "100+ Mbps": "#0e8c0e"
    };
    
    // Create a global variable for the broadband layer
    window.broadbandLayer = null;
    
    // Add broadband speed layer
    fetch("cleveland_broadband_speeds_no_legend.geojson")
        .then(response => {
            console.log("GeoJSON response status:", response.status);
            if (!response.ok) {
                throw new Error('Network response was not ok: ' + response.statusText);
            }
            return response.json();
        })
        .then(data => {
            console.log('Broadband data loaded successfully!');
            console.log('Number of features:', data.features.length);
            
            // Verify coordinate system
            if (data.crs && data.crs.properties && data.crs.properties.name === "urn:ogc:def:crs:OGC:1.3:CRS84") {
                console.log('Coordinate system verified: CRS84');
            } else {
                console.warn('Warning: Unexpected coordinate system or missing CRS information');
            }
            
            // Create the GeoJSON layer with coordinate validation
            window.broadbandLayer = L.geoJSON(data, {
                coordsToLatLng: function(coords) {
                    // Ensure coordinates are in [longitude, latitude] order for CRS84
                    // Leaflet expects [latitude, longitude]
                    return new L.LatLng(coords[1], coords[0]);
                },
                style: function(feature) {
                    return {
                        fillColor: feature.properties.color,
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
            
            // Check if any features were added to the layer
            var featureCount = 0;
            window.broadbandLayer.eachLayer(function() { featureCount++; });
            console.log('Number of features added to the layer:', featureCount);
            
            if (featureCount === 0) {
                console.error('No features were added to the broadband layer!');
                return;
            }
            
            // Add to the map
            window.broadbandLayer.addTo(map);
            console.log('Broadband layer added to map');
            
            // Force the map to redraw
            map.invalidateSize();
            
            // Get the bounds of the broadband layer and fit the map to it
            // Only do this if there are features
            if (featureCount > 0) {
                var bounds = window.broadbandLayer.getBounds();
                console.log('Broadband layer bounds:', bounds);
                
                // Check if the Cleveland center is within the bounds
                var clevelandCenter = L.latLng(41.4993, -81.6944);
                var containsCenter = bounds.contains(clevelandCenter);
                console.log('Bounds contain Cleveland center:', containsCenter);
                
                // Only adjust view if bounds are reasonable and contain Cleveland
                if (bounds.isValid() && containsCenter) {
                    map.fitBounds(bounds, {
                        padding: [50, 50], // Add padding around bounds
                        maxZoom: 14 // Limit maximum zoom level
                    });
                    console.log('Map view updated to fit broadband layer');
                } else {
                    console.warn('Broadband layer bounds seem invalid or do not contain Cleveland center');
                    // Fall back to Cleveland center
                    map.setView(clevelandCenter, 12);
                }
            }
            
            // Add legend for broadband speeds
            var broadbandLegend = L.control({position: "bottomright"});
            broadbandLegend.onAdd = function(map) {
                var div = L.DomUtil.create("div", "info legend");
                div.innerHTML = "<h4>Broadband Speeds</h4>";
                
                var speeds = ["0-9 Mbps", "10-24 Mbps", "25-49 Mbps", "50-100 Mbps", "100+ Mbps"];
                
                for (var i = 0; i < speeds.length; i++) {
                    div.innerHTML += 
                        "<div style='margin-bottom:5px;'>" +
                        "<i style='background:" + broadbandLayerColors[speeds[i]] + 
                        "; width: 18px; height: 18px; float: left; margin-right: 8px; opacity: 0.7'></i> " +
                        speeds[i] + "</div>";
                }
                
                return div;
            };
            
            broadbandLegend.addTo(map);
            console.log('Broadband legend added to map');
        })
        .catch(error => {
            console.error('Error loading broadband data:', error);
        });
});

