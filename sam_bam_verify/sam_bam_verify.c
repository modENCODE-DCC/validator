#include "sam_bam_verify.h"

int debug_level = 0;

int main(int argc, char *argv[]) {

  samfile_t *infp;
  samfile_t *outfp;

  char *aux = 0;
  char in_mode[5];
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
    char *extension = strcasestr(argv[1], ".bam");
    if (extension && strcasecmp(extension, ".bam") == 0) { strcat(in_mode, "b"); } // BAM file?
    if ((infp = samopen(argv[1], in_mode, aux)) == 0) {
      fprintf(stderr, "Failed to open input file %s\n", argv[1]);
      return 1;
    }
  }
  if (argc == 4 && strcmp(argv[3], "-v") == 0) {
    debug_level = 1;
  }

  bam_header_t *header = (infp->header);

  bam1_t *alignment = bam_init1(); // Create alignment object, I think
  bam1_core_t *core;
  core = &alignment->core;
  long long mapped_read_count = 0;

  // XXX: This may be unnecessary...
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
  // XXX: END This may be unnecessary...

  char *replace_here;
  char *new_text = strdup(header->text);
  while ((replace_here = strstr(new_text, "SN:chr"))) {
    strcpy(replace_here+3, replace_here + 6);
  }
  free(header->text);
  header->text = strdup(new_text);
  free(new_text);

  header->l_text = strlen(header->text);

  // Output the header so it can be checked against modENCODE stuff
  if (debug_level & 1)
    fprintf(stderr, "New header:\n%s", header->text);

  // Open output file with (potentially fixed) header
  if ((outfp = samopen(argv[2], "wb", header)) == 0) {
    fprintf(stderr, "Failed to open output file %s\n", argv[2]);
    return 1;
  }

  while (samread(infp, alignment) >= 0) {
    // Generate BAM with chromosome prefixes stripped off
    if (!((core)->flag & BAM_FUNMAP)) ++mapped_read_count;
    bam_write1(outfp->x.bam, alignment);
  }
  bam_destroy1(alignment);

  // Output the read count
  printf("Mapped reads: %lld\n", mapped_read_count);

  samclose(outfp);
  samclose(infp);
  return 0;
}

void show_usage() {
  fprintf(stderr, "Usage:\n");
  fprintf(stderr, "  ./sam_bam_verify <input.sam|input.bam> <output.bam> [-v]\n");
  fprintf(stderr, "    -v   Verbose output (to stderr).\n");
}

