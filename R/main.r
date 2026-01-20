# =========================================================
# Hydrography + Terrain in rayshader
# =========================================================

# 0) Packages
pacman::p_load(
    terra, sf, giscoR, marmap,
    rnaturalearth, png, tidyterra,
    rayshader
)

# 1) Parameters/Inputs
sf::sf_use_s2(FALSE) # sf
crs_work <- "EPSG:3035"
out_file <- "italy.png"
url <- "https://dl.polyhaven.org/file/ph-assets/HDRIs/hdr/4k/snow_field_4k.hdr"
env_hdr <- basename(url)
download.file(
    url = url,
    destfile = env_hdr,
    mode = "wb"
)

# 2) Country geometry (Italy)
countries_sf <- giscoR::gisco_get_countries(
    resolution = "1", region = "Europe"
)

country_sf <- subset(countries_sf, ISO3_CODE == "ITA") # ==
bb <- sf::st_bbox(country_sf)

lon1 <- bb["xmin"] - 2
lon2 <- bb["xmax"] + 2
lat1 <- bb["ymin"] - 2
lat2 <- bb["ymax"] + 2

# 3) Lakes (Italy)
lakes_global <- rnaturalearth::ne_download(
    scale = 10, type = "lakes",
    category = "physical", returnclass = "sf"
)

lakes_country <- sf::st_intersection(
    lakes_global, country_sf
) |> sf::st_transform(crs = crs_work)

# 4) Fetch GEBCO topo+bathy and convert to SpatRaster
bathy_raw <- marmap::getNOAA.bathy(
    lon1, lon2, lat1, lat2,
    resolution = 0.033
)

bathy_rast <- terra::rast(
    marmap::as.raster(bathy_raw)
)

# 5) Land / sea masks on the GEBCO grid
# All European land polygons (so Balkans remain land, not sea)
land_sf <- sf::st_union(countries_sf)

# Rasterize land: 1 = land, NA = sea
land_mask <- terra::rasterize(
    terra::vect(land_sf),
    bathy_rast,
    field = 1
)

# SEA mask: 1 = sea, NA = land
# (We want land to be NA so mask() will drop it later)
sea_mask <- terra::ifel(is.na(land_mask), 1, NA)

# 6) Split topo+bathy into Italy elevation & surrounding sea
# Italy elevation: keep only inside Italy, clamp negatives to 0
country_poly <- terra::vect(country_sf)
elev_country <- terra::mask(
    bathy_rast, country_poly
)
elev_country[elev_country < 0] <- 0

# SEA-only bathymetry
# Step 1: keep only negative values from the full GEBCO grid
bathy_neg <- terra::classify(
    bathy_rast,
    rcl = rbind(c(0, Inf, NA))
)

# Step 2: enforce sea-only: drop ANY land
# (including negative land cells)
# sea_mask: 1 = sea, NA = land
bathy_sea <- terra::mask(bathy_neg, sea_mask)

# 7) Flat sea plane and merged heightmap
# Make a flat sea plane: 0 where ocean exists, NA elsewhere
sea_plane <- terra::classify(
    bathy_sea,
    rcl = rbind(c(-Inf, Inf, -1))
)

# Normalize to 0 (sea level)
sea_plane[!is.na(sea_plane)] <- 0

# Align sea plane to Italy elevation grid
sea_plane_resampled <- terra::resample(
    sea_plane, elev_country,
    method = "near"
)

# Fill NA cells of Italy elevation with the sea plane (0)
# Result: Italy relief + flat sea (0), NA elsewhere
h_flat <- terra::cover(elev_country, sea_plane_resampled)

# 8) Project everything to metric CRS
h_flat <- terra::project(h_flat, crs_work)
bathy_sea <- terra::project(bathy_sea, crs_work)
sea_mask_proj <- terra::project(
    sea_mask, crs_work,
    method = "near"
)

# Resample bathy to match the heightmap grid exactly
bathy_sea <- terra::resample(
    bathy_sea, h_flat,
    method = "bilinear"
)
sea_mask <- terra::resample(
    sea_mask_proj, h_flat,
    method = "near"
)

# 9) Bathymetry color overlay from true depth values
dmin <- -6000
dmax <- 0
bathy_clip <- terra::clamp(
    bathy_sea, dmin, dmax
)

cols <- c(
    "#9ED8FF", "#6BB6F0", "#2C8FD8",
    "#1E6FB5", "#134E8F", "#0E3B70"
)
pal_bathy <- colorRampPalette(
    cols
)(256)

source("https://raw.githubusercontent.com/milos-agathon/3d-bathymetry-terrain/refs/heads/main/R/colorize_to_png.R")

png_path <- colorize_to_png(
    x = bathy_sea,
    align_to = h_flat,
    file = "bathy_classes.png",
    breaks = c(
        -6000, -4000, -2000, -1000, 
        -500, -200, -50, 0
    ),
    cols = c(
        "#0E3B70", "#134E8F", "#1E6FB5",
        "#2C8FD8", "#6BB6F0", "#95C8F8", 
        "#CBE9FF"),
    with_alpha = TRUE
)

img <- png::readPNG(png_path)

# 10) Rayshader: land texture + bathy overlay
hm <- rayshader::raster_to_matrix(
    h_flat
)
pal_land <- tidyterra::hypso.colors2(
    12, "colombia"
)[c(6:8, 11)]
tex_land <- colorRampPalette(
    rev(pal_land), bias = 1
)(128)

hm |>
    rayshader::height_shade(
        texture = rev(tex_land)
    ) |>
    rayshader::add_overlay(
        img, alphalayer = 1
    ) |>
    rayshader::add_overlay(
        rayshader::generate_polygon_overlay(
            lakes_country,
            extent = h_flat,
            heightmap = hm, #heightmap
            linecolor = cols[[4]],
            palette = cols[[4]]
        )
    ) |>
    rayshader::plot_3d(
        hm,
        zscale = 25,
        solid = FALSE,
        shadow = FALSE,
        shadow_darkness = 1,
        background = "white",
        windowsize = c(600, 600),
        zoom = 0.6, phi = 80, theta = 0
    )

rayshader::render_camera(zoom = 0.53)

# 11) Environment light & high-quality render
rayshader::render_highquality(
    filename = out_file,
    preview = TRUE,
    light = FALSE,
    environment_light = env_hdr,
    intensity = 1.2,
    rotate_env = 225,
    parallel = TRUE,
    interactive = FALSE,
    width = 4000,
    height = 4000
)
