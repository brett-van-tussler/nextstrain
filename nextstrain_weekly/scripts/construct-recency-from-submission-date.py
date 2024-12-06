import argparse
import re
from datetime import datetime
import sys
import pandas as pd
import json

def get_recency(date_str, ref_date):
    if re.match(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}$", date_str):
        date_str = date_str
    elif re.match(r"^[0-9]{4}-[0-9]{2}$", date_str):
        date_str = date_str + "-01"
    elif re.match(r"^[0-9]{4}$", date_str):
        date_str = date_str + "-01-01"
   # date_str = date_str if re.match(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}$", date_str) else (date_str + "-01" if re.match(r"^[0-9]{4}-[0-9]{2}$", date_str) else (date_str + "-01-01" if re.match(r"^[0-9]{4}$", date_str)))
    date_submitted = datetime.strptime(date_str, '%Y-%m-%d').toordinal()
    ref_day = ref_date.toordinal()

    delta_days = ref_day - date_submitted
    if delta_days<=0:
        return 'New'
    elif delta_days<3:
        return '1-2 days ago'
    elif delta_days<8:
        return '3-7 days ago'
    elif delta_days<15:
        return 'One week ago'
    elif delta_days<31:
        return 'One month ago'
    elif delta_days>=31:
        return 'Older'

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description="Assign each sequence a field that specifies when it was added",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )

    parser.add_argument('--metadata', type=str, required=True, help="metadata file")
    parser.add_argument('--output', type=str, required=True, help="output json")
    args = parser.parse_args()
    ref_date = datetime.now()
    metadata = pd.read_csv(args.metadata, sep='\t')
    metadata['recency'] = metadata['collection_date'].apply(lambda x: get_recency(x, ref_date))

    node_data = {"nodes": {}}

    # Iterate over each row in the 'metadata' DataFrame
    for _, row in metadata.iterrows():
        # Get the strain and recency for the current row
        strain = row['strain']
        recency = row['recency']
        
        # Add the strain and recency to the dictionary
        node_data["nodes"][strain] = {"recency": recency}

    with open(args.output, 'wt') as fh:
        json.dump(node_data, fh)