#!/usr/bin/env python3
"""
Extended and More Realistic DIS PDU Simulation Script

This script uses the open-dis-python bindings to craft and send different DIS PDUs over UDP.
It simulates multiple entities, their movement (EntityStatePdu), and occasional Fire and Collision events.

Ensure that the opendis package is installed and properly configured.
"""

import socket
import time
import random
from io import BytesIO
from opendis.DataOutputStream import DataOutputStream
from opendis.dis7 import EntityStatePdu, FirePdu, CollisionPdu, EntityID as DisEntityID
from opendis.RangeCoordinates import GPS, deg2rad

# --- Simulation Configuration ---
UDP_PORT = 32000  # [cite: 130]
DESTINATION_ADDRESS = "192.168.49.2"  # Replace with `minikube ip` or target GKE Node IP [cite: 130]

SIMULATION_DURATION_SECONDS = 300  # Run for 5 minutes
PDUS_PER_SECOND_PER_ENTITY = 0.5  # ESPDUs per entity per second
NUM_SIMULATED_ENTITIES = 5

# Probability of other events per entity update cycle
FIRE_EVENT_PROBABILITY = 0.02  # 2% chance to fire
COLLISION_EVENT_PROBABILITY = 0.005 # 0.5% chance to collide

# Entity Details
DEFAULT_SITE_ID = 18
DEFAULT_APPLICATION_ID = 23
DEFAULT_EXERCISE_ID = 1 # [cite: 136]

# Movement simulation
MAX_SPEED_METERS_PER_SECOND = 20.0  # Max speed in any direction for ECEF coordinates
WORLD_BOUNDS_ECEF = { # Approximate ECEF bounds to keep entities somewhat contained (very rough)
    'x_min': -2700000, 'x_max': -2600000,
    'y_min': -4300000, 'y_max': -4200000,
    'z_min': 3700000, 'z_max': 3800000
}

# --- Global Setup ---
udpSocket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM) # [cite: 130]
udpSocket.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1) # [cite: 130]
gps = GPS() # [cite: 130]

# Helper to create DIS EntityID object
def create_entity_id(site, app, entity_val):
    eid = DisEntityID()
    eid.siteID = site
    eid.applicationID = app
    eid.entityID = entity_val
    return eid

# Simulated Entity State
simulated_entities = []

def initialize_entities():
    global simulated_entities
    simulated_entities = []
    start_lat, start_lon, start_alt = 36.6, -121.9, 1.0 # Monterey coordinates [cite: 131]

    for i in range(NUM_SIMULATED_ENTITIES):
        # Slightly vary initial positions around Monterey
        lat_offset = (random.random() - 0.5) * 0.05 # Small offset
        lon_offset = (random.random() - 0.5) * 0.05 # Small offset
        
        initial_ecef = gps.llarpy2ecef(
            deg2rad(start_lat + lat_offset),
            deg2rad(start_lon + lon_offset),
            start_alt + random.uniform(-50, 50),
            0, 0, 0
        )
        
        simulated_entities.append({
            "id_obj": create_entity_id(DEFAULT_SITE_ID, DEFAULT_APPLICATION_ID, 1000 + i),
            "protocol_version": 7, # Default to DIS v7
            "location_x": initial_ecef[0],
            "location_y": initial_ecef[1],
            "location_z": initial_ecef[2],
            "orientation_psi": initial_ecef[3], # Will be static for simplicity
            "orientation_theta": initial_ecef[4],
            "orientation_phi": initial_ecef[5],
            "velocity_x": (random.random() - 0.5) * 2 * MAX_SPEED_METERS_PER_SECOND,
            "velocity_y": (random.random() - 0.5) * 2 * MAX_SPEED_METERS_PER_SECOND,
            "velocity_z": (random.random() - 0.5) * 0.5 * MAX_SPEED_METERS_PER_SECOND, # Slower vertical
            "marking": f"Entity-{1000+i}",
            "force_id": random.choice([1, 2]), # Friendly or Hostile
            "entity_kind": 1, # Platform
            "domain": 1,      # Land
            "country": 225,   # USA
            "category": random.randint(1, 10),
            "subcategory": random.randint(1, 10),
            "specific": random.randint(1, 10),
            "last_espdu_sent_time": time.time()
        })
    print(f"Initialized {NUM_SIMULATED_ENTITIES} entities.")

def update_entity_position(entity, dt):
    entity["location_x"] += entity["velocity_x"] * dt
    entity["location_y"] += entity["velocity_y"] * dt
    entity["location_z"] += entity["velocity_z"] * dt

    # Simple boundary reflection
    if not (WORLD_BOUNDS_ECEF['x_min'] < entity["location_x"] < WORLD_BOUNDS_ECEF['x_max']):
        entity["velocity_x"] *= -1
        entity["location_x"] = max(WORLD_BOUNDS_ECEF['x_min'], min(entity["location_x"], WORLD_BOUNDS_ECEF['x_max']))
    if not (WORLD_BOUNDS_ECEF['y_min'] < entity["location_y"] < WORLD_BOUNDS_ECEF['y_max']):
        entity["velocity_y"] *= -1
        entity["location_y"] = max(WORLD_BOUNDS_ECEF['y_min'], min(entity["location_y"], WORLD_BOUNDS_ECEF['y_max']))
    if not (WORLD_BOUNDS_ECEF['z_min'] < entity["location_z"] < WORLD_BOUNDS_ECEF['z_max']):
        entity["velocity_z"] *= -1
        entity["location_z"] = max(WORLD_BOUNDS_ECEF['z_min'], min(entity["location_z"], WORLD_BOUNDS_ECEF['z_max']))


def send_entity_state_pdu(entity_state):
    pdu = EntityStatePdu()
    pdu.protocolVersion = entity_state["protocol_version"] # [cite: 130]
    pdu.exerciseID = DEFAULT_EXERCISE_ID
    pdu.pduType = 1  # Entity State PDU type [cite: 130]
    pdu.pduStatus = 0 # [cite: 130]

    pdu.entityID.siteID = entity_state["id_obj"].siteID # [cite: 131]
    pdu.entityID.applicationID = entity_state["id_obj"].applicationID # [cite: 131]
    pdu.entityID.entityID = entity_state["id_obj"].entityID # [cite: 131]
    
    pdu.marking.setString(entity_state["marking"]) # [cite: 131]
    pdu.entityAppearance = 0 # [cite: 131]
    pdu.capabilities = 0 # [cite: 131]

    pdu.entityLocation.x = entity_state["location_x"] # [cite: 132]
    pdu.entityLocation.y = entity_state["location_y"] # [cite: 132]
    pdu.entityLocation.z = entity_state["location_z"] # [cite: 132]
    pdu.entityOrientation.psi = entity_state["orientation_psi"] # [cite: 132]
    pdu.entityOrientation.theta = entity_state["orientation_theta"] # [cite: 133]
    pdu.entityOrientation.phi = entity_state["orientation_phi"] # [cite: 133]

    if pdu.protocolVersion == 7:
        pdu.forceId = entity_state["force_id"] # [cite: 134]
        pdu.entityType.entityKind = entity_state["entity_kind"] # [cite: 134]
        pdu.entityType.domain = entity_state["domain"] # [cite: 134]
        pdu.entityType.country = entity_state["country"] # [cite: 134]
        pdu.entityType.category = entity_state["category"] # [cite: 134]
        pdu.entityType.subcategory = entity_state["subcategory"] # [cite: 134]
        pdu.entityType.specific = entity_state["specific"] # [cite: 134]
        pdu.entityType.extra = 0 # [cite: 134]

    memoryStream = BytesIO() # [cite: 134]
    outputStream = DataOutputStream(memoryStream) # [cite: 134]
    pdu.serialize(outputStream) # [cite: 134]
    data = memoryStream.getvalue() # [cite: 134]

    udpSocket.sendto(data, (DESTINATION_ADDRESS, UDP_PORT)) # [cite: 134]
    # print(f"Sent EntityStatePdu v{pdu.protocolVersion} for {entity_state['marking']}. {len(data)} bytes.")
    entity_state["last_espdu_sent_time"] = time.time()


def send_fire_pdu(firing_entity, target_entity):
    if not firing_entity or not target_entity:
        return

    pdu = FirePdu()
    pdu.protocolVersion = 7  # FirePdu often associated with DIS v7
    pdu.exerciseID = DEFAULT_EXERCISE_ID
    pdu.pduType = 2  # Fire PDU type [cite: 135]
    pdu.pduStatus = 0 # [cite: 135]

    pdu.firingEntityID.siteID = firing_entity["id_obj"].siteID # [cite: 135]
    pdu.firingEntityID.applicationID = firing_entity["id_obj"].applicationID # [cite: 135]
    pdu.firingEntityID.entityID = firing_entity["id_obj"].entityID # [cite: 135]

    pdu.targetEntityID.siteID = target_entity["id_obj"].siteID # [cite: 135]
    pdu.targetEntityID.applicationID = target_entity["id_obj"].applicationID # [cite: 135]
    pdu.targetEntityID.entityID = target_entity["id_obj"].entityID # [cite: 135]
    
    # Simplified munition ID
    pdu.munitionExpendableID.siteID = firing_entity["id_obj"].siteID # [cite: 136]
    pdu.munitionExpendableID.applicationID = firing_entity["id_obj"].applicationID # [cite: 136]
    pdu.munitionExpendableID.entityID = random.randint(1,100) # Some munition ID [cite: 136]

    # Other FirePdu fields can be set as needed, e.g., location, range
    # For simplicity, keeping them default for now.

    memoryStream = BytesIO()
    outputStream = DataOutputStream(memoryStream)
    pdu.serialize(outputStream)
    data = memoryStream.getvalue()

    udpSocket.sendto(data, (DESTINATION_ADDRESS, UDP_PORT))
    print(f"Sent FirePdu from {firing_entity['marking']} to {target_entity['marking']}. {len(data)} bytes.")


def send_collision_pdu(issuing_entity, colliding_entity):
    if not issuing_entity or not colliding_entity:
        return

    pdu = CollisionPdu()
    pdu.protocolVersion = 7
    pdu.exerciseID = DEFAULT_EXERCISE_ID # [cite: 136]
    pdu.pduType = 4  # Collision PDU type [cite: 136]
    pdu.pduStatus = 0 # [cite: 136]

    pdu.issuingEntityID.siteID = issuing_entity["id_obj"].siteID # [cite: 137]
    pdu.issuingEntityID.applicationID = issuing_entity["id_obj"].applicationID # [cite: 137]
    pdu.issuingEntityID.entityID = issuing_entity["id_obj"].entityID # [cite: 137]

    pdu.collidingEntityID.siteID = colliding_entity["id_obj"].siteID # [cite: 137]
    pdu.collidingEntityID.applicationID = colliding_entity["id_obj"].applicationID # [cite: 137]
    pdu.collidingEntityID.entityID = colliding_entity["id_obj"].entityID # [cite: 137]
    
    # Other CollisionPdu fields e.g. collisionType, velocity, mass, location
    # For simplicity, keeping them default.

    memoryStream = BytesIO()
    outputStream = DataOutputStream(memoryStream)
    pdu.serialize(outputStream)
    data = memoryStream.getvalue()

    udpSocket.sendto(data, (DESTINATION_ADDRESS, UDP_PORT))
    print(f"Sent CollisionPdu between {issuing_entity['marking']} and {colliding_entity['marking']}. {len(data)} bytes.")


def main():
    initialize_entities()
    start_time = time.time()
    last_update_time = start_time
    total_pdus_sent = 0
    
    espdu_send_interval = 1.0 / PDUS_PER_SECOND_PER_ENTITY if PDUS_PER_SECOND_PER_ENTITY > 0 else float('inf')

    print(f"Starting DIS PDU simulation for {SIMULATION_DURATION_SECONDS} seconds.")
    print(f"Simulating {NUM_SIMULATED_ENTITIES} entities.")
    print(f"Targeting {DESTINATION_ADDRESS}:{UDP_PORT}")

    try:
        while time.time() - start_time < SIMULATION_DURATION_SECONDS:
            current_time = time.time()
            dt = current_time - last_update_time
            last_update_time = current_time

            if not simulated_entities:
                print("No entities to simulate. Exiting.")
                break

            for entity in simulated_entities:
                update_entity_position(entity, dt)
                
                # Send ESPDU based on its individual rate
                if current_time - entity.get("last_espdu_sent_time", 0) >= espdu_send_interval:
                    send_entity_state_pdu(entity)
                    total_pdus_sent +=1

                # Randomly send FirePdu
                if random.random() < FIRE_EVENT_PROBABILITY * (dt / espdu_send_interval if espdu_send_interval > 0 else 1.0): # Scale probability by time step relative to ESPDU interval
                    # Select a random target that is not itself
                    possible_targets = [e for e in simulated_entities if e["id_obj"].entityID != entity["id_obj"].entityID]
                    if possible_targets:
                        target_entity = random.choice(possible_targets)
                        send_fire_pdu(entity, target_entity)
                        total_pdus_sent +=1

                # Randomly send CollisionPdu
                if random.random() < COLLISION_EVENT_PROBABILITY * (dt / espdu_send_interval if espdu_send_interval > 0 else 1.0) :
                    possible_collision_partners = [e for e in simulated_entities if e["id_obj"].entityID != entity["id_obj"].entityID]
                    if possible_collision_partners:
                        colliding_entity = random.choice(possible_collision_partners)
                        # In a real collision, both entities might issue one, or a central system.
                        # Here, the current 'entity' is the one 'issuing' the collision PDU.
                        send_collision_pdu(entity, colliding_entity)
                        total_pdus_sent +=1
            
            # Control overall send rate by sleeping for a short period
            # This loop processes all entities, then sleeps.
            # Effective PDU rate per entity is controlled by espdu_send_interval
            # Total PDU rate is roughly (NUM_SIMULATED_ENTITIES / espdu_send_interval) + event PDUs
            # We need a small sleep to prevent a busy loop if espdu_send_interval is very small or dt is small
            time.sleep(max(0.01, espdu_send_interval / NUM_SIMULATED_ENTITIES / 10)) # Dynamic sleep, ensure CPU doesn't spin too hard


    except KeyboardInterrupt:
        print("\nSimulation stopped by user.")
    finally:
        print(f"Simulation finished. Total time: {time.time() - start_time:.2f} seconds.")
        print(f"Total PDUs sent: {total_pdus_sent}")
        udpSocket.close()

if __name__ == "__main__":
    main()