#========================================
# Usage
# sh scriptname <working directory> <input fastq file> <output prefix> <reference file>
# Reference file will be used to compare assembly statistics, misassembly report using quast
#========================================
workdir=$1
fastqfile=$2
prefix=$3
reffile=$4

# Set different tool paths
sashta=/home/priyabrata/learn/assembly/shasta/shasta-Linux-0.6.0
fastq2fasta=/home/priyabrata/learn/assembly/shasta/FastqToFasta.py
canu=/home/priyabrata/software/canu-2.1.1/bin/canu
minimap2=/home/priyabrata/github/minimap2/minimap2
miniasm=miniasm
asm_stats=/home/priyabrata/github/assembly-stats/build/assembly-stats
flye=/home/priyabrata/github/Flye/bin/flye
wtdbg2path=/home/priyabrata/github/wtdbg2
racon=/home/priyabrata/github/racon-v1.4.3/build/bin/racon
quast=/home/priyabrata/learn/assembly/quast-5.0.2/./quast.py


#========================================
# Assembly using Sashta
#========================================
	cd $workdir
	echo 'Fastq to fasta using Sashta command FastqToFasta.py'
	fastafile=$prefix".fasta"
	$fastq2fasta $fastqfile $fastafile
	echo 'Fastq to fasta conversion is complete'

	echo 'Running Sashta with 100 minReadLength parameter'
	$sashta --input $fastafile --assemblyDirectory sashta_assembly --Reads.minReadLength 100
	echo 'Sashta run completed'

	echo 'Running Quast to check assembly statistics'
	$quast -o sashta_assembly_quast ./sashta_assembly/Assembly.fasta
	echo 'Quast analysis completed'

	echo 'Check Assembly statistics using assembly-stats'
	$asm_stats ./sashta_assembly/Assembly.fasta
	echo 'assembly-stats generated'

#========================================
# Assembly using CANU assembler
#========================================
	echo 'Running Canu with default parameter'
	echo -e 'maxThreads=6\nmaxMemory=6G' > canu_spec.txt
	$canu -p myassembly -d  canu_assembly  genomeSize=1m  -nanopore $fastafile -s canu_spec.txt
	echo 'CANU run completed'

	echo 'Running Quast to check assembly statistics'
	$quast -o canu_assembly_quast ./canu_assembly/myassembly.contigs.fasta
	echo 'Quast analysis completed'

	echo 'Check Assembly statistics using assembly-stats'
	$asm_stats ./canu_assembly/myassembly.contigs.fasta
	echo 'assembly-stats generated'

#========================================
# Assembly using Flye assembler
#========================================
	echo 'Running flye with default parameter'
	$flye -t 6 --nano-raw $fastqfile --genome-size 1m --out-dir ./flye_assembly
	echo 'Assembly completed'
	
	echo 'Running Quast to check assembly statistics'
	$quast -o flye_assembly_quast ./flye_assembly/assembly.fasta
	echo 'Quast analysis completed'

	echo 'Check Assembly statistics using assembly-stats'
	$asm_stats ./flye_assembly/assembly.fasta
	echo 'assembly-stats generated'


#========================================
# Assembly using Miniasm
#========================================
	mkdir minimap_output
	
	echo 'Running Minimap2'
	$minimap2 -x ava-ont $fastqfile $fastqfile | gzip -1 > ./minimap_output/minimap.paf.gz
	echo 'Minimap2 complete'

	echo 'Assembly using Miniasm'
	mkdir miniasm_assembly
	miniasm -f $fastqfile ./minimap_output/minimap.paf.gz > ./miniasm_assembly/miniasm.gfa
	echo 'Miniasm completed'

	echo 'Converting GFA to Fasta format'
	cd ./miniasm_assembly
	awk '/^S/{print ">"$2"\n"$3}' miniasm.gfa > miniasm.fasta
	echo 'Assembly Fasta is generated'

	cd $workdir
	echo 'Running Quast'
	$quast -o miniasm_assembly_quast ./miniasm_assembly/miniasm.fasta
	echo 'Quast analysis completed'

	echo 'Check Assembly statistics using assembly-stats'
	$asm_stats ./miniasm_assembly/miniasm.fasta
	echo 'assembly-stats generated'


#========================================
# Assembly using wtdbg2
#========================================
	cd $workdir
	mkdir wtdbg2_assembly
	
	echo 'Running wtdbg2'
	$wtdbg2path/wtdbg2 -x ont -g 1m -t 6 -i $fastqfile -fo ./wtdbg2_assembly/assembly
	echo 'wtdbg2 assembly completed'

	echo 'Generating consensus using wtpoa-cns'
	$wtdbg2path/wtpoa-cns -t 6 -i ./wtdbg2_assembly/assembly.ctg.lay.gz -fo ./wtdbg2_assembly/assembly.fasta
	echo 'Consensus done'

	echo 'Running Quast'
	$quast -o wtdbg2_assembly_quast ./wtdbg2_assembly/assembly.fasta
	echo 'Quast analysis completed'

	echo 'Check Assembly statistics using assembly-stats'
	$asm_stats ./wtdbg2_assembly/assembly.fasta
	echo 'assembly-stats generated'

#========================================
# Compare assembly statistics of all tools using QUAST
# Without using genome reference sequence
#========================================
	$quast -o quast_woref -l 'shasta,flye,miniasm,wtdbg2,canu' ./sashta_assembly/Assembly.fasta ./flye_assembly/assembly.fasta ./miniasm_assembly/miniasm.fasta ./wtdbg2_assembly/assembly.fasta ./canu_assembly/myassembly.contigs.fasta


#========================================
# Compare assembly statistics of all tools using QUAST
# With using genome reference sequence
#========================================
$quast -r $reffile -o quast -l 'shasta,flye,miniasm,wtdbg2,canu' ./sashta_assembly/Assembly.fasta ./flye_assembly/assembly.fasta ./miniasm_assembly/miniasm.fasta ./wtdbg2_assembly/assembly.fasta ./canu_assembly/myassembly.contigs.fasta

