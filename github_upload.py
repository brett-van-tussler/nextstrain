#!/usr/bin/env python
import os
import sys
import subprocess
from datetime import datetime
# Import necessary modules for file operations, subprocess calls, and command-line argument parsing



def main():
    """
    Main function to handle the file operations and GitHub interactions.
    """
    # Find the JSON files needed for processing using the `find` command
    tip_freq_json = subprocess.check_output(
        ['find', './running_NS/results/', '-type', 'f', '-name', 'out-ncov_*tip-frequencies.json']
    ).decode().strip()

    json = subprocess.check_output(
        ['find', './running_NS/results/', '-type', 'f', '-name', 'out-ncov_*json', '!', '-name', 'out-ncov_*tip-frequencies.json']
    ).decode().strip()

    # Extract year and first three letters of the month from the provided date
    current_date = str(datetime.now().date())
    current_year = current_date.split('-')[0]
    first_three_letters = current_date.split('-')[1][:3].upper()
    folder = f"{current_year}{first_three_letters}"

    # Define the destination directory path
    dir_path = f"/tnorth_labs/COVIDseq/Nextstrain_buildArchive/cyclical/{folder}"
    # Create the directory if it doesn't already exist
    os.makedirs(dir_path, exist_ok=True)



    # Validate that the file exists, is not empty, and meets size requirements
    if os.path.isfile(json) and os.stat(json).st_size > 0 and os.stat(json).st_size < 104857600:
        # Copy the JSON files to the cyclical archive folder
        subprocess.run(['cp', json, dir_path])
        subprocess.run(['cp', tip_freq_json, dir_path])

        # Copy the JSON files to the Arizona COVID-19 specific directory
        subprocess.run(['cp', json, '/tnorth_labs/COVIDseq/Nextstrain_buildArchive/arizona-covid-19/auspice/arizona-covid-19_AZ.json'])
        subprocess.run(['cp', tip_freq_json, '/tnorth_labs/COVIDseq/Nextstrain_buildArchive/arizona-covid-19/auspice/arizona-covid-19_AZ_tip-frequencies.json'])

        # Change to the Arizona COVID-19 GitHub directory
        os.chdir('/tnorth_labs/COVIDseq/Nextstrain_buildArchive/arizona-covid-19/auspice')

        # Stage the updated files in Git
        subprocess.run(['git', 'add', 'arizona-covid-19_AZ.json'])
        subprocess.run(['git', 'add', 'arizona-covid-19_AZ_tip-frequencies.json'])

        # Commit the changes with an automated message containing the current date
        subprocess.run(['git', 'commit', '-m', f"Automated update on {current_date}"])

        # Push the changes to the master branch on GitHub
        subprocess.run(['git', 'push', '-u', 'origin', 'master'])
    else:
        # If the file doesn't meet criteria, print a message and exit with an error code
        print(f"File {json} does not meet the size criteria for the Nextstrain automated build. Check the subsampling step to identify if the correct quantity of sequences are being selected and/or check the json.")
        sys.exit(1)

if __name__ == "__main__":
    main()
