#####################################################################
#
# Init setup file
# Created by Genus(TM) Synthesis Solution on 09/12/2019 09:08:20
#
#####################################################################


read_mmmc /home/student/pziebinski/projekt/PPCU_ALU/synth/RESULTS/mtm_Alu.mmmc.tcl

read_physical -lef {/cad/dk/umc180/SUS/SUSLIB_UCL_tech.lef /cad/dk/umc180/SUS/SUSLIB_UCL.lef}

read_netlist /home/student/pziebinski/projekt/PPCU_ALU/synth/RESULTS/mtm_Alu.v

init_design -skip_sdc_read
