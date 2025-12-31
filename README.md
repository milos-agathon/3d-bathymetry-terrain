# 3D Cinematic-Quality maps!

Render a **3D terrain map of Italy** with:
- **Land relief** (topography)
- A **flat sea plane** at sea level
- **Bathymetry color overlay** (depth classes)
- **Lake polygons** drawn on top
- **HDRI environment lighting** for a clean, “cinematic” final render

The script downloads the required boundary, lake, bathymetry, and HDRI assets, builds a heightmap + overlays, then exports a **high-resolution PNG**.

![alt text](https://github.com/milos-agathon/3d-bathymetry-terrain/blob/main/italy.png?raw=true)

---

## What this produces

- **Output file:** `italy.png` (default)
- **Resolution:** 4000 × 4000 (default)
- **Look:** 3D relief with shaded land + colored sea depths + lakes + HDR lighting

---

## How it works (high level)

1. Get **Italy polygon** from GISCO (Europe countries layer).
2. Build a bounding box around Italy (+ margin).
3. Download **global lakes** and clip them to Italy.
4. Download **GEBCO topo+bathy** (NOAA via `marmap`) for the bbox.
5. Create **land and sea masks** (European land union so nearby land stays land).
6. Split raster into:
   - Italy elevation (negatives clamped to 0)
   - Sea-only bathymetry (negatives only + sea mask)
7. Create a **flat sea plane** (0) and merge with Italy elevation to form a single heightmap.
8. Reproject rasters to **EPSG:3035** (metric) and align grids.
9. Convert bathymetry to a **transparent PNG overlay** using class breaks.
10. Shade land + add bathy overlay + add lakes overlay.
11. Render high-quality output with **HDRI environment lighting**.

---

## Requirements

### System
- R (recent version recommended)
- Internet connection (downloads data + HDRI + helper function)

### R packages
The script loads/installs these via `pacman::p_load()`:
- `terra`, `sf`, `giscoR`, `marmap`
- `rnaturalearth`, `png`, `tidyterra`
- `rayshader`

---

## Quick start

1. Save the script as `italy_hydro_rayshader.R` (or any name).
2. Run it from RStudio **or** from the terminal:

```bash
Rscript italy_hydro_rayshader.R
````

When it finishes, you should have:

* `italy.png` (final render)
* `bathy_classes.png` (intermediate bathymetry overlay PNG)
* `snow_field_4k.hdr` (downloaded HDRI file)

---

## Customize

### Key parameters you can change

**Working CRS**

```r
crs_work <- "EPSG:3035"
```

* Keep this metric CRS if you want consistent scaling and alignment.

**Bounding box margin**

```r
lon1 <- bb["xmin"] - 2
lon2 <- bb["xmax"] + 2
lat1 <- bb["ymin"] - 2
lat2 <- bb["ymax"] + 2
```

* Increase margin for more surrounding sea/context.

**Bathy resolution**

```r
resolution = 0.033
```

* Lower values = more detail but slower + heavier.

**Depth styling**

```r
breaks = c(-6000, -4000, -2000, -1000, -500, -200, -50, 0)
cols   = c("#0E3B70", "#134E8F", "#1E6FB5", "#2C8FD8", "#6BB6F0", "#95C8F8", "#CBE9FF")
```

* Adjust breaks/colors to match your aesthetic.

**3D camera**

```r
zoom = 0.6; phi = 80; theta = 0
rayshader::render_camera(zoom = 0.53)
```

**Final render size**

```r
width = 4000
height = 4000
```

**HDRI rotation / intensity**

```r
intensity = 1.2
rotate_env = 225
```

---

## Notes & gotchas

### 1) `sf_use_s2(FALSE)`

The script disables `s2`:

```r
sf::sf_use_s2(FALSE)
```

This can avoid geometry quirks in intersections for some datasets.

### 2) Remote `source()` call

The script loads a helper function from GitHub:

```r
source("https://raw.githubusercontent.com/.../colorize_to_png.R?...token=...")
```

This is convenient, but **be aware**:

* Remote code can change.
* Tokens in URLs can expire or should not be committed publicly.

**Best practice:** vendor the helper locally:

1. Download `colorize_to_png.R` into `R/colorize_to_png.R`
2. Replace `source()` with:

```r
source("R/colorize_to_png.R")
```

### 3) Speed

`render_highquality()` can be slow at 4000×4000 depending on your machine.
Try 2000×2000 first while iterating.

---

## Troubleshooting

### `generate_polygon_overlay` error about heightmap / width / height

Make sure you pass:

* `extent = h_flat`
* `heightmap = hm`

(Your script already does this correctly.)

### Missing packages

If `pacman` isn’t installed:

```r
install.packages("pacman")
```

### Download failures

* Check firewall / proxy settings.
* Try running R with permission to write files in the working directory.

---

## Data & credits

* **Country boundaries:** GISCO via `giscoR`
* **Lakes:** Natural Earth via `rnaturalearth`
* **Topo/Bathy:** NOAA/GEBCO via `marmap::getNOAA.bathy()`
* **HDRI environment light:** Poly Haven (`snow_field_4k.hdr`)
* **3D rendering:** `rayshader` / `rayrender`

---

## License

Use freely for personal/educational work.
If you plan to redistribute or publish, ensure you comply with the licenses of:

* Natural Earth
* Poly Haven HDRIs
* Any upstream R package dependencies
* Any downloaded datasets

---

## Author

Made by **milos-makes-maps**
If you build something with it, tag me and share your render.
