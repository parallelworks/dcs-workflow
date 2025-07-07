import pandas as pd
import matplotlib.pyplot as plt
import argparse
from datetime import datetime

# Parse command-line arguments
parser = argparse.ArgumentParser(description='Plot cumulative job usage over time.')
parser.add_argument('--start_date', type=str, default='', help='Start date in yy/mm/dd format (optional)')
parser.add_argument('--end_date', type=str, default='', help='End date in yy/mm/dd format (optional)')
args = parser.parse_args()

# Read the CSV file
input_file = 'processed_output.csv'
df = pd.read_csv(input_file)

# Convert date columns to datetime
df['start_date'] = pd.to_datetime(df['start_date'], format='%a %b %d %H:%M:%S UTC %Y')
df['end_date'] = pd.to_datetime(df['end_date'], format='%a %b %d %H:%M:%S UTC %Y')

# Calculate duration in hours
def calculate_duration(row):
    if pd.isna(row['end_date']) or row['start_date'] == row['end_date']:
        return 0.025  # Assume 0.025 hours if start_date equals end_date or end_date is missing
    return (row['end_date'] - row['start_date']).total_seconds() / 3600

df['duration_hours'] = df.apply(calculate_duration, axis=1)

# Extract date for grouping (use start_date)
df['date'] = df['start_date'].dt.date

# Convert input dates to datetime.date objects
start_date = None
end_date = None

if args.start_date:
    start_date = datetime.strptime(args.start_date, '%y/%m/%d').date()
if args.end_date:
    end_date = datetime.strptime(args.end_date, '%y/%m/%d').date()

# Filter data based on start_date and end_date
if start_date or end_date:
    if start_date:
        df = df[df['date'] >= start_date]
    if end_date:
        df = df[df['date'] <= end_date]

# Calculate cumulative total usage per date
total_usage = df.groupby('date')['duration_hours'].sum().reset_index()
total_usage = total_usage.sort_values('date')  # Ensure chronological order
total_usage['cumulative_hours'] = total_usage['duration_hours'].cumsum()

# Calculate cumulative usage per user per date
user_usage = df.groupby(['date', 'username'])['duration_hours'].sum().unstack().fillna(0)
user_usage = user_usage.sort_index()  # Ensure chronological order
user_usage_cumulative = user_usage.cumsum()

# Plotting
plt.figure(figsize=(12, 6))

# Plot cumulative total usage
plt.plot(total_usage['date'], total_usage['cumulative_hours'], label='Total Cumulative Usage', marker='o', linewidth=2)

# Plot cumulative usage per user
for user in user_usage_cumulative.columns:
    plt.plot(user_usage_cumulative.index, user_usage_cumulative[user], label=f'{user} Cumulative Usage', marker='.', linestyle='--')

# Customize the plot
plt.title('Cumulative Job Usage Over Time', fontsize=14)
plt.xlabel('Date', fontsize=12)
plt.ylabel('Cumulative Usage (Hours)', fontsize=12)
plt.legend()
plt.grid(True)
plt.xticks(rotation=45)
plt.tight_layout()

# Save and show the plot
plt.savefig('cumulative_usage_time_series.png')
plt.show()

# Print summary
print("Cumulative Total Usage Summary:")
print(total_usage[['date', 'cumulative_hours']])
print("\nCumulative Usage per User Summary:")
print(user_usage_cumulative)

# Print total usage per user
print("\nTotal Usage per User (Hours):")
print(df.groupby('username')['duration_hours'].sum())

# Print overall total usage
print("\nOverall Total Usage (Hours):")
print(df['duration_hours'].sum())