; G8P2.asm

; Group 8 Project 2 for CSC-323, Spring 2022
;    Version 6
;
; Reverse Polish Notation Calculator

; Authors:
;   Karl Miller   MIL7233@calu.edu
;   Luke Bates    BAT6731@calu.edu
;

INCLUDE Irvine32.inc                    ; use irvine library



.data
; =============================================================================== main data

; ------------ general  message strings   -------------------
    header_msg byte " G8P2.asm ", 0
    out_msg byte 10,10,10," This program was created by Karl Miller and Luke Bates. Goodbye.", 10, 10, 0

    ; prompt_strings
    prompt_msg byte "Stack Operation? ", 0

    ; error_strings
    operation_error_msg byte     "The operation failed!", 0
    div_zero_message byte        "Can't divide by zero.", 0
    stack_full_message byte      "The stack is full.", 0
    too_few_msg byte             "Not enough operands.", 0
    prompt_error_msg byte        "Your input was not understood!", 0
    overflow_error_msg byte      "Integers must be between -2,147,483,648 and +2,147,483,647", 0
    clear_error_msg byte         "                                                          ", 0

    top_stack_msg byte "      Stack Top:  ", 0
    stack_empty_msg byte "empty       ", 0
    stack_contents_msg byte 10, "Stack Operation? ", 0
    stack_only_msg byte 10, " -- Stack -- ", 0

    ; 39 spaces is the the distance between the input prompt and the help box
    blank_space_39 byte "                                              ",0

; ------------ input buffer allocation   ------------

    ; 39 characters between input start and the help box + 30 width of the help box = 69
    ; user can write in help box but their text will be overwritten on the redraw
    ; if they write more chars than the buffer, a clrscr will be called
    BUFF_SIZE equ 69
    input_buffer byte BUFF_SIZE DUP(0)
    buffer_clear_string byte BUFF_SIZE DUP(' ')
    last_input_size dword ?             ; the size of the last input, in characters/bytes

; ------------ stack allocation          -------------------

    stack_size equ 8                    ; the maximum number of SDWORDs that the custom stack can contain
    stack_index sdword -4               ; the initial index is set to -4 (-1 sdwords) so the first push will be in element 0 in the stack. -1 index indicates that stack is empty
    full_stack equ (stack_size-1)*4      ; the full size of the stack, in bytes , because we increment before push
    rpn_stack sdword stack_size dup(77)  ; the rpn stack. Allocate 8 sdwords initially set to 0.

; ------------ karl's pretty print stuff ----------------------------------------
        ; see https://docs.microsoft.com/en-us/windows/console/setconsolemode for info on windows api
    outHandle HANDLE ?                      ; windows HANDLE for a console (dword)
    original_console_out_settings DWORD ?   ; original console mode, for restoring when program is done
    _o_mode_eol_wrap equ 1                  ; amount of bit offset for bit 2 of console output mode to control end of line wrap (1 == enable)
                                            ; we will disable end of line wrap for slightly better appearance on a mis-sized buffer

    settings word 0000000000000010b         ; bit 0   : 0 = stack showing, 1 = not
                                            ; bit 1   : 0 = help showing,  1 = not
                                            ; bit 3   : 0 = int mode,      1 = hex mode
    title_location            COORD <2, 0>  ; coords for printing title
    st_start_location         COORD <23, 7> ; coordinates for pretty-printing the stack (x,y)
    help_box_print_location   COORD <60, 0> ; coordinates for the help box
    input_start_location      COORD <5, 4>  ; coordinates for input prompt
    user_entry_location       COORD <23, 4> ; coordinates for input entry
    error_start_location      COORD <2, 6>  ; error print location
    top_stack_start_location  COORD <5, 2>  ; top of stack print location
    st_current_print_location COORD <?,?>   ; changable struct for current printing location
    st_title_str byte "Stack:                                  ", 0
    st_clear_str byte "                                        ", 0      ; for clearing a line in the stack.
      ; stack clear line has extra length to support WriteBin at some point, only needs 11 chars right now technically


.code

; =============================================================================== configuration, initialization (1)

get_handle proc
    ; ---------------------------------------------------------------------------------------------------------------
    ; get_handle
    ;
    ; gets the HANDLE dword for the console so we can use the Windows API and stores it in the global mem location outHandle
    ; gets the original console mode and stores it in the global mem location original_console_out_settings
    ;    @see Microsoft Docs and SmallWin.inc for info about Windows API
    ; ---------------------------------------------------------------------------------------------------------------
    push eax
    pushf
    invoke GetStdHandle, STD_OUTPUT_HANDLE      ; get the console output handle
    mov outHandle, eax                          ; save the handle for later use
    invoke GetConsoleMode, outHandle, OFFSET original_console_out_settings  ; get the current console mode
    mov eax, original_console_out_settings
    btc eax, _o_mode_eol_wrap       ; the point of this to improve viewing on a mis-sized window, but only made a minor difference
    invoke SetConsoleMode, outHandle, eax ;  ; but at least the right text wont overflow to the left
    popf
    pop eax
    ret
get_handle endp

; =============================================================================== pretty printing procedures (21)

print_coord_down proc
    ; ----------------------------------------------------------------
    ; print_coord_down
    ;
    ; changes the second word in st_current_print_location by 1
    ; invokes SetConsoleCursor Position to move cursor down 1
    ; ---------------------------------------------------------------
    pushad                             ; save eax
    mov eax, st_current_print_location   ; mov the pair of words to eax
    rol eax, 16                          ; move the second word into position
    inc ax                               ; increment that word
    rol eax, 16                          ; return to the original arrangement
    mov st_current_print_location, eax   ; save in memory
    invoke SetConsoleCursorPosition, outHandle, st_current_print_location
    popad                              ; restore eax
    ret
print_coord_down endp

print_coord_up proc
    ; ----------------------------------------------------------------
    ; print_coord_up
    ;
    ; changes the second word in st_current_print_location by 1
    ; invokes SetConsoleCursor Position to move cursor up 1
    ; ---------------------------------------------------------------
    pushad
    mov eax, st_current_print_location
    rol eax, 16
    dec ax
    rol eax, 16
    mov st_current_print_location, eax
    pop eax
    invoke SetConsoleCursorPosition, outHandle, st_current_print_location
    popad
    ret
print_coord_up endp

print_title proc
    ; ----------------------------------------------------------------
    ; print_title
    ;
    ; prints the group name in the upper left
    ; ----------------------------------------------------------------
    pushad
    invoke SetConsoleCursorPosition, outHandle, title_location
    call GetTextColor               ; EAX::original_color = GetTextColor()
    push eax                        ; Stack.push(EAX::original_color)

    mov eax, white + (gray*16)      ; EAX::new_color = white with gray background
    call SetTextColor               ; SetTextColor(EAX::new_color)
    mov edx, OFFSET header_msg      ; EDX::message_address = *header_msg
    call WriteString                ; WriteString(EDX::message_address)

    pop eax                         ; EAX::original_color = Stack.pop()
    call SetTextColor               ; SetTextColor(EAX::original_color)

    popad
    ret
print_title endp

quit_msg_and_console_reset proc
    ; -----------------------------------------------------------------------
    ; quit_msg_and_console_reset
    ;
    ; Prints the goodbye message and returns console mode to original settings.
    ; -----------------------------------------------------------------------

    invoke SetConsoleMode, outHandle, original_console_out_settings
        ; we reset console mode first in case user ctrl+c quits on the goodbye delay
        ; want to try to make sure their console goes back to the original mode before exiting
    call Clrscr
    call print_title            ; keep the group title up
    call GetTextColor
    push eax                    ; pretty print a goodbye message
    mov eax, blue
    call SetTextColor
    mov edx, OFFSET out_msg
    call WriteString
    pop eax
    call SetTextColor
    invoke Sleep, 750

    ret
quit_msg_and_console_reset endp

print_in_mode proc
    ; ---------------------------------------------------------------------------------
    ; print_in_mode
    ;
    ; Calls either WriteInt or WriteHex depending on the 3rd bit of the settings word.
    ;   RECEIVES eax - the number to print
    ; --------------------------------------------------------------------------------
    push eax
    push ebx

    mov bx, settings
    bt bx, 2                            ; move bit 3 to carry flag
    jc was_set_to_write_hex             ; if carry flag 1, that means its hex mode

    was_set_to_write_int:
        call WriteInt
        jmp finish

    was_set_to_write_hex:
        call WriteHex

    finish:

    pop ebx
    pop eax
    ret
print_in_mode endp

print_integer proc
    ; -------------------------------------------------------------------------------------------------------------
    ; print_integer
    ;
    ; prints a number colored based on its value. Sets color and calls print_in_mode to print in appropriate base
    ;   RECEIVES: eax - integer to print
    ; -------------------------------------------------------------------------------------------------------------
    push ebx
    push eax                            ; stack.push(eax)

    call GetTextColor                   ; eax = GetTextColor();     // need the original color first
    mov ebx, eax                        ; ebx = eax

    pop eax                             ; eax = stack.pop()        // need the original value, might seem funny to pop and push
    push eax                            ; stack.push(eax)          // but its necessary as eax is used for setting colors
    cmp eax, 2147483647                 ; if(eax == max
    je print_overflow                   ;    ||
    cmp eax, -2147483648                ;  eax == min)
    je print_overflow                   ;     setColor("overflow")
    cmp eax, 0                          ; else if(eax < 0)
    jl print_negative                   ;      setColor("negative")
    je print_zero                       ;
                                        ; else
    print_positive:                     ;      setColor("positive")
        mov eax, green
        call SetTextColor
        jmp execute_print_and_finish

    print_negative:
        mov eax, lightRed
        call SetTextColor
        jmp execute_print_and_finish

    print_zero:
        mov eax, yellow
        call SetTextColor
        jmp execute_print_and_finish

    print_overflow:
        mov eax, white + (magenta * 16)
        call SetTextColor
        jmp execute_print_and_finish

    execute_print_and_finish:
        pop eax                         ; eax = stack.pop()
        ;call print_number_in_setting_mode
        call print_in_mode                   ; WriteInt(eax)
        push eax                        ; stack.push(eax)
        mov eax, ebx                    ; eax = ebx                     // use b register to restore color
        call SetTextColor               ; SetTextColor(eax)


    pop eax                             ; return
    pop ebx
    ret
print_integer endp

stack_print proc
    ; ------------------------------------------------------------------------------------------------------------------
    ; stack_print
    ;
    ; prints the stack starting at st_start location. Prints vertically, with 'Stack' in blue and values as colored ints.
    ; only prints active stack elements, no junk data.
    ; -------------------------------------------------------------------------------------------------------------------
    pushad                          ; save all registers, as many of the invokes have mutations

    mov eax, st_start_location      ; set initial printing position
    mov st_current_print_location, eax
    invoke SetConsoleCursorPosition, outHandle, st_current_print_location

    call GetTextColor
    mov ebx, eax                    ; save original text color

    mov eax, cyan
    call SetTextColor               ; set color to cyan

    mov edx, OFFSET st_title_str    ; print "Stack:" in cyan
    call WriteString


    mov ecx, full_stack             ; two loop counters, one for full size of stack
    mov esi, stack_index            ; second for active stack

    while_stack_to_print:
        call print_coord_down       ; move the cursor down 1 for each val
        cmp ecx, 0                  ; if done printing stack
        jl end_while_loop           ;    break
        cmp esi, 0                  ; if done printing active indices
        jl write_blank_line         ;   print a blank line
        mov eax, rpn_stack[esi]     ; otherwise
        call print_integer          ;   write that stack value and continue
        mov edx, OFFSET st_clear_str
        call WriteString
        jmp continue_looping
        write_blank_line:
            mov edx, OFFSET st_clear_str
            call WriteString

        continue_looping:
            sub ecx, 4
            sub esi, 4
            jmp while_stack_to_print

    end_while_loop:

    mov eax, ebx                    ; restore original text color
    call SetTextColor

    popad
    ret
stack_print endp

clear_stack_print proc
    ; ---------------------------------------------------------------------------------------------
    ; clear_stack_print
    ;
    ; clears the stack starting at st_start location by writing blank lines instead of stack values
    ; ----------------------------------------------------------------------------------------------
    pushad                          ; save all registers, some of the invokes could have mutations

    mov eax, st_start_location      ; set initial printing position
    mov st_current_print_location, eax
    invoke SetConsoleCursorPosition, outHandle, st_current_print_location

    mov esi, 0
    mov edx, OFFSET st_clear_str

    do_while_have_area_left_to_clear:
        call WriteString
        call print_coord_down
        cmp esi, stack_size
        jg end_while
        inc esi
        jmp do_while_have_area_left_to_clear

    end_while:


    popad

    ret
clear_stack_print endp

error_print proc
    ; ------------------------------------------------------------------------
    ; error_print
    ;
    ; prints a message in red at the location specified by error_start_location
    ;       RECEIVES edx - the offset of an error message to print
    ; ------------------------------------------------------------------------
    push eax
    push ebx
    push edx
    invoke SetConsoleCursorPosition, outHandle, error_start_location
    call GetTextColor
    mov ebx, eax            ; save old text color
    mov eax, red
    call SetTextColor
    pop edx
    call WriteString
    push edx
    mov eax, ebx
    call SetTextColor       ; restore old text color
    pop edx
    pop ebx
    pop eax
    ret
error_print endp

error_overflow proc
    ; -------------------------------------------------------
    ; error_overflow
    ;
    ; just calls error_print with the overflow error message
    ; ------------------------------------------------------
    push edx
    mov edx, offset overflow_error_msg
    call error_print
    pop edx
    ret
error_overflow endp

clear_error proc
    ; -------------------------------------------------------------------------------------------
    ; clear_error
    ;
    ; clears the error message from the console by writing whitespace in the error print location
    ; ------------------------------------------------------------------------------------------

    push edx
    push eax   ; cursor position uses eax

    invoke SetConsoleCursorPosition, outHandle, error_start_location
    mov edx, OFFSET clear_error_msg
    call WriteString

    pop eax
    pop edx
    ret
clear_error endp

prompt_print proc
    ; ----------------------------------------------------------------------------------------------------------
    ; prompt_print
    ;
    ; prints the input prompt at input_start_location and prints a clearing string over the user_entry_location
    ; ----------------------------------------------------------------------------------------------------------
    push edx
    push eax
    invoke SetConsoleCursorPosition, outHandle, input_start_location
    mov edx, OFFSET prompt_msg
    call WriteString
    call clear_input_area
    pop eax
    pop edx
    ret
prompt_print endp

clear_input_area proc
    ; ------------------------------------------------
    ; clear_input_area
    ;
    ; prints a string for clearing input area
    ; ------------------------------------------------
    push edx
    push eax
    invoke SetConsoleCursorPosition, outHandle, user_entry_location
    mov edx, OFFSET blank_space_39
    call WriteString
    pop eax
    pop edx
    ret
clear_input_area endp

top_stack_print proc
    ; -------------------------------------------------------------------------
    ; top_stack_print
    ;
    ; prints "Stack Top: " and the top of the stack at top_stack_start_location
    ; -------------------------------------------------------------------------
    push eax
    push edx
    push esi
    invoke SetConsoleCursorPosition, outHandle, top_stack_start_location
    mov edx, OFFSET top_stack_msg
    call WriteString
    mov esi, stack_index
    cmp esi, 0
    jl print_empty
    call GetTextColor
    mov eax, rpn_stack[esi]
    call print_integer
    jmp finish_print

    print_empty:
        call GetTextColor
        mov esi, eax                        ; using esi to save prev color, since we dont need it now
        mov eax, gray
        call SetTextColor
        mov edx, OFFSET stack_empty_msg     ; print empty in gray if empty
        call WriteString
        mov eax, esi
        call SetTextColor

    finish_print:
        mov edx, OFFSET st_clear_str        ; print some white spaces to clear long ints
        call WriteString

    pop esi
    pop edx
    pop eax
    ret
top_stack_print endp

toggle_print_mode proc
    ; ----------------------------------------------------------------
    ; toggle_print_mode
    ;
    ; toggles the 3rd bit in settings to change the print mode
    ; 0 = int, 1 = hex
    ; ----------------------------------------------------------------
    push eax
    pushf

    mov ax, settings
    btc ax, 2           ; 3rd bit controls mode
    mov settings, ax

    popf
    pop eax
    ret
toggle_print_mode endp

toggle_stack_view proc
    ; ---------------------------------------------------------------------------------------------------------------------
    ; toggle_stack_view
    ;
    ; Toggles whether the pretty-printed stack is displayed and clears the stack if it was toggled to hide.
    ; changes the low bit in settings to 1 if we want to show stack. Otherwise, changes it to 0 and calls clear_stack_print
    ; ---------------------------------------------------------------------------------------------------------------------
    push eax
    pushf
    mov ax, settings
    btc ax, 0           ; bit test and compliment - flip the lowest bit
    jnc finish           ; if carry == 1, dont clear screen
    call clear_stack_print ; clear the stack if we just set it to hide

    finish:
        mov settings, ax
    popf
    pop eax
    ret
toggle_stack_view endp

.data

    ; this data segment is for printing the help box

    help_box_title byte       "       Available Operators     ",0  ; each line must be the same width!
    help_box_divider byte     " ----------------------------- ",0
    help_addition byte        " +    addition  ( next + top  )",0  ; each of these segments probably
    help_subtraction byte     " -    subtract  ( next - top  )",0  ;  dont have to be named individually
    help_multiply byte        " *    multiply  ( next * top  )",0  ;  as they are retrieved based on
    help_divide byte          " /    divide    ( next / top  )",0  ;  their offset from help_box_title.
    help_exchange byte        " X    exchange  ( next <-> top)",0
    help_negate byte          " N    negate    ( top *= -1   )",0
    help_roll_up byte         " U    roll up   (top to bottom)",0
    help_roll_down byte       " D    roll down (bottom to top)",0
    help_clear byte           " C    clear stack              ",0
    help_view byte            " V    toggle stack view        ",0
    help_toggle byte          " H    toggle help view         ",0
    help_mode byte            " M    toggle int/hex           ",0
    help_cls byte             " O    reset buffer (cls)       ",0
    help_quit byte            " Q    quit                     ",0
    help_box_lines equ 15          ; if a line or command is added, this must be incremented
    help_blank byte           "                               ",0 ; line clearance string

.code
print_help_box proc
    ; ----------------------------------------------------------------------------------------------------------
    ; print_help_box
    ;
    ; prints the help box. Each line of the box must be equal length and stored consecutively in a data segment.
    ; ---------------------------------------------------------------------------------------------------------
    push edx                            ; for printing
    push ebx                            ; for increment size
    push ecx                            ; for limit of printing
    push eax                            ; for color setting

    call GetTextColor                   ; eax = getTextColor()
    push eax                            ; run_time_stack.push(eax)   -- save for restoration at end
    mov eax, gray                       ; eax = gray
    call SetTextColor                   ; setTextColor(eax)

    mov edx, help_box_print_location    ; current_print_location = help_box_start_print_location
    mov st_current_print_location, edx
    invoke SetConsoleCursorPosition, outHandle, st_current_print_location

    mov ebx, LENGTHOF help_box_title    ; increment = help_box_title.length()
    mov edx, OFFSET help_box_title      ; start = *help_box_title
    mov ecx, ebx                        ; end = increment
    imul ecx, help_box_lines            ; end *= number_of_lines
    add ecx, edx                        ; end += start

    do_while_lines_left_to_print:       ; do:
        call WriteString                ;   writeString(start)
        call print_coord_down           ;   print_coord_down()
        add edx, ebx                    ;   start += increment
        cmp edx, ecx                    ;   while(start < end)
        jg end_while
        jmp do_while_lines_left_to_print

    end_while:

    pop eax                             ; eax = stack.pop()    -- get original text color back
    call SetTextColor                   ; setTextColor(eax)

    pop eax
    pop ecx
    pop ebx
    pop edx
    ret
print_help_box endp

clear_help_box proc
    ; ----------------------------------------------------------------------------------
    ; clear_help_box
    ;
    ; clears the help box by printing the help_blank line over each line of the text box
    ; ----------------------------------------------------------------------------------
    push edx                            ; for printing
    push ecx                            ; for counter

    mov edx, help_box_print_location    ; current_print_location = help_box_start_print_location
    mov st_current_print_location, edx
    push eax                            ; setPos returns in eax, but we don't need the
                                        ; return and dont want the reg to change
    invoke SetConsoleCursorPosition, outHandle, st_current_print_location
    pop eax

    mov edx, OFFSET help_blank          ; start = *help_box_clear
    mov ecx, 0

    do_while_lines_left_to_print:       ; do:
        call WriteString                ;   writeString(start)
        call print_coord_down           ;   print_coord_down()
        inc ecx
        cmp ecx, help_box_lines
        jle do_while_lines_left_to_print
        jmp end_while

    end_while:

    pop ecx
    pop edx
    ret
clear_help_box endp

toggle_help_box proc
    ; -----------------------------------------------------------------------------------------------------
    ; toggle_help_box
    ;
    ; toggles whether the pretty-printed help box is displayed and clears it if it was just toggled to hide.
    ; changes the 2nd bit in settings to 1 if we want to show help, otherwise, changes it to 0
    ; -----------------------------------------------------------------------------------------------------
    push eax
    pushf
    mov ax, settings
    ;call WriteBin ; writing bin for debugging flags
    btc ax, 1                   ; bit test and compliment - flip the 2nd bit
    jnc finish                   ; if carry == 0, don't clear
    call clear_help_box         ; clear the help box

    finish:
        mov settings, ax
    popf
    pop eax
    ret
toggle_help_box endp

print_visible_structures proc
    ; ---------------------------------------------------------------------------------------
    ; print_visible_structures
    ;
    ; calls the print functions based on menu settings to draw the active parts of the screen
    ; ---------------------------------------------------------------------------------------
    pushad
    call prompt_print           ; this clears over the help box a little, so call it first
    call top_stack_print
    bt settings, 0      ;                       0 == dont print, 1 == print
    jc possibly_print_the_stack  ;              toggle_stack calls stack_clear print function but its an option
    jmp check_the_help_print_settings ;         to do it here every time instead if there are errors.
    possibly_print_the_stack:
        call stack_print
    check_the_help_print_settings:
        bt settings, 1
        jc possibly_print_the_help_box
        jmp finish_up
    possibly_print_the_help_box:
        call print_help_box
    finish_up:
        call print_title

    popad
    ret
print_visible_structures endp


; =============================================================================== Debug functions (6)
 ; they simply pretty print the named register and wait for a moment
    .data
        _db_eax_m byte " | EAX : ", 0
        _db_ebx_m byte " | EBX : ", 0
        _db_ecx_m byte " | ECX : ", 0
        _db_edx_m byte " | EDX : ", 0
        _db_esi_m byte " | ESI : ", 0
        _db_endstr byte "  |", 0
    .code
    _db_eax proc
        pushad
        mov edx, OFFSET _db_eax_m
        call ____db_x_wait
        popad
        ret
    _db_eax endp
    _db_esi proc
        pushad
        mov edx, OFFSET _db_esi_m
        mov eax, esi
        call ____db_x_wait
        popad
        ret
    _db_esi endp
    _db_ebx proc
        pushad
        mov edx, OFFSET _db_ebx_m
        mov eax, ebx
        call ____db_x_wait
        popad
        ret
    _db_ebx endp
    _db_ecx proc
        pushad
        mov edx, OFFSET _db_ecx_m
        mov eax, ecx
        call ____db_x_wait
        popad
        ret
    _db_ecx endp
    _db_edx proc
        pushad
        mov eax, edx
        mov edx, OFFSET _db_edx_m
        call ____db_x_wait
        popad
        ret
    _db_edx endp
    ____db_x_wait proc         ; destructive- dont call this directly!
        call WriteString
        call print_integer
        mov edx, offset _db_endstr
        call WriteString
        invoke Sleep, 450
        ret
    ____db_x_wait endp
    ; ; @@@@@@@@ db box, copy this around as needed @@@@@@@@
    ;     pushad
    ;     call _db_ebx
    ;     call _db_ecx
    ;     call _db_esi
    ;     call _db_eax
    ;     call _db_edx
    ;     invoke Sleep, 2000
    ;     popad
    ; ; @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


; =============================================================================== stack manipulations (5)

stack_roll_down_from_index proc
    ; ---------------------------------------------------------------
    ; stack_roll_down_from_index
    ;
    ; Roll the stack down. The bottom of the stack moves to the top of the
    ; stack and all positions move toward the bottom.
    ; Only used positions will roll. (No junk data)
    ; ---------------------------------------------------------------

    push ebx
    push eax
    push esi
    push edx

    mov esi, stack_index

    mov edx, rpn_stack[esi]
    mov ebx, rpn_stack[0]

    while_stack_left_to_roll:

        sub esi, 4
        cmp esi, 0
        jl end_while
        mov eax, rpn_stack[esi]
        mov rpn_stack[esi], edx
        mov edx, eax

        jmp while_stack_left_to_roll

    end_while:

    mov esi, stack_index
    mov rpn_stack[esi], ebx

    stc
    pop edx
    pop esi
    pop eax
    pop ebx
    ret
stack_roll_down_from_index endp

stack_roll_up_to_index proc
    ; ---------------------------------------------------------------
    ; stack_roll_up_to_index
    ;
    ; Roll the stack up. The top of the stack moves to the bottom of
    ; the stack and all positions move toward the top one position.
    ; Only used, n, positions will roll.
    ; ----------------------------------------------------------------
	pushad

	mov edi, stack_index			; Save stack index
	mov esi, stack_index			; Begin ESI at stack index
	sub esi, 4						; Push all values except top

	save_rpn_state:
		cmp esi, 0					; Save values until ESI < 0
		jl  send_top_to_bottom

		push rpn_stack[esi]			; Save each value

		sub esi, 4					; Iterate through the RPN Stack
		jmp save_rpn_state

	send_top_to_bottom:				; RPN Bottom = RPN Top
		mov esi, 0
		mov eax, rpn_stack[edi]
		mov rpn_stack[esi], eax

	restore_rpn_state:
		cmp esi, stack_index		; Repeat until top is reached
		jge end_rollup

		add esi, 4					; Start 1 element away from the bottom
		pop rpn_stack[esi]			; Restore the values until top is reached

		jmp restore_rpn_state

	end_rollup:
		popad
		ret

stack_roll_up_to_index endp

stack_clear proc
    ; ----------------------------------------------------------------
    ; stack_clear
    ;
    ; clears the stack by setting index back to -4
    ; ----------------------------------------------------------------
    pushf
    mov stack_index, -4
    popf
    ret
stack_clear endp

push_rpn proc
 ;---------------------------------------------------------------------
 ; push_rpn
 ;
 ; pushes eax onto rpn_stack, increments stack_index
 ;
 ;   RECEIVES: eax as an sdword to push to the stack
 ;---------------------------------------------------------------------
    push esi                            ; save esi to the runtime stack (different from rpn_stack) because we will be using it
    push edx
    push eax
    pushf
    mov esi, stack_index                ; move custom stack_index to esi register to operate on
    cmp esi, full_stack                 ; if stack is full:
    jge stack_full                      ;   jump to stack_full label
                                        ; else:
    add esi, 4                          ;   mov stack_index to esi and increment it by 1
    mov rpn_stack[esi], eax             ;   push the value in eax to the memory location in stack indicated by esi
    mov stack_index, esi                ;   save the new stack index
    jmp end_push                        ;   restore the regular esi and return
    stack_full:
        mov edx, OFFSET stack_full_message
        call error_print
    end_push:
        popf
        pop eax
        pop edx
        pop esi                         ; restore esi
        ret                             ; end the procedure
push_rpn endp

pop_rpn proc
	;-------------------------------------------------------------------------------------------
	; pop_rpn
	;
	; Pops the stack into EAX
	;
	;	RECEIVES:	None
	;	RETURNS:	Popped value into EAX. Carry flag is 1 if successful
	;-------------------------------------------------------------------------------------------
	push esi							; Save ESI
	mov esi, stack_index				; ESI = Stack Index

	check_empty:						; Stack is empty if (ESI < 0)
		cmp esi, 0
		jl  stack_empty

	pop_value:
		mov eax, rpn_stack[esi]			; EAX = Top of stack
		sub esi, 4						; Decrease stack index
		mov stack_index, esi			; Stack Index = ESI
		stc								; Set the carry flag
		jmp end_pop

	stack_empty:
		clc								; Clear the carry flag

	end_pop:
		pop esi							; Restore ESI
		ret								; End the procedure
pop_rpn endp

exchange_rpn proc
    ;----------------------------------------
    ; exchange_rpn
    ;
    ; exchanges the top to items on the stack
    ; prints an error if not enough operands
    ; ---------------------------------------
    push ebx
    push eax
    push esi
    pushf

    mov esi, stack_index
    cmp esi, 4
    jl insuf_operand

    mov eax, rpn_stack[esi]
    mov ebx, rpn_stack[esi-4]
    mov rpn_stack[esi], ebx
    mov rpn_stack[esi-4], eax
    jmp end_oper

    insuf_operand:
        mov edx, offset too_few_msg
        call error_print

	end_oper:
    popf
    pop esi
    pop eax
    pop ebx
    ret
exchange_rpn endp

; =============================================================================== math operations (4)

addition_rpn proc
	; --------------------------------------------------------------------
	; addition_rpn
	;
    ; Pops the top two elements, adds them together, and pushes the result.
    ; OR prints an error if insufficient operands.
	; --------------------------------------------------------------------
	pushad								; Save registers

    mov ebx, stack_index                ; if(stack_index < 2)
    cmp ebx, 4                          ;    return
    jl insuf_operand

	call pop_rpn						; Pop stack into EAX
	mov ebx, eax						; EBX = EAX

	call pop_rpn						; Pop stack into EAX

	add eax, ebx						; EAX += EBX
	call push_rpn						; Push the new calculation to the stack

	jmp end_oper						; End the operation successfully

    insuf_operand:
        mov edx, offset too_few_msg
        call error_print

	end_oper:
	popad								; Restore registers
	ret

addition_rpn endp

subtraction_rpn proc
	; ------------------------------------------------------------------------------------
	; subtraction_rpn
	;
    ; Pops the top two elements, subtracts the first from the second, and pushes the result.
    ; OR prints an error if insufficient operands.
    ;    Next - Top
	; -----------------------------------------------------------------------------------
	pushad								; Save registers

    mov ebx, stack_index                ; if(stack_index < 2)
    cmp ebx, 4                          ;    return
    jl insuf_operand

	call pop_rpn						; Pop stack into EAX
	mov ebx, eax						; EBX = EAX
	call pop_rpn						; Pop stack into EAX

	sub eax, ebx						; EAX -= EBX
	call push_rpn						; Push the new calculation to the stack

	jmp end_oper						; End the operation successfully

	insuf_operand:
        mov edx, offset too_few_msg
        call error_print

	end_oper:
	popad								; Restore registers
	ret
subtraction_rpn endp

multiply_rpn proc
	; --------------------------------------------------------------------------
	; multiply_rpn
	;
    ; Pops the top two elements, multiplies them together, and pushes the result.
    ; OR prints an error if insufficient operands.
	; --------------------------------------------------------------------------
	pushad								; Save registers

    mov ebx, stack_index                ; if(stack_index < 2)
    cmp ebx, 4                          ;    return
    jl insuf_operand

	call pop_rpn						; Pop stack into EAX
	mov ebx, eax						; EBX = EAX
	call pop_rpn						; Pop stack into EAX

	mov edx, 0							; Clear EDX before operation
	imul ebx							; EAX *= EBX
	call push_rpn						; Push the new calculation to the stack

	jmp end_oper						; End the operation successfully

	insuf_operand:
        mov edx, offset too_few_msg     ; print insufficient operand error
        call error_print

	end_oper:
	popad								; Restore registers
	ret
multiply_rpn endp

divide_rpn proc
	;-------------------------------------------------------------------------------------------
	; divide_rpn
	;
	; Divide the top two elements in the manner described in the specs
    ;   top_element = second_element / top_element
    ;   if the most recent entry on the stack was a zero it will fail
    ;   if there are not two elements in the stack, it will fail and print an error
	;-------------------------------------------------------------------------------------------
	pushad								; Save registers

    mov ebx, stack_index                ; if(stack_index < 2)
    cmp ebx, 4                          ;
    jl insuf_operand                    ;   print error and return

	call pop_rpn						; ebx = pop()
    mov ebx, eax                        ; eax = pop()
    call pop_rpn

    cmp ebx, 0                          ; if(ebx != 0):
    je div_zero

	cdq									;	Extend sign bit from EAX to EDX
	idiv ebx							;   eax = eax/ebx

	push_result:
    	call push_rpn                   ;   push(eax)
    	jmp end_oper

	insuf_operand:
        mov edx, offset too_few_msg     ; print insufficient operand error
        call error_print
        jmp end_oper

    div_zero:
        call push_rpn
        mov eax, ebx                    ; push what we got back on the stack
        call push_rpn
        mov edx, OFFSET div_zero_message
        call error_print

	end_oper:
	    popad								; Restore registers
                                            ; return
	    ret

divide_rpn endp

negate_rpn proc
    ; -------------------------------------
    ; negate_rpn
    ;
    ; negates the top element of the stack
    ; prints error if stack empty
    ; --------------------------------------

    push edx
    push esi
    mov esi, stack_index
    cmp stack_index, 0
    jl insuf_operand
    mov edx, rpn_stack[esi]
    neg edx
    mov rpn_stack[esi], edx
    jmp end_oper
	insuf_operand:
        mov edx, offset too_few_msg     ; print insufficient operand
        call error_print
        jmp end_oper

    end_oper:

    pop esi
    pop edx
    ret

negate_rpn endp

; =============================================================================== input handling (5)

is_whitespace proc
    ; ----------------------------------------------------------------
    ; is_whitespace
    ;
    ; parses a character and determines if it is whitespace
    ;   RECEIVES    al :    the character to process
    ;   RETURNS     cf :    1 if whitespace, 0 if not whitespace
    ; ----------------------------------------------------------------
    cmp al, 33              ; all ascii codes < 33 are whitespace
    jl whitespace_true
    jmp whitespace_false

    whitespace_true:
        stc
        jmp finish

    whitespace_false:
        clc

    finish:

    ret
is_whitespace endp

get_number_end_index proc
    ; ---------------------------------------------------------------------------------------------
    ; get_number_end_index
    ;
    ; gets the index at which the input buffer stops being a digit. Returns -1 if none are digits
    ;
    ;   RECEIVES    ecx : the number of characters the user entered
    ;               ebx : the number at which valid *number* input starts
    ;
    ;   RETURNS     eax : the next index which has non-number input
    ; --------------------------------------------------------------------------------------------
    push edx
    push ebx
    push ecx
    push esi
    pushf

    mov eax, ebx

    mov esi, ebx                                                ; ESI::counter = EBX::start_input_index

    do_while_index_greater_than_start_of_valid_input:           ; do 
        mov al, input_buffer[esi]                               ;       AL::test = input_buffer[ESI::counter]
        call isDigit                                            ;       ZF::testIsDigit = isDigit(AL::test)
        jnz end_while
        inc esi                                                 ;       ESI::counter += 1
        cmp esi, ecx
        jg end_while                                            ; while ZF::testIsDigit && ESI::counter < ECX::user_entry_finish_index
        jmp do_while_index_greater_than_start_of_valid_input

    end_while:

        mov eax, esi                        ; EAX::result = ESI::counter

    popf
    pop esi
    pop ecx
    pop ebx
    pop edx
    ret
get_number_end_index endp

get_text_start_index proc
    ; --------------------------------------------------------------------------------------------------------
    ; get_text_start_index
    ;
    ; returns the index in the buffer where valid input starts (whitespace ends). If no valid input, returns -1
    ;   RECEIVES eax : the number of characters the user entered
    ;   RETURNS  ebx : the index at which valid input starts, -1 if no valid input
    ; ------------------------------------------------------------------------------------------------------
    push eax
    push esi
    push ecx
    pushf

    ; call WriteInt

    mov ecx, eax                                ; max_index = param number chars
    mov esi, 0                                  ; index = 0
    while_have_left_to_parse:                   ; while( index < max_index)
        cmp esi, ecx
        jg no_characters_found
        mov al, input_buffer[esi]               ;   test = input_buffer[index]
        call is_whitespace                      ;   if(!is_not_whitespace(test))
        jnc found_character; if not whitespace  ;       return index
        inc esi                                 ;   index++
        jmp while_have_left_to_parse

    found_character:
        mov ebx, esi
        jmp finish

    no_characters_found:                        ; return -1
        mov ebx, -1

    finish:
    popf
    pop ecx
    pop esi
    pop eax

    ret
get_text_start_index endp

parse_digit_from_buffer proc
    ; ------------------------------------------------------------------
    ; parse_digit_from_buffer v2
    ;
    ; parses the input buffer starting at the location given by ebx for numerical input. Iterates over the array of chars.
    ; Parses a leading negative of positve sign, if extant.
    ; clear carry flag if succesful parsing, sets carry flag if unsuccesful
    ; also should have overflow flag set if it overflowed
    ;
    ;   RECEIVES: ebx: the index at which valid input starts
    ;   RECEIVES: ecx: total length of user input that fit in the buffer
    ;   RETURNS:  eax: the integer parsed from the string.
    ;               CF = 0 - parse succesful
    ;               CF = 1 - parse unsuccesful
    ; ---------------------------------------------------------------------------
    push ecx
    push ebx
    push esi
    push edx


    mov al, input_buffer[ebx]               ; AL:test = input_buffer[EBX::start_index]
    cmp al, '-'
    je is_leading_negative_sign
    cmp al, '+'
    je is_leading_positive_sign
    jmp positive_multiply

    is_leading_negative_sign:               ; if(AL::test == '-')
        mov edx, -1                         ;   EDX::temporary_multiplier_tracker = -1
        inc ebx                             ;   EBX::start_index += 1     //the number starts 1 index forward
        jmp parse_number_between_indices

    is_leading_positive_sign:               ; else
        inc ebx                             ;    if(AL::test == '+')
                                            ;       EBX:: start_index += 1
    positive_multiply:                      ;       
        mov edx, 1                          ;    EDX::temporary_multiplier_tracker = 1

    parse_number_between_indices:           ;                            buffer swaps: need ecx for param, saving multiplier val with edx for now
                                            ;                                               /
    call get_number_end_index               ; EAX::number_end_index = get_number_end_index(ECX::num_chars, EBX::input_start_index)

    mov ecx, edx                            ; ECX::multiplier       = EDX::temporary_multiplier_tracker

    mov esi, eax                            ; ESI::number_length    = EAX::number_end_index
    mov eax, 0                              ; EAX::accumulation     = 0

    dec esi                                 ; ESI::start_of_counter = ESI::number_length - 1

    while_buffer_to_parse:



        mov edx, 0                          ; EDX::tester           = 0
        cmp esi, ebx                        ; while(ESI::counter > EBX::input_start_index)
        jl end_while
        movzx edx, input_buffer[esi]        ;   DL::tester = input_buffer[ESI::counter]
        sub edx, '0'                        ;   DL::tester -= '0'
        imul edx, ecx                       ;   EDX::digit_result *= ECX::multiplier
        jo overflow_error                   ;     catch(overflow) throw(overflow)
        add eax, edx                        ;   EAX::accumulation += EDX::digit_result
        imul ecx, 10                        ;   ECX:: multiplier *= 10

        dec esi                             ;   ESI::counter -= 1
        jmp while_buffer_to_parse

    end_while:
        clc
        jmp finish_up

    overflow_error:
        stc             ; stc may be redundant as add should set the carry flag as well if it overflowed

    finish_up:

    pop edx
    pop esi
    pop ebx
    pop ecx

    ret
parse_digit_from_buffer endp

parse_user_input proc
    ; ----------------------------------------------------------------
    ; parse_user_input
    ;
    ; parses a command and calls the appropriate function
    ;   RECEIVES eax : the number of characters the user entered
    ;            ebx : the index valid input starts at, must be > 0 and < eax-1
    ;   RETURNS  carry_flag == 1 if user elects to QUIT
    ;            carry_flag == 0 otherwise
    ; ----------------------------------------------------------------
    push eax
    push ebx
    push ecx

    mov ecx, eax                                   ; ECX::input_size = ECX::input_size

    mov al, input_buffer[ebx]

    switch_for_numbers:                            ; switch (al)
        case_neg:
            cmp al, '-'
            je case_neg_body
            jmp case_pos

        case_neg_body:
            mov al, input_buffer[ebx+1]             ; AL::test = inptu_buffer[ebx+1]
            call isDigit                            ; ZF = isDigit(AL::test)
            jnz switch_for_operators                ; if(!ZF) break;
            call parse_digit_from_buffer            ; EAX::int_result = parse_digit_from_buffer(EBX::start_valid_input, ECX::input_size)
            jo overflow_error                       ;   catch(overflow) print_overflow_error();
            call push_rpn                           ; push(EAX::int_result)
            jmp case_not_quit

        case_pos:
            cmp al, '+'
            je case_pos_body
            jmp case_digit

        case_pos_body:
            mov al, input_buffer[ebx+1]             ; AL::test = inptu_buffer[ebx+1]
            call isDigit                            ; ZF = isDigit(AL::test)
            jnz switch_for_operators                ; if(!ZF) break;
            call parse_digit_from_buffer            ; EAX::int_result = parse_digit_from_buffer(EBX::start_valid_input, ECX::input_size)
            jo overflow_error                       ;   catch(overflow) print_overflow_error();
            call push_rpn                           ; push(EAX::int_result)
            jmp case_not_quit

        case_digit:
            call isDigit                            ; zf = isDigit(al)
            jnz switch_for_operators

        case_digit_body:
            call parse_digit_from_buffer            ; EAX::int_result = parse_digit_from_buffer(EBX::start_valid_input, ECX::input_size)
            jo overflow_error                       ;    catch(overflow) print_overflow_error();
            call push_rpn                           ; push(EAX::int_result)
            jmp case_not_quit                       ;    continue

    switch_for_operators:
        mov al, input_buffer[ebx]                  ; go back to looking at buffer[0], in case al was changed

        case_div:
            cmp al, '/'
            jne case_mul
            call divide_rpn
            jmp case_not_quit

        case_mul:
            cmp al, '*'
            jne case_add
            call multiply_rpn
            jmp case_not_quit

        case_add:
            cmp al, '+'
            jne case_subtract
            call addition_rpn
            jmp case_not_quit

        case_subtract:
            cmp al, '-'
            jne switch_for_commands
            call subtraction_rpn
            jmp case_not_quit


    switch_for_commands:
        and al, 11011111b                          ; al.capitalize()

        case_toggle_number_mode:
            cmp al, 'M'
            jne case_clear_buffer
            call toggle_print_mode
            jmp case_not_quit

        case_clear_buffer:
            cmp al, 'O'
            jne case_toggle_help
            call Clrscr
            jmp case_not_quit

        case_toggle_help:
            cmp al, 'H'
            jne case_negate
            call toggle_help_box
            jmp case_not_quit

        case_negate:
            cmp al, 'N'
            jne case_xchng
            call negate_rpn
            jmp case_not_quit

        case_xchng:
            cmp al, 'X'
            jne case_clear
            call exchange_rpn
            jmp case_not_quit

        case_clear:
            cmp al, 'C'
            jne case_quit
            call stack_clear
            jmp case_not_quit

        case_quit:
            cmp al, 'Q'
            jne case_toggle_view                    ; set carry flag
            jmp case_quit_selected

        case_toggle_view:
            cmp al, 'V'
            jne case_roll_down
            call toggle_stack_view
            jmp case_not_quit

        case_roll_down:
            cmp al, 'D'
            jne case_roll_up
            call stack_roll_down_from_index
            call clear_error
            jmp case_not_quit

        case_roll_up:
            cmp al, 'U'
            jne bad_input
            call stack_roll_up_to_index
            call clear_error
            jmp case_not_quit

    overflow_error:
        call error_overflow
        jmp case_not_quit

    bad_input:
        mov edx, OFFSET prompt_error_msg
        call error_print
        jmp case_not_quit

    case_quit_selected:
        stc
        jmp finish_parsing


    case_not_quit:
        clc

    finish_parsing:

    pop ecx
    pop ebx
    pop eax
    ret
parse_user_input endp

get_input_and_draw_until_quit proc
    push edx
    push ecx
    push eax

    while_not_quit:                                                     ; While not CF::QuitFlag 
        call print_visible_structures

        invoke SetConsoleCursorPosition, outHandle, user_entry_location     

        mov edx, OFFSET input_buffer            ; where input will be read to
        mov ecx, SIZEOF input_buffer -1         ; buf_size = siz(buff)-1   //minus 1 for null term

        ; @  reminder on Read String procedure
        ;
        ; ReadString PROC
        ; Reads a string of up to ECX non-null characters from standard input, stopping when the user
        ; presses the Enter key. A null byte is stored following the characters input, but the trailing
        ; carriage return and line feed characters are not placed into the buffer.
        ;
        ;  ECX should always be smaller than the buffer size (never equal to the buffer size) because
        ;  the null byte could be the (ECX+1)th character stored.
        ;
        ;  EDX is the address of the buffer in memory.
        ;
        ; returns EAX - size of string

        call ReadString                         ; EAX:actual_chars_entered = ReadString(*input_buffer, buf_size)

        ; there is an alternative and probably better way to get input for this program, which would involve
        ; grabbing each character individually and deciding whether to print it or execute, obviating the need
        ; for the user to press <ENTER> after every command. Real calculators often work this way.

        cmp eax, SIZEOF input_buffer -3         ; turns out this is all that is entered into the buffer - annoying bug to find!!
        jg invalid_input
        call clear_error                       
        call get_text_start_index               ; EBX:start_index = get_text_start_index(EAX:actual_chars_entered)
        cmp ebx, 0                              ; if(EBX:start_index < 0)
        jl invalid_input                        ;    error_print("invalid input")
        call parse_user_input                   ;    continue
        jc end_while                            ; else
        jmp while_not_quit                      ;   CF:Quit = parse_user_input(EAX:actual_chars_entered, EBX:start_index)
                                                ;    

        invalid_input:
            call Clrscr                         ; clear screen gets rid of whatever garbage that user might have tried to leave on our buffer
            mov edx, OFFSET prompt_error_msg    ; print error after clearing screen so it's visible, users should know better
            call error_print
        jmp while_not_quit

    end_while:

    pop eax
    pop ecx
    pop edx

    ret
get_input_and_draw_until_quit endp

; ===============================================================================    main

main proc
    call Clrscr                        ; clear the screen
    call get_handle                    ; get console handle and set up for pretty print
    call get_input_and_draw_until_quit ; start the command loop
    call quit_msg_and_console_reset    ; done looping? reset console and print goodbye
exit
main endp
end main
