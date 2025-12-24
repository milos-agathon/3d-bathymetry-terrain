colorize_to_png <- function(
    x,
    file = "bathy_classes.png",
    breaks = c(-6000, -4000, -2000, -1000, -500, -200, -50, 0),
    cols = c(
        "#0E3B70", "#134E8F", "#1E6FB5", "#2C8FD8",
        "#6BB6F0", "#95C8F8", "#CBE9FF"
    ),
    align_to = NULL,
    with_alpha = TRUE) {
    stopifnot(length(cols) == (length(breaks) - 1))

    # Align to reference grid if provided
    if (!is.null(align_to)) {
        x <- terra::resample(x, align_to, method = "bilinear")
    }

    # Reclass matrix: [from, to) → class id
    K <- length(cols)
    rcl <- cbind(breaks[-length(breaks)], breaks[-1], 1:K)
    # Ensure top bin is closed on the right
    rcl[nrow(rcl), 2] <- rcl[nrow(rcl), 2] + 1e-6

    cls <- terra::classify(x, rcl) # integer classes, NA preserved

    # Map class id → RGB bytes
    rgb_tbl <- t(col2rgb(cols)) # K x 3 (0..255)

    # Create empty UINT8 rasters for R,G,B,(A)
    R <- G <- B <- terra::rast(x)
    terra::values(R) <- 0L
    terra::values(G) <- 0L
    terra::values(B) <- 0L

    cls_vals <- terra::values(cls)
    id <- which(!is.na(cls_vals))

    if (length(id)) {
        vals <- cls_vals[id]
        terra::values(R)[id] <- as.integer(rgb_tbl[vals, 1])
        terra::values(G)[id] <- as.integer(rgb_tbl[vals, 2])
        terra::values(B)[id] <- as.integer(rgb_tbl[vals, 3])
    }

    if (with_alpha) {
        A <- terra::rast(x)
        terra::values(A) <- ifelse(is.na(cls_vals), 0L, 255L)
        rgba <- c(R, G, B, A)
        names(rgba) <- c("R", "G", "B", "A")
        terra::writeRaster(rgba, file, datatype = "INT1U", overwrite = TRUE)
    } else {
        rgb <- c(R, G, B)
        names(rgb) <- c("R", "G", "B")
        terra::writeRaster(rgb, file, datatype = "INT1U", overwrite = TRUE)
    }

    invisible(normalizePath(file))
}
