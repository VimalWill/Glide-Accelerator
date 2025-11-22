#!/bin/bash
####################################################################################
# Vivado Automation Script
# Project: Efficient Transformer Accelerator - Systolic-Quant Integration
# Usage: ./run_vivado.sh [sim|synth|both|clean|help]
####################################################################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HW_DIR="$SCRIPT_DIR"
SCRIPTS_DIR="$HW_DIR/scripts"

# Check if Vivado is in PATH
if ! command -v vivado &> /dev/null; then
    echo -e "${RED}ERROR: Vivado not found in PATH${NC}"
    echo "Please source Vivado settings first:"
    echo "  source /tools/Xilinx/Vivado/<version>/settings64.sh"
    exit 1
fi

# Display header
print_header() {
    echo -e "${BLUE}=========================================="
    echo -e "$1"
    echo -e "==========================================${NC}"
}

# Run simulation
run_simulation() {
    print_header "Running Vivado Simulation"

    cd "$SCRIPTS_DIR" || exit 1

    echo -e "${YELLOW}Launching Vivado in batch mode...${NC}"
    vivado -mode batch -source vivado_sim.tcl -log ../vivado_sim.log -journal ../vivado_sim.jou

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Simulation completed successfully${NC}"
        echo -e "  Log file: vivado_sim.log"
        echo -e "  Journal: vivado_sim.jou"
    else
        echo -e "${RED}✗ Simulation failed${NC}"
        echo -e "  Check vivado_sim.log for details"
        exit 1
    fi

    cd "$HW_DIR" || exit 1
}

# Run synthesis
run_synthesis() {
    print_header "Running Vivado Synthesis"

    cd "$SCRIPTS_DIR" || exit 1

    echo -e "${YELLOW}Launching Vivado synthesis...${NC}"
    vivado -mode batch -source vivado_synth.tcl -log ../vivado_synth.log -journal ../vivado_synth.jou

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Synthesis completed successfully${NC}"
        echo -e "  Log file: vivado_synth.log"
        echo -e "  Reports: vivado_synth/"
        echo ""
        echo -e "${BLUE}Resource utilization summary:${NC}"
        grep -A 20 "Slice Logic Distribution" vivado_synth/utilization.rpt 2>/dev/null || echo "  (Open project in GUI to see detailed reports)"
    else
        echo -e "${RED}✗ Synthesis failed${NC}"
        echo -e "  Check vivado_synth.log for details"
        exit 1
    fi

    cd "$HW_DIR" || exit 1
}

# Run simulation in GUI mode
run_simulation_gui() {
    print_header "Launching Vivado Simulator GUI"

    cd "$SCRIPTS_DIR" || exit 1

    echo -e "${YELLOW}Opening Vivado GUI...${NC}"
    vivado -mode gui -source vivado_sim.tcl &

    echo -e "${GREEN}Vivado GUI launched${NC}"
    echo -e "  The simulation will run automatically"
    echo -e "  Add signals to waveform viewer to see results"

    cd "$HW_DIR" || exit 1
}

# Run synthesis in GUI mode
run_synthesis_gui() {
    print_header "Launching Vivado Synthesis GUI"

    cd "$SCRIPTS_DIR" || exit 1

    echo -e "${YELLOW}Opening Vivado GUI...${NC}"
    vivado -mode gui -source vivado_synth.tcl &

    echo -e "${GREEN}Vivado GUI launched${NC}"

    cd "$HW_DIR" || exit 1
}

# Run implementation
run_implementation() {
    print_header "Running Vivado Implementation (Place & Route)"

    cd "$SCRIPTS_DIR" || exit 1

    echo -e "${YELLOW}Launching implementation...${NC}"
    echo -e "  This may take several minutes depending on design complexity"
    vivado -mode batch -source vivado_impl.tcl -log ../vivado_impl.log -journal ../vivado_impl.jou

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Implementation completed successfully${NC}"
        echo -e "  Log file: vivado_impl.log"
        echo -e "  Reports: vivado_synth/impl_*.rpt"
        echo ""
        echo -e "${BLUE}Check timing summary:${NC}"
        grep -A 5 "Timing Closure Check" ../vivado_impl.log 2>/dev/null || echo "  (Check vivado_impl.log for details)"
    else
        echo -e "${RED}✗ Implementation failed${NC}"
        echo -e "  Check vivado_impl.log for details"
        exit 1
    fi

    cd "$HW_DIR" || exit 1
}

# Run implementation in GUI mode
run_implementation_gui() {
    print_header "Launching Vivado Implementation GUI"

    cd "$SCRIPTS_DIR" || exit 1

    echo -e "${YELLOW}Opening Vivado GUI for implementation...${NC}"
    vivado -mode gui -source vivado_impl.tcl &

    echo -e "${GREEN}Vivado GUI launched${NC}"

    cd "$HW_DIR" || exit 1
}

# Package IP
package_ip() {
    print_header "Packaging IP"

    cd "$SCRIPTS_DIR" || exit 1

    echo -e "${YELLOW}Creating Vivado IP package...${NC}"
    vivado -mode batch -source create_ip.tcl -log ../vivado_ip.log -journal ../vivado_ip.jou

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ IP packaging completed successfully${NC}"
        echo -e "  Log file: vivado_ip.log"
        echo -e "  IP location: ip_repo/"
        echo ""
        echo -e "${BLUE}To use this IP:${NC}"
        echo -e "  1. Open Vivado project"
        echo -e "  2. Settings -> IP -> Repository"
        echo -e "  3. Add: $HW_DIR/ip_repo"
        echo -e "  4. Find 'Systolic Array Accelerator' in IP Catalog"
    else
        echo -e "${RED}✗ IP packaging failed${NC}"
        echo -e "  Check vivado_ip.log for details"
        exit 1
    fi

    cd "$HW_DIR" || exit 1
}

# Create block design
create_block_design() {
    print_header "Creating Block Design (PS + PL)"

    cd "$SCRIPTS_DIR" || exit 1

    echo -e "${YELLOW}Creating Zynq UltraScale+ block design...${NC}"
    echo -e "  This will create a complete PS-PL system"
    vivado -mode batch -source create_bd.tcl -log ../vivado_bd.log -journal ../vivado_bd.jou

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Block design created successfully${NC}"
        echo -e "  Log file: vivado_bd.log"
        echo ""
        echo -e "${BLUE}Memory Map:${NC}"
        echo -e "  Systolic Accelerator: 0xA000_0000"
        echo -e "  DMA Input:            0xA001_0000"
        echo -e "  DMA Output:           0xA002_0000"
        echo -e "  Interrupt Controller: 0xA003_0000"
    else
        echo -e "${RED}✗ Block design creation failed${NC}"
        echo -e "  Check vivado_bd.log for details"
        exit 1
    fi

    cd "$HW_DIR" || exit 1
}

# Create block design in GUI
create_block_design_gui() {
    print_header "Creating Block Design (PS + PL) in GUI"

    cd "$SCRIPTS_DIR" || exit 1

    echo -e "${YELLOW}Opening Vivado GUI with block design...${NC}"
    echo -e "  You will be able to see and modify the design"
    vivado -mode gui -source create_bd_gui.tcl &

    echo -e "${GREEN}Vivado GUI launched${NC}"
    echo -e "  The block design will be created and opened automatically"

    cd "$HW_DIR" || exit 1
}

# Clean generated files
clean_project() {
    print_header "Cleaning Vivado Projects"

    echo -e "${YELLOW}Removing generated files...${NC}"

    # Simulation files
    rm -rf "$SCRIPTS_DIR/vivado_sim"
    rm -f "$HW_DIR/vivado_sim.log"
    rm -f "$HW_DIR/vivado_sim.jou"

    # Synthesis files
    rm -rf "$SCRIPTS_DIR/vivado_synth"
    rm -f "$HW_DIR/vivado_synth.log"
    rm -f "$HW_DIR/vivado_synth.jou"

    # Implementation files
    rm -f "$HW_DIR/vivado_impl.log"
    rm -f "$HW_DIR/vivado_impl.jou"

    # IP and BD files
    rm -rf "$HW_DIR/ip_repo"
    rm -f "$HW_DIR/vivado_ip.log"
    rm -f "$HW_DIR/vivado_ip.jou"
    rm -f "$HW_DIR/vivado_bd.log"
    rm -f "$HW_DIR/vivado_bd.jou"

    # Other Vivado files
    rm -rf "$HW_DIR/.Xil"
    rm -rf "$SCRIPTS_DIR/.Xil"
    rm -f "$HW_DIR/vivado*.backup.log"
    rm -f "$HW_DIR/vivado*.backup.jou"

    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

# Display usage
show_usage() {
    echo -e "${BLUE}Usage: $0 [OPTION]${NC}"
    echo ""
    echo "Options:"
    echo "  sim         Run behavioral simulation (batch mode)"
    echo "  sim-gui     Run simulation in GUI mode"
    echo "  synth       Run synthesis (batch mode)"
    echo "  synth-gui   Run synthesis in GUI mode"
    echo "  impl        Run implementation/place & route (batch mode)"
    echo "  impl-gui    Run implementation in GUI mode"
    echo "  both        Run simulation and synthesis (batch)"
    echo "  full        Run simulation, synthesis, and implementation (batch)"
    echo "  package-ip  Package design as Vivado IP"
    echo "  create-bd   Create block design with PS + PL integration (batch)"
    echo "  create-bd-gui Create block design and open in GUI"
    echo "  clean       Remove all generated files"
    echo "  help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 sim              # Run simulation in batch mode"
    echo "  $0 sim-gui          # Open simulation in Vivado GUI"
    echo "  $0 synth            # Run synthesis"
    echo "  $0 impl             # Run implementation (requires synthesis first)"
    echo "  $0 full             # Run complete flow: sim -> synth -> impl"
    echo "  $0 package-ip       # Package as IP for reuse"
    echo "  $0 create-bd        # Create Zynq block design"
    echo "  $0 create-bd-gui    # Create block design in GUI (visual)"
    echo "  $0 clean            # Clean all generated files"
    echo ""
}

# Main script logic
main() {
    case "$1" in
        sim)
            run_simulation
            ;;
        sim-gui)
            run_simulation_gui
            ;;
        synth)
            run_synthesis
            ;;
        synth-gui)
            run_synthesis_gui
            ;;
        impl)
            run_implementation
            ;;
        impl-gui)
            run_implementation_gui
            ;;
        both)
            run_simulation
            echo ""
            run_synthesis
            ;;
        full)
            run_simulation
            echo ""
            run_synthesis
            echo ""
            run_implementation
            ;;
        package-ip)
            package_ip
            ;;
        create-bd)
            create_block_design
            ;;
        create-bd-gui)
            create_block_design_gui
            ;;
        clean)
            clean_project
            ;;
        help|--help|-h)
            show_usage
            ;;
        "")
            echo -e "${RED}ERROR: No option specified${NC}"
            echo ""
            show_usage
            exit 1
            ;;
        *)
            echo -e "${RED}ERROR: Unknown option '$1'${NC}"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
