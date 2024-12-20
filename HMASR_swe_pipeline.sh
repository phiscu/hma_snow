#!/bin/bash

################################################################################
# Script Name: HMASR_swe_pipeline.sh
# Description:
#   Processes High Mountain Asia UCLA Daily Snow Reanalysis data to derive
#   catchment-wide mean SWE time series and optionally generate annual SWE plots.
#
# Workflow Overview:
#   1. Data Download: Downloads raw data from NSIDC using a Python script.
#   2. Data Processing: Organizes, mosaics, and reprojects GeoTIFF files.
#   3. Post-Processing: Calculates mean SWE time series and generates annual SWE plots.
#
# Prerequisites:
#   - A NASA EarthData account is required to download data.
#   - EarthData login credentials are requested in the command line.
#   - The following tools and Python libraries must be installed:
#       - GDAL
#       - NCO
#       - parallel
#       - pandas, rasterio, xarray, numpy, matplotlib, argparse, scienceplots
#
# References:
#   - Original data: Liu, Y., Fang, Y., & Margulis, S. A. (2021).
#     High Mountain Asia UCLA Daily Snow Reanalysis, Version 1.
#     DOI: 10.5067/HNAUGJQXSCVU
#     URL: https://nsidc.org/data/HMA_SR_D/versions/1
#   - Data downloader: Based on NSIDC Python script.
#   - Reprojection: Adapted from Simon Gascoin's code 
#     (https://github.com/sgascoin/HMA-Snow-Reanalysis-scripts).
#
# Notes:
#   - Temporary files can consume several gigabytes of disk space depending on 
#     the target area. These files are cleaned up automatically.
#   - Shapefiles need to be provided for processing specific catchments.
#   - The temporal coverage of the dataset is 1999 to 2016.
#
# Usage:
#   ./HMASR_swe_pipeline.sh --threads ALL_CPUS --catchment "Kyzylsuu_final" \
#       --start_y 1999 --end_y 2016 --projEqArea "+proj=aea ..." \
#       --cutline_shp "shp/Catchment_shapefile_new.shp" --SKIP_DOWNLOAD false \
#       --CLEANUP true --modules "nco,anaconda" --output_fig "/annual_swe.png"
#
# Options:
#   --threads         Number of threads to use (default: ALL_CPUS)
#   --catchment       Name of the catchment (default: Kyzylsuu)
#   --start_y         Start year for the analysis (default: 1999)
#   --end_y           End year for the analysis (default: 2016)
#   --projEqArea      Projection string (default: Albers Equal Area)
#   --opt             GDAL compression options (default: COMPRESS=DEFLATE)
#   --cutline_shp     Path to shapefile for cutline (default: shp/Catchment_shapefile_new.shp)
#   --SKIP_DOWNLOAD   Skip data download (default: false)
#   --CLEANUP         Clean up intermediate files (default: true)
#   --modules         Comma-separated list of modules to load.  Use empty value to skip. (default: "nco,anaconda")
#   --output_fig      Path for saving mean daily SWE plots. Default: <catchment>_mean_swe.png
#
# Author: Phillip Schuster
# Date: 2024-12-19
################################################################################

# Default Values
THREADS="ALL_CPUS"
catchment="Kyzylsuu"
start_y=1999
end_y=2016
projEqArea="+proj=aea +lon_0=82.5 +lat_1=29.1666667 +lat_2=41.8333333 +lat_0=35.5 +datum=WGS84 +units=m +no_defs"
opt="?&gdal:co:COMPRESS=DEFLATE"
cutline_shp="shp/Catchment_shapefile_new.shp"
SKIP_DOWNLOAD=false
CLEANUP=true
modules=("nco" "anaconda") # Default modules
output_fig=""

# Parse Command-Line Arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --threads)
            THREADS="$2"
            shift 2
            ;;
        --catchment)
            catchment="$2"
            shift 2
            ;;
        --start_y)
            start_y="$2"
            shift 2
            ;;
        --end_y)
            end_y="$2"
            shift 2
            ;;
        --projEqArea)
            projEqArea="$2"
            shift 2
            ;;
        --opt)
            opt="$2"
            shift 2
            ;;
        --cutline_shp)
            cutline_shp="$2"
            shift 2
            ;;
        --SKIP_DOWNLOAD)
            SKIP_DOWNLOAD="$2"
            shift 2
            ;;
        --CLEANUP)
            CLEANUP="$2"
            shift 2
            ;;
        --modules)
            IFS=',' read -r -a modules <<< "$2"
            shift 2
            ;;
        --output_fig)
            output_fig="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo
            echo "Options:"
            echo "  --threads         Number of threads to use (default: ALL_CPUS)"
            echo "  --catchment       Name of the catchment (default: Kyzylsuu)"
            echo "  --start_y         Start year for the analysis (default: 1999)"
            echo "  --end_y           End year for the analysis (default: 2016)"
            echo "  --projEqArea      Projection string (default: Albers Equal Area)"
            echo "  --opt             GDAL compression options (default: COMPRESS=DEFLATE)"
            echo "  --cutline_shp     Path to shapefile for cutline (default: shp/Catchment_shapefile_new.shp)"
            echo "  --SKIP_DOWNLOAD   Skip data download (default: false)"
            echo "  --CLEANUP         Clean up intermediate files (default: true)"
            echo "  --modules         List of modules to load (default: nco,anaconda). Use empty value to skip."
            echo "  --output_fig      Path for saving mean daily SWE plots. Default: <catchment>_mean_swe.png"
            echo
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
done

# Default output figure path if not specified
if [[ -z "$output_fig" ]]; then
    output_fig="${catchment}_mean_swe.png"
fi

# Load required modules if specified
if [[ ${#modules[@]} -gt 0 ]]; then
    echo "Loading modules: ${modules[*]}"
    for module in "${modules[@]}"; do
        module load "$module" && echo "Loaded $module successfully"
    done
else
    echo "No modules specified. Skipping module loading."
fi

# Options to suppress warnings from GDAL and NetCDF
export CPL_LOG=/dev/null
export GDAL_DISABLE_READDIR_ON_OPEN=TRUE
export CPL_SUPPRESS_GDAL_ERRORS=YES

echo "Starting main script..."

# Derive bounding box from shapefile (minX, minY, maxX, maxY)
bounding_box=$(ogrinfo -al -so "${cutline_shp}" | grep "Extent" | \
    sed -E 's/.*\(([^,]+), ([^)]+)\) - \(([^,]+), ([^)]+)\).*/\1,\2,\3,\4/')
echo "Bounding box derived from cropline shape: ${bounding_box}"

# Absolute paths for organization
download_dir=$(pwd)
catchment_dir="${download_dir}/${catchment}"
processed_dir="${catchment_dir}/processed"
mask_dir="${catchment_dir}/MASK"
swe_dir="${catchment_dir}/SWE_SCA_POST"

# Ensure directories exist
mkdir -p "${mask_dir}" "${swe_dir}" "${processed_dir}"

# Calculate end_y + 1 (hydrological vs. calendar years)
end_y_plus1=$((end_y + 1))

# Conditional execution: Run the Python data downloader script only if SKIP_DOWNLOAD is false
if [[ "${SKIP_DOWNLOAD}" == "false" ]]; then
    echo "Downloading data..."
    python3 nsidc_data_downloader.py \
        --time_start "${start_y}-10-01T00:00:00Z" \
        --time_end "${end_y_plus1}-09-30T23:59:59Z" \
        --bounding_box "${bounding_box}"
else
    echo "Skipping data download as SKIP_DOWNLOAD=true"
fi

# Organize downloaded files
echo "Organizing downloaded files..."
for file in "${download_dir}"/*.nc "${download_dir}"/*.xml; do
    if [[ $file == *_MASK.nc ]]; then
        mv "$file" "${mask_dir}/"
    elif [[ $file == *_SWE_SCA_POST.nc ]]; then
        mv "$file" "${swe_dir}/"
    elif [[ -f $file ]]; then
        rm -f "$file"
        echo "Deleted unnecessary file: $file"
    fi
done

echo "Download cleanup complete."

# List of variables to process and their specific layer names
declare -A var_layers
var_layers["SWE_SCA_POST"]="SWE_Post"
var_layers["MASK"]="Non_seasonal_snow_mask"

# Main Loop to process each variable
for v in "${!var_layers[@]}"; do
    layer_name=${var_layers[$v]}

    # Set paths for input, sliced, and transposed data
    if [[ "$v" == "SWE_SCA_POST" ]]; then
        pin="${swe_dir}"
    elif [[ "$v" == "MASK" ]]; then
        pin="${mask_dir}"
    fi

    psliced="${pin}/sliced/"
    pout="${pin}/transposed/"
    mkdir -p "${psliced}" "${pout}"

    echo "Processing variable: ${v}"
    echo "Input directory: ${pin}"
    echo "Sliced directory: ${psliced}"
    echo "Transposed directory: ${pout}"

    # Extract and rearrange NetCDF files
    nc_files=(${pin}/*.nc)
    if [[ ${#nc_files[@]} -gt 0 ]]; then
        if [[ "$v" == "SWE_SCA_POST" ]]; then
            parallel ncks -v Latitude,Longitude,${layer_name} -d Stats,0,0 {} ${psliced}{/} ::: ${nc_files[@]}
            parallel ncpdq -a Day,Stats,Latitude,Longitude {} ${pout}{/} ::: ${psliced}/*.nc
        elif [[ "$v" == "MASK" ]]; then
            parallel ncks -v Latitude,Longitude,${layer_name} {} ${psliced}{/} ::: ${nc_files[@]}
            parallel ncpdq -a Latitude,Longitude {} ${pout}{/} ::: ${psliced}/*.nc
        fi
    else
        echo "No NetCDF files found for ${v} in ${pin}. Skipping..."
        continue
    fi

    # Mosaicking NetCDF tiles into virtual rasters
    parallel gdalbuildvrt $pout/HMA_SR_D_v01_WY{}_${v}.vrt $pout/*WY{}*nc ::: $(seq ${start_y} ${end_y})

    # Reproject and compute statistics for each year
    parallel -j1 gdalwarp -multi -wo NUM_THREADS=${THREADS} -co COMPRESS=DEFLATE \
        -s_srs EPSG:4326 --config GDALWARP_IGNORE_BAD_CUTLINE YES \
        -r near -t_srs "'"${projEqArea}"'" -crop_to_cutline -cutline ${cutline_shp} \
        $pout/HMA_SR_D_v01_WY{}_${v}.vrt ${processed_dir}/HMA_SR_D_v01_WY{}_${v}_${catchment}.tif \
        ::: $(seq ${start_y} ${end_y})

    # Cleanup intermediate folders if enabled
    if [[ ${CLEANUP} == true ]]; then
        echo "Cleaning up intermediate files for ${v}..."
        rm -rf ${psliced} ${pout}
    fi
done

echo "Processing of .tif files complete. Processed files can be found in: ${processed_dir}"

# Process GeoTIFF files and calculate SWE means
python HMASR_postprocess.py \
    --input_dir "${processed_dir}" \
    --output_csv "${catchment_dir}/${catchment}_mean_swe.csv" \
    --output_fig "${output_fig}" \
    --start_year ${start_y} \
    --end_year ${end_y}

# Final cleanup of MASK and SWE_SCA_POST directories
if [[ ${CLEANUP} == true ]]; then
    echo "Final cleanup: Removing downloaded files in MASK and SWE_SCA_POST directories..."
    rm -rf "${mask_dir}" "${swe_dir}"
    echo "Final cleanup complete."
fi

echo "Processing complete. Final results of the target catchment ${catchment} is saved in: ${catchment_dir}"

