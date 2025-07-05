#!/usr/bin/env python3
"""
Extended and More Realistic DIS PDU Simulation Script
This script uses the open-dis-python bindings to craft and send different DIS PDUs over UDP.
It simulates multiple entities, their movement (EntityStatePdu), and occasional Fire and Collision events.
PDUs are now sent with a DIS-standard absolute timestamp (seconds since epoch with MSB set).

Ensure that the opendis package is installed and properly configured.
"""

import socket
import time
import random
import opendis.dis7 as dis7
from io import BytesIO
from opendis.DataOutputStream import DataOutputStream
from opendis.dis7 import (
    EntityID,EntityStatePdu, CollisionPdu, FirePdu, DetonationPdu, DataPdu,
    ActionRequestPdu, StartResumePdu, SetDataPdu, DesignatorPdu,
    ElectromagneticEmissionsPdu,ClockTime
)
from opendis.RangeCoordinates import GPS, deg2rad

# --- Simulation Configuration ---
UDP_PORT = 32000
# Use environment variable for destination if set, otherwise default to GKE IP
DESTINATION_ADDRESS = "34.142.175.247"  # Default GKE IP

# Uncomment and set this for local Minikube testing
# DESTINATION_ADDRESS = "192.168.49.2"  # Replace with the output of `minikube ip`

SIMULATION_DURATION_SECONDS = 9999
PDUS_PER_SECOND_PER_ENTITY = 2
NUM_SIMULATED_ENTITIES = 5

# Equal probability distribution for all PDU types
FIRE_EVENT_PROBABILITY = 0.01
DETONATION_PDU_PROBABILITY = 0.01
COLLISION_EVENT_PROBABILITY = 0.01
DATA_PDU_PROBABILITY = 0.01
ACTION_REQUEST_PDU_PROBABILITY = 0.01
START_RESUME_PDU_PROBABILITY = 0.01
SET_DATA_PDU_PROBABILITY = 0.01
DESIGNATOR_PDU_PROBABILITY = 0.01
EMISSION_PDU_PROBABILITY = 0.01

DEFAULT_SITE_ID = 18
DEFAULT_APPLICATION_ID = 23
DEFAULT_EXERCISE_ID = 1

MAX_SPEED_METERS_PER_SECOND = 20.0
WORLD_BOUNDS_ECEF = {
    'x_min': -2700000, 'x_max': -2600000,
    'y_min': -4300000, 'y_max': -4200000,
    'z_min': 3700000, 'z_max': 3800000
}

udpSocket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
udpSocket.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
gps = GPS()

def get_current_dis_timestamp():
    """
    Returns current time as an absolute DIS timestamp.
    This is seconds since epoch, with the Most Significant Bit (MSB) set to 1.
    The value must fit within a 32-bit unsigned integer.
    """
    seconds_since_epoch = int(time.time())
    # Set the MSB to 1 for absolute timestamp.
    # 0x80000000 is 2^31. Unix time in seconds will not exceed 2^31-1 for many decades.
    absolute_timestamp = seconds_since_epoch | 0x80000000
    return absolute_timestamp

# Helper to create DIS EntityID object (remains the same)
def create_entity_id(site, app, entity_val):
    eid = EntityID()
    eid.siteID = site
    eid.applicationID = app
    eid.entityID = entity_val
    return eid

simulated_entities = [] #

def initialize_entities(): #
    global simulated_entities
    simulated_entities = []
    start_lat, start_lon, start_alt = 36.6, -121.9, 1.0

    for i in range(NUM_SIMULATED_ENTITIES):
        lat_offset = (random.random() - 0.5) * 0.05
        lon_offset = (random.random() - 0.5) * 0.05
        initial_ecef = gps.llarpy2ecef(
            deg2rad(start_lat + lat_offset),
            deg2rad(start_lon + lon_offset),
            start_alt + random.uniform(-50, 50), 0, 0, 0
        )
        simulated_entities.append({
            "id_obj": create_entity_id(DEFAULT_SITE_ID, DEFAULT_APPLICATION_ID, 1000 + i),
            "protocol_version": 7,
            "location_x": initial_ecef[0], "location_y": initial_ecef[1], "location_z": initial_ecef[2],
            "orientation_psi": initial_ecef[3], "orientation_theta": initial_ecef[4], "orientation_phi": initial_ecef[5],
            "velocity_x": (random.random() - 0.5) * 2 * MAX_SPEED_METERS_PER_SECOND,
            "velocity_y": (random.random() - 0.5) * 2 * MAX_SPEED_METERS_PER_SECOND,
            "velocity_z": (random.random() - 0.5) * 0.5 * MAX_SPEED_METERS_PER_SECOND,
            "marking": f"Entity-{1000+i}", "force_id": random.choice([1, 2]),
            "entity_kind": 1, "domain": 1, "country": 225,
            "category": random.randint(1, 10), "subcategory": random.randint(1, 10), "specific": random.randint(1, 10),
            "last_espdu_sent_time": time.time()
        })
    print(f"Initialized {NUM_SIMULATED_ENTITIES} entities.")

def update_entity_position(entity, dt): #
    entity["location_x"] += entity["velocity_x"] * dt
    entity["location_y"] += entity["velocity_y"] * dt
    entity["location_z"] += entity["velocity_z"] * dt
    if not (WORLD_BOUNDS_ECEF['x_min'] < entity["location_x"] < WORLD_BOUNDS_ECEF['x_max']):
        entity["velocity_x"] *= -1
        entity["location_x"] = max(WORLD_BOUNDS_ECEF['x_min'], min(entity["location_x"], WORLD_BOUNDS_ECEF['x_max']))
    if not (WORLD_BOUNDS_ECEF['y_min'] < entity["location_y"] < WORLD_BOUNDS_ECEF['y_max']):
        entity["velocity_y"] *= -1
        entity["location_y"] = max(WORLD_BOUNDS_ECEF['y_min'], min(entity["location_y"], WORLD_BOUNDS_ECEF['y_max']))
    if not (WORLD_BOUNDS_ECEF['z_min'] < entity["location_z"] < WORLD_BOUNDS_ECEF['z_max']):
        entity["velocity_z"] *= -1
        entity["location_z"] = max(WORLD_BOUNDS_ECEF['z_min'], min(entity["location_z"], WORLD_BOUNDS_ECEF['z_max']))

#1. EntityStatePdu
def send_entity_state_pdu(entity_state):
    try:
        pdu = EntityStatePdu()
        pdu.protocolVersion = entity_state["protocol_version"]
        pdu.exerciseID = DEFAULT_EXERCISE_ID
        pdu.pduType = 1
        pdu.timestamp = get_current_dis_timestamp()
        pdu.pduStatus = 0
        pdu.entityAppearance = 0
        pdu.capabilities = 0

        # Set Entity ID
        eid = entity_state["id_obj"]
        pdu.entityID.siteID = eid.siteID
        pdu.entityID.applicationID = eid.applicationID
        pdu.entityID.entityID = eid.entityID

        # Set marking (must be 11 characters max)
        pdu.marking.setString(entity_state["marking"].ljust(11)[:11])

        # Location & orientation
        pdu.entityLocation.x = entity_state["location_x"]
        pdu.entityLocation.y = entity_state["location_y"]
        pdu.entityLocation.z = entity_state["location_z"]
        pdu.entityOrientation.psi = entity_state["orientation_psi"]
        pdu.entityOrientation.theta = entity_state["orientation_theta"]
        pdu.entityOrientation.phi = entity_state["orientation_phi"]


        if pdu.protocolVersion == 7:
            pdu.forceId = entity_state["force_id"]
            pdu.entityType.entityKind = entity_state["entity_kind"]
            pdu.entityType.domain = entity_state["domain"]
            pdu.entityType.country = entity_state["country"]
            pdu.entityType.category = entity_state["category"]
            pdu.entityType.subcategory = entity_state["subcategory"]
            pdu.entityType.specific = entity_state["specific"]
            pdu.entityType.extra = 0

        # Serialize and send
        memoryStream = BytesIO()
        outputStream = DataOutputStream(memoryStream)
        pdu.serialize(outputStream)
        data = memoryStream.getvalue()
        udpSocket.sendto(data, (DESTINATION_ADDRESS, UDP_PORT))

        entity_state["last_espdu_sent_time"] = time.time()

        print(f"Sent EntityStatePdu for {entity_state['marking']} ({eid.siteID}, {eid.applicationID}, {eid.entityID}), {len(data)} bytes.")
    except Exception as ex:
        print(f"Error sending EntityStatePdu: {ex}")

# 2. Firepdu
def send_fire_pdu(firing_entity, target_entity):
    if not firing_entity or not target_entity: return
    pdu = FirePdu()
    pdu.protocolVersion = 7
    pdu.exerciseID = DEFAULT_EXERCISE_ID
    pdu.pduType = 2
    pdu.timestamp = get_current_dis_timestamp() # MODIFIED
    pdu.pduStatus = 0
    # ... (rest of the fields set as before) ...
    pdu.firingEntityID.siteID = firing_entity["id_obj"].siteID 
    pdu.firingEntityID.applicationID = firing_entity["id_obj"].applicationID 
    pdu.firingEntityID.entityID = firing_entity["id_obj"].entityID 
    pdu.targetEntityID.siteID = target_entity["id_obj"].siteID 
    pdu.targetEntityID.applicationID = target_entity["id_obj"].applicationID 
    pdu.targetEntityID.entityID = target_entity["id_obj"].entityID 
    pdu.munitionExpendableID.siteID = firing_entity["id_obj"].siteID 
    pdu.munitionExpendableID.applicationID = firing_entity["id_obj"].applicationID 
    pdu.munitionExpendableID.entityID = random.randint(1,100) 

    memoryStream = BytesIO()
    outputStream = DataOutputStream(memoryStream)
    pdu.serialize(outputStream)
    data = memoryStream.getvalue()
    udpSocket.sendto(data, (DESTINATION_ADDRESS, UDP_PORT))
    print(f"Sent FirePdu from {firing_entity['marking']} to {target_entity['marking']} (TS: {pdu.timestamp}). {len(data)} bytes.")

# 3. CollisionPdu
def send_collision_pdu(issuing_entity, colliding_entity):
    if not issuing_entity or not colliding_entity: return
    pdu = CollisionPdu()
    pdu.protocolVersion = 7
    pdu.exerciseID = DEFAULT_EXERCISE_ID
    pdu.pduType = 4
    pdu.timestamp = get_current_dis_timestamp() # MODIFIED
    pdu.pduStatus = 0
    # ... (rest of the fields set as before) ...
    pdu.issuingEntityID.siteID = issuing_entity["id_obj"].siteID 
    pdu.issuingEntityID.applicationID = issuing_entity["id_obj"].applicationID 
    pdu.issuingEntityID.entityID = issuing_entity["id_obj"].entityID 
    pdu.collidingEntityID.siteID = colliding_entity["id_obj"].siteID 
    pdu.collidingEntityID.applicationID = colliding_entity["id_obj"].applicationID 
    pdu.collidingEntityID.entityID = colliding_entity["id_obj"].entityID 

    memoryStream = BytesIO()
    outputStream = DataOutputStream(memoryStream)
    pdu.serialize(outputStream)
    data = memoryStream.getvalue()
    udpSocket.sendto(data, (DESTINATION_ADDRESS, UDP_PORT))
    print(f"Sent CollisionPdu between {issuing_entity['marking']} and {colliding_entity['marking']} (TS: {pdu.timestamp}). {len(data)} bytes.")

# 4. DetonationPdu
def send_detonation_pdu(firing_entity, target_entity):
    if not firing_entity or not target_entity:
        return

    pdu = DetonationPdu()
    pdu.protocolVersion = 7
    pdu.exerciseID = DEFAULT_EXERCISE_ID
    pdu.pduType = 3
    pdu.timestamp = get_current_dis_timestamp()
    pdu.pduStatus = 0

    # Entity IDs
    pdu.firingEntityID.siteID = firing_entity["id_obj"].siteID
    pdu.firingEntityID.applicationID = firing_entity["id_obj"].applicationID
    pdu.firingEntityID.entityID = firing_entity["id_obj"].entityID

    pdu.targetEntityID.siteID = target_entity["id_obj"].siteID
    pdu.targetEntityID.applicationID = target_entity["id_obj"].applicationID
    pdu.targetEntityID.entityID = target_entity["id_obj"].entityID

    pdu.locationInEntityCoordinates.x = 1000.0
    pdu.locationInEntityCoordinates.y = 2000.0
    pdu.locationInEntityCoordinates.z = 0.0

    pdu.velocity.x = 0.0
    pdu.velocity.y = 0.0
    pdu.velocity.z = 0.0

    memoryStream = BytesIO()
    outputStream = DataOutputStream(memoryStream)
    pdu.serialize(outputStream)
    data = memoryStream.getvalue()
    udpSocket.sendto(data, (DESTINATION_ADDRESS, UDP_PORT))

    print(f"Sent DetonationPdu from {firing_entity['marking']} to {target_entity['marking']} (TS: {pdu.timestamp}). {len(data)} bytes.")

# 5. DataPdu
def send_data_pdu(originatingEntityID, receivingEntityID):
    if not originatingEntityID or not receivingEntityID:
        return
    pdu = DataPdu()
    pdu.protocolVersion = 7
    pdu.exerciseID = DEFAULT_EXERCISE_ID
    pdu.pduType = 20  # Corrected PDU type for DataPdu
    pdu.pduStatus = 0 
    pdu.timestamp = get_current_dis_timestamp()
    pdu.pduStatus = 0

    # Entity IDs
    pdu.originatingEntityID.siteID = originatingEntityID["id_obj"].siteID
    pdu.originatingEntityID.applicationID = originatingEntityID["id_obj"].applicationID
    pdu.originatingEntityID.entityID = originatingEntityID["id_obj"].entityID

    pdu.receivingEntityID.siteID = receivingEntityID["id_obj"].siteID
    pdu.receivingEntityID.applicationID = receivingEntityID["id_obj"].applicationID
    pdu.receivingEntityID.entityID = receivingEntityID["id_obj"].entityID

    pdu.dataValues = b"HelloDIS"

    memoryStream = BytesIO()
    outputStream = DataOutputStream(memoryStream)
    pdu.serialize(outputStream)
    data = memoryStream.getvalue()
    udpSocket.sendto(data, (DESTINATION_ADDRESS, UDP_PORT))

    print(f"Sent DataPdu from {originatingEntityID['marking']} to {receivingEntityID['marking']} (TS: {pdu.timestamp}). {len(data)} bytes.")

# 6. ActionRequestPdu
def send_action_request_pdu(originatingEntityID, receivingEntityID):
    if not originatingEntityID or not receivingEntityID:
        return

    pdu = ActionRequestPdu()
    pdu.protocolVersion = 7
    pdu.exerciseID = DEFAULT_EXERCISE_ID
    pdu.pduType = 16  # Correct PDU type for ActionRequestPdu
    pdu.timestamp = get_current_dis_timestamp()
    pdu.pduStatus = 0

    # Entity IDs
    pdu.originatingEntityID.siteID = originatingEntityID["id_obj"].siteID
    pdu.originatingEntityID.applicationID = originatingEntityID["id_obj"].applicationID
    pdu.originatingEntityID.entityID = originatingEntityID["id_obj"].entityID

    pdu.receivingEntityID.siteID = receivingEntityID["id_obj"].siteID
    pdu.receivingEntityID.applicationID = receivingEntityID["id_obj"].applicationID
    pdu.receivingEntityID.entityID = receivingEntityID["id_obj"].entityID

    memoryStream = BytesIO()
    outputStream = DataOutputStream(memoryStream)
    pdu.serialize(outputStream)
    data = memoryStream.getvalue()
    udpSocket.sendto(data, (DESTINATION_ADDRESS, UDP_PORT))

    print(f"Sent ActionRequestPdu from {originatingEntityID['marking']} to {receivingEntityID['marking']} (TS: {pdu.timestamp}). {len(data)} bytes.")

# 7. StartResumePdu
def send_start_resume_pdu():
    pdu = StartResumePdu()
    pdu.protocolVersion = 7
    pdu.exerciseID = DEFAULT_EXERCISE_ID
    pdu.pduType = 13  # Correct PDU type for StartResumePdu
    pdu.timestamp = get_current_dis_timestamp()
    # pdu.realWorldTime = int(time.time())
    pdu.realWorldTime = ClockTime()
    pdu.realWorldTime.time = int(time.time())
    pdu.realWorldTime.fraction = 0  
    pdu.pduStatus = 0

    memoryStream = BytesIO()
    outputStream = DataOutputStream(memoryStream)
    pdu.serialize(outputStream)
    data = memoryStream.getvalue()
    udpSocket.sendto(data, (DESTINATION_ADDRESS, UDP_PORT))
    print(f"Sent StartResumePdu (TS: {pdu.timestamp}). {len(data)} bytes.")

# 8. SetDataPdu
def send_set_data_pdu(entity):
    pdu = SetDataPdu()
    pdu.protocolVersion = 7
    pdu.exerciseID = DEFAULT_EXERCISE_ID
    pdu.pduType = 19  # Corrected PDU type for SetDataPdu
    pdu.timestamp = get_current_dis_timestamp()
    pdu.originatingEntityID = entity["id_obj"]
    pdu.dataValues = b"SetDataExample"
    pdu.pduStatus = 0

    memoryStream = BytesIO()
    outputStream = DataOutputStream(memoryStream)
    pdu.serialize(outputStream)
    data = memoryStream.getvalue()
    udpSocket.sendto(data, (DESTINATION_ADDRESS, UDP_PORT))
    print(f"Sent SetDataPdu from {entity['marking']} (TS: {pdu.timestamp}). {len(data)} bytes.")

# 9. DesignatorPdu
def send_designator_pdu(entity):
    pdu = DesignatorPdu()
    pdu.protocolVersion = 7
    pdu.exerciseID = DEFAULT_EXERCISE_ID
    pdu.pduType = 24  # Corrected PDU type for DesignatorPdu
    pdu.timestamp = get_current_dis_timestamp()
    pdu.designatingEntityID = entity["id_obj"]
    pdu.pduStatus = 0

    memoryStream = BytesIO()
    outputStream = DataOutputStream(memoryStream)
    pdu.serialize(outputStream)
    data = memoryStream.getvalue()
    udpSocket.sendto(data, (DESTINATION_ADDRESS, UDP_PORT))
    print(f"Sent DesignatorPdu from {entity['marking']} (TS: {pdu.timestamp}). {len(data)} bytes.")

# 10. ElectromagneticEmissionsPdu
def send_emission_pdu(entity):
    pdu = ElectromagneticEmissionsPdu()
    pdu.protocolVersion = 7
    pdu.exerciseID = DEFAULT_EXERCISE_ID
    pdu.pduType = 23  # Corrected PDU type for ElectromagneticEmissionsPdu
    pdu.timestamp = get_current_dis_timestamp()
    pdu.emittingEntityID = entity["id_obj"]
    pdu.pduStatus = 0

    memoryStream = BytesIO()
    outputStream = DataOutputStream(memoryStream)
    pdu.serialize(outputStream)
    data = memoryStream.getvalue()
    udpSocket.sendto(data, (DESTINATION_ADDRESS, UDP_PORT))
    print(f"Sent ElectromagneticEmissionsPdu from {entity['marking']} (TS: {pdu.timestamp}). {len(data)} bytes.")


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
            if dt <= 0:
                dt = 0.01
            last_update_time = current_time

            if not simulated_entities:
                break

            for entity in simulated_entities:
                update_entity_position(entity, dt)

                if current_time - entity.get("last_espdu_sent_time", 0) >= espdu_send_interval:
                    send_entity_state_pdu(entity)
                    total_pdus_sent += 1

                # Fire PDU - equally distributed with other PDU types
                if random.random() < FIRE_EVENT_PROBABILITY * (dt / espdu_send_interval if espdu_send_interval > 0 else 1.0):
                    possible_targets = [e for e in simulated_entities if e["id_obj"].entityID != entity["id_obj"].entityID]
                    if possible_targets:
                        target_entity = random.choice(possible_targets)
                        send_fire_pdu(entity, target_entity)
                        total_pdus_sent += 1
                
                # Detonation PDU - now independent from Fire PDU
                if random.random() < DETONATION_PDU_PROBABILITY * (dt / espdu_send_interval if espdu_send_interval > 0 else 1.0):
                    possible_targets = [e for e in simulated_entities if e["id_obj"].entityID != entity["id_obj"].entityID]
                    if possible_targets:
                        target_entity = random.choice(possible_targets)
                        send_detonation_pdu(entity, target_entity)
                        total_pdus_sent += 1

                # Collision PDU
                if random.random() < COLLISION_EVENT_PROBABILITY * (dt / espdu_send_interval if espdu_send_interval > 0 else 1.0):
                    possible_collisions = [e for e in simulated_entities if e["id_obj"].entityID != entity["id_obj"].entityID]
                    if possible_collisions:
                        colliding_entity = random.choice(possible_collisions)
                        send_collision_pdu(entity, colliding_entity)
                        total_pdus_sent += 1

                # Data PDU
                if random.random() < DATA_PDU_PROBABILITY * (dt / espdu_send_interval if espdu_send_interval > 0 else 1.0):
                    possible_targets = [e for e in simulated_entities if e["id_obj"].entityID != entity["id_obj"].entityID]
                    if possible_targets:
                        target = random.choice(possible_targets)
                        send_data_pdu(entity, target)
                        total_pdus_sent += 1
                
                # Action Request PDU
                if random.random() < ACTION_REQUEST_PDU_PROBABILITY * (dt / espdu_send_interval if espdu_send_interval > 0 else 1.0):
                    possible_targets = [e for e in simulated_entities if e["id_obj"].entityID != entity["id_obj"].entityID]
                    if possible_targets:
                        target = random.choice(possible_targets)
                        send_action_request_pdu(entity, target)
                        total_pdus_sent += 1
                
                # Start Resume PDU
                if random.random() < START_RESUME_PDU_PROBABILITY * (dt / espdu_send_interval if espdu_send_interval > 0 else 1.0):
                    send_start_resume_pdu()
                    total_pdus_sent += 1
                
                # Set Data PDU
                if random.random() < SET_DATA_PDU_PROBABILITY * (dt / espdu_send_interval if espdu_send_interval > 0 else 1.0):
                    send_set_data_pdu(entity)
                    total_pdus_sent += 1
                
                # Designator PDU
                if random.random() < DESIGNATOR_PDU_PROBABILITY * (dt / espdu_send_interval if espdu_send_interval > 0 else 1.0):
                    send_designator_pdu(entity)
                    total_pdus_sent += 1

                # Electromagnetic Emissions PDU
                if random.random() < EMISSION_PDU_PROBABILITY * (dt / espdu_send_interval if espdu_send_interval > 0 else 1.0):
                    send_emission_pdu(entity)
                    total_pdus_sent += 1

            time.sleep(max(0.01, espdu_send_interval / (NUM_SIMULATED_ENTITIES if NUM_SIMULATED_ENTITIES > 0 else 1) / 10.0))

    except KeyboardInterrupt:
        print("\nSimulation stopped by user.")
    finally:
        print(f"Simulation finished. Total time: {time.time() - start_time:.2f} seconds.")
        print(f"Total PDUs sent: {total_pdus_sent}")
        udpSocket.close()

if __name__ == "__main__":
    main()
