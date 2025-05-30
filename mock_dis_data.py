import psycopg2
import datetime
import random
import time

# Run "kubectl port-forward svc/postgres 5432:5432" beforehand

# --- Database Configuration ---
DB_HOST = "localhost" 
DB_PORT = "5432"
DB_NAME = "dis_db"
DB_USER = "dis_user"
DB_PASS = "dis_pass"

# --- Data Generation Configuration ---
DATA_PERIODS_MONTHLY = [
    (2025, 5, 28, 50, 5),
    (2025, 4, 25, 30, 3),
    (2024, 12, 20, 40, 4),
]
CLEAR_EXISTING_DATA = True

def connect_db():
    """Connects to the PostgreSQL database."""
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            dbname=DB_NAME,
            user=DB_USER,
            password=DB_PASS
        )
        print("Successfully connected to PostgreSQL.")
        return conn
    except psycopg2.Error as e:
        print(f"Error connecting to PostgreSQL: {e}")
        exit(1)

def to_dis_absolute_timestamp(dt_utc):
    """Converts a datetime object (UTC) to a DIS absolute timestamp."""
    epoch_seconds = int(dt_utc.timestamp())
    return epoch_seconds | 0x80000000

def generate_entity_state_data(dis_timestamp):
    """Generates a single mock EntityStateRecord data tuple."""
    # Ensure the order matches the INSERT statement columns
    return (
        18,  # site
        23,  # application
        random.randint(1000, 1004),  # entity
        random.uniform(-2700000, -2600000),  # locationx
        random.uniform(-4300000, -4200000),  # locationy
        random.uniform(3700000, 3800000),   # locationz
        dis_timestamp # timestamp
    )

def generate_fire_event_data(dis_timestamp):
    """Generates a single mock FireEventRecord data tuple."""
    # Ensure the order matches the INSERT statement columns
    return (
        18,  # firing_site
        23,  # firing_application
        random.randint(1000, 1004),  # firing_entity
        18,  # target_site
        23,  # target_application
        random.randint(1000, 1004),  # target_entity
        18,  # munition_site
        23,  # munition_application
        random.randint(1, 100),      # munition_entity
        dis_timestamp # timestamp
    )

def populate_data_for_day(conn, year, month, day, num_entity_states, num_fire_events):
    """Populates data for a specific day."""
    cursor = conn.cursor()
    print(f"  Populating data for {year}-{month:02d}-{day:02d}...")

    # Generate entity states
    entity_state_records_to_insert = []
    for _ in range(num_entity_states):
        hour = random.randint(0, 23)
        minute = random.randint(0, 59)
        second = random.randint(0, 59)
        dt_utc = datetime.datetime(year, month, day, hour, minute, second, tzinfo=datetime.timezone.utc)
        dis_ts = to_dis_absolute_timestamp(dt_utc)
        entity_state_records_to_insert.append(generate_entity_state_data(dis_ts))
    
    if entity_state_records_to_insert:
        try:
            # Corrected column names to all lowercase
            insert_query_es = """
                INSERT INTO entity_state_record 
                (site, application, entity, locationx, locationy, locationz, timestamp)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
            """
            # For batch insert, use execute_values if available and preferred, or loop execute
            for record_data in entity_state_records_to_insert:
                 cursor.execute(insert_query_es, record_data)
        except psycopg2.Error as e:
            print(f"Error inserting entity state records: {e}")
            conn.rollback()
            return # Stop for this day if there's an error

    # Generate fire events
    fire_event_records_to_insert = []
    for _ in range(num_fire_events):
        hour = random.randint(0, 23)
        minute = random.randint(0, 59)
        second = random.randint(0, 59)
        dt_utc = datetime.datetime(year, month, day, hour, minute, second, tzinfo=datetime.timezone.utc)
        dis_ts = to_dis_absolute_timestamp(dt_utc)
        fire_event_records_to_insert.append(generate_fire_event_data(dis_ts))

    if fire_event_records_to_insert:
        try:
            insert_query_fe = """
                INSERT INTO fire_event_record 
                (firing_site, firing_application, firing_entity, 
                 target_site, target_application, target_entity,
                 munition_site, munition_application, munition_entity, timestamp)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """
            for record_data in fire_event_records_to_insert:
                cursor.execute(insert_query_fe, record_data)
        except psycopg2.Error as e:
            print(f"Error inserting fire event records: {e}")
            conn.rollback()
            return # Stop for this day if there's an error
            
    conn.commit()
    cursor.close()

def main():
    conn = connect_db()
    cursor = conn.cursor()

    if CLEAR_EXISTING_DATA:
        print("Clearing existing data from tables...")
        try:
            cursor.execute("TRUNCATE TABLE entity_state_record RESTART IDENTITY CASCADE;")
            cursor.execute("TRUNCATE TABLE fire_event_record RESTART IDENTITY CASCADE;")
            conn.commit()
            print("Data cleared successfully.")
        except psycopg2.Error as e:
            print(f"Error truncating tables: {e}")
            conn.rollback()
            conn.close()
            exit(1)
            
    print("\nStarting data generation...")
    for year, month, num_days, daily_es, daily_fe in DATA_PERIODS_MONTHLY:
        print(f"\nGenerating data for {year}-{month:02d} for {num_days} day(s):")
        days_in_month = min(num_days, 28) 
        for i in range(days_in_month):
            day_to_generate = i + 1
            populate_data_for_day(conn, year, month, day_to_generate, daily_es, daily_fe)
    
    print("\nMock data generation complete.")
    
    cursor.close()
    conn.close()
    print("Database connection closed.")

if __name__ == "__main__":
    main()