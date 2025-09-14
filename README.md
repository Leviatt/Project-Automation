# PLC Automation Simulation – Assembly Line

## System Overview

This project implements a simplified assembly line with conveyors, clamps, and a pick-and-place arm.  
The control logic is written in Structured Text (ST) and tested with **OpenPLC + Factory I/O**.  
It demonstrates finite state machine (FSM) design for each subsystem and basic fault handling.

## Hardware / Software Assumptions

- **PLC Runtime**: OpenPLC v3  
- **Simulation**: Factory I/O (trial)  
- **Programming Language**: IEC 61131-3 Structured Text  
- **I/O Mapping**:  
  - `%IX100.*` → sensors, push buttons, clamps feedback  
  - `%QX100.* / %QX101.*` → actuators (motors, clamps, arm axes, blade)  

## Setup Instructions

1. Import the `Assembly.st` program into OpenPLC Editor.  
2. Start the OpenPLC runtime and load the compiled program.  
3. In Factory I/O, configure the **PLC driver** (Modbus/TCP or OpenPLC) and map the I/Os according to the provided addresses.  
4. Start the simulation: pressing **Start** will begin the process cycle.  

## Logic Description

The system is organized into FSMs:

- **Conveyors (Lids and Bases)**:  
  - States: Idle → Running → Waiting for pickup/placement.  
  - Jams detected via timeout → trigger fault state.  
- **Clamps (Lid and Base)**:  
  - States: Open → Clamp → Release after successful grab/place.  
- **Arm (Pick-and-Place)**:  
  - States: Idle → Move Z down → Grab → Move X → Place → Return.  
- **Blade**:  
  - Activates after base arrives, cuts part, then releases conveyor.  

All subsystems run inside the global **STATE machine**:

- `STATE = 0` → Stop (reset, waiting for Start)  
- `STATE = 1` → Run (normal operation)  
- `STATE = 2` → Fault (timeouts, jams, or emergency stop)  

## Fault Handling

- **Timeouts** on Z or X movement trigger a fault (STATE=2).  
- **Emergency Stop** can be added by wiring `%IX100.*` input and forcing STATE=2.  
- Recovery: press Start again after clearing the condition.  
- Alarm lamp turns ON in fault state, run lamp OFF.  

## Migration Notes

An older system would use linear or monolithic ladder logic.  
This implementation migrates to **modular FSMs** per subsystem, improving readability, reusability, and scalability.  
In a TIA Portal project, each FSM can be an FB with its own instance DB.  

## Scalability

To scale this solution for production:  

- Modularize logic into FBs for each conveyor, clamp, and arm axis.  
- Add HMI for operator control, diagnostics, counters, and alarm history.  
- Expand fault handling: individual alarm codes, retry strategies.  
- Support networking (OPC UA, Profinet) for SCADA/MES integration.  
- Safety integration: certified E-Stop, door switches, safe I/O modules.  
- Hardware scaling: multiple arms or conveyors can be added by instantiating additional FBs without rewriting core logic.  

## Block Diagrams

Block diagrams (`Block-diagrams.pdf`) are included to visualize the FSMs for:  

- Lids conveyor  
- Bases conveyor  
- Clamps (lid and base)  
- Arm  

## Video Demo

A short screen recording (2–6 minutes) should demonstrate:  

- PLC project setup in OpenPLC  
- Factory I/O simulation running  
- Explanation of FSM transitions  
- Example of fault handling (e.g., trigger jam, recovery)  

---


