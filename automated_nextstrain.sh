#!/usr/bin/env bash
#SBATCH --cpus-per-task=14
#SBATCH --mem=140G
#SBATCH --partition=data-mover
#source /home/bvan-tassel/miniconda3/etc/profile.d/conda.sh
#conda activate /home/bvan-tassel/miniconda3/envs/R

source /home/bvan-tassel/miniforge3/etc/profile.d/conda.sh
conda activate R

rm -r running_NS

builder=/tnorth_labs/COVIDseq/Nextstrain_tools/nextstrain_weekly
seq=/tnorth_labs/COVIDseq/Nextstrain_tools/weekly_DATA/sequences.fasta
meta=/tnorthlabs/COVIDseq/Nextstrain_tools/weekly_DATA/metadata.tsv
style=AZ
config_alt=/tnorth_labs/COVIDseq/Nextstrain_tools/nextstrain_config_alternatives
cp -R ${builder} running_NS
cp -R ${config_alt}/${style}/config.json running_NS/config/config.json
Rscript sample_gisaid.R ${style}
Rscript pangoColors.R

rooter=$(cat root.name)
# Replace VttLJ2gz1X4B with the root name in Snake file
sed -i -e "s/VttLJ2gz1X4B/${rooter:-oldest}/" running_NS/Snakefile
# Sym link the sampled files to the running_NS directory.
ln -s $( readlink -e subset_sequences.fasta ) running_NS/data/sequences.fasta
ln -s $( readlink -e subset_metadata.tsv ) running_NS/data/metadata.tsv

#Run the nextstrain snake file
#source ~/miniconda3/etc/profile.d/conda.sh
#conda activate /home/jmonroy-nieto/miniconda3/envs/nextstrain
conda activate nextstrain
#export PYTHONPATH="$PYTHONPATH:/home/jmonroy-nieto/miniconda3/envs/nextstrain/lib/python3.6/site-packages/augur"
export AUGUR_RECURSION_LIMIT=10000
cd running_NS
snakemake --cores 14

glober=results/out-ncov_*_.json
fileX=$(echo ${glober})
cd ..
today=$(date +"%Y-%m-%d")
python3 github_upload.py -d $today
