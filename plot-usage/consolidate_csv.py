import pandas as pd
from datetime import datetime

# Read the input CSV file
input_file = 'output.csv'
df = pd.read_csv(input_file)

# Convert date column to datetime
df['date'] = pd.to_datetime(df['date'], format='%a %b %d %H:%M:%S UTC %Y')

# Group by username and jobid, and get min/max dates
result = df.groupby(['username', 'jobid'])['date'].agg(['min', 'max']).reset_index()

# Rename columns to match desired output
result.columns = ['username', 'jobid', 'start_date', 'end_date']

# Format datetime columns to match input format
result['start_date'] = result['start_date'].dt.strftime('%a %b %d %H:%M:%S UTC %Y')
result['end_date'] = result['end_date'].dt.strftime('%a %b %d %H:%M:%S UTC %Y')

# Write to output CSV
output_file = 'processed_output.csv'
result.to_csv(output_file, index=False)

print(f"Output written to {output_file}")
