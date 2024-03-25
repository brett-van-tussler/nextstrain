#!/usr/bin/env bash
tip_freq_json=$(find ./running_NS/results/ -type f -name 'out-ncov_*tip-frequencies.json')
json=$(find ./running_NS/results -type f -name 'out-ncov_*json' ! -name 'out-ncov_*tip-frequencies.json')

if [ $# -ne 1 ]; then
    echo "Usage: $0 <date>"
    exit 1
fi

current_date="$1"

current_date=$(date +%Y-%m-%d)
current_year=$(date +%Y)
first_three_letters=$(date +%b | cut -c 1-3)
first_three_letters_upper=$(echo "$first_three_letters" | tr '[:lower:]' '[:upper:]')
folder="${current_year}${first_three_letters_upper}"

dir="/labs/COVIDseq/Nextstrain_buildArchive/cyclical/"$folder""

mkdir -p $dir

if [[ -f "$json" && $(stat -c %s "$json") -gt 0 && $(stat -c %s "$json") -lt 104857600 ]]; then
  #Copy the files to appropriate directories
  cp $json $dir
  cp $tip_freq_json $dir
  cp $json /labs/COVIDseq/Nextstrain_buildArchive/arizona-covid-19/auspice/arizona-covid-19_AZ.json
  cp $tip_freq_json /labs/COVIDseq/Nextstrain_buildArchive/arizona-covid-19/auspice/arizona-covid-19_AZ_tip-frequencies.json
  cd /labs/COVIDseq/Nextstrain_buildArchive/arizona-covid-19/auspice
  #add and push to github
  git add arizona-covid-19_AZ.json
  git add arizona-covid-19_AZ_tip-frequencies.json
  git commit -m "Automated update on ${current_date}"
  git push -u origin master

else
  #send an email that this script failed
  echo "File $file does not meet the size criteria for the nextstrain automated build. Please check." | mail -s "File Size Alert" "$usr_name"

fi
