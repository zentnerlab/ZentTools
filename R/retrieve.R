
#' Retrieve Reads from SRA
#'
#' @importFrom stringr str_c str_detect
#' @importFrom purrr walk map
#'
#' @param zent_obj Zent object.
#' @param outdir Directory to donwload files to.
#'
#' @export

retrieve_reads <- function(
  zent_obj,
  outdir = getwd()
) {

  ## Input checks.
  analysis_type <- pull_setting(zent_obj, "analysis_type")
  paired_status <- as.logical(pull_setting(zent_obj, "paired"))
  if (!str_detect(outdir, "/$")) outdir <- str_c(outdir, "/")

  ## Make sure outdir exists.
  if (!dir.exists(outdir)) dir.create(outdir, recursive = TRUE)

  ## Get vector of accession numbers.
  accessions <- zent_obj@sample_sheet[["file_1"]]

  if (analysis_type %in% c("ChIP-seq", "ChEC-seq")) {
    controls <- unique(zent_obj@sample_sheet[["control_file_1"]])
    accessions <- c(accessions, controls)
  }

  ## Prepare command to get data from ENA.
  command <- str_c(
    "enaDataGet",
    "-f", "fastq",
    "-d", outdir,
    sep = " "
  )

  command <- map(accessions, function(x) {
    str_c(command, x, sep = " ")
  })

  ## Run the fasterq-dump command.
  walk(command, system, ignore.stdout = TRUE, ignore.stderr = TRUE)

  ## Update the sample sheet.
  sample_sheet <- copy(zent_obj@sample_sheet)

  if (paired_status) {
    sample_sheet[, c("file_1", "file_2") := list(
      str_c(outdir, file_1, "/", file_1, "_1.fastq"),
      str_c(outdir, file_1, "/", file_1, "_2.fastq")
    )]

    if (analysis_type %in% c("ChIP-seq", "ChEC-seq")) {
      sample_sheet[, c("control_file_1", "control_file_2") := list(
        str_c(outdir, control_file_1, "/", control_file_1, "_1.fastq"),
        str_c(outdir, control_file_1, "/", control_file_1, "_2.fastq")
      )]
    }
  } else {
    sample_sheet[, file_1 := str_c(outdir, file_1, "/", file_1, ".fastq")]

    if (analysis_type %in% c("ChIP-seq", "ChEC-seq")) {
      sample_sheet[,
        control_file_1 := str_c(outdir, control_file_1, "/", control_file_1, ".fastq")
      ]
    }
  }

  zent_obj@sample_sheet <- sample_sheet

  ## Unzip the sequences.
  sequences <- zent_obj@sample_sheet[["file_1"]]
  
  if (paired_status) {
    sequences <- c(sequences, zent_obj@sample_sheet[["file_2"]])
  }

  if (analysis_type %in% c("ChIP-seq", "ChEC-seq")) {
    sequences <- c(
      sequences,
      unique(zent_obj@sample_sheet[["control_file_1"]])
    )

    if (paired_status) {
      sequences <- c(
        sequences,
        unique(zent_obj@sample_sheet[["control_file_2"]])
      )
    }
  }

  walk(sequences, function(x) {
    command <- str_c("gunzip", str_c(x, ".gz"), sep = " ")
    system(command, ignore.stdout = TRUE, ignore.stderr = TRUE) 
  })

  ## Return the zent object.
  return(zent_obj)

}
