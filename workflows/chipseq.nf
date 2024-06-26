/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Loaded from modules/local/
//
include { BEDTOOLS_GENOMECOV                  } from '../modules/local/bedtools_genomecov'
include { FRIP_SCORE                          } from '../modules/local/frip_score'
include { PLOT_MACS2_QC                       } from '../modules/local/plot_macs2_qc'
include { PLOT_HOMER_ANNOTATEPEAKS            } from '../modules/local/plot_homer_annotatepeaks'
include { MACS2_CONSENSUS                     } from '../modules/local/macs2_consensus'
include { ANNOTATE_BOOLEAN_PEAKS              } from '../modules/local/annotate_boolean_peaks'
include { DESEQ2_QC                           } from '../modules/local/deseq2_qc'
include { IGV                                 } from '../modules/local/igv'
include { MULTIQC                             } from '../modules/local/multiqc'
include { MULTIQC_CUSTOM_PHANTOMPEAKQUALTOOLS } from '../modules/local/multiqc_custom_phantompeakqualtools'
include { MULTIQC_CUSTOM_PEAKS                } from '../modules/local/multiqc_custom_peaks'

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { paramsSummaryMap       } from 'plugin/nf-validation'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_chipseq_pipeline'
include { INPUT_CHECK            } from '../subworkflows/local/input_check'
include { ALIGN_STAR             } from '../subworkflows/local/align_star'
include { BAM_FILTER_BAMTOOLS    } from '../subworkflows/local/bam_filter_bamtools'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//

include { PICARD_MERGESAMFILES          } from '../modules/nf-core/picard/mergesamfiles/main'
include { PICARD_COLLECTMULTIPLEMETRICS } from '../modules/nf-core/picard/collectmultiplemetrics/main'
include { PRESEQ_LCEXTRAP               } from '../modules/nf-core/preseq/lcextrap/main'
include { PHANTOMPEAKQUALTOOLS          } from '../modules/nf-core/phantompeakqualtools/main'
include { UCSC_BEDGRAPHTOBIGWIG         } from '../modules/nf-core/ucsc/bedgraphtobigwig/main'
include { DEEPTOOLS_COMPUTEMATRIX       } from '../modules/nf-core/deeptools/computematrix/main'
include { DEEPTOOLS_PLOTPROFILE         } from '../modules/nf-core/deeptools/plotprofile/main'
include { DEEPTOOLS_PLOTHEATMAP         } from '../modules/nf-core/deeptools/plotheatmap/main'
include { DEEPTOOLS_PLOTFINGERPRINT     } from '../modules/nf-core/deeptools/plotfingerprint/main'
include { KHMER_UNIQUEKMERS             } from '../modules/nf-core/khmer/uniquekmers/main'
include { MACS2_CALLPEAK                } from '../modules/nf-core/macs2/callpeak/main'
include { SUBREAD_FEATURECOUNTS         } from '../modules/nf-core/subread/featurecounts/main'

include { HOMER_ANNOTATEPEAKS as HOMER_ANNOTATEPEAKS_MACS2     } from '../modules/nf-core/homer/annotatepeaks/main'
include { HOMER_ANNOTATEPEAKS as HOMER_ANNOTATEPEAKS_CONSENSUS } from '../modules/nf-core/homer/annotatepeaks/main'

//
// SUBWORKFLOW: Consisting entirely of nf-core/modules
//

include { FASTQ_FASTQC_UMITOOLS_TRIMGALORE } from '../subworkflows/nf-core/fastq_fastqc_umitools_trimgalore/main'
include { FASTQ_ALIGN_BWA                  } from '../subworkflows/nf-core/fastq_align_bwa/main'
include { FASTQ_ALIGN_BOWTIE2              } from '../subworkflows/nf-core/fastq_align_bowtie2/main'
include { FASTQ_ALIGN_CHROMAP              } from '../subworkflows/nf-core/fastq_align_chromap/main'
include { BAM_MARKDUPLICATES_PICARD        } from '../subworkflows/nf-core/bam_markduplicates_picard/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// JSON files required by BAMTools for alignment filtering
ch_bamtools_filter_se_config = file(params.bamtools_filter_se_config)
ch_bamtools_filter_pe_config = file(params.bamtools_filter_pe_config)

// Header files for MultiQC
ch_spp_nsc_header           = file("$projectDir/assets/multiqc/spp_nsc_header.txt", checkIfExists: true)
ch_spp_rsc_header           = file("$projectDir/assets/multiqc/spp_rsc_header.txt", checkIfExists: true)
ch_spp_correlation_header   = file("$projectDir/assets/multiqc/spp_correlation_header.txt", checkIfExists: true)
ch_peak_count_header        = file("$projectDir/assets/multiqc/peak_count_header.txt", checkIfExists: true)
ch_frip_score_header        = file("$projectDir/assets/multiqc/frip_score_header.txt", checkIfExists: true)
ch_peak_annotation_header   = file("$projectDir/assets/multiqc/peak_annotation_header.txt", checkIfExists: true)
ch_deseq2_pca_header        = file("$projectDir/assets/multiqc/deseq2_pca_header.txt", checkIfExists: true)
ch_deseq2_clustering_header = file("$projectDir/assets/multiqc/deseq2_clustering_header.txt", checkIfExists: true)

// Save AWS IGenomes file containing annotation version
def anno_readme = params.genomes[ params.genome ]?.readme
if (anno_readme && file(anno_readme).exists()) {
    file("${params.outdir}/genome/").mkdirs()
    file(anno_readme).copyTo("${params.outdir}/genome/")
}


// // Info required for completion email and summary
// def multiqc_report = []

workflow CHIPSEQ {

    take:
    ch_samplesheet   // channel: path(sample_sheet.csv)
    ch_versions      // channel: [ path(versions.yml) ]
    ch_fasta         // channel: path(genome.fa)
    ch_fai           // channel: path(genome.fai)
    ch_gtf           // channel: path(genome.gtf)
    ch_gene_bed      // channel: path(gene.beds)
    ch_chrom_sizes   // channel: path(chrom.sizes)
    ch_filtered_bed  // channel: path(filtered.bed)
    ch_bwa_index     // channel: path(bwa/index/)
    ch_bowtie2_index // channel: path(bowtie2/index)
    ch_chromap_index // channel: path(chromap.index)
    ch_star_index    // channel: path(star/index/)
    
    main:
    ch_multiqc_files = Channel.empty()

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    ch_input = file(ch_samplesheet)
    INPUT_CHECK (
        ch_input,
        params.seq_center
    )
    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)
    // TODO: OPTIONAL, you can use nf-validation plugin to create an input channel from the samplesheet with Channel.fromSamplesheet("input")
    // See the documentation https://nextflow-io.github.io/nf-validation/samplesheets/fromSamplesheet/
    // ! There is currently no tooling to help you write a sample sheet schema

    //
    // SUBWORKFLOW: Read QC and trim adapters
    //
    FASTQ_FASTQC_UMITOOLS_TRIMGALORE (
        INPUT_CHECK.out.reads,
        params.skip_fastqc || params.skip_qc,
        false,
        false,
        params.skip_trimming,
        0,
        10000
    )
    ch_versions = ch_versions.mix(FASTQ_FASTQC_UMITOOLS_TRIMGALORE.out.versions)

    //
    // SUBWORKFLOW: Alignment with BWA & BAM QC
    //
    ch_genome_bam        = Channel.empty()
    ch_genome_bam_index  = Channel.empty()
    ch_samtools_stats    = Channel.empty()
    ch_samtools_flagstat = Channel.empty()
    ch_samtools_idxstats = Channel.empty()
    if (params.aligner == 'bwa') {
        FASTQ_ALIGN_BWA (
            FASTQ_FASTQC_UMITOOLS_TRIMGALORE.out.reads,
            ch_bwa_index,
            false,
            ch_fasta
                .map {
                    [ [:], it ]
                }
        )
        ch_genome_bam        = FASTQ_ALIGN_BWA.out.bam
        ch_genome_bam_index  = FASTQ_ALIGN_BWA.out.bai
        ch_samtools_stats    = FASTQ_ALIGN_BWA.out.stats
        ch_samtools_flagstat = FASTQ_ALIGN_BWA.out.flagstat
        ch_samtools_idxstats = FASTQ_ALIGN_BWA.out.idxstats
        ch_versions = ch_versions.mix(FASTQ_ALIGN_BWA.out.versions)
    }

    //
    // SUBWORKFLOW: Alignment with Bowtie2 & BAM QC
    //
    if (params.aligner == 'bowtie2') {
        FASTQ_ALIGN_BOWTIE2 (
            FASTQ_FASTQC_UMITOOLS_TRIMGALORE.out.reads,
            ch_bowtie2_index,
            params.save_unaligned,
            false,
            ch_fasta
                .map {
                    [ [:], it ]
                }
        )
        ch_genome_bam        = FASTQ_ALIGN_BOWTIE2.out.bam
        ch_genome_bam_index  = FASTQ_ALIGN_BOWTIE2.out.bai
        ch_samtools_stats    = FASTQ_ALIGN_BOWTIE2.out.stats
        ch_samtools_flagstat = FASTQ_ALIGN_BOWTIE2.out.flagstat
        ch_samtools_idxstats = FASTQ_ALIGN_BOWTIE2.out.idxstats
        ch_versions = ch_versions.mix(FASTQ_ALIGN_BOWTIE2.out.versions)
    }

    //
    // SUBWORKFLOW: Alignment with Chromap & BAM QC
    //
    if (params.aligner == 'chromap') {
        FASTQ_ALIGN_CHROMAP (
            FASTQ_FASTQC_UMITOOLS_TRIMGALORE.out.reads,
            ch_chromap_index,
            ch_fasta
                .map {
                    [ [:], it ]
                },
            [],
            [],
            [],
            []
        )
        ch_genome_bam        = FASTQ_ALIGN_CHROMAP.out.bam
        ch_genome_bam_index  = FASTQ_ALIGN_CHROMAP.out.bai
        ch_samtools_stats    = FASTQ_ALIGN_CHROMAP.out.stats
        ch_samtools_flagstat = FASTQ_ALIGN_CHROMAP.out.flagstat
        ch_samtools_idxstats = FASTQ_ALIGN_CHROMAP.out.idxstats
        ch_versions = ch_versions.mix(FASTQ_ALIGN_CHROMAP.out.versions)
    }

    //
    // SUBWORKFLOW: Alignment with STAR & BAM QC
    //
    if (params.aligner == 'star') {
        ALIGN_STAR (
            FASTQ_FASTQC_UMITOOLS_TRIMGALORE.out.reads,
            ch_star_index,
            ch_fasta
                .map {
                        [ [:], it ]
                },
            params.seq_center ?: ''
        )
        ch_genome_bam        = ALIGN_STAR.out.bam
        ch_genome_bam_index  = ALIGN_STAR.out.bai
        ch_transcriptome_bam = ALIGN_STAR.out.bam_transcript
        ch_samtools_stats    = ALIGN_STAR.out.stats
        ch_samtools_flagstat = ALIGN_STAR.out.flagstat
        ch_samtools_idxstats = ALIGN_STAR.out.idxstats
        ch_star_multiqc      = ALIGN_STAR.out.log_final

        ch_versions = ch_versions.mix(ALIGN_STAR.out.versions)
    }

    //
    // MODULE: Merge resequenced BAM files
    //
    ch_genome_bam
        .map {
            meta, bam ->
                def meta_clone = meta.clone()
                meta_clone.remove('read_group')
                meta_clone.id = meta_clone.id.split('_')[0..-2].join('_')
                [ meta_clone, bam ]
        }
        .groupTuple(by: [0])
        .map {
            it ->
                [ it[0], it[1].flatten() ]
        }
        .set { ch_sort_bam }

    PICARD_MERGESAMFILES (
        ch_sort_bam
    )
    ch_versions = ch_versions.mix(PICARD_MERGESAMFILES.out.versions.first())

    //
    // SUBWORKFLOW: Mark duplicates & filter BAM files after merging
    //
    BAM_MARKDUPLICATES_PICARD (
        PICARD_MERGESAMFILES.out.bam,
        ch_fasta
            .map {
                [ [:], it ]
            },
        ch_fai
            .map {
                [ [:], it ]
            }
    )
    ch_versions = ch_versions.mix(BAM_MARKDUPLICATES_PICARD.out.versions)

    //
    // SUBWORKFLOW: Filter BAM file with BamTools
    //
    BAM_FILTER_BAMTOOLS (
        BAM_MARKDUPLICATES_PICARD.out.bam.join(BAM_MARKDUPLICATES_PICARD.out.bai, by: [0]),
        ch_filtered_bed.first(),
        ch_fasta
            .map {
                [ [:], it ]
            },
        ch_bamtools_filter_se_config,
        ch_bamtools_filter_pe_config
    )
    ch_versions = ch_versions.mix(BAM_FILTER_BAMTOOLS.out.versions)

    //
    // MODULE: Preseq coverage analysis
    //
    ch_preseq_multiqc = Channel.empty()
    if (!params.skip_preseq) {
        PRESEQ_LCEXTRAP (
            BAM_MARKDUPLICATES_PICARD.out.bam
        )
        ch_preseq_multiqc = PRESEQ_LCEXTRAP.out.lc_extrap
        ch_versions = ch_versions.mix(PRESEQ_LCEXTRAP.out.versions.first())
    }

    //
    // MODULE: Picard post alignment QC
    //
    ch_picardcollectmultiplemetrics_multiqc = Channel.empty()
    if (!params.skip_picard_metrics) {
        PICARD_COLLECTMULTIPLEMETRICS (
            BAM_FILTER_BAMTOOLS
                .out
                .bam
                .map {
                    [ it[0], it[1], [] ]
                },
            ch_fasta
                .map {
                    [ [:], it ]
                },
            ch_fai
                .map {
                    [ [:], it ]
                }
        )
        ch_picardcollectmultiplemetrics_multiqc = PICARD_COLLECTMULTIPLEMETRICS.out.metrics
        ch_versions = ch_versions.mix(PICARD_COLLECTMULTIPLEMETRICS.out.versions.first())
    }

    //
    // MODULE: Phantompeaktools strand cross-correlation and QC metrics
    //
    ch_phantompeakqualtools_spp_multiqc                 = Channel.empty()
    ch_multiqc_phantompeakqualtools_nsc_multiqc         = Channel.empty()
    ch_multiqc_phantompeakqualtools_rsc_multiqc         = Channel.empty()
    ch_multiqc_phantompeakqualtools_correlation_multiqc = Channel.empty()
    if (!params.skip_spp) {
        PHANTOMPEAKQUALTOOLS (
            BAM_FILTER_BAMTOOLS.out.bam
        )
        ch_phantompeakqualtools_spp_multiqc           = PHANTOMPEAKQUALTOOLS.out.spp
        ch_versions = ch_versions.mix(PHANTOMPEAKQUALTOOLS.out.versions.first())

        //
        // MODULE: MultiQC custom content for Phantompeaktools
        //
        MULTIQC_CUSTOM_PHANTOMPEAKQUALTOOLS (
            PHANTOMPEAKQUALTOOLS.out.spp.join(PHANTOMPEAKQUALTOOLS.out.rdata, by: [0]),
            ch_spp_nsc_header,
            ch_spp_rsc_header,
            ch_spp_correlation_header
        )
        ch_multiqc_phantompeakqualtools_nsc_multiqc         = MULTIQC_CUSTOM_PHANTOMPEAKQUALTOOLS.out.nsc
        ch_multiqc_phantompeakqualtools_rsc_multiqc         = MULTIQC_CUSTOM_PHANTOMPEAKQUALTOOLS.out.rsc
        ch_multiqc_phantompeakqualtools_correlation_multiqc = MULTIQC_CUSTOM_PHANTOMPEAKQUALTOOLS.out.correlation
    }

    //
    // MODULE: BedGraph coverage tracks
    //
    BEDTOOLS_GENOMECOV (
        BAM_FILTER_BAMTOOLS.out.bam.join(BAM_FILTER_BAMTOOLS.out.flagstat, by: [0])
    )
    ch_versions = ch_versions.mix(BEDTOOLS_GENOMECOV.out.versions.first())

    //
    // MODULE: BigWig coverage tracks
    //
    UCSC_BEDGRAPHTOBIGWIG (
        BEDTOOLS_GENOMECOV.out.bedgraph,
        ch_chrom_sizes
    )
    ch_versions = ch_versions.mix(UCSC_BEDGRAPHTOBIGWIG.out.versions.first())

    ch_deeptoolsplotprofile_multiqc = Channel.empty()
    if (!params.skip_plot_profile) {
        //
        // MODULE: deepTools matrix generation for plotting
        //
        DEEPTOOLS_COMPUTEMATRIX (
            UCSC_BEDGRAPHTOBIGWIG.out.bigwig,
            ch_gene_bed
        )
        ch_versions = ch_versions.mix(DEEPTOOLS_COMPUTEMATRIX.out.versions.first())

        //
        // MODULE: deepTools profile plots
        //
        DEEPTOOLS_PLOTPROFILE (
            DEEPTOOLS_COMPUTEMATRIX.out.matrix
        )
        ch_deeptoolsplotprofile_multiqc = DEEPTOOLS_PLOTPROFILE.out.table
        ch_versions = ch_versions.mix(DEEPTOOLS_PLOTPROFILE.out.versions.first())

        //
        // MODULE: deepTools heatmaps
        //
        DEEPTOOLS_PLOTHEATMAP (
            DEEPTOOLS_COMPUTEMATRIX.out.matrix
        )
        ch_versions = ch_versions.mix(DEEPTOOLS_PLOTHEATMAP.out.versions.first())
    }

    //
    // Create channels: [ meta, [ ip_bam, control_bam ] [ ip_bai, control_bai ] ]
    //
    BAM_FILTER_BAMTOOLS
        .out
        .bam
        .join(BAM_FILTER_BAMTOOLS.out.bai, by: [0])
        .set { ch_genome_bam_bai }

    ch_genome_bam_bai
        .map {
            meta, bam, bai ->
                meta.control ? null : [ meta.id, [ bam ] , [ bai ] ]
        }
        .set { ch_control_bam_bai }

    ch_genome_bam_bai
        .map {
            meta, bam, bai ->
                meta.control ? [ meta.control, meta, [ bam ], [ bai ] ] : null
        }
        .combine(ch_control_bam_bai, by: 0)
        .map { it -> [ it[1] , it[2] + it[4], it[3] + it[5] ] }
        .set { ch_ip_control_bam_bai }

    //
    // MODULE: deepTools plotFingerprint joint QC for IP and control
    //
    ch_deeptoolsplotfingerprint_multiqc = Channel.empty()
    if (!params.skip_plot_fingerprint) {
        DEEPTOOLS_PLOTFINGERPRINT (
            ch_ip_control_bam_bai
        )
        ch_deeptoolsplotfingerprint_multiqc = DEEPTOOLS_PLOTFINGERPRINT.out.matrix
        ch_versions = ch_versions.mix(DEEPTOOLS_PLOTFINGERPRINT.out.versions.first())
    }

    //
    // MODULE: Calculute genome size with khmer
    //
    // TODO move to prepare genome
    ch_macs_gsize                     = Channel.empty()
    ch_custompeaks_frip_multiqc       = Channel.empty()
    ch_custompeaks_count_multiqc      = Channel.empty()
    ch_plothomerannotatepeaks_multiqc = Channel.empty()
    ch_subreadfeaturecounts_multiqc   = Channel.empty()
    ch_macs_gsize = params.macs_gsize
    if (!params.macs_gsize) {
        KHMER_UNIQUEKMERS (
            ch_fasta,
            params.read_length
        )
        ch_macs_gsize = KHMER_UNIQUEKMERS.out.kmers.map { it.text.trim() }
    }

    // Create channels: [ meta, ip_bam, control_bam ]
    ch_ip_control_bam_bai
        .map {
            meta, bams, bais ->
                [ meta , bams[0], bams[1] ]
        }
        .set { ch_ip_control_bam }

    //
    // MODULE: Call peaks with MACS2
    //
    MACS2_CALLPEAK (
        ch_ip_control_bam,
        ch_macs_gsize
    )
    ch_versions = ch_versions.mix(MACS2_CALLPEAK.out.versions.first())

    //
    // Filter out samples with 0 MACS2 peaks called
    //
    MACS2_CALLPEAK
        .out
        .peak
        .filter {
            meta, peaks ->
                peaks.size() > 0
        }
        .set { ch_macs2_peaks }

    // Create channels: [ meta, ip_bam, peaks ]
    ch_ip_control_bam
        .join(ch_macs2_peaks, by: [0])
        .map {
            it ->
                [ it[0], it[1], it[3] ]
        }
        .set { ch_ip_bam_peaks }

    //
    // MODULE: Calculate FRiP score
    //
    FRIP_SCORE (
        ch_ip_bam_peaks
    )
    ch_versions = ch_versions.mix(FRIP_SCORE.out.versions.first())

    // Create channels: [ meta, peaks, frip ]
    ch_ip_bam_peaks
        .join(FRIP_SCORE.out.txt, by: [0])
        .map {
            it ->
                [ it[0], it[2], it[3] ]
        }
        .set { ch_ip_peaks_frip }

    //
    // MODULE: FRiP score custom content for MultiQC
    //
    MULTIQC_CUSTOM_PEAKS (
        ch_ip_peaks_frip,
        ch_peak_count_header,
        ch_frip_score_header
    )
    ch_custompeaks_frip_multiqc  = MULTIQC_CUSTOM_PEAKS.out.frip
    ch_custompeaks_count_multiqc = MULTIQC_CUSTOM_PEAKS.out.count

    if (!params.skip_peak_annotation) {
        //
        // MODULE: Annotate peaks with MACS2
        //
        HOMER_ANNOTATEPEAKS_MACS2 (
            ch_macs2_peaks,
            ch_fasta,
            ch_gtf
        )
        ch_versions = ch_versions.mix(HOMER_ANNOTATEPEAKS_MACS2.out.versions.first())

        if (!params.skip_peak_qc) {
            //
            // MODULE: MACS2 QC plots with R
            //
            PLOT_MACS2_QC (
                ch_macs2_peaks.collect{it[1]},
                params.narrow_peak
            )
            ch_versions = ch_versions.mix(PLOT_MACS2_QC.out.versions)

            //
            // MODULE: Peak annotation QC plots with R
            //
            PLOT_HOMER_ANNOTATEPEAKS (
                HOMER_ANNOTATEPEAKS_MACS2.out.txt.collect{it[1]},
                ch_peak_annotation_header,
                "_peaks.annotatePeaks.txt"
            )
            ch_plothomerannotatepeaks_multiqc = PLOT_HOMER_ANNOTATEPEAKS.out.tsv
            ch_versions = ch_versions.mix(PLOT_HOMER_ANNOTATEPEAKS.out.versions)
        }
    }

    //
    //  Consensus peaks analysis
    //
    ch_macs2_consensus_bed_lib   = Channel.empty()
    ch_macs2_consensus_txt_lib   = Channel.empty()
    ch_deseq2_pca_multiqc        = Channel.empty()
    ch_deseq2_clustering_multiqc = Channel.empty()
    if (!params.skip_consensus_peaks) {
        // Create channels: [ meta , [ peaks ] ]
        // Where meta = [ id:antibody, multiple_groups:true/false, replicates_exist:true/false ]
        ch_macs2_peaks
            .map {
                meta, peak ->
                    [ meta.antibody, meta.id.split('_')[0..-2].join('_'), peak ]
            }
            .groupTuple()
            .map {
                antibody, groups, peaks ->
                    [
                        antibody,
                        groups.groupBy().collectEntries { [(it.key) : it.value.size()] },
                        peaks
                    ]
            }
            .map {
                antibody, groups, peaks ->
                    def meta_new = [:]
                    meta_new.id = antibody
                    meta_new.multiple_groups = groups.size() > 1
                    meta_new.replicates_exist = groups.max { groups.value }.value > 1
                    [ meta_new, peaks ]
            }
            .set { ch_antibody_peaks }

        //
        // MODULE: Generate consensus peaks across samples
        //
        MACS2_CONSENSUS (
            ch_antibody_peaks,
            params.narrow_peak
        )
        ch_macs2_consensus_bed_lib = MACS2_CONSENSUS.out.bed
        ch_macs2_consensus_txt_lib = MACS2_CONSENSUS.out.txt
        ch_versions = ch_versions.mix(MACS2_CONSENSUS.out.versions)

        if (!params.skip_peak_annotation) {
            //
            // MODULE: Annotate consensus peaks
            //
            HOMER_ANNOTATEPEAKS_CONSENSUS (
                MACS2_CONSENSUS.out.bed,
                ch_fasta,
                ch_gtf
            )
            ch_versions = ch_versions.mix(HOMER_ANNOTATEPEAKS_CONSENSUS.out.versions)

            //
            // MODULE: Add boolean fields to annotated consensus peaks to aid filtering
            //
            ANNOTATE_BOOLEAN_PEAKS (
                MACS2_CONSENSUS.out.boolean_txt.join(HOMER_ANNOTATEPEAKS_CONSENSUS.out.txt, by: [0]),
            )
            ch_versions = ch_versions.mix(ANNOTATE_BOOLEAN_PEAKS.out.versions)
        }

        // Create channels: [ antibody, [ ip_bams ] ]
        ch_ip_control_bam
            .map {
                meta, ip_bam, control_bam ->
                    [ meta.antibody, ip_bam ]
            }
            .groupTuple()
            .set { ch_antibody_bams }

        // Create channels: [ meta, [ ip_bams ], saf ]
        MACS2_CONSENSUS
            .out
            .saf
            .map {
                meta, saf ->
                    [ meta.id, meta, saf ]
            }
            .join(ch_antibody_bams)
            .map {
                antibody, meta, saf, bams ->
                    [ meta, bams.flatten().sort(), saf ]
            }
            .set { ch_saf_bams }

        //
        // MODULE: Quantify peaks across samples with featureCounts
        //
        SUBREAD_FEATURECOUNTS (
            ch_saf_bams
        )
        ch_subreadfeaturecounts_multiqc = SUBREAD_FEATURECOUNTS.out.summary
        ch_versions = ch_versions.mix(SUBREAD_FEATURECOUNTS.out.versions.first())

        if (!params.skip_deseq2_qc) {
            //
            // MODULE: Generate QC plots with DESeq2
            //
            DESEQ2_QC (
                SUBREAD_FEATURECOUNTS.out.counts,
                ch_deseq2_pca_header,
                ch_deseq2_clustering_header
            )
            ch_deseq2_pca_multiqc        = DESEQ2_QC.out.pca_multiqc
            ch_deseq2_clustering_multiqc = DESEQ2_QC.out.dists_multiqc
        }
    }

    //
    // MODULE: Create IGV session
    //
    if (!params.skip_igv) {
        IGV (
            params.aligner,
            params.narrow_peak ? 'narrow_peak' : 'broad_peak',
            ch_fasta,
            UCSC_BEDGRAPHTOBIGWIG.out.bigwig.collect{it[1]}.ifEmpty([]),
            ch_macs2_peaks.collect{it[1]}.ifEmpty([]),
            ch_macs2_consensus_bed_lib.collect{it[1]}.ifEmpty([]),
            ch_macs2_consensus_txt_lib.collect{it[1]}.ifEmpty([])
        )
        ch_versions = ch_versions.mix(IGV.out.versions)
    }

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(storeDir: "${params.outdir}/pipeline_info", name: 'nf_core_atacseq_software_mqc_versions.yml', sort: true, newLine: true)
        .set { ch_collated_versions }

    //
    // MODULE: MultiQC
    //
    if (!params.skip_multiqc) {
        ch_multiqc_config        = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
        ch_multiqc_custom_config = params.multiqc_config ? Channel.fromPath( params.multiqc_config ): Channel.empty()
        ch_multiqc_logo          = params.multiqc_logo   ? Channel.fromPath( params.multiqc_logo )  : Channel.empty()
        summary_params           = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
        ch_workflow_summary      = Channel.value(paramsSummaryMultiqc(summary_params))
        ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
        ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)

        MULTIQC (
            ch_multiqc_files.collect(),
            ch_multiqc_config.toList(),
            ch_multiqc_custom_config.toList(),
            ch_multiqc_logo.toList(),

            FASTQ_FASTQC_UMITOOLS_TRIMGALORE.out.fastqc_zip.collect{it[1]}.ifEmpty([]),
            FASTQ_FASTQC_UMITOOLS_TRIMGALORE.out.trim_zip.collect{it[1]}.ifEmpty([]),
            FASTQ_FASTQC_UMITOOLS_TRIMGALORE.out.trim_log.collect{it[1]}.ifEmpty([]),

            ch_samtools_stats.collect{it[1]}.ifEmpty([]),
            ch_samtools_flagstat.collect{it[1]}.ifEmpty([]),
            ch_samtools_idxstats.collect{it[1]}.ifEmpty([]),

            BAM_MARKDUPLICATES_PICARD.out.stats.collect{it[1]}.ifEmpty([]),
            BAM_MARKDUPLICATES_PICARD.out.flagstat.collect{it[1]}.ifEmpty([]),
            BAM_MARKDUPLICATES_PICARD.out.idxstats.collect{it[1]}.ifEmpty([]),
            BAM_MARKDUPLICATES_PICARD.out.metrics.collect{it[1]}.ifEmpty([]),

            BAM_FILTER_BAMTOOLS.out.stats.collect{it[1]}.ifEmpty([]),
            BAM_FILTER_BAMTOOLS.out.flagstat.collect{it[1]}.ifEmpty([]),
            BAM_FILTER_BAMTOOLS.out.idxstats.collect{it[1]}.ifEmpty([]),
            ch_picardcollectmultiplemetrics_multiqc.collect{it[1]}.ifEmpty([]),

            ch_preseq_multiqc.collect{it[1]}.ifEmpty([]),

            ch_deeptoolsplotprofile_multiqc.collect{it[1]}.ifEmpty([]),
            ch_deeptoolsplotfingerprint_multiqc.collect{it[1]}.ifEmpty([]),

            ch_phantompeakqualtools_spp_multiqc.collect{it[1]}.ifEmpty([]),
            ch_multiqc_phantompeakqualtools_nsc_multiqc.collect{it[1]}.ifEmpty([]),
            ch_multiqc_phantompeakqualtools_rsc_multiqc.collect{it[1]}.ifEmpty([]),
            ch_multiqc_phantompeakqualtools_correlation_multiqc.collect{it[1]}.ifEmpty([]),

            ch_custompeaks_frip_multiqc.collect{it[1]}.ifEmpty([]),
            ch_custompeaks_count_multiqc.collect{it[1]}.ifEmpty([]),
            ch_plothomerannotatepeaks_multiqc.collect().ifEmpty([]),
            ch_subreadfeaturecounts_multiqc.collect{it[1]}.ifEmpty([]),

            ch_deseq2_pca_multiqc.collect().ifEmpty([]),
            ch_deseq2_clustering_multiqc.collect().ifEmpty([])
        )
        ch_multiqc_report = MULTIQC.out.report
    }
}
