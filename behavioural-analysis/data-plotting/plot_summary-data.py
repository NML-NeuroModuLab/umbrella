
import argparse
from pathlib import Path

import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from scipy.stats import sem

# Input and output paths
parser = argparse.ArgumentParser(
    description="Plot group means and SEM from a behavioural summary workbook."
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
margin = 0.10 #10% margin for Y-axis limit

for sheet_name, y_label in sheets_info.items():
    # Load sheet
    df = pd.read_excel(file_path, sheet_name=sheet_name)

    # Compute max for this sheet and apply margin
    max_val = df[training_days].max().max()
    y_max_limit = max_val * (1 + margin)

    # Separate groups
    bipac_df = df[df['Subject'].str.startswith('BP')]
    control_df = df[df['Subject'].str.startswith('CT')]

    # Calculate means and SEM
    bipac_means = bipac_df[training_days].mean()
    bipac_sem = bipac_df[training_days].apply(sem)

    control_means = control_df[training_days].mean()
    control_sem = control_df[training_days].apply(sem)

    # Plot
    plt.figure(figsize=(8, 6))
    x = np.arange(len(training_days))

    plt.errorbar(x, bipac_means, yerr=bipac_sem, fmt='-o', capsize=5, label='BiPAC')
    plt.errorbar(x, control_means, yerr=control_sem, fmt='-o', capsize=5, label='Control')

    plt.xticks(x, training_days, rotation=45)
    plt.ylabel(y_label)
    plt.xlabel('Training Days')
    plt.title(f'{sheet_name.capitalize()} Across Training Days')

    plt.ylim(0, y_max_limit) # Apply Y-axis limits from 0 to data max
    plt.legend()
    plt.tight_layout()


    # Save as SVG
    output_file = output_folder / f"{sheet_name}_plot.svg"
    plt.savefig(output_file, format="svg")
    plt.close()

    print(f"Saved: {output_file}")
