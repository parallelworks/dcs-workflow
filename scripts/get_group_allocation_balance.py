import os
import requests
from base64 import b64encode
import sys

def encode_string_to_base64(text):
    # Convert the string to bytes
    text_bytes = text.encode('utf-8')
    # Encode the bytes to base64
    encoded_bytes = b64encode(text_bytes)
    # Convert the encoded bytes back to a string
    encoded_string = encoded_bytes.decode('utf-8')
    return encoded_string

# This script needs to run in the user container to access the PW_API_KEY
# Therefore, it is called by the main script using the reverse ssh tunnel
# Prints the balance in json format

ALLOCATION_NAME_3DCS = sys.argv[1]
CUSTOMER_ORG_NAME = sys.argv[2]

PW_PLATFORM_HOST = os.environ.get('PW_PLATFORM_HOST')
HEADERS = {"Authorization": "Basic {}".format(encode_string_to_base64(os.environ['PW_API_KEY']))}
# ORGANIZATION_ID = os.environ.get('ORGANIZATION_ID')
# ORGANIZATION_URL = f'https://{PW_PLATFORM_HOST}/api/v2/organization/teams?organization={ORGANIZATION_ID}'
# ORGANIZATION_URL = f'https://{PW_PLATFORM_HOST}/api/v2/organization/teams'
ORGANIZATION_URL = f'https://{PW_PLATFORM_HOST}/api/organizations/{CUSTOMER_ORG_NAME}/groups'


def get_balance():
    res = requests.get(ORGANIZATION_URL, headers = HEADERS)
    
    for group in res.json():
        if group['name'] == ALLOCATION_NAME_3DCS:
            allocation_total = group['allocations']['total']
            if 'used' in group['allocations']:
                allocation_used = group['allocations']['used']
            else:
                allocation_used = 0
            
            allocation_balance = allocation_total - allocation_used
            return allocation_balance
    
    return 0

def main():
    allocation_balance = get_balance()
    if allocation_balance <= 0:
        raise Exception("The allocation balance is zero or negative!")
    print(allocation_balance)

if __name__ == '__main__':
    main()
