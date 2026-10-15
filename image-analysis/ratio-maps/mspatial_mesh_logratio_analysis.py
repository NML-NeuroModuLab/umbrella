"""
Spatial D2/D1 ratio maps from taSPN datasets
For each mouse and treatment (CTR / STI):  
    A section
    B section
    C section
are loaded, meshed (20 x 20), converted into
    log2((D2 + 0.5)/(D1 + 0.5))
ratio maps and averaged.
Outputs:
    One SVG ratio map per mouse/treatment.
"""
# ---------------------------------------------------------------------
# 1. SETTINGS
# ---------------------------------------------------------------------

import argparse
from pathlib import Path
import re
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

GFP_THRESHOLD = 100
MESH_X = 20
MESH_Y = 20
PSEUDOCOUNT = 0.5
EXCLUDED_SUBJECTS = []

# ---------------------------------------------------------------------
# 2. FILE HELPERS
# ---------------------------------------------------------------------

def parse_filename(file_stem):
    m = re.match(r"(\d+)([ABC])(CTR|STI)", file_stem)
    if m is None:
        return None
    return m.group(1), m.group(2), m.group(3)

def find_dataset_pairs(folder):
    datasets=[]
    for gfp_file in sorted(folder.glob('*_taSPNs_gfp.txt')):
        prefix=gfp_file.name.replace('_taSPNs_gfp.txt','')
        str_file=folder / f'{prefix}_STR.txt'
        if not str_file.exists():
            continue
        parsed=parse_filename(prefix)
        if parsed is None:
            continue
        subject, level, treatment = parsed
        if subject in EXCLUDED_SUBJECTS:
            continue
        datasets.append({'subject':subject,'level':level,'treatment':treatment,'prefix':prefix,'gfp_file':gfp_file,'str_file':str_file})
    return datasets

# ---------------------------------------------------------------------
# 3. LOAD TA-SPNs - load ImageJ taSPN output
# ---------------------------------------------------------------------


def load_taspns(path):
    df = pd.read_csv(path, sep=r'\s+', engine='python')
    df['type']=np.where(df['Mean']>=GFP_THRESHOLD,'D2','D1')
    return df

# ---------------------------------------------------------------------
# 4. BUILD COMMON COORDINATE SPACE
# ---------------------------------------------------------------------

def get_global_bounds(datasets):
    xmins=[]; xmaxs=[]; ymins=[]; ymaxs=[]
    for row in datasets:
        df=load_taspns(row['gfp_file'])
        xmins.append(df['X'].min()); xmaxs.append(df['X'].max())
        ymins.append(df['Y'].min()); ymaxs.append(df['Y'].max())
    return min(xmins), max(xmaxs), min(ymins), max(ymaxs)

# ---------------------------------------------------------------------
# 5. COMPUTE MESH MAP - generate a 20x20 log2(D2/D1) ratio map.
# ---------------------------------------------------------------------

def compute_ratio_map(df,xmin,xmax,ymin,ymax):
    x_edges=np.linspace(xmin,xmax,MESH_X+1)
    y_edges=np.linspace(ymin,ymax,MESH_Y+1)
    ratio_map=np.zeros((MESH_Y,MESH_X))
    for y in range(MESH_Y):
        for x in range(MESH_X):
            cell=df[(df['X']>=x_edges[x])&(df['X']<x_edges[x+1])&(df['Y']>=y_edges[y])&(df['Y']<y_edges[y+1])]
            d1=np.sum(cell['type']=='D1')
            d2=np.sum(cell['type']=='D2')
            ratio_map[y,x]=np.log2((d2+PSEUDOCOUNT)/(d1+PSEUDOCOUNT))
    return ratio_map

# ---------------------------------------------------------------------
# 6. AVERAGE A/B/C MAPS
# ---------------------------------------------------------------------

def average_maps(section_maps):
    stack = np.stack(section_maps, axis=0)
    return np.nanmean(stack, axis=0)

# ---------------------------------------------------------------------
# 7. PLOT MAP - save SVG ratio map
# ---------------------------------------------------------------------

def plot_ratio_map(ratio_map, subject, treatment, output_folder):
    fig, ax = plt.subplots(figsize=(5,5))
    sns.heatmap(ratio_map,cmap='coolwarm',center=0,vmin=-3.5,vmax=3.5,square=True,cbar=True,xticklabels=False,yticklabels=False,ax=ax)
    ax.set_title(f'Mouse {subject} - {treatment}')
    plt.tight_layout()
    fig.savefig(output_folder / f'{subject}_{treatment}_ratio_map.svg', format='svg', bbox_inches='tight')
    plt.close()

# ---------------------------------------------------------------------
# 8. MAIN ANALYSIS
# ---------------------------------------------------------------------

def run_analysis(data_folder, output_folder):
    datasets=find_dataset_pairs(data_folder)
    if not datasets:
        raise FileNotFoundError(
            f"No matched *_taSPNs_gfp.txt and *_STR.txt datasets found in {data_folder}"
        )
    output_folder.mkdir(parents=True, exist_ok=True)
    xmin,xmax,ymin,ymax=get_global_bounds(datasets)
    grouped={}
    for row in datasets:
        grouped.setdefault((row['subject'],row['treatment']),[]).append(row)
    for (subject,treatment), sections in grouped.items():
        maps=[]
        for section in sections:
            df=load_taspns(section['gfp_file'])
            maps.append(compute_ratio_map(df,xmin,xmax,ymin,ymax))
        mean_map=np.nanmean(np.stack(maps,axis=0),axis=0)
        plot_ratio_map(mean_map,subject,treatment,output_folder)


def parse_args():
    parser = argparse.ArgumentParser(
        description="Create spatial D2/D1 ratio maps from ImageJ taSPN outputs."
    )
    parser.add_argument(
        "data_folder",
        type=Path,
        help="Folder containing paired *_taSPNs_gfp.txt and *_STR.txt files.",
    )
    parser.add_argument(
        "--output-folder",
        type=Path,
        help="Destination for SVG files (default: <data_folder>/plots).",
    )
    return parser.parse_args()

# ---------------------------------------------------------------------
# 9. MAIN ENTRY POINT
# ---------------------------------------------------------------------

if __name__ == '__main__':
    args = parse_args()
    data_folder = args.data_folder.expanduser().resolve()
    if not data_folder.is_dir():
        raise NotADirectoryError(f"Data folder not found: {data_folder}")
    output_folder = (
        args.output_folder.expanduser().resolve()
        if args.output_folder
        else data_folder / "plots"
    )
    run_analysis(data_folder,output_folder)
