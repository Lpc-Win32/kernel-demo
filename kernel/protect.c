#include "pub.h"

extern init_8259A();
extern int disp_pos;
extern gate_t g_idt[IDT_SIZE];

typedef void (*int_handler)();

/* 中断处理函数 */
void	divide_error();
void	single_step_exception();
void	nmi();
void	breakpoint_exception();
void	overflow();
void	bounds_check();
void	inval_opcode();
void	copr_not_available();
void	double_fault();
void	copr_seg_overrun();
void	inval_tss();
void	segment_not_present();
void	stack_exception();
void	general_protection();
void	page_fault();
void	copr_error();


void exception_handler(int vec_no, int err_code, int cs, int eflags)
{

	char* err_msg[] =
	{
		"Divide Error",
		"Single Step Exception",
		"NMI Interrupt",
		"Breakpoint",
		"Overflow",
		"Bound Range Exceeded",
		"Undefined Opcode",
		"Device Not Available",
		"Double Fault",
		"Segment Overrun",
		"Invalid TSS",
		"Segment Not Present",
		"Stack Exception",
		"General Protection",
		"Page Fault",
		"Intel Reserved",
		"Floating Point Error",
		"Alignment Check",
		"Machine Check",
		"Floating Point Exception"
	};

	disp_pos = 0;
	int i;
	for (i = 0; i < 80 * 5; ++i)
	{
		disp_str(" ");
	}
	disp_pos = 0;

	disp_str("Exception: ");
	disp_str(err_msg[vec_no]);

	return;
}

void init_idt_desc(unsigned char vector, uint8_t desc_type,
		int_handler handler, unsigned char privilege)
{
	gate_t * p_gate = &g_idt[vector];
	uint32_t base = (uint32_t)handler;
	p_gate->offset_low = base & 0xFFFF;
	p_gate->selector = SELECTOR_KERNEL_CS;
	p_gate->dcount = 0;
	p_gate->attr = desc_type | (privilege<<5);
	p_gate->offset_high = (base>>16) & 0xFFFF;
}

void init_prot()
{
	init_8259A();

	// 全部初始化成中断门(没有陷阱门)
	init_idt_desc(INT_VECTOR_DIVIDE,	DA_386IGate,
		      divide_error,		PRIVILEGE_KRNL);

	init_idt_desc(INT_VECTOR_DEBUG,		DA_386IGate,
		      single_step_exception,	PRIVILEGE_KRNL);

	init_idt_desc(INT_VECTOR_NMI,		DA_386IGate,
		      nmi,			PRIVILEGE_KRNL);

	init_idt_desc(INT_VECTOR_BREAKPOINT,	DA_386IGate,
		      breakpoint_exception,	PRIVILEGE_USER);

	init_idt_desc(INT_VECTOR_OVERFLOW,	DA_386IGate,
		      overflow,			PRIVILEGE_USER);

	init_idt_desc(INT_VECTOR_BOUNDS,	DA_386IGate,
		      bounds_check,		PRIVILEGE_KRNL);

	init_idt_desc(INT_VECTOR_INVAL_OP,	DA_386IGate,
		      inval_opcode,		PRIVILEGE_KRNL);

	init_idt_desc(INT_VECTOR_COPROC_NOT,	DA_386IGate,
		      copr_not_available,	PRIVILEGE_KRNL);

	init_idt_desc(INT_VECTOR_DOUBLE_FAULT,	DA_386IGate,
		      double_fault,		PRIVILEGE_KRNL);

	init_idt_desc(INT_VECTOR_COPROC_SEG,	DA_386IGate,
		      copr_seg_overrun,		PRIVILEGE_KRNL);

	init_idt_desc(INT_VECTOR_INVAL_TSS,	DA_386IGate,
		      inval_tss,		PRIVILEGE_KRNL);

	init_idt_desc(INT_VECTOR_SEG_NOT,	DA_386IGate,
		      segment_not_present,	PRIVILEGE_KRNL);

	init_idt_desc(INT_VECTOR_STACK_FAULT,	DA_386IGate,
		      stack_exception,		PRIVILEGE_KRNL);

	init_idt_desc(INT_VECTOR_PROTECTION,	DA_386IGate,
		      general_protection,	PRIVILEGE_KRNL);

	init_idt_desc(INT_VECTOR_PAGE_FAULT,	DA_386IGate,
		      page_fault,		PRIVILEGE_KRNL);

	init_idt_desc(INT_VECTOR_COPROC_ERR,	DA_386IGate,
		      copr_error,		PRIVILEGE_KRNL);
}
