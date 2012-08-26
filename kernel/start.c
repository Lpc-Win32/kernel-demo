#include "pub.h"

extern void* memcpy(void* dst, void* src, int size);
extern void disp_str(char* str);
extern void init_prot();

uint8_t g_gdt_ptr[6];
descriptor_t g_gdt[GDT_SIZE];

uint8_t g_idt_ptr[6];
gate_t g_idt[IDT_SIZE];

void cstart()
{
	uint16_t* p_gdt_limit = (uint16_t*)(&g_gdt_ptr[0]);
	uint32_t* p_gdt_base = (uint32_t*)(&g_gdt_ptr[2]);
	uint16_t* p_idt_limit = (uint16_t*)(&g_idt_ptr[0]);
	uint32_t* p_idt_base = (uint32_t*)(&g_idt_ptr[2]);

	memcpy(g_gdt, (void*)(*p_gdt_base), *p_gdt_limit + 1);

	*p_gdt_base = (uint32_t)g_gdt;
	*p_gdt_limit = GDT_SIZE * sizeof(descriptor_t) - 1;
	*p_idt_base = (uint32_t)g_idt;
	*p_idt_limit = IDT_SIZE * sizeof(gate_t) - 1;

	init_prot();
	
	disp_str("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\nhello world\n");
	return ;
}

