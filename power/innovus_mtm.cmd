#######################################################
#                                                     
#  Innovus Command Logging File                     
#  Created on Sat Sep  7 22:24:00 2019                
#                                                     
#######################################################

#@(#)CDS: Innovus v17.13-s098_1 (64bit) 02/08/2018 11:26 (Linux 2.6.18-194.el5)
#@(#)CDS: NanoRoute 17.13-s098_1 NR180117-1602/17_13-UB (database version 2.30, 414.7.1) {superthreading v1.44}
#@(#)CDS: AAE 17.13-s036 (64bit) 02/08/2018 (Linux 2.6.18-194.el5)
#@(#)CDS: CTE 17.13-s031_1 () Feb  1 2018 09:16:44 ( )
#@(#)CDS: SYNTECH 17.13-s011_1 () Jan 14 2018 01:24:42 ( )
#@(#)CDS: CPE v17.13-s062
#@(#)CDS: IQRC/TQRC 16.1.1-s220 (64bit) Fri Aug  4 09:53:48 PDT 2017 (Linux 2.6.18-194.el5)

read_db ../pr/RESULTS_PR/mtm_Alu_innovus
set_analysis_view -dynamic BC_av -leakage BC_av -setup WC_av -hold BC_av
reset_power_activity
read_activity_file ../run_post/RESULTS/mtm_Alu.tcf -format TCF -scope DUT
report_unannotated_nets -type tcf
report_unannotated_nets -type tcf -file REPORTS/tcf_unannotated_nets.rpt
report_power -out_dir REPORTS -report_prefix pwr -format simple
