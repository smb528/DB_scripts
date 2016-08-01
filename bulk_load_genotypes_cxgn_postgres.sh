shopt -s nullglob
for file in /home/vagrant/Downloads/cassava_chunks/*
do
  # sed -i 1,15d $file
   perl /home/vagrant/cxgn/sgn/bin/load_genotypes_vcf_cxgn_postgres.pl -H localhost -D fixture -i "$file" -g "cassava_chunks_pop_05" -p "cassava_chunks_project_05" -y 2016 -l "BTI" -m "cassava_chunks_protocol_05" -o "Manihot" -q "Manihot esculenta" -a
done
shopt -u nullglob
