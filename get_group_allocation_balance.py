import os
import requests
from base64 import b64encode

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

ALLOCATION_NAME_3DCS = 'japan-3dcs-run-hours'
PW_PLATFORM_HOST = os.environ.get('PW_PLATFORM_HOST')
HEADERS = {"Authorization": "Basic {}".format(encode_string_to_base64(os.environ['PW_API_KEY']))}
# ORGANIZATION_ID = os.environ.get('ORGANIZATION_ID')
# GT_ORGANIZATION_URL = f'https://{PW_PLATFORM_HOST}/api/v2/organization/teams?organization={ORGANIZATION_ID}'
GT_ORGANIZATION_URL = f'https://{PW_PLATFORM_HOST}/api/v2/organization/teams'

def get_balance():
    res = requests.get(GT_ORGANIZATION_URL, headers = HEADERS)
    
    for group in res.json():
        if group['name'] == ALLOCATION_NAME_3DCS:
            allocation_total = group['allocations']['total']['value']
            if 'used' in group['allocations']:
                allocation_used = group['allocations']['used']['value']
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
