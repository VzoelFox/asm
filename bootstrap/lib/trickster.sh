#!/bin/bash
# Trickster: Expression Engine for Morph Compiler
# Implements Shunting-yard algorithm to handle complex expressions without AST.

# Global Stack for Shunting Yard
declare -a OP_STACK
declare -a RPN_OUTPUT

# Tokenizer: Splits string into tokens array
# Input: "a + b * (c - 1)"
# Output: stored in global TOKENS array
tokenize_expression() {
    local input="$1"
    TOKENS=()

    # Add spaces around operators to simplify splitting
    # Note: We need to handle multi-char operators like ==, !=, <=, >= later.
    # For now P1/P2 context, we focus on arithmetic +, -, *, /, %, &, |, ^, ! and ( )

    # 1. Add spaces around single char operators
    local formatted="$input"
    # Move dash to start to avoid range issues
    formatted=$(echo "$formatted" | sed 's/\([-+*/%&|^!()]\)/ \1 /g')

    # 2. Fix potential double spaces or split
    # Using read -ra to split by whitespace
    IFS=' ' read -ra RAW_TOKENS <<< "$formatted"

    TOKENS=("${RAW_TOKENS[@]}")
}

# Precedence Helper
get_precedence() {
    case "$1" in
        "|"|"^") echo 1 ;;
        "&") echo 2 ;;
        "+"|"-") echo 3 ;;
        "*"|"/"|"%") echo 4 ;;
        "!") echo 5 ;; # Unary right associative
        *) echo 0 ;;
    esac
}

is_operator() {
    local op_regex='^[-+*/%&|^!]$'
    [[ "$1" =~ $op_regex ]]
}

# Shunting-yard Algorithm
# Input: Populates RPN_OUTPUT from TOKENS
shunting_yard() {
    RPN_OUTPUT=()
    OP_STACK=()

    for token in "${TOKENS[@]}"; do
        if [[ "$token" =~ ^[a-zA-Z0-9_]+$ || "$token" =~ ^[0-9]+$ || "$token" =~ ^\".*\"$ ]]; then
            # Operand (Variable, Number, String Literal)
            RPN_OUTPUT+=("$token")
        elif [[ "$token" == "(" ]]; then
            OP_STACK+=("$token")
        elif [[ "$token" == ")" ]]; then
            # Pop until (
            while [ ${#OP_STACK[@]} -gt 0 ]; do
                local top="${OP_STACK[-1]}"
                if [ "$top" == "(" ]; then
                    unset 'OP_STACK[${#OP_STACK[@]}-1]'
                    break
                fi
                RPN_OUTPUT+=("$top")
                unset 'OP_STACK[${#OP_STACK[@]}-1]'
            done
        elif is_operator "$token"; then
            local prec_curr=$(get_precedence "$token")

            while [ ${#OP_STACK[@]} -gt 0 ]; do
                local top="${OP_STACK[-1]}"
                local prec_top=$(get_precedence "$top")

                # If stack top has greater or equal precedence, pop it
                # (Assuming left-associative)
                if [ "$top" != "(" ] && [ "$prec_top" -ge "$prec_curr" ]; then
                    RPN_OUTPUT+=("$top")
                    unset 'OP_STACK[${#OP_STACK[@]}-1]'
                else
                    break
                fi
            done
            OP_STACK+=("$token")
        fi
    done

    # Pop remaining operators
    while [ ${#OP_STACK[@]} -gt 0 ]; do
        local top="${OP_STACK[-1]}"
        RPN_OUTPUT+=("$top")
        unset 'OP_STACK[${#OP_STACK[@]}-1]'
        # Use reverse loop or just pop from end? Stack is LIFO.
        # We popped from end in the loop.
    done
}

# Compile RPN to Assembly
# Generates "push/pop" based code.
compile_rpn() {
    # We iterate RPN_OUTPUT
    # If operand: generate 'push'
    # If operator: generate 'pop', 'op', 'push'

    for token in "${RPN_OUTPUT[@]}"; do
        if is_operator "$token"; then
            if [ "$token" == "!" ]; then
                # Unary
                echo "    pop rax"
                echo "    cmp rax, 0"
                echo "    sete al"
                echo "    movzx rax, al"
                echo "    push rax"
            else
                # Binary
                echo "    pop rbx" # Right operand
                echo "    pop rax" # Left operand

                case "$token" in
                    "+") echo "    add rax, rbx" ;;
                    "-") echo "    sub rax, rbx" ;;
                    "*") echo "    imul rax, rbx" ;;
                    "/")
                        echo "    cqo"
                        echo "    idiv rbx"
                        ;;
                    "%")
                        echo "    cqo"
                        echo "    idiv rbx"
                        echo "    mov rax, rdx"
                        ;;
                    "&") echo "    and rax, rbx" ;;
                    "|") echo "    or rax, rbx" ;;
                    "^") echo "    xor rax, rbx" ;;
                esac

                echo "    push rax"
            fi
        else
            # Operand
            if [[ "$token" =~ ^-?[0-9]+$ ]]; then
                echo "    push $token"
            elif [[ "$token" =~ ^\" ]]; then
                # String Literal (Not supported in math, but maybe for concat?)
                # For now assume math only in trickster v1
                :
            else
                # Variable
                echo "    push qword [var_$token]"
            fi
        fi
    done

    # Result is on stack top.
    # Caller should 'pop rax' to get result.
}

# Main Entry Point
# Usage: compile_expression "a + b * c"
compile_expression() {
    local expr="$1"
    tokenize_expression "$expr"
    shunting_yard
    compile_rpn
}
