# qsys scripting (.tcl) file for fft
package require -exact qsys 16.0

create_system {fft}

set_project_property DEVICE_FAMILY {MAX 10}
set_project_property DEVICE {10M02DCU324A6G}
set_project_property HIDE_FROM_IP_CATALOG {true}

# Instances and instance parameters
# (disabled instances are intentionally culled)
add_instance fft_ii_0 altera_fft_ii 17.1
set_instance_parameter_value fft_ii_0 {data_flow} {Burst}
set_instance_parameter_value fft_ii_0 {data_rep} {Block Floating Point}
set_instance_parameter_value fft_ii_0 {direction} {Bi-directional}
set_instance_parameter_value fft_ii_0 {dsp_resource_opt} {0}
set_instance_parameter_value fft_ii_0 {engine_arch} {Quad Output}
set_instance_parameter_value fft_ii_0 {hard_fp} {0}
set_instance_parameter_value fft_ii_0 {hyper_opt} {0}
set_instance_parameter_value fft_ii_0 {in_order} {Natural}
set_instance_parameter_value fft_ii_0 {in_width} {12}
set_instance_parameter_value fft_ii_0 {length} {2048}
set_instance_parameter_value fft_ii_0 {num_engines} {1}
set_instance_parameter_value fft_ii_0 {out_order} {Natural}
set_instance_parameter_value fft_ii_0 {out_width} {29}
set_instance_parameter_value fft_ii_0 {twid_width} {12}

# exported interfaces
set_instance_property fft_ii_0 AUTO_EXPORT {true}

# interconnect requirements
set_interconnect_requirement {$system} {qsys_mm.clockCrossingAdapter} {HANDSHAKE}
set_interconnect_requirement {$system} {qsys_mm.enableEccProtection} {FALSE}
set_interconnect_requirement {$system} {qsys_mm.insertDefaultSlave} {FALSE}
set_interconnect_requirement {$system} {qsys_mm.maxAdditionalLatency} {1}

save_system {fft.qsys}
