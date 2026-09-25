
import argparse
from pathlib import Path

import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from scipy.signal import savgol_filter

# Input and output paths
parser = argparse.ArgumentParser(
    description="Plot individual traces from a behavioural summary workbook."
)
parser.add_argument("input_file", type=Path, help="Summary-data .xlsx workbook.")
parser.add_argument(
    "--output-folder",
    type=Path,
    help="Destination for SVG files (default: beside the workbook).",
)
args = parser.parse_args()

file_path = args.input_file.expanduser().resolve()
if not file_path.is_file():
    raise FileNotFoundError(f"Workbook not found: {file_path}")
output_folder = (
    args.output_folder.expanduser().resolve()
    if args.output_folder
    else file_path.parent
)
output_folder.mkdir(parents=True, exist_ok=True)

# Sheets and Y-axis labels
sheets_info = {
    "press-rate": "Lever Press Rate (press/min)",
    "mag-rate": "Magazine Entry Rate (entries/min)",
    "session-time": "Session Time (minutes)"
}

# Training day columns
training_days = ['1st_cont', 'RI15', 'RI30-1', 'RI30-2', 'RI30-3', 'RI30-retrain']
margin = 0.10  # 10% margin for Y-axis limit
window_length = 3  # smoothing window (must be odd)
polyorder = 1      # polynomial order for smoothing

# Loop through sheets
for sheet_name, y_label in sheets_info.items():
    df = pd.read_excel(file_path, sheet_name=sheet_name)

    # (Line 19) Compute max for this sheet and apply margin
    max_val = df[training_days].max().max()
    y_max_limit = max_val * (1 + margin)

    # Separate groups
    bipac_df = df[df['Subject'].str.startswith('BP')]
    control_df = df[df['Subject'].str.startswith('CT')]

    # Plot
    plt.figure(figsize=(10, 6))
    x = np.arange(len(training_days))

    # BiPAC subjects
    for _, row in bipac_df.iterrows():
        y = row[training_days].values
        y_smooth = savgol_filter(y, window_length, polyorder)
        plt.plot(x, y_smooth, '-o', alpha=0.7, color='blue')

    # Control subjects
    for _, row in control_df.iterrows():
        y = row[training_days].values
        y_smooth = savgol_filter(y, window_length, polyorder)
        plt.plot(x, y_smooth, '-o', alpha=0.7, color='orange')

    plt.xticks(x, training_days, rotation=45)
    plt.ylabel(y_label)
    plt.xlabel('Training Days')
    plt.title(f'Individual Traces - {sheet_name.capitalize()}')

    # Apply Y-axis limit
    plt.ylim(0, y_max_limit)
    
    # Add legend for groups
    from matplotlib.lines import Line2D
    legend_elements = [
    Line2D([0], [0], color='blue', lw=2, label='BiPAC'),
    Line2D([0], [0], color='orange', lw=2, label='Control')
    ]
    plt.legend(handles=legend_elements, loc='upper left')

    
    plt.tight_layout()

    # Save as SVG
    output_file = output_folder / f"{sheet_name}_individual_traces.svg"
    plt.savefig(output_file, format="svg")
    plt.close()

    print(f"Saved: {output_file}")
