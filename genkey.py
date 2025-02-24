import random
import string
import json
import os
from supabase import create_client, Client
from colorama import init, Fore

# เริ่มต้น colorama
init(autoreset=True)

# ตรวจสอบว่ามี config.json หรือไม่
CONFIG_FILE = "config.json"
if os.path.exists(CONFIG_FILE):
    with open(CONFIG_FILE, "r") as f:
        config = json.load(f)
else:
    config = {
        "supabase_url": input(Fore.CYAN + "Enter your Supabase URL: "),
        "supabase_key": input(Fore.CYAN + "Enter your Supabase API Key: "),
        "key_prefix": input(Fore.CYAN + "Enter key prefix (e.g., Motify): ")
    }
    with open(CONFIG_FILE, "w") as f:
        json.dump(config, f, indent=4)

# ตั้งค่าการเชื่อมต่อกับ Supabase
supabase: Client = create_client(config["supabase_url"], config["supabase_key"])

# ฟังก์ชันในการสร้างคีย์ใหม่
def generate_key(valid_days_str, num_keys):
    keys = []
    
    # ตรวจสอบค่า valid_days
    if valid_days_str.lower() == "lt":
        valid_days = 999999
    else:
        valid_days = int(valid_days_str)
    
    # เปิดไฟล์ keys.txt เพื่อบันทึก
    with open("keys.txt", "a") as file:
        file.write("=" * 40 + "\n")
        file.write("Motify Key Generator - List of Keys\n")
        file.write("=" * 40 + "\n")
        
        for _ in range(num_keys):
            new_key = f"{config['key_prefix']}-" + ''.join(random.choices(string.ascii_letters + string.digits, k=8))
            
            key_data = {
                "key": new_key,
                "status": "Pending",
                "days_": valid_days
            }
            keys.append(key_data)
            
            file.write(f"Key: {new_key}\n")
            file.write(f"Valid for: {valid_days} days\n")
            file.write("-" * 40 + "\n")
    
    supabase.table('keys').insert(keys).execute()
    
    print(Fore.GREEN + "\n" + "=" * 40)
    print(Fore.YELLOW + "Motify Key Generator - Key Generation Successful!")
    print(Fore.GREEN + "=" * 40)
    print(f"{num_keys} keys have been generated and saved to Supabase.")
    print(Fore.CYAN + "The keys have been saved to keys.txt.")
    print(Fore.GREEN + "=" * 40)

# ฟังก์ชันการลบคีย์
def delete_key():
    key_to_delete = input(Fore.CYAN + "Enter the key to delete: ")
    
    try:
        response = supabase.table('keys').delete().eq('key', key_to_delete).execute()
        if response.data:
            print(Fore.GREEN + f"Key {key_to_delete} has been deleted from Supabase.")
            
            # อัปเดตไฟล์ keys.txt
            with open("keys.txt", "r") as file:
                lines = file.readlines()
            
            with open("keys.txt", "w") as file:
                skip = False
                for line in lines:
                    if key_to_delete in line:
                        skip = True
                    elif skip and line.strip() == "-" * 40:
                        skip = False
                    elif not skip:
                        file.write(line)
        else:
            print(Fore.RED + "Key not found in Supabase.")
    except Exception as e:
        print(Fore.RED + f"Error deleting key: {e}")

# เริ่มต้นโปรแกรม
while True:
    print(Fore.CYAN + "Choose an option:")
    print("1. Generate keys")
    print("2. Delete a key")
    
    choice = input(Fore.CYAN + "Enter 1 or 2: ")
    
    if choice == "1":
        valid_days = input(Fore.CYAN + "Enter the valid days for the key (3, 7, 14, 30, or lt for LifeTime): ")
        num_keys = int(input(Fore.CYAN + "Enter the number of keys to generate: "))
        generate_key(valid_days, num_keys)
    elif choice == "2":
        delete_key()
    else:
        print(Fore.RED + "Invalid choice. Please select 1 or 2.")
