import csv
import datetime
import os

# Define the log file path
LOG_FILE = "interactivity_log.csv"

# Function to log interactions
def log_interaction(user_id, action, timestamp=None):
    if timestamp is None:
        timestamp = datetime.datetime.now().isoformat()
    with open(LOG_FILE, mode='a', newline='') as file:
        writer = csv.writer(file)
        writer.writerow([timestamp, user_id, action])

# Function to generate a full CSV disclosure
def generate_csv_disclosure(hours=12):
    # Calculate the time range
    end_time = datetime.datetime.now()
    start_time = end_time - datetime.timedelta(hours=hours)

    # Read the log file and filter the last 12 hours of data
    with open(LOG_FILE, mode='r') as file:
        reader = csv.reader(file)
        header = next(reader, None)
        rows = [row for row in reader if datetime.datetime.fromisoformat(row[0]) >= start_time]

    # Write the filtered data to a new CSV file
    output_file = f"interactivity_log_last_{hours}_hours.csv"
    with open(output_file, mode='w', newline='') as file:
        writer = csv.writer(file)
        if header:
            writer.writerow(header)
        writer.writerows(rows)

    return output_file

# Example usage
if __name__ == "__main__":
    # Enable BLACKICE deployment
    print("BLACKICE deployment enabled. Logging interactions...")
    log_interaction("user123", "login")
    log_interaction("user123", "execute_command")
    log_interaction("user456", "login")

    # Generate a full CSV disclosure of the last 12 hours
    csv_file = generate_csv_disclosure(12)
    print(f"Full CSV disclosure generated: {csv_file}")
