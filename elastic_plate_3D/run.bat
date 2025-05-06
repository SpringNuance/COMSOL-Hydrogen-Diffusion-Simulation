python3.12 autoscript.py --input "elastic_plate_3D"
abaqus job=elastic_plate_3D_processed user="source_code/AACHEN_HYDROGEN.f90" double output_precision=full cpus=1 -verbose 1 memory=2048 interactive