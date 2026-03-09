
# generate the 3DCS macro script for the run
echo "Writing Macro File..."
echo

in_name=$(basename ${dcs_model_file%.*})

# Move results to common directory
mkdir -p Results
for f in $(find . -name *.hlm | grep Results);do
    mv ${f} Results/
done

num_runs=$(find . -name *.hlm | grep Results | wc -l)

cat > macroScript.txt <<END
//Generic Needed
DCSVERS	200
DCSMSSG	1  0 // 1st 0 MEANS print-msg is OFF; 2nd 0 MEANS using RELATIVE path
DCSWORK .
DCSCOMPLIANT 1
DCSMECHANICAL 1

//load a model (wtx) 
DCSLOAD $in_name.wtx

DCSSENS_MERGE $num_runs ${in_name}.hlm
END

# write the merge indices
for f in $(find . -name *.hlm | grep Results); do
    echo "DCS_DATA $(basename $f)" >> macroScript.txt
done

cat >> macroScript.txt <<END
DCSSENS_LOAD ${in_name}
//Activating DCSREPORT_GEN breaks DCSSENS_SAVE
//DCSREPORT_GEN 1 ./reports
//DCSSENS ${in_name}

//save sens as rss
DCSSENS_SAVE 1 ${in_name}_HLM_RSLT
//save sens as html
DCSSENS_SAVE 2 ${in_name}_HLM_RSLT
//save sens as StatRowCsv
DCSSENS_SAVE 3 ${in_name}_HLM_RSLT
END
# End with empty line
