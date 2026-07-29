# EGO1 configuration bank uses 3.3 V. Set both device properties so Vivado
# can fully evaluate configuration-bank I/O voltage support.
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

# Switches, board reset, and UART RX are asynchronous physical inputs. Their
# first product-domain stages own metastability containment, so there is no
# synchronous external launch relationship to the 50 MHz product clock.
set_false_path -from [get_ports {fpga_rst rx sw[*]}]

# LED, seven-segment, and UART TX outputs are observed asynchronously by board
# devices or a serial receiver; no external capture clock exists in this SoC.
set_false_path -to [get_ports {led[*] dig_en[*] dig_seg[*] dig_seg1[*] tx}]
