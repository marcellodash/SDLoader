#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct __attribute__((__packed__)) {
	unsigned char record_type;
	unsigned char header_byte;
	unsigned char cpu_type;
	unsigned char granularity;
	unsigned long start_address;
	unsigned short length;
} precord_t;

void conv_endian_short(unsigned short * ptr) {
	unsigned short value;
	
	value = *ptr;
	*ptr = (value >> 8) | (value << 8);
}

void conv_endian_long(unsigned long * ptr) {
	unsigned long value;
	
	value = *ptr;
	*ptr = (value >> 24) | ((value & 0x00FF0000) >> 8) | ((value & 0x0000FF00) << 8) | ((value & 0x000000FF) << 24);
}

int main(int argc, char *argv[]) {
	unsigned char pdata[65536];
	unsigned char * fdata;
	unsigned short word;
	unsigned char byte;
	unsigned long total_length = 0;
	precord_t precord;

	FILE * fp;
	FILE * fin;
	FILE * fout;
	
	if ((sizeof(unsigned char) != 1) ||
		(sizeof(unsigned short) != 2) ||
		(sizeof(unsigned long) != 4)) {
		puts("OVERLAY: Type incompatibility error.\n");
		return 1;
	}
	
	if (argc != 4) {
		puts("Usage: overlay pfile topatch patched\n");
		return 1;
	}
	
	fp = fopen(argv[1], "rb");
	fin = fopen(argv[2], "rb");
	fout = fopen(argv[3], "wb");
	
	if ((fp == NULL) || (fin == NULL) || (fout == NULL)) {
		puts("OVERLAY: One of the specified files can't be opened.\n");
		fclose(fp);
		fclose(fin);
		fclose(fout);
		return 1;
	}
	
	fdata = (unsigned char *)malloc(0x80000);
	if (fdata == NULL) {
		puts("OVERLAY: Malloc failed.\n");
		fclose(fp);
		fclose(fin);
		fclose(fout);
		return 1;
	}
	fread(fdata, 1, 0x80000, fin);
	
	fread(&word, 1, sizeof(word), fp);
	conv_endian_short(&word);
	if (word != 0x8914) {
		puts("OVERLAY: Wrong magic word in p file.\n");
		fclose(fp);
		fclose(fin);
		fclose(fout);
		free(fdata);
		return 1;
	}
	
	while (fread(&precord, 1, sizeof(precord_t), fp)) {
		if (precord.record_type == 0x81) {
			//conv_endian_long(&precord.start_address);
			//conv_endian_short(&precord.length);
			printf("P - Start:%06lX Length:%04X\n", precord.start_address, precord.length);
			
			fread(&pdata, 1, precord.length, fp);
			
			memcpy(fdata + precord.start_address - 0xC00000, &pdata, precord.length);
			
			total_length += precord.length;
		} else if (precord.record_type == 0x00) {
			break;
		} else  {
			printf("OVERLAY: Unknown record type %lX.\n", precord.record_type);
			fclose(fp);
			fclose(fin);
			fclose(fout);
			free(fdata);
			return 1;
		}
	}
	
	fwrite(fdata, 1, 0x80000, fout);
	
	printf("Overlaid %lu bytes.\n", total_length);
	
	fclose(fp);
	fclose(fin);
	fclose(fout);
	
	free(fdata);

	return 0;
}

