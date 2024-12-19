# High Mountain Asia Daily Snow Reanalysis Processing Workflow



## Overview

This repository provides a workflow to process the **High Mountain Asia UCLA Daily Snow Reanalysis (HMA-SR)** dataset. It includes:
1. A Bash script for organizing, mosaicking, and reprojecting data.
2. A Python script for downloading the data from NSIDC.
3. A Python script for post-processing GeoTIFF files to calculate mean SWE time series.

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

### Tools
- **GDAL**
- **NCO**
- **parallel**

### Python Libraries
- `pandas`
- `rasterio`
- `xarray`
- `numpy`
- `matplotlib`
- `argparse`

## Usage

1. Replace the example shapefile in the `shp` directory or provide the path to our shapefile in the next step.

2. Run the Bash script with required arguments. Example:
```bash
./process_hma_sr.sh --threads ALL_CPUS --catchment "Kyzylsuu" \
    --start_y 1999 --end_y 2016 --projEqArea "+proj=aea ..." \
    --cutline_shp "shp/Catchment_shapefile_new.shp" --SKIP_DOWNLOAD false \
    --CLEANUP true
```
3. Feel free to use the `HMASR_postprocess.py` script as basis for further analysis.

## Options

- `--threads`: Number of threads to use (default: ALL_CPUS).
- `--catchment`: Name of the catchment (default: Kyzylsuu_final).
- `--start_y`: Start year for the analysis (default: 1999).
- `--end_y`: End year for the analysis (default: 2000).
- `--projEqArea`: Projection string (default: Albers Equal Area).
- `--cutline_shp`: Path to the shapefile for cutline.
- `--SKIP_DOWNLOAD`: Skip downloading data if already present (default: false).
- `--CLEANUP`: Clean up intermediate files (default: true).
- `--modules`: Comma-separated list of modules to load (default: `nco,anaconda`). Use an empty value to skip loading modules.

## Output

Returns two outputs:
1. A directory named `processed` containing two types of `.tif` files.
   - Annual ensemble mean SWE rasters for your catchment with one band per day.
   - Annual binary masks separating seasonal and non-seasonal snow.
3. A `.csv` file with daily catchment-wide mean SWE values for the requested study period.

## Notes

- To process data for a custom catchment, provide the catchment's outline as a shapefile and specify the file path using the `--cutline_shp` option.
- Temporary files may require significant disk space depending on the target area. Ensure sufficient storage is available during processing.
- The temporal coverage of the dataset is 1999 to 2016.

## Prerequisites

### Tools
- **GDAL**
- **NCO**
- **parallel**

### Python Libraries
- `pandas`
- `rasterio`
- `xarray`
- `numpy`
- `matplotlib`

### Acknowledements
- The reprojection and some parts of the workflow are adapted from **Simon Gascoin**'s [HMA-Snow-Reanalysis-scripts](https://github.com/sgascoin/HMA-Snow-Reanalysis-scripts).

## Author
**Phillip Schuster** - (https://github.com/phiscu)
