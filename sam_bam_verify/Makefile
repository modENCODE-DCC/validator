CC=			gcc
CFLAGS=		-g -Wall -O2 #-m64 #-arch ppc
PROG=		sam_bam_verify
INCLUDES=	-I../samtools/
LIBPATH=	-L../samtools/

all:$(PROG)

sam_bam_verify: sam_bam_verify.c sam_bam_verify.h
	$(CC) sam_bam_verify.c $(CFLAGS) -o $@ $(INCLUDES) $(LIBPATH) -lz -lbam

clean:
	rm -f $(PROG)
