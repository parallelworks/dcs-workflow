# CREATE MONTECARLO MACRO SCRIPT
out_hst=$(basename ${dcs_model_file%.*})_${case_index}

cat >> macroScript.txt <<END
DCSVERS	200
DCSMSSG	1  0
DCSWORK .
DCSCOMPLIANT 1
DCSMECHANICAL 1

DCSLOADDLL1 C:\Program Files\DCS\3DCS_MC_8_0_0_2\addIns\Extra_Dlls\dcu_lsqgeomv.dll
DCSLOADDLL1 C:\Program Files\DCS\3DCS_MC_8_0_0_2\addIns\Extra_Dlls\dcu_3devmove.dll
DCSLOADDLL1 C:\Program Files\DCS\3DCS_MC_8_0_0_2\addIns\Extra_Dlls\dcu_AxisTol.dll
DCSLOADDLL1 C:\Program Files\DCS\3DCS_MC_8_0_0_2\addIns\Extra_Dlls\dcu_calcdir.dll
DCSLOADDLL1 C:\Program Files\DCS\3DCS_MC_8_0_0_2\addIns\Extra_Dlls\dcu_CntrPntTl.dll
DCSLOADDLL1 C:\Program Files\DCS\3DCS_MC_8_0_0_2\addIns\Extra_Dlls\dcu_floatMv.dll
DCSLOADDLL1 C:\Program Files\DCS\3DCS_MC_8_0_0_2\addIns\Extra_Dlls\dcu_formTl.dll
DCSLOADDLL1 C:\Program Files\DCS\3DCS_MC_8_0_0_2\addIns\Extra_Dlls\dcu_linfloat.dll
DCSLOADDLL1 C:\Program Files\DCS\3DCS_MC_8_0_0_2\addIns\Extra_Dlls\dcu_loopMv.dll
DCSLOADDLL1 C:\Program Files\DCS\3DCS_MC_8_0_0_2\addIns\Extra_Dlls\dcu_lsqgeomv.dll
DCSLOADDLL1 C:\Program Files\DCS\3DCS_MC_8_0_0_2\addIns\Extra_Dlls\dcu_mtmlib1.dll
DCSLOADDLL1 C:\Program Files\DCS\3DCS_MC_8_0_0_2\addIns\Extra_Dlls\dcu_mtmlib2.dll
DCSLOADDLL1 C:\Program Files\DCS\3DCS_MC_8_0_0_2\addIns\Extra_Dlls\dcu_MultiPtTrans.dll
DCSLOADDLL1 C:\Program Files\DCS\3DCS_MC_8_0_0_2\addIns\Extra_Dlls\dcu_NestMove.dll
DCSLOADDLL1 C:\Program Files\DCS\3DCS_MC_8_0_0_2\addIns\Extra_Dlls\dcu_Polyfloat.dll
DCSLOADDLL1 C:\Program Files\DCS\3DCS_MC_8_0_0_2\addIns\Extra_Dlls\dcu_vblock.dll
DCSLOADDLL1 C:\Program Files\DCS\3DCS_MC_8_0_0_2\addIns\Extra_Dlls\dcu_xformMv.dll


DCSLOADDLL1 C:\Program Files\DCS\3DCS_MC_8_0_0_2\addIns\dcu_autobend.dll
DCSLOADDLL1 C:\Program Files\DCS\3DCS_MC_8_0_0_2\addIns\dcu_avgmove.dll
DCSLOADDLL1 C:\Program Files\DCS\3DCS_MC_8_0_0_2\addIns\dcu_cr2cr.dll
DCSLOADDLL1 C:\Program Files\DCS\3DCS_MC_8_0_0_2\addIns\dcu_avgtole.dll
DCSLOADDLL1 C:\Program Files\DCS\3DCS_MC_8_0_0_2\addIns\dcu_cmmdev2.dll
DCSLOADDLL1 C:\Program Files\DCS\3DCS_MC_8_0_0_2\addIns\dcu_stat_row.dll

DCS_DEL_FILE *.hst

DCSLOAD ${dcs_model_file}

DCS_CFG_SETTING ${dcs_thread} 0

DCSSIMU_RUN_WITH_SEED 1 ${dcs_num_seeds} ${dcs_concurrency} ${case_index}
DCS_DATA ${out_hst}
END
