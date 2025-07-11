
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
          "<i style='background:" + broadbandLayerColors[speeds[i]] + "; width: 18px; height: 18px; float: left; margin-right: 8px; opacity: 0.7'></i> " +
          speeds[i] + "<br>";
      }
      
      return div;
    };
    
    broadbandLegend.addTo(map);
  });

