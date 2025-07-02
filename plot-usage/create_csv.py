import os
import csv
from pathlib import Path

# Constant for directory path
DIRECTORY = "/home/honda/.3dcs/usage-processed"

def get_files(directory):
    """Get list of files in the specified directory."""
    return [f for f in os.listdir(directory) if os.path.isfile(os.path.join(directory, f))]

def parse_filename(filename):
    """Parse filename to extract username and jobid."""
    parts = filename.split('-', 1)
    if len(parts) != 2:
        return None, None
    return parts[0], parts[1]

def read_dates(filepath):
    """Read dates from a file."""
    try:
        with open(filepath, 'r') as f:
            return [line.strip() for line in f if line.strip()]
    except Exception as e:
        print(f"Error reading {filepath}: {e}")
        return []

def write_csv(data, output_file):
    """Write data to CSV file."""
    with open(output_file, 'w', newline='') as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(['username', 'jobid', 'date'])
        for row in data:
            writer.writerow(row)

def process_directory(directory, output_file):
    """Process all files in directory and create CSV."""
    csv_data = []
    for filename in get_files(directory):
        username, jobid = parse_filename(filename)
        if username and jobid:
            filepath = os.path.join(directory, filename)
            dates = read_dates(filepath)
            for date in dates:
                csv_data.append([username, jobid, date])
    
    write_csv(csv_data, output_file)
    print(f"CSV file created: {output_file}")

def main():
    """Main function to execute the processing."""
    output_file = "output.csv"
    
    if not os.path.exists(DIRECTORY):
        print(f"Directory {DIRECTORY} does not exist")
        return
    
    process_directory(DIRECTORY, output_file)

if __name__ == "__main__":
    main()
