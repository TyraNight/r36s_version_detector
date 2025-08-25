# r36s_version_detector

Small, plug-and-play script to identify your **R36S** setup:
- Detects whether you’re running **ArkOS (AEUX)** or **EmuELEC**
- Maps DTB **MD5** → screen panel revision (**V3 / V4 / Panel 4 (V5) / old V5**)
- Works from EmulationStation with a simple `dialog` UI and writes a log next to the script

## Installation

**Stock/original microSD (factory setup)**  
1. Copy the script to `Easyroms/`.  
2. In EmulationStation, open **Options → 351Files** and copy the script to `opt/system`.  
   > Otherwise it won’t show up in the Tools menu on the original microSD.

**Reinstalled console (ArkOS / AEUX / K36)**  
- Copy the script to `Easyroms/tools/` and run it from the EmulationStation **Tools** menu.
