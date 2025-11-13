#!/bin/bash

################################################################################
# Vivado Non-GUI Run Script
# Runs synthesis and implementation for requantization module
################################################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}Vivado Non-GUI Flow Runner${NC}"
echo -e "${GREEN}======================================${NC}"

# Check if Vivado is available
if ! command -v vivado &> /dev/null
then
    echo -e "${RED}Error: Vivado not found in PATH${NC}"
    echo "Please source Vivado settings:"
    echo "  source /tools/Xilinx/Vivado/<version>/settings64.sh"
    exit 1
fi

# Show Vivado version
echo -e "\n${YELLOW}Vivado Version:${NC}"
vivado -version | head -n 3

# Navigate to scripts directory
cd "$(dirname "$0")/scripts" || exit 1

# Run Vivado in batch mode
echo -e "\n${GREEN}Starting Vivado in batch mode...${NC}"
echo -e "${YELLOW}This may take several minutes...${NC}\n"

vivado -mode batch -source vivado_flow.tcl -log vivado_run.log -journal vivado_run.jou

# Check exit status
if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}======================================${NC}"
    echo -e "${GREEN}Vivado flow completed successfully!${NC}"
    echo -e "${GREEN}======================================${NC}"

    echo -e "\n${YELLOW}Check the following for results:${NC}"
    echo "  - Reports: reports/"
    echo "  - Project: scripts/build/"
    echo "  - Log file: scripts/vivado_run.log"

    # Show timing summary if available
    if [ -f "../reports/post_impl_timing_summary.rpt" ]; then
        echo -e "\n${YELLOW}Quick Timing Summary:${NC}"
        grep -A 5 "Design Timing Summary" ../reports/post_impl_timing_summary.rpt 2>/dev/null || echo "See reports/post_impl_timing_summary.rpt"
    fi

else
    echo -e "\n${RED}======================================${NC}"
    echo -e "${RED}Vivado flow failed!${NC}"
    echo -e "${RED}======================================${NC}"
    echo -e "Check the log file: scripts/vivado_run.log"
    exit 1
fi
