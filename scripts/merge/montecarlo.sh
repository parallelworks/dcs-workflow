
# generate the 3DCS macro script for the run
echo "Writing Macro File..."
echo

in_name=$(basename ${dcs_model_file%.*})

# Move results to common directory
mkdir -p Results
for f in $(find . -name *.hst | grep Results);do
    mv ${f} Results/
done

num_runs=$(find . -name *.hst | grep Results | wc -l)

cat > macroScript.txt <<END
//Generic Needed
DCSVERS	200
DCSMSSG	1  0 // 1st 0 MEANS print-msg is OFF; 2nd 0 MEANS using RELATIVE path
DCSWORK .
DCSCOMPLIANT 1
DCSMECHANICAL 1
DCSLOAD_CFG dcs4d.cfg

//load a model (wtx) 
DCSLOAD $in_name.wtx

//merge results files (in Results folder)
DCSSIMU_MERGE $num_runs ${in_name}.hst
END

# write the merge indices
for f in $(find . -name *.hst | grep Results); do
    echo "DCS_DATA $(basename $f)" >> macroScript.txt
done

cat >> macroScript.txt <<END
DCSSIMU_LOAD ${in_name}
//Activating DCSREPORT_GEN breaks DCSSENS_SAVE
//DCSREPORT_GEN 1 ./reports

//save simu as rsh
DCSSIMU_SAVE 1 ${in_name}_HST_RSLT
//save simu as rel
DCSSIMU_SAVE 2 ${in_name}_HST_RSLT
//save simu as csv
DCSSIMU_SAVE 3 ${in_name}_HST_RSLT
//save simu as html
DCSSIMU_SAVE 4 ${in_name}_HST_RSLT
//save simu as raw
DCSSIMU_SAVE 7 ${in_name}_HST_RSLT
//save simu as cmmdev
DCSSIMU_SAVE 8 ${in_name}_HST_RSLT
//save simu as hsu
DCSSIMU_SAVE 9 ${in_name} 
END
# End with empty line
