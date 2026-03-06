
echo; echo; echo macroScript.txt
cat macroScript.txt

out_file=$(basename ${dcs_model_file%.*})_${case_index}

mkdir Results
touch Results/${out_file}.hst Results/${out_file}.hlm

tree