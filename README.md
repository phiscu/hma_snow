# Snow Water Equivalent Extraction Tool for the HMA Daily Snow Reanalysis (SWEETR)

## Overview

This repository provides a workflow to process the **High Mountain Asia UCLA Daily Snow Reanalysis (HMA-SR)** dataset. It includes:
1. A Python script for downloading the data from NSIDC.
2. A Bash script for organizing, mosaicking, and reprojecting data as GeoTIFF files for mapping.
3. A Python script for post-processing to calculate mean SWE time series.

This workflow focuses on **ensemble mean SWE**, but it can be adapted for other variables in the HMA-SR dataset. Please refer to the [original data source](https://nsidc.org/data/HMA_SR_D/versions/1) and the [related publication](https://doi.org/10.1029/2022GL100082) for details on the dataset.

## Workflow Components

### 1. **Data Download**
The dataset is downloaded from the National Snow and Ice Data Center ([NSIDC](https://nsidc.org/home)) using a modified version of the DAAC Data Access Tool Python script. The original dataset is:
- **Liu, Y., Fang, Y., & Margulis, S. A. (2021)**  
  _High Mountain Asia UCLA Daily Snow Reanalysis, Version 1._  
  DOI: [10.5067/HNAUGJQXSCVU](https://doi.org/10.5067/HNAUGJQXSCVU)  
  URL: [NSIDC Data Page](https://nsidc.org/data/HMA_SR_D/versions/1)

The download requires a NASA EarthData account. Register [here](https://urs.earthdata.nasa.gov/users/new). You will be asked for login credentials in the command line.
Due to the data structure on the server side several redundant files need to be downloaded that can take up to several gigabytes. They will be deleted after download.

### 2. **Data Processing**
The Bash script organizes files, reprojects them, and provides catchment-specific raster files (`.tif`) with daily SWE values and the mask for non-seasonal snow. Temporary files can consume significant disk space depending on the area being processed, but they are cleaned up automatically.

### 3. **Post-Processing**
A Python script calculates aggregated SWE time series for the section of the target catchment identified as seasonal snow.

## Requirements
The tool is designed as a command line application and was developed on Ubuntu 22.04. To use it on other OS than Linux make sure the following dependencies are installed and the paths match the required syntax. For Windows users I recommend the Windows Subsystem for Linux (WSL) which can be installed from the Microsoft store.

### Tools
- **GDAL**
- **NCO**
- **parallel**

### Python Dependencies
The following Python libraries are required to run the `HMASR_postprocess.py` script:
- `pandas`
- `rasterio`
- `xarray`
- `numpy`
- `matplotlib`
- `argparse`
- `scienceplots`

Ensure these are installed in your Python environment before running the script.

## Usage

1. Replace the example shapefile in the `shp` directory or specify the path to your shapefile using the `--cutline_shp` option.

2. Run the Bash script with required arguments. Example:
```bash
./HMASR_swe_pipeline.sh --threads ALL_CPUS --catchment "Kyzylsuu" \
    --start_y 1999 --end_y 2016 --projEqArea "+proj=aea +lon_0=82.5 +lat_1=29.1666667 +lat_2=41.8333333 +lat_0=35.5 +datum=WGS84 +units=m +no_defs" \
    --cutline_shp "shp/Catchment_shapefile_new.shp" --SKIP_DOWNLOAD false \
    --CLEANUP true --modules "nco,anaconda" --output_fig "/mean_swe.png"
```
3. Feel free to use the `HMASR_postprocess.py` script as a basis for further analysis. If your plans go beyond mapping and aggregation you might want to set `--CLEANUP false` and use the intermediate `.ncdf` files instead of `.tif` for speed gains and metadata support.

## Options

- `--threads`: Number of threads to use (default: ALL_CPUS).
- `--catchment`: Name of the catchment (default: Kyzylsuu_final).
- `--start_y`: Start year for the analysis (default: 1999).
- `--end_y`: End year for the analysis (default: 2016).
- `--projEqArea`: Projection string (default: Albers Equal Area).
- `--opt`: GDAL compression options (default: COMPRESS=DEFLATE).
- `--cutline_shp`: Path to the shapefile for the cutline.
- `--SKIP_DOWNLOAD`: Skip downloading data if already present (default: false).
- `--CLEANUP`: Clean up intermediate files (default: true).
- `--modules`: Comma-separated list of modules to load (default: `nco,anaconda`). Use an empty value to skip loading modules.
- `--output_fig`: Path for saving annual SWE plots. If left blank, the script generates a plot named `<catchment>_mean_swe.png` in the same directory as the CSV output.

## Output

Returns the following outputs:
1. A directory named `processed` containing two types of `.tif` files.
   - Annual ensemble **mean SWE rasters** for your catchment with one band per day in a 500m spatial resolution.
   - Annual **binary masks** separating seasonal and non-seasonal snow.
2. A `.csv` file with **daily catchment-wide mean SWE** values for the requested study period.
3. **Annual SWE Plot (Optional)**:
   - A PNG figure visualizing the mean daily SWE for each year in the study period.
   - Saved to the path specified by `--output_fig` or defaults to `<catchment>_mean_swe.png`.

## Notes

- Temporary files may require significant disk space depending on the target area. Ensure sufficient storage is available during processing.
- The temporal coverage of the dataset is 1999 to 2016.

## Acknowledements
The reprojection and some parts of the workflow are adapted from **Simon Gascoin**'s [HMA-Snow-Reanalysis-scripts](https://github.com/sgascoin/HMA-Snow-Reanalysis-scripts) repository for his study on the Indus basin:
  - **Gascoin, S. (2021)** Snowmelt and Snow Sublimation in the Indus Basin. Water, 13(19), 2621. DOI: [10.3390/w13192621](https://doi.org/10.3390/w13192621)
  
## Author
**Phillip Schuster** - (https://github.com/phiscu)
