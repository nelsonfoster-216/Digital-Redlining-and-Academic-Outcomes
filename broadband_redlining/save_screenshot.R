#!/usr/bin/env Rscript

# Save the screenshot as broadband_map.png
library(magick)

# For now, create a placeholder image with sample broadband zones
# In practice, you would save the actual screenshot you provided
img <- image_blank(width = 1200, height = 800, color = "#ffffff")
img <- image_draw(img)

# Fill background with light green
rect(0, 0, 1200, 800, col = "#abd9e9", border = NA)

# Draw some sample zones that mimic the screenshot

# Red zones (0-9 Mbps)
polygon(c(600, 650, 700, 680, 600), c(400, 380, 450, 500, 400), 
        col = "#d73027", border = NA)

# Orange zones (10-24 Mbps)
polygon(c(400, 500, 550, 480, 400), c(300, 280, 350, 400, 300), 
        col = "#f46d43", border = NA)

# Yellow zones (25-49 Mbps)
polygon(c(700, 800, 850, 780, 700), c(200, 180, 250, 300, 200), 
        col = "#fdae61", border = NA)

# Light green zones (50-100 Mbps)
polygon(c(200, 300, 350, 280, 200), c(500, 480, 550, 600, 500), 
        col = "#abd9e9", border = NA)

# Dark green zones (100+ Mbps)
polygon(c(800, 900, 950, 880, 800), c(600, 580, 650, 700, 600), 
        col = "#74add1", border = NA)

# Add some roads
lines(c(0, 1200), c(400, 400), col = "black", lwd = 3)
lines(c(600, 600), c(0, 800), col = "black", lwd = 3)
lines(c(200, 800), c(200, 600), col = "black", lwd = 3)

dev.off()

# Save the image
image_write(img, path = "broadband_map.png")

cat("Created broadband_map.png with sample zones.\n")
cat("You should replace this with the actual screenshot for accurate results.\n")
cat("Now you can run image_process_broadband.R to extract the polygons.\n") 