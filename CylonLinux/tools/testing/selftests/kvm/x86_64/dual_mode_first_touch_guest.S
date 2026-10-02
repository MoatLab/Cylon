/* SPDX-License-Identifier: GPL-2.0 */
/* Identity mapped long-mode code, copied to GPA 0x1000. No host references. */
.section .rodata
.global ft_guest_start, ft_guest_end
ft_guest_start:
	/* rdi: target, rsi: operation, rbx: control page, r8: wrong marker. */
	mov $1, %al
	out %al, $0x80
	cmp $1, %rsi
	je 2f
	cmp $2, %rsi
	je 3f
	cmp $3, %rsi
	je 4f
	cmp $4, %rsi
	je 6f
	mov (%rdi), %rax
	jmp 8f
2:
	mov %r9, (%rdi)
	mov %r9, %rax
	jmp 8f
3:
	call *%rdi
	jmp 8f
4:
	cmpq $0, 32(%rbx)
	je 4b
5:
	mov (%rdi), %rax
	mov %rax, 24(%rbx)
	cmp %r8, %rax
	jne 9f
	incq 16(%rbx)
	jmp 1f
9:
	cmp %r11, %rax
	je 1f
	incq 40(%rbx)
1:
	incq 8(%rbx)
	cmpq $0, (%rbx)
	je 5b
	jmp 8f
6:
	mov $1, %r10
7:
	mov %r10, (%rdi)
	mov %r10, 8(%rbx)
	inc %r10
	cmpq $0, (%rbx)
	je 7b
	mov 8(%rbx), %rax
8:
	mov %rax, 24(%rbx)
	mov $2, %al
	out %al, $0x80
	hlt
ft_guest_end:
.section .note.GNU-stack,"",@progbits
