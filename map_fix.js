// Enhanced map indicator switching functionality
document.addEventListener('DOMContentLoaded', function() {
  console.log('DOM loaded, initializing enhanced map functionality');
  
  // Function to update map display based on selected indicator
  window.showIndicator = function(indicatorName) {
    console.log('showIndicator called with:', indicatorName);
    
    // Find all map elements
    const mapContainers = document.querySelectorAll('[id^="map-"]');
    console.log('Found', mapContainers.length, 'map containers');
    
    // Hide all maps
    mapContainers.forEach(container => {
      container.style.display = 'none';
    });
    
    // Show the selected map
    const selectedMapId = 'map-' + indicatorName;
    const selectedMap = document.getElementById(selectedMapId);
    
    if (selectedMap) {
      console.log('Found and displaying map:', selectedMapId);
      selectedMap.style.display = 'block';
      
      // Force redraw of any leaflet maps
      setTimeout(function() {
        window.dispatchEvent(new Event('resize'));
      }, 100);
    } else {
      console.error('Selected map not found:', selectedMapId);
    }
  };
  
  // Set up dropdown listener
  const dropdown = document.getElementById('indicator-select');
  if (dropdown) {
    console.log('Found dropdown element');
    
    // Set initial selection
    if (dropdown.options.length > 0 && !dropdown.value) {
      dropdown.selectedIndex = 0;
    }
    
    // Trigger initial display
    if (dropdown.value) {
      console.log('Initial indicator:', dropdown.value);
      showIndicator(dropdown.value);
    }
    
    // Attach event listener
    dropdown.addEventListener('change', function() {
      console.log('Dropdown changed to:', this.value);
      showIndicator(this.value);
    });
  }
});
