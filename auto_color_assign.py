import pandas as pd
import numpy as np
from colorsys import rgb_to_hls, hls_to_rgb
import random

# Convert HEX to RGB
def hex_to_rgb(hex_color):
    hex_color = hex_color.lstrip('#')
    return tuple(int(hex_color[i:i+2], 16) for i in (0, 2, 4))

# Convert RGB to HSL
def rgb_to_hsl(r, g, b):
    r, g, b = r/255, g/255, b/255
    h, l, s = rgb_to_hls(r, g, b)
    return h * 360, s * 100, l * 100

# Convert HEX to HSL
def hex_to_hsl(hex_color):
    rgb = hex_to_rgb(hex_color)
    return rgb_to_hsl(*rgb)

def hsl_to_hex(hue, saturation, lightness):
    r, g, b = hls_to_rgb(hue / 360, lightness / 100, saturation / 100)
    return "#{:02x}{:02x}{:02x}".format(int(r * 255), int(g * 255), int(b * 255))

# For all new letters, add a row.
# Function to get new hue
def get_new_hue(pango_lineage_df):
    hues = pango_lineage_df['hue'].dropna().sort_values().values
    hue_diff = np.diff(hues)
    max_gap_index = np.argmax(hue_diff)

    return int(hues[max_gap_index] + hue_diff[max_gap_index] / 2)

# Add new lineage letters
def add_new_lineage_letters(distinct_lineage_letter_df, predetermined_lineages):
    for _, row in distinct_lineage_letter_df.iterrows():
        hue = get_new_hue(predetermined_lineages)
        saturation, lightness = 100, 50
        color = hsl_to_hex(hue, saturation, lightness)
        lineage_value = f"{row['pango_letters']}.{row['numbers']}" if row['numbers'] not in [None, '', np.nan] else row['pango_letters']
        new_row = {
            'feature': 'Pango_lineage', 'value': lineage_value, 'pango_letters': row['pango_letters'], 'numbers': row['numbers'], 
            'hue': hue, 'saturation': saturation, 'lightness': lightness, 'color': color
        }
        predetermined_lineages = pd.concat([predetermined_lineages, pd.DataFrame([new_row])], ignore_index=True)
    return predetermined_lineages

# Process new number DataFrame
def process_new_number_df(new_number_df, predetermined_lineages):
    for _, row in new_number_df.iterrows():
        pango_letters = row['pango_letters']
        hue = predetermined_lineages.loc[predetermined_lineages['pango_letters'] == pango_letters, 'hue'].iloc[0]
        saturation = random.uniform(50, 100)
        lightness = random.uniform(50, 100)
        color = hsl_to_hex(hue, saturation, lightness)
        lineage_value = f"{row['pango_letters']}.{row['numbers']}" if row['numbers'] not in [None, '', np.nan] else row['pango_letters']
        new_row = {
            'feature': 'Pango_lineage', 'value': lineage_value, 'pango_letters': pango_letters, 'numbers': row['numbers'], 
            'hue': hue, 'saturation': saturation, 'lightness': lightness, 'color': color
        }
        predetermined_lineages = pd.concat([predetermined_lineages, pd.DataFrame([new_row])], ignore_index=True)
    return predetermined_lineages

def main():
    # Read the current pangocolors CSV, read in all the lineages in arizona, gather new colors accordingly
    pangocolors = pd.read_csv('pangocolors.csv')
    pangocolors_lineages = pangocolors['value'].values.tolist()
    arizona_meta = pd.read_csv('arizona_meta.tsv', sep='\t')
    all_arizona_lineages = arizona_meta['Pango lineage'].unique().tolist()
    missing_lineages = list(set(all_arizona_lineages) - set(pangocolors_lineages))
    
    # Create a dataframe using the new lineages
    new_lineage_df = pd.DataFrame({
        'feature': ['Pango_lineage'] * len(missing_lineages),
        'value': missing_lineages,
        'color': [''] * len(missing_lineages)
    })
    new_lineage_df = new_lineage_df[~new_lineage_df['value'].isna()]
    # If there are no new colors, write to the running_NS directory and exit.
    if new_lineage_df.empty:
        pangocolors.to_csv('running_NS/config/colors.tsv', index=False, header=False, sep='\t', mode='a')
        exit()

    # Read new_lineage_df, get the lineage letters and numbers.
    new_lineage_df[['pango_letters', 'numbers']] = new_lineage_df['value'].str.split('.', n=1, expand=True)
    new_lineage_df['numbers'] = new_lineage_df['numbers'].fillna('')

    # Do not process NA lineages because the color generation functions cannot handle NA lineages
    pangocolors=pangocolors[~pangocolors['value'].isna()]

    # Separate 'value' into 'pango_letters' and 'numbers'. Same as above
    pangocolors[['pango_letters', 'numbers']] = pangocolors['value'].str.split('.', n=1, expand=True)
    pangocolors['numbers'] = pangocolors['numbers'].fillna('')

    # Calculate HSL values for each row. Only hue is used.
    pangocolors[['hue', 'saturation', 'lightness']] = pangocolors['color'].dropna().apply(lambda x: pd.Series(hex_to_hsl(x)))

    # Get all the distinct letters that do not exist in pangocolored. New letters get a new color. Similar letters and different numbers just get a new saturation and lightness value.
    distinct_lineage_df = new_lineage_df.drop_duplicates(subset=['pango_letters'])
    distinct_lineage_letter_df = distinct_lineage_df[~distinct_lineage_df['pango_letters'].isin(pangocolors['pango_letters'])]

    # Add the new lineage letter dataframe to our output dataframe. Assign hues by finding the most distant color possible.
    pangocolors = add_new_lineage_letters(distinct_lineage_letter_df, pangocolors)

    # Get the new number dataframe, meaning the letters are in pangocolors, but the number isn't. 
    new_number_df = new_lineage_df[~new_lineage_df['value'].isin(pangocolors['value'])]

    #Add the new colors, which are slight changes in hue and saturation randomly generated. Each new number gets a randomly generated saturation and lightness, without considering the other colors already assigned.
    pangocolors = process_new_number_df(new_number_df, pangocolors)

    pangocolors = pangocolors[['feature', 'value', 'color']]

    # add in NA as a lineage value again. This is to prevent anything that could be an issue in the future.
    new_row = {'feature': 'Pango_lineage', 'value': 'None', 'color': '#808080'}
    pangocolors = pangocolors.sort_values(by='value')

    # Convert the new row to a DataFrame
    new_row_df = pd.DataFrame([new_row])

    # Concatenate the new row with the original DataFrame
    pangocolors = pd.concat([pangocolors, new_row_df], ignore_index=True)

    # Write the the nextstrain run directory and save the pangocolors locally.
    pangocolors.to_csv('pangocolors.csv', index=False)
    pangocolors.to_csv('running_NS/config/colors.tsv', index=False, header=False, sep='\t', mode='a')
    
if __name__ == "__main__":
    main()