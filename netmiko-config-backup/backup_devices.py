from netmiko import ConnectHandler
from datetime import datetime
from dotenv import load_dotenv
import os

load_dotenv()

devices = [
    {
        'name': 'frr1',
        'device_type': 'linux',
        'host': '192.168.122.165',
        'username': 'root',
        'password': os.getenv('FRR1_PASSWORD'),
        'use_keys': False,
        'allow_agent': False,
    },
    {
        'name': 'frr2',
        'device_type': 'linux',
        'host': '192.168.122.107',
        'username': 'root',
        'password': os.getenv('FRR2_PASSWORD'),
        'use_keys': False,
        'allow_agent': False,
    },
    {
        'name': '2950',
        'device_type': 'cisco_ios_telnet',
        'host': '10.10.30.10',
        'password': os.getenv('SW2950_PASSWORD'),
        'secret': os.getenv('SW2950_SECRET'),
    },
]

os.makedirs('backups', exist_ok=True)

for device in devices:
    name = device.pop('name')
    try:
        conn = ConnectHandler(**device)

        if not conn.check_enable_mode():
            conn.enable()

        output = conn.send_command('show running-config')
        conn.disconnect()

        timestamp = datetime.now().strftime('%Y-%m-%d_%H%M%S')
        filename = f'backups/{name}_{timestamp}.cfg'

        with open(filename, 'w') as f:
            f.write(output)

        print(f'[OK] {name} backed up to {filename}')

    except Exception as e:
        print(f'[FAIL] {name}: {e}')
