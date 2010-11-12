#define _GNU_SOURCE
#include <string.h>
#include <stdio.h>
#include "sam.h"

void show_usage();
void update_header_text(bam_header_t* header);

// Private SAM API
bam_header_t *bam_header_dup(const bam_header_t *h0);
void bam_sort_core(int is_by_qname, const char *fn, const char *prefix, size_t max_mem);
