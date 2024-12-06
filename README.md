# nextstrain


## Overview

The `automated_nextstrain.sh` script automates the daily execution of TGen's Nextstrain analysis pipeline. This script is configured to run as a cron job, processing GISAID data, sampling genomes, and building a Nextstrain tree for Arizona-specific sequences.

### SLURM Directives

The script begins with SLURM job specifications:

```bash
#SBATCH --cpus-per-task=14
#SBATCH --mem=140G
#SBATCH --partition=data-mover
```

- **CPUs**: Allocates 14 CPUs for the task.
- **Memory**: Allocates 140 GB of RAM.
- **Partition**: Runs on the `data-mover` partition.

---

### Environment Setup

```bash
source /home/bvan-tassel/miniforge3/etc/profile.d/conda.sh
conda activate R
```

The script activates the `R` Conda environment, used later for genome sampling and other R-based tasks.

---

### Directory Preparation

```bash
rm -r running_NS
cp -R ${builder} running_NS
cp -R ${config_alt}/${style}/config.json running_NS/config/config.json
```

- Removes any existing `running_NS` directory.
- Copies the `nextstrain_weekly` builder (containing the Snakemake workflow) into the `running_NS` directory.
- Updates the Nextstrain configuration file with Arizona-specific settings.

---

### Genome Sampling

```bash
Rscript sample_gisaid.R ${style}
```

This command uses an R script to sample genomes from the GISAID dataset based on a likelihood model, ensuring newer genomes are more likely to be included in the analysis.

---

### Color Assignment

```bash
conda run -n nextstrain python auto_color_assign.py
```

Assigns colors to new lineages for tree visualization in Nextstrain. The color information is added to the configuration folder.

---

### Tree Rooting

```bash
rooter=$(cat root.name)
sed -i -e "s/VttLJ2gz1X4B/${rooter:-oldest}/" running_NS/Snakefile
```

- Retrieves the root name from the `root.name` file.
- Updates the Snakemake file to use the correct root for the phylogenetic tree.

---

### Linking Data Files

```bash
ln -s $( readlink -e subset_sequences.fasta ) running_NS/data/sequences.fasta
ln -s $( readlink -e subset_metadata.tsv ) running_NS/data/metadata.tsv
```

Creates symbolic links for the sampled sequences and metadata files, making them accessible to the Snakemake workflow.

---

### Running the Nextstrain Workflow

```bash
conda activate nextstrain
export AUGUR_RECURSION_LIMIT=10000
cd running_NS
snakemake --cores 14
```

- Activates the `nextstrain` environment.
- Sets `AUGUR_RECURSION_LIMIT` to handle large datasets.
- Executes the Snakemake workflow using 14 cores.

---

### GitHub Update

```bash
python3 github_upload.py
```

Uploads the results to a GitHub repository. This includes metadata and color files used in the Nextstrain visualization.

---

### Cron Job Integration

The script is scheduled to run daily using a cron job. Example cron entry:

```bash
40 1 * * * source /home/bvan-tassel/miniforge3/etc/profile.d/conda.sh && conda activate nextstrain; cd /tnorth_labs/COVIDseq/nextstrain/ && sh automated_nextstrain.sh | mail -s "Nextstrain update" bvan-tassel@tgen.org
```

This schedules the script to run at 1:40 AM every day.

---

### Script Location

Ensure the script is stored in a directory accessible to the SLURM environment and cron job.

---

## Dependencies

1. **Conda Environments**:
   - `R`
   - `nextstrain`
2. **External Tools**:
   - [Snakemake](https://snakemake.readthedocs.io/)
   - [AUGUR](https://docs.nextstrain.org/projects/augur/en/stable/)

## Output

The workflow generates:
- A phylogenetic tree in Nextstrain format.
- Updated metadata and lineage colors.
- Results pushed to [a designated GitHub repository](https://github.com/TGenNorth/arizona-covid-19).

## Notes

- Ensure SLURM, Conda, and Python configurations are properly set up on your system.
- Verify the paths to GISAID data files (`seq` and `meta`) and configuration files.