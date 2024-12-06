#!/usr/bin/env bash
#SBATCH --cpus-per-task=14
#SBATCH --mem=140G
#SBATCH --partition=data-mover
#source /home/bvan-tassel/miniconda3/etc/profile.d/conda.sh
#conda activate /home/bvan-tassel/miniconda3/envs/R

source /home/bvan-tassel/miniforge3/etc/profile.d/conda.sh
conda activate R

rm -r running_NS

builder=nextstrain_weekly
seq=/tnorth_scratch/bvan-tassel/gisaid_api_downloads/gisaid.fasta
meta=/tnorth_scratch/bvan-tassel/gisaid_api_downloads/gisaid_meta.tsv
style=AZ
config_alt=/tnorth_labs/COVIDseq/Nextstrain_tools/nextstrain_config_alternatives

# Copy the nextstrain builder, this has the Snakemake file and will be used to run nextstrain.
cp -R ${builder} running_NS
# Get a copy of the nextflow config.json, maps the metadata columns to nextstrain leaf attributes that show on hover and are used for filtering and coloring.
cp -R ${config_alt}/${style}/config.json running_NS/config/config.json

# There are too many genomes to include into the nextstrain, sample these genomes with a likelihood, meaning older genomes are less likely to be selected, and newer ones are more likely.
Rscript sample_gisaid.R ${style}

# Run the auto color assigner to assign colors to new lineages and to write color information into config folder.
conda run -n nextstrain python auto_color_assign.py

# Get the root of the tree 
rooter=$(cat root.name)
# Replace VttLJ2gz1X4B with the root name in Snake file
sed -i -e "s/VttLJ2gz1X4B/${rooter:-oldest}/" running_NS/Snakefile
# Sym link the sampled files to the running_NS directory.
ln -s $( readlink -e subset_sequences.fasta ) running_NS/data/sequences.fasta
ln -s $( readlink -e subset_metadata.tsv ) running_NS/data/metadata.tsv

#Run the nextstrain snake file
conda activate nextstrain
#export PYTHONPATH="$PYTHONPATH:/home/jmonroy-nieto/miniconda3/envs/nextstrain/lib/python3.6/site-packages/augur"
export AUGUR_RECURSION_LIMIT=10000
cd running_NS
snakemake --cores 14

glober=results/out-ncov_*_.json
fileX=$(echo ${glober})
cd ..
today=$(date +"%Y-%m-%d")
# update the github
python3 github_upload.py -d $today
