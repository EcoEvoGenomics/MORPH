nextflow.preview.output = true

workflow {

    main:
    contig_morphs = file(params.morphs, checkIfExists: true)
    input_fasta = file(params.fasta, checkIfExists: true)
    input_gff = file(params.gff, checkIfExists: true)

    morphed = RENAME_REFERENCE_CONTIGS(contig_morphs, input_fasta, input_gff)
    fai = SAMTOOLS_FAIDX(morphed.fasta)
    bwa = BWA_INDEX(morphed.fasta)

    publish:
    fasta = morphed.fasta
    gff = morphed.gff
    fai = fai
    bwa = bwa

}

output {
    
    fasta { path "./" }
    gff { path "./" }
    fai { path "./" }
    bwa { path "./" }

}

process RENAME_REFERENCE_CONTIGS {

    container "quay.io/biocontainers/python:3.13.7"
    cpus 1
    memory 1.GB
    time { 1.h }

    input:
    path(morphs)
    path(fasta)
    path(gff)

    output:
    path("${fasta.simpleName}.morph.fasta"), emit: fasta
    path("${gff.simpleName}.morph.gff"), emit: gff

    script:
    """
    #!/usr/bin/env python
    import sys

    morphs = {}
    with open("${morphs.toString()}") as morph_table:
        for row in morph_table:
            find, replace = row.rstrip("\\n").split("\\t")
            morphs[find] = replace
    
    with open("${fasta.toString()}") as fasta, open("${fasta.simpleName}.morph.fasta", "w") as morphed:
        contig_marker = ">"
        for line in fasta:
            if line.startswith(contig_marker):
                header_parts = line[1:].split(maxsplit = 1)
                contig_name = header_parts[0]
                contig_meta = header_parts[1] if len(header_parts) > 1 else ""
                if contig_name in morphs:
                    line = f">{morphs[contig_name]} {contig_meta}" if contig_meta else f">{morphs[contig_name]}\\n"
            morphed.write(line)
    
    with open("${gff.toString()}") as gff, open("${gff.simpleName}.morph.gff", "w") as morphed:
        for row in gff:
            skip_row = row.startswith("#") or not row.strip()
            if skip_row:
                morphed.write(row)
                continue
            fields = row.rstrip("\\n").split("\\t")
            if fields[0] in morphs:
                fields[0] = morphs[fields[0]]
            morphed.write("\\t".join(fields) + "\\n")
    """

}

process SAMTOOLS_FAIDX {

    // Container build page: https://wave.seqera.io/view/builds/bd-7673b9c618b4118a_1
    container "community.wave.seqera.io/library/bwa_samtools:7673b9c618b4118a"
    cpus 1
    memory { 6.GB * Math.ceil(fasta.size() / 1024 ** 3) }
    time { 24.h }

    input:
    path(fasta)

    output:
    path("${fasta.baseName}.fasta.fai")

    script:
    """
    samtools faidx ${fasta}
    """

}

process BWA_INDEX {

    // Container build page: https://wave.seqera.io/view/builds/bd-7673b9c618b4118a_1
    container "community.wave.seqera.io/library/bwa_samtools:7673b9c618b4118a"
    cpus 1
    memory { 6.GB * Math.ceil(fasta.size() / 1024 ** 3) }
    time { 24.h }

    input:
    path(fasta)

    output:
    path("${fasta.baseName}.fasta*.{amb,ann,bwt,pac,sa}")

    script:
    """
    bwa index -a bwtsw ${fasta}
    """

}
