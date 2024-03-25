#!/usr/bin/env bash
#SBATCH --cpus-per-task=14
cd running_NS/data
rm sequences.fasta
rm metadata.tsv
ln -s $( readlink -e ../../subset_sequences.fasta ) sequences.fasta
ln -s $( readlink -e ../../subset_metadata.tsv ) metadata.tsv 
source ~/miniconda3/etc/profile.d/conda.sh
cd ..
conda activate /home/jmonroy-nieto/miniconda3/envs/nextstrain
export PYTHONPATH="$PYTHONPATH:/home/jmonroy-nieto/miniconda3/envs/nextstrain/lib/python3.6/site-packages/augur"
export AUGUR_RECURSION_LIMIT=10000
snakemake --cores 14

