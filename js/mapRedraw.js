
Shiny.addCustomMessageHandler('mapRedraw', function(message) {
  // Force map redraw
  window.dispatchEvent(new Event('resize'));
  console.log('Map redraw triggered via Shiny');
});

