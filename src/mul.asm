                section         .text

                global          _start
_start:

                sub             rsp, 2 * 128 * 8
                lea             rdi, [rsp + 128 * 8]
                mov             rcx, 128
                call            read_long
                mov             rdi, rsp
                call            read_long
                lea             rsi, [rsp + 128 * 8]
                call            multiply_long_long

                mov             rcx, 256            ; result might be 256 qwords long
                call            write_long

                mov             al, 0x0a
                call            write_char

                jmp             exit

; multiplies two long numbers
;    rdi -- address of factor #1 (long number)
;    rsi -- address of factor #2 (long number)
;    rcx -- length of long numbers in qwords
; result:
;    product is written to rdi
multiply_long_long:
                push            rdi
                push            rsi
                push            rcx

                mov             r15, rsp                    ; storing the right-end of the stack memory available for calculations
                lea             r11, [rcx * 8]
                sub             rsp, r11                    ; allocating memory on the stack for further calculations

                mov             r11, rdi                    ; nullifying allocated memory
                mov             rdi, rsp
                call            set_zero
                mov             rdi, r11

                mov             r8, rsp                     ; pointer to the start of the value calculated on every loop iteration
                lea             r9, [rcx * 2]               ; loop counter (128 for multiplying and 128 for moving remained qwords to answer)
.loop:                                                      ; in this loop the current qword-multiplier is being chosen
                cmp             r9, rcx                     ; if we have already done rcx (128) iterations then we have iterated through all qwords of one of the factors (rdi)
                jbe              .skip
                call            mul_and_add_on_stack
.skip:
                mov             r11, [r8]                   ; moving the lowest qword (which will become the highest because of cycling) of the result of previous operation
                mov             [rdi], r11                  ; to the answer (this rdi-address will never be used again during multiplication, so it can be used as the answer storage already)
                mov             [r8], rbx                   ; putting overflow to newly highest qword
                lea             r8, [r8 + 8]                ; moving r8 to position of current lowest qword
                call            check_if_cycling_is_needed
                lea             rdi, [rdi + 8]              ; moving the current qword-multiplier
                dec             r9
                jnz             .loop

                lea             rsp, [rsp + rcx * 8]
                pop             rcx
                pop             rsi
                pop             rdi
                ret

; multiplies long number by a short and adds it to previous one calculated on the stack
;    rsi -- address of multiplier #1 (long number)
;    [rdi] -- multiplier #2 (64-bit unsigned)
;    rcx -- length of long number in qwords
; result:
;    product is written to r8
;    overflow is written to rbx
mul_and_add_on_stack:
                push            rax
                push            rsi
                push            rdx
                push            r9

                mov             r9, rcx
                xor             rbx, rbx
.loop:
                mov             rax, [rsi]
                mul             qword [rdi]
                add             rax, rbx
                adc             rdx, 0
                add             [r8], rax
                adc             rdx, 0
                mov             rbx, rdx
                lea             rsi, [rsi + 8]
                lea             r8, [r8 + 8]
                call            check_if_cycling_is_needed
                dec             r9
                jnz             .loop

                pop             r9
                pop             rdx
                pop             rsi
                pop             rax
                ret

; checks if the and of available memory on the stack is reached by the r8 and cycles it if so
; r8  -- current address to some qword on the stack
; r15 -- address of the end of the stack available to use
; rcx -- size of allocated memory on the stack
check_if_cycling_is_needed:
                push            r11

                cmp             r8, r15
                jne             .skip
                lea             r11, [rcx * 8]
                sub             r8, r11
.skip:
                pop             r11
                ret

; adds 64-bit number to long number
;    rdi -- address of summand #1 (long number)
;    rax -- summand #2 (64-bit unsigned)
;    rcx -- length of long number in qwords
; result:
;    sum is written to rdi
add_long_short:
                push            rdi
                push            rcx
                push            rdx

                xor             rdx,rdx
.loop:
                add             [rdi], rax
                adc             rdx, 0
                mov             rax, rdx
                xor             rdx, rdx
                add             rdi, 8
                dec             rcx
                jnz             .loop

                pop             rdx
                pop             rcx
                pop             rdi
                ret

; multiplies long number by a short
;    rdi -- address of multiplier #1 (long number)
;    rbx -- multiplier #2 (64-bit unsigned)
;    rcx -- length of long number in qwords
; result:
;    product is written to rdi
mul_long_short:
                push            rax
                push            rdi
                push            rcx

                xor             rsi, rsi
.loop:
                mov             rax, [rdi]
                mul             rbx
                add             rax, rsi
                adc             rdx, 0
                mov             [rdi], rax
                add             rdi, 8
                mov             rsi, rdx
                dec             rcx
                jnz             .loop

                pop             rcx
                pop             rdi
                pop             rax
                ret

; divides long number by a short
;    rdi -- address of dividend (long number)
;    rbx -- divisor (64-bit unsigned)
;    rcx -- length of long number in qwords
; result:
;    quotient is written to rdi
;    rdx -- remainder
div_long_short:
                push            rdi
                push            rax
                push            rcx

                lea             rdi, [rdi + 8 * rcx - 8]
                xor             rdx, rdx

.loop:
                mov             rax, [rdi]
                div             rbx
                mov             [rdi], rax
                sub             rdi, 8
                dec             rcx
                jnz             .loop

                pop             rcx
                pop             rax
                pop             rdi
                ret

; assigns a zero to long number
;    rdi -- argument (long number)
;    rcx -- length of long number in qwords
set_zero:
                push            rax
                push            rdi
                push            rcx

                xor             rax, rax
                rep stosq

                pop             rcx
                pop             rdi
                pop             rax
                ret

; checks if a long number is a zero
;    rdi -- argument (long number)
;    rcx -- length of long number in qwords
; result:
;    ZF=1 if zero
is_zero:
                push            rax
                push            rdi
                push            rcx

                xor             rax, rax
                rep scasq

                pop             rcx
                pop             rdi
                pop             rax
                ret

; read long number from stdin
;    rdi -- location for output (long number)
;    rcx -- length of long number in qwords
read_long:
                push            rcx
                push            rdi

                call            set_zero
.loop:
                call            read_char
                or              rax, rax
                js              exit
                cmp             rax, 0x0a
                je              .done
                cmp             rax, '0'
                jb              .invalid_char
                cmp             rax, '9'
                ja              .invalid_char

                sub             rax, '0'
                mov             rbx, 10
                call            mul_long_short
                call            add_long_short
                jmp             .loop

.done:
                pop             rdi
                pop             rcx
                ret

.invalid_char:
                mov             rsi, invalid_char_msg
                mov             rdx, invalid_char_msg_size
                call            print_string
                call            write_char
                mov             al, 0x0a
                call            write_char

.skip_loop:
                call            read_char
                or              rax, rax
                js              exit
                cmp             rax, 0x0a
                je              exit
                jmp             .skip_loop

; write long number to stdout
;    rdi -- argument (long number)
;    rcx -- length of long number in qwords
write_long:
                push            rax
                push            rcx

                mov             rax, 20
                mul             rcx
                mov             rbp, rsp
                sub             rsp, rax

                mov             rsi, rbp

.loop:
                mov             rbx, 10
                call            div_long_short
                add             rdx, '0'
                dec             rsi
                mov             [rsi], dl
                call            is_zero
                jnz             .loop

                mov             rdx, rbp
                sub             rdx, rsi
                call            print_string

                mov             rsp, rbp
                pop             rcx
                pop             rax
                ret

; read one char from stdin
; result:
;    rax == -1 if error occurs
;    rax \in [0; 255] if OK
read_char:
                push            rcx
                push            rdi

                sub             rsp, 1
                xor             rax, rax
                xor             rdi, rdi
                mov             rsi, rsp
                mov             rdx, 1
                syscall

                cmp             rax, 1
                jne             .error
                xor             rax, rax
                mov             al, [rsp]
                add             rsp, 1

                pop             rdi
                pop             rcx
                ret
.error:
                mov             rax, -1
                add             rsp, 1
                pop             rdi
                pop             rcx
                ret

; write one char to stdout, errors are ignored
;    al -- char
write_char:
                sub             rsp, 1
                mov             [rsp], al

                mov             rax, 1
                mov             rdi, 1
                mov             rsi, rsp
                mov             rdx, 1
                syscall
                add             rsp, 1
                ret

exit:
                mov             rax, 60
                xor             rdi, rdi
                syscall

; print string to stdout
;    rsi -- string
;    rdx -- size
print_string:
                push            rax

                mov             rax, 1
                mov             rdi, 1
                syscall

                pop             rax
                ret


                section         .rodata
invalid_char_msg:
                db              "Invalid character: "
invalid_char_msg_size: \
                equ             $ - invalid_char_msg
