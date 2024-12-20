import pandas as pd
import rasterio
import xarray as xr
import numpy as np
import os
import argparse
import matplotlib.pyplot as plt
import scienceplots

plt.style.use(['science', 'grid'])

def geotiff2xr(file_path):
    """
    Convert a GeoTIFF file into an xarray DataArray with spatial and temporal dimensions.

    Parameters
    ----------
    file_path : str
        Path to the GeoTIFF file.

    Returns
    -------
    xarray.DataArray or None
        DataArray representing the GeoTIFF data, or None if the file does not contain SWE or MASK.
    """
    with rasterio.open(file_path) as src:
        data = src.read()
        transform = src.transform
        crs = src.crs
        height = src.height
        width = src.width
        number_of_days = data.shape[0]
        x_coords = np.linspace(transform.c, transform.c + (width - 1) * transform.a, width)
        y_coords = np.linspace(transform.f, transform.f + (height - 1) * transform.e, height)

        if "SWE" in file_path:
            da = xr.DataArray(data, dims=("day", "y", "x"),
                              coords={"day": range(1, number_of_days + 1), "y": y_coords, "x": x_coords}, name="SWE")
            da.attrs["crs"] = crs
            da.attrs["transform"] = transform
            return da
        elif "MASK" in file_path:
            ma = xr.DataArray(data, dims=("Non_seasonal_snow", "y", "x"),
                              coords={"Non_seasonal_snow": range(1, number_of_days + 1), "y": y_coords, "x": x_coords},
                              name="Non_seasonal_snow")
            ma.attrs["crs"] = crs
            ma.attrs["transform"] = transform
            return ma
        else:
            return None

def select_tif(directory, keyword1, keyword2):
    """
    Select GeoTIFF files in a directory matching specific keywords.

    Parameters
    ----------
    directory : str
        Path to the directory containing GeoTIFF files.
    keyword1 : str
        First keyword to filter files.
    keyword2 : str
        Second keyword to filter files.

    Returns
    -------
    list
        List of file paths matching the specified keywords.
    """
    specific_tif_files = [os.path.join(directory, file) for file in os.listdir(directory)
                          if file.endswith('.tif') and keyword1 in file and keyword2 in file]
    return specific_tif_files

def plot_mean_swe_per_year(input_dir, start_year=1999, end_year=2016, output_fig="mean_swe_per_year.png"):
    """
    Create a figure with mean SWE for each year, using subplots for visualization.

    Parameters
    ----------
    input_dir : str
        Path to the directory containing input GeoTIFF files.
    start_year : int
        Start year for the analysis.
    end_year : int
        End year for the analysis.
    output_fig : str
        Path to save the output figure.

    Returns
    -------
    None
    """
    years = range(start_year, end_year + 1)
    fig, axes = plt.subplots(6, 3, figsize=(15, 20), dpi=300)  # Up to 18 plots
    axes = axes.flatten()

    for idx, year in enumerate(years):
        if idx >= len(axes):
            break

        mask_tif = select_tif(input_dir, str(year), "MASK")
        swe_tif = select_tif(input_dir, str(year), "SWE")

        if not mask_tif or not swe_tif:
            print(f"Missing files for year {year}. Skipping...")
            continue

        mask = geotiff2xr(mask_tif[0]).mean(dim="Non_seasonal_snow")
        swe = geotiff2xr(swe_tif[0]).mean(dim="day")

        # Mask non-seasonal snow
        masked_swe = swe.where(mask == 0)

        ax = axes[idx]
        masked_swe.plot.imshow(ax=ax, cmap="viridis", add_colorbar=False)
        mask.plot.imshow(ax=ax, cmap="Reds", alpha=0.4, add_colorbar=False)
        ax.set_title(f"Mean SWE {year}")
        ax.set_xlabel("X")
        ax.set_ylabel("Y")

    # Hide unused subplots
    for ax in axes[len(years):]:
        ax.axis("off")

    plt.tight_layout()
    plt.savefig(output_fig)
    print(f"Mean SWE plots saved to {output_fig}")

def swe_means(input_dir, start_year=1999, end_year=2016):
    """
    Calculate daily mean SWE values for a range of years.

    Parameters
    ----------
    input_dir : str
        Path to the directory containing GeoTIFF files.
    start_year : int
        Start year for the analysis.
    end_year : int
        End year for the analysis.

    Returns
    -------
    pandas.DataFrame
        DataFrame containing daily mean SWE values with dates as the index.
    """
    swe_list = []
    years = range(start_year, end_year + 1)

    for year in years:
        mask_tif = select_tif(input_dir, str(year), "MASK")
        swe_tif = select_tif(input_dir, str(year), "SWE")

        if not mask_tif or not swe_tif:
            print(f"Missing files for year {year}. Skipping...")
            continue

        mask = geotiff2xr(mask_tif[0])
        swe = geotiff2xr(swe_tif[0])

        masked_swe = swe.where(mask == 0)
        mean_swe = masked_swe.mean(dim=['x', 'y'])
        swe_list.append(mean_swe.values.tolist())

    time_series_data = []

    for year_data in swe_list:
        for day_value in year_data:
            time_series_data.append(round(day_value[0], 4))

    date_range = pd.date_range(start=str(start_year) + '-10-01', end=str(end_year + 1) + '-09-30', freq="D")
    swe_df = pd.DataFrame({"Date": date_range, "SWE_Mean": time_series_data})
    swe_df.set_index("Date", inplace=True)

    return swe_df

def plot_annual_swe(input_dir, start_year, end_year, output_file):
    """
    Generate annual mean SWE plots for a range of years.

    Parameters
    ----------
    input_dir : str
        Path to the directory containing GeoTIFF files.
    start_year : int
        Start year for the analysis.
    end_year : int
        End year for the analysis.
    output_file : str
        Path to save the output plot.

    Returns
    -------
    None
    """
    years = range(start_year, end_year + 1)
    ncols = 4
    nrows = -(-len(years) // ncols)

    fig, axes = plt.subplots(nrows=nrows, ncols=ncols, figsize=(15, nrows * 5))
    axes = axes.flatten()

    for idx, year in enumerate(years):
        mask_tif = select_tif(input_dir, str(year), "MASK")
        swe_tif = select_tif(input_dir, str(year), "SWE")

        if not mask_tif or not swe_tif:
            print(f"Missing files for year {year}. Skipping...")
            continue

        mask = geotiff2xr(mask_tif[0])
        swe = geotiff2xr(swe_tif[0])

        masked_swe = swe.where(swe != -999)
        mean_annual_swe_2d = masked_swe.mean(dim="day")

        vmin = mean_annual_swe_2d.min().values
        vmax = mean_annual_swe_2d.max().values

        ax = axes[idx]
        im = mean_annual_swe_2d.plot.imshow(ax=ax, cmap="viridis", add_colorbar=False, vmin=vmin, vmax=vmax)

        ax.ticklabel_format(style="sci", axis="both", scilimits=(0, 0))
        ax.set_title(f"{year}", fontsize=32)
        ax.set_xlabel("")
        ax.set_ylabel("")

    # Adjust layout and add colorbar
    fig.tight_layout()
    cbar = fig.colorbar(im, ax=axes, orientation='vertical', fraction=0.0175, pad=0.02)
    cbar.set_label("SWE [mm]", fontsize=30)
    cbar.ax.tick_params(labelsize=20)

    fig.suptitle("Annual Mean Snow Water Equivalent", fontsize=40, y=1.02)

    for ax in axes[len(years):]:
        ax.remove()

    plt.savefig(output_file, dpi=300, bbox_inches="tight")
    plt.close(fig)
    print(f"Annual SWE plots saved to {output_file}")

def main():
    """
    Main function to parse arguments, calculate SWE means, and optionally generate plots.

    Parameters
    ----------
    None

    Returns
    -------
    None
    """
    parser = argparse.ArgumentParser(description="Calculate SWE means from GeoTIFF files and optionally generate plots.")
    parser.add_argument("--input_dir", required=True,
                        help="Path to the directory containing the input GeoTIFF files.")
    parser.add_argument("--output_csv", required=True,
                        help="Path to save the output CSV file containing SWE means.")
    parser.add_argument("--output_fig", required=False, default="",
                        help="Path to save the output figure with annual SWE plots. Leave blank to skip plot generation.")
    parser.add_argument("--start_year", type=int, default=1999,
                        help="Start year for the analysis (default: 1999).")
    parser.add_argument("--end_year", type=int, default=2016,
                        help="End year for the analysis (default: 2016).")

    args = parser.parse_args()

    print(f"Calculating SWE means for {args.start_year} to {args.end_year}...")
    print(f"Input directory: {args.input_dir}")
    print(f"Output CSV: {args.output_csv}")

    swe_df = swe_means(args.input_dir, start_year=args.start_year, end_year=args.end_year)
    swe_df.to_csv(args.output_csv)
    print(f"SWE means saved to {args.output_csv}")

    if args.output_fig:
        print("Generating annual SWE plots...")
        plot_annual_swe(args.input_dir, args.start_year, args.end_year, args.output_fig)
        print(f"Annual SWE plots saved to {args.output_fig}")
    else:
        print("No output figure specified. Skipping plot generation.")

if __name__ == "__main__":
    main()

