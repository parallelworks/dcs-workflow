#!/usr/bin/python3
import fcntl
import os
import sys
import time
from datetime import datetime
import requests
from base64 import b64encode
import logging
import shutil

"""
3DCS workers periodically write timestamps to files named <hostname>-<pw-job-id> 
in the DCS_PENDING_USAGE_DIR. This script processes each file in this directory, assuming the 
worker has stopped if no new timestamps are reported. It calculates the worker's runtime in hours 
and updates the group's allocation usage accordingly. This script runs on a centralized machine 
where 3DCS workers report their usage.
"""

def encode_string_to_base64(text):
    # Convert the string to bytes
    text_bytes = text.encode('utf-8')
    # Encode the bytes to base64
    encoded_bytes = b64encode(text_bytes)
    # Convert the encoded bytes back to a string
    encoded_string = encoded_bytes.decode('utf-8')
    return encoded_string

# The sleep time must be large enough for the workers to report the next heartbeat 
SLEEP_TIME: int = 360
DCS_DIR: str = os.path.expanduser('~/.3dcs/')
DCS_PENDING_USAGE_DIR = os.path.join(DCS_DIR, 'usage-pending')
os.makedirs(DCS_PENDING_USAGE_DIR, exist_ok=True)
DCS_PROCESSED_USAGE_DIR = os.path.join(DCS_DIR, 'usage-processed')
os.makedirs(DCS_PROCESSED_USAGE_DIR, exist_ok=True)
LOCK_FILE_PATH = os.path.join(DCS_DIR, 'update-3dcs-usage.lock')

# See https://cloud.parallel.works/api/v2/organization
CUSTOMER_ORG_ID = '63572a4c1129281e00477a0c'
PW_PLATFORM_HOST = os.environ.get('PW_PLATFORM_HOST')
PW_API_KEY = os.environ.get('PW_API_KEY')
CUSTOMER_ORG_NAME = os.environ.get('CUSTOMER_ORG_NAME')

group_name_to_id_mapping = {}
HEADERS = {"Authorization": "Basic {}".format(encode_string_to_base64(os.environ['PW_API_KEY']))}

GROUP_NAME: str = '3dcs-run-hours'
# ORGANIZATION_URL: str = f'https://{PW_PLATFORM_HOST}/api/v2/organization/teams?organization={CUSTOMER_ORG_ID}'
# ORGANIZATION_URL: str = f'https://{PW_PLATFORM_HOST}/api/v2/organization/teams'
ORGANIZATION_URL = f'https://{PW_PLATFORM_HOST}/api/organizations/{CUSTOMER_ORG_NAME}/groups'


CONNECTED_WORKERS = {}

logging.basicConfig(
    filename = os.path.join(DCS_DIR, 'update-3dcs-usage.log'), 
    level = logging.INFO, 
    format = '%(asctime)s - %(levelname)s - %(message)s'
)

logger = logging.getLogger(__name__)


def is_running():
    global lock_file
    lock_file = open(LOCK_FILE_PATH, 'w')
    try:
        fcntl.flock(lock_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
        return False
    except IOError:
        return True


def get_group_info():
    res = requests.get(ORGANIZATION_URL, headers = HEADERS)
    for group in res.json():
        if group['name'] == GROUP_NAME:
            return group

def get_allocation_used(group):
    if 'used' in group['allocations']:
        return group['allocations']['used']['value']
    return 0    

def http_put_sync(url, payload):
    response = requests.put(url, json=payload,  headers = HEADERS)
    return response.json()

def update_group_allocation_used(group_id, allocation_used):
    #logger.info(f'Updating {group_id} used allocation to {allocation_used}')
    url = f"https://{PW_PLATFORM_HOST}/api/v2/organization/teams/{group_id}"
    payload = {
        "allocation_used": allocation_used
    }
    return http_put_sync(url, payload)

def get_group_id(group_name):

    res = requests.get(ORGANIZATION_URL, headers = get_headers())

    for group in res.json():
        group_name_to_id_mapping[group['name']] = group['id']

    return group_name_to_id_mapping

def list_files_in_directory(directory):
    """
    Returns a list of all files under the specified directory.
    
    :param directory: The directory to search for files.
    :return: A list of file paths.
    """
    files_list = []
    for root, dirs, files in os.walk(directory):
        for file in files:
            files_list.append(os.path.join(root, file))
    return files_list

def calculate_time_difference(file_path):
    """
    Calculates the time difference between the first and last timestamps in a file.
    
    :param file_path: The path to the file.
    :return: The time difference in seconds.
    """
    with open(file_path, 'r') as file:
        lines = file.readlines()
        
    if not lines:
        return None
    
    # Parse the first and last timestamps
    first_time_str = lines[0].strip()
    last_time_str = lines[-1].strip()
    
    # Define the datetime format
    #time_format = '%a %b %d %I:%M:%S %p %Z %Y'
    time_format = '%a %b %d %H:%M:%S %Z %Y'
    # Convert strings to datetime objects
    first_time = datetime.strptime(first_time_str, time_format)
    last_time = datetime.strptime(last_time_str, time_format)
    
    # Calculate the difference in hours
    time_difference = (last_time - first_time).total_seconds()/3600
    return time_difference

def move_pending_file_to_processed(pending_file_path):
    file_name = os.path.basename(pending_file_path)

    # Construct the full file path for the processed file
    processed_file_path = os.path.join(DCS_PROCESSED_USAGE_DIR, file_name)
    
    # Check if the file already exists in the processed directory
    if os.path.exists(processed_file_path):
        # Find a new filename with an increasing number
        base, extension = os.path.splitext(file_name)
        counter = 2
        new_file_name = f"{base}{extension}.{counter}"
        new_processed_file_path = os.path.join(DCS_PROCESSED_USAGE_DIR, new_file_name)
        
        while os.path.exists(new_processed_file_path):
            counter += 1
            new_file_name = f"{base}{extension}.{counter}"
            new_processed_file_path = os.path.join(DCS_PROCESSED_USAGE_DIR, new_file_name)
        
        logger.warning(f'{file_name} already exists in the processed directory. Renaming to {new_file_name}')
        processed_file_path = new_processed_file_path
    
    # Move the file
    shutil.move(pending_file_path, processed_file_path)
    logger.info(f"Moved: {file_name} to {processed_file_path}")
    return processed_file_path

def count_lines_in_file(file_path):
    """
    Count the number of lines in a given file.

    Parameters:
    file_path (str): The path to the file.

    Returns:
    int: The number of lines in the file.
    """
    with open(file_path, 'r') as file:
        return sum(1 for line in file)

def process_worker_file(worker_file):
    processed_worker_file = move_pending_file_to_processed(worker_file)
    used_hours = calculate_time_difference(processed_worker_file)
    logger.info(f'Worker file {worker_file} used {used_hours} hours.')
    return used_hours

def process_worker_files(worker_files, allocation_used):
    cached_usage = 0
    for worker_file in worker_files:
        worker_file_name = os.path.basename(worker_file)

        # Initialize worker
        if worker_file_name not in CONNECTED_WORKERS:
            logger.info(f'Initializing worker file {worker_file_name}.')
            CONNECTED_WORKERS[worker_file_name] = 1


        logger.info(f'Processing file {worker_file}.')
        # Each line is a time stamp
        number_of_lines = count_lines_in_file(worker_file)
        if number_of_lines > CONNECTED_WORKERS[worker_file_name]:
            CONNECTED_WORKERS[worker_file_name] = number_of_lines
        elif number_of_lines > 1:
            logger.info(f'Worker {worker_file_name} disconnected after {number_of_lines} heartbeats.')
            used_hours = process_worker_file(worker_file)
            cached_usage += used_hours
            del CONNECTED_WORKERS[worker_file_name]
            # Update allocation used HERE to include worker information
        else:
            logger.info(f'Worker {worker_file_name} disconnected after {number_of_lines} heartbeats. Assuming 90 seconds connection.')
            processed_worker_file = move_pending_file_to_processed(worker_file)
            cached_usage += 0.025
            del CONNECTED_WORKERS[worker_file_name]
    
    if cached_usage > 0:
        allocation_used += cached_usage
        logger.info(f'Updating allocation used to {allocation_used}.')
        update_group_allocation_used(group_id, round(allocation_used,2))
    
    return allocation_used


logger.info('Running script ' + sys.argv[0])


if is_running():
    logger.info('Another instance is already running. Exiting.')
    sys.exit(0)


logger.info('Starting update-3dcs-usage service.')

logger.info('Reading allocation information.')
group_info = get_group_info()

if not group_info:
    logger.error('Group information is empty.')
    raise ValueError('Group information cannot be empty.')

allocation_used = get_allocation_used(group_info)
logger.info('Allocation used: ' + str(allocation_used))
group_id = group_info['id']


# Keep the script running to hold the lock
try:
    while True:
        time.sleep(SLEEP_TIME)
        worker_files = list_files_in_directory(DCS_PENDING_USAGE_DIR)
        if worker_files:
            logger.info('Found worker files ' + ' '.join(worker_files))
            allocation_used = process_worker_files(worker_files, allocation_used)            
finally:
    lock_file.close()
    os.remove(LOCK_FILE_PATH)
