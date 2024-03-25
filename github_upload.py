#!/usr/bin/env python
import os
import sys
import subprocess
import argparse

def cmdline_parser():
    parser = argparse.ArgumentParser(description="Upload files to GitHub")
    parser.add_argument("-d", "--date", required=True, help="Date in YYYY-MM-DD format")
    return parser.parse_args()

def main(current_date):
    tip_freq_json = subprocess.check_output(['find', './running_NS/results/', '-type', 'f', '-name', 'out-ncov_*tip-frequencies.json']).decode().strip()
    json = subprocess.check_output(['find', './running_NS/results/', '-type', 'f', '-name', 'out-ncov_*json', '!', '-name', 'out-ncov_*tip-frequencies.json']).decode().strip()
    current_year = current_date.split('-')[0]
    first_three_letters = current_date.split('-')[1][:3].upper()
    folder = f"{current_year}{first_three_letters}"
    dir_path = f"/labs/COVIDseq/Nextstrain_buildArchive/cyclical/{folder}"
    os.makedirs(dir_path, exist_ok=True)
    print(os.stat(json).st_size)
    print(os.stat(json).st_size < 104857600)
    if os.path.isfile(json) and os.stat(json).st_size > 0 and os.stat(json).st_size < 104857600:
        subprocess.run(['cp', json, dir_path])
        subprocess.run(['cp', tip_freq_json, dir_path])
        subprocess.run(['cp', json, '/labs/COVIDseq/Nextstrain_buildArchive/arizona-covid-19/auspice/arizona-covid-19_AZ.json'])
        subprocess.run(['cp', tip_freq_json, '/labs/COVIDseq/Nextstrain_buildArchive/arizona-covid-19/auspice/arizona-covid-19_AZ_tip-frequencies.json'])
        os.chdir('/labs/COVIDseq/Nextstrain_buildArchive/arizona-covid-19/auspice')
        subprocess.run(['git', 'add', 'arizona-covid-19_AZ.json'])
        subprocess.run(['git', 'add', 'arizona-covid-19_AZ_tip-frequencies.json'])
        subprocess.run(['git', 'commit', '-m', f"Automated update on {current_date}"])
        subprocess.run(['git', 'push', '-u', 'origin', 'master'])
    else:
        print(f"File {json} does not meet the size criteria for the Nextstrain automated build. Please check.")
        sys.exit(1)

if __name__ == "__main__":
    args = cmdline_parser()
    main(args.date)

