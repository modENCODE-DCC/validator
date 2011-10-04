#include "sam_bam_verify.h"

int debug_level = 0;

int main(int argc, char *argv[]) {

  samfile_t *infp;
  samfile_t *outfp;

  char in_mode[3];
  strcpy(in_mode, "r");
  if (argc < 3) {
    show_usage();
    return 1;
  } else {
    if (strcmp(argv[1], argv[2]) == 0) {
      fprintf(stderr, "Can't read and write the same file.\n");
      show_usage();
      return 1;
    }

    char *aux = 0;
    if (argc >= 4 && strcmp(argv[3], "-v") != 0) {
      char *fn_ref = strdup(argv[3]);
      aux = samfaipath(fn_ref);
    }

    int i;
    for (i = argc-1; i > 0; i--) {
      if (strcmp(argv[i], "-v") == 0) {
        debug_level <<= 1;
        debug_level += 1;
      } else {
        break;
      }
    }
    /*
     * Figure out if we're opening a BAM or a SAM, and attach a reference FASTA if provided
     */
    char *extension = strcasestr(argv[1], ".bam");
    if (extension && strcasecmp(extension, ".bam") == 0) { strcat(in_mode, "b"); aux = 0; } // BAM file?

    if (aux != 0 && debug_level & 1) {
      fprintf(stderr, "Using FASTA file %s\n", aux);
    }
    if ((infp = samopen(argv[1], in_mode, aux)) == 0) {
      fprintf(stderr, "Failed to open input file %s\n", argv[1]);
      return 1;
    }
  }

  bam_header_t *header = bam_header_dup(infp->header);

  bam1_t *alignment = bam_init1(); // Create alignment object, I think
  bam1_core_t *core;
  core = &alignment->core;

  /*
   * Update header and remove "chr" prefixes
   */
  int i;
  for (i = 0; i < header->n_targets; i++) {
    char *target = header->target_name[i];
    if (target == strstr(target, "chr")) {
      if (strlen(target) > 3 && header->target_len[i] > 3) {
        char *new_text = strdup(target+3);
        if (debug_level & 1)
          fprintf(stderr, "Removing 'chr' prefix. %s becomes %s\n", target, target+3);
        free(header->target_name[i]);
        header->target_name[i] = new_text;
        header->target_len[i] = strlen(new_text);
      }
    }
  }


  if ((!header->text || strlen(header->text) == 0) && header->n_targets > 0) {
    // Regenerate it
    header->text = "";
    char *buf1;
    char *buf2;
    fprintf(stderr, "No header found, regenerating.\n");
    for (i = 0; i < header->n_targets; i++) {
      if (asprintf(&buf1, "@SQ\tSN:%s\tLN:%d\n", header->target_name[i], header->target_len[i]) < 0) {
        fprintf(stderr, "Out of memory while reformatting header!\n"); fflush(stderr);
        exit(1);
      }
      if (asprintf(&buf2, "%s%s", header->text, buf1) < 0) {
        fprintf(stderr, "Out of memory while reformatting header!\n"); fflush(stderr);
        exit(1);
      }
      header->text = strdup(buf2);
      free(buf1);
      free(buf2);
    }
  }
  char *new_text = strdup(header->text);
  char *replace_here;
  while ((replace_here = strstr(new_text, "SN:chr"))) {
    strcpy(replace_here+3, replace_here + 6);
  }
  free(header->text);
  header->text = strdup(new_text);
  free(new_text);

  header->l_text = strlen(header->text) + 1;
  bam_init_header_hash(header);

  // Output the header if verbose mode
  if (debug_level & 1)
    fprintf(stderr, "New header:\n%s", header->text);

  // Open output file with (potentially fixed) header
  if ((outfp = samopen(argv[2], "wb", header)) == 0) {
    fprintf(stderr, "Failed to open output file %s\n", argv[2]);
    return 1;
  }


  long long total_reads = 0;

  // Write out updated file as BAM
  long long mapped_read_count = 0;
  while (samread(infp, alignment) >= 0) {
    // Generate BAM with chromosome prefixes stripped off
    ++total_reads;
    if (!((core)->flag & BAM_FUNMAP)) ++mapped_read_count;

    // If we updated the header, we also have to update the content to remove "chr" prefixes
    bam1_core_t *c = &alignment->core;
    char *qname = bam1_qname(alignment);
    if (c->tid < 0) {
      // This is an unmapped sequence, which should probably be error-worthy.
      fprintf(stderr, "Unknown reference sequence found for read %s. Discarding from processed file!\n", qname);
      // fprintf(stderr, "  Provided reference sequences were:\n");
      // fprintf(stderr, "%s\n", infp->header->text);
      // exit(1);
      continue;
    } else {
      //only write out those reads that have mapped references
      bam_write1(outfp->x.bam, alignment);
    }
  }

  bam_destroy1(alignment);
  samclose(outfp);
  samclose(infp);

  // Sort by ID for faster/lower memory read counts?
  char * outfile_prefix;
  char * outfile;
  if (asprintf(&outfile_prefix, "%s.sorted_by_id", argv[2]) < 0) {
    fprintf(stderr, "Couldn't allocate memory for sorted output filename.\n");
    exit(1);
  }
#ifdef __x86_64__
  //size_t mem_max = 2684354560;
  size_t mem_max = 1879048192;
#else
  size_t mem_max = 1879048192;
#endif
  bam_sort_core(1, argv[2], outfile_prefix, mem_max); // Sort by ID, allow 1.75GB of RAM to be used
  if (asprintf(&outfile, "%s.bam", outfile_prefix) < 0) {
    fprintf(stderr, "Couldn't allocate memory for sorted output filename.\n");
    exit(1);
  }
  free(outfile_prefix);
  if ((infp = samopen(outfile, "rb", 0)) == 0) {
    fprintf(stderr, "Failed to open newly created sorted BAM file for reading: %s\n", outfile);
    return 1;
  }
  // Scan the new sorted file for unique reads
  alignment = bam_init1(); // Create new alignment object
  core = &alignment->core;

  char * last_read_id = 0;
  char * current_read_id;
  int current_read_num;

  long long unique_mapped_reads = 0;
  long long unique_reads = 0;
  int last_read_nums[2];

  while (samread(infp, alignment) >= 0) {
    current_read_id = bam1_qname(alignment);
    current_read_num = !((core)->flag & BAM_FREAD1);
    if (last_read_id && strcmp(current_read_id, last_read_id) == 0) {
      // IDs are unique
      if (last_read_nums[current_read_num]) {
        // And we've seen this read number before:
        // Dup!
        if (debug_level & 2) {
          printf("Duplicate id:\n");
          printf("  %s %d\n", current_read_id, current_read_num);
          printf("  %s [%i, %i]\n", last_read_id, last_read_nums[0], last_read_nums[1]);
        }
      } else {
        // Unique by read number, increment
        if (!((core)->flag & BAM_FUNMAP)) { unique_mapped_reads++; }
        unique_reads++;
      }
    } else {
      // New read ID
      last_read_nums[0] = last_read_nums[1] = 0;
      last_read_id = strdup(current_read_id);

      // Unique by ID, increment
      if (!((core)->flag & BAM_FUNMAP)) { unique_mapped_reads++; }
      unique_reads++;
    }
    last_read_nums[current_read_num] = 1;
  }
  bam_destroy1(alignment);
  samclose(infp);
  unlink(outfile);

  // Output the read count
  printf("Mapped reads: %lld\n", mapped_read_count);
  printf("Total reads: %lld\n", total_reads);
  printf("Unique mapped reads: %lld\n", unique_mapped_reads);
  printf("Unique total reads: %lld\n", unique_reads);


  return 0;
}

void show_usage() {
  fprintf(stderr, "Usage:\n");
  fprintf(stderr, "  ./sam_bam_verify <input.sam|input.bam> <output.bam> [reference.fa] [-v]\n");
  fprintf(stderr, "    -v   Verbose output (to stderr).\n");
}
