#!/bin/bash
# Trickster: Expression Engine for Morph Compiler
# Implements Shunting-yard algorithm to handle complex expressions without AST.
# Replaces Regex/Sed with Character-by-Character Scanner for robustness.

# Global Stack for Shunting Yard
declare -a OP_STACK
declare -a RPN_OUTPUT
declare -a TOKENS

# Tokenizer: Splits string into tokens array using state machine
# Input: "a + b * (c - 1)"
# Output: stored in global TOKENS array
tokenize_expression() {
    local input="$1"
    TOKENS=()
    local len=${#input}
    local i=0

    # Define regex for operators safely
    # Note: ] must be first in list to be matched as literal ']'
    # Pattern: [-+*/%&|^!<>=\(\)]
    # We use a variable to avoid shell expansion issues
    local op_pattern='^[-+*/%&|^!<>=\(\)]$ '

    while [ $i -lt $len ]; do
        local char="${input:$i:1}"

        # 1. Skip Whitespace
        if [[ "$char" =~ [[:space:]] ]]; then
            ((i++))
            continue
        fi

        # 2. String Literals ("...")
        if [ "$char" == "\"" ]; then
            local str_val="\""
            ((i++))
            while [ $i -lt $len ]; do
                local c="${input:$i:1}"
                str_val+="$c"
                ((i++))
                if [ "$c" == "\"" ]; then
                    break
                fi
            done
            TOKENS+=("$str_val")
            continue
        fi

        # 3. Numbers
        if [[ "$char" =~ [0-9] ]]; then
            local num_val=""
            while [ $i -lt $len ]; do
                local c="${input:$i:1}"
                if [[ "$c" =~ [0-9] ]] || [ "$c" == "." ]; then
                    num_val+="$c"
                    ((i++))
                else
                    break
                fi
            done
            TOKENS+=("$num_val")
            continue
        fi

        # 4. Identifiers (Variables)
        if [[ "$char" =~ [a-zA-Z_] ]]; then
            local id_val=""
            while [ $i -lt $len ]; do
                local c="${input:$i:1}"
                if [[ "$c" =~ [a-zA-Z0-9_] ]]; then
                    id_val+="$c"
                    ((i++))
                else
                    break
                fi
            done
            TOKENS+=("$id_val")
            continue
        fi

        # 5. Operators (Multi-char support)
        # Check against list of known operator starts
        # Escape special regex chars: + * . [ ] \
        # Simpler: just switch case or simple string check if strict regex is hard
        if [[ "$char" == "+" || "$char" == "-" || "$char" == "*" || "$char" == "/" || "$char" == "%" || \
              "$char" == "&" || "$char" == "|" || "$char" == "^" || "$char" == "!" || \
              "$char" == "<" || "$char" == ">" || "$char" == "=" || "$char" == "(" || "$char" == ")" ]]; then

            local next_char=""
            if [ $((i + 1)) -lt $len ]; then
                next_char="${input:$((i+1)):1}"
            fi

            local combined="$char$next_char"
            local token=""

            case "$combined" in
                "<<") token="<<" ;;
                ">>") token=">>" ;;
                "==") token="==" ;;
                "!=") token="!=" ;;
                "<=") token="<=" ;;
                ">=") token=">=" ;;
                "&&") token="&&" ;;
                "||") token="||" ;;
                *)    token="$char" ;;
            esac

            TOKENS+=("$token")
            if [ ${#token} -eq 2 ]; then
                ((i+=2))
            else
                ((i++))
            fi
            continue
        fi

        # Unknown char
        ((i++))
    done
}

# Precedence Helper
get_precedence() {
    case "$1" in
        "||") echo 0 ;;
        "&&") echo 1 ;;
        "|"|"^") echo 2 ;;
        "&") echo 3 ;;
        "=="|"!=") echo 4 ;;
        "<"|">"|"<="|">=") echo 5 ;;
        "<<") echo 6 ;;
        ">>") echo 6 ;;
        "+"|"-") echo 7 ;;
        "*"|"/"|"%") echo 8 ;;
        "!"|"u-") echo 9 ;;
        *) echo -1 ;;
    esac
}

get_associativity() {
    case "$1" in
        "!"|"u-") echo "RIGHT" ;;
        *) echo "LEFT" ;;
    esac
}

is_operator() {
    local prec=$(get_precedence "$1")
    if [ "$prec" -ge 0 ]; then
        return 0 # True
    else
        return 1 # False
    fi
}

# Shunting-yard Algorithm
shunting_yard() {
    RPN_OUTPUT=()
    OP_STACK=()
    local prev_token="START"

    for token in "${TOKENS[@]}"; do
        if [[ "$token" =~ ^[a-zA-Z0-9_]+$ || "$token" =~ ^[0-9.]+$ || "$token" =~ ^\".*\"$ ]]; then
            RPN_OUTPUT+=("$token")
            prev_token="OPERAND"
        elif [[ "$token" == "(" ]]; then
            OP_STACK+=("$token")
            prev_token="LPAREN"
        elif [[ "$token" == ")" ]]; then
            while [ ${#OP_STACK[@]} -gt 0 ]; do
                local top="${OP_STACK[-1]}"
                if [ "$top" == "(" ]; then
                    unset 'OP_STACK[${#OP_STACK[@]}-1]'
                    break
                fi
                RPN_OUTPUT+=("$top")
                unset 'OP_STACK[${#OP_STACK[@]}-1]'
            done
            prev_token="RPAREN"
        elif is_operator "$token"; then
            local curr_op="$token"

            # --- UNARY MINUS DETECTION ---
            if [ "$curr_op" == "-" ]; then
                if [[ "$prev_token" == "START" || "$prev_token" == "LPAREN" || "$prev_token" == "OP" ]]; then
                    curr_op="u-"
                fi
            fi

            local prec_curr=$(get_precedence "$curr_op")
            local assoc_curr=$(get_associativity "$curr_op")

            while [ ${#OP_STACK[@]} -gt 0 ]; do
                local top="${OP_STACK[-1]}"
                if [ "$top" == "(" ]; then break; fi

                local prec_top=$(get_precedence "$top")

                if [ "$assoc_curr" == "LEFT" ] && [ "$prec_top" -ge "$prec_curr" ]; then
                     RPN_OUTPUT+=("$top")
                     unset 'OP_STACK[${#OP_STACK[@]}-1]'
                elif [ "$assoc_curr" == "RIGHT" ] && [ "$prec_top" -gt "$prec_curr" ]; then
                     RPN_OUTPUT+=("$top")
                     unset 'OP_STACK[${#OP_STACK[@]}-1]'
                else
                    break
                fi
            done
            OP_STACK+=("$curr_op")
            prev_token="OP"
        fi
    done

    while [ ${#OP_STACK[@]} -gt 0 ]; do
        local top="${OP_STACK[-1]}"
        RPN_OUTPUT+=("$top")
        unset 'OP_STACK[${#OP_STACK[@]}-1]'
    done
}

# Compile RPN to Assembly
compile_rpn() {
    IS_FLOAT_EXPR=0

    # 1. Detect Float
    for token in "${RPN_OUTPUT[@]}"; do
        if [[ "$token" =~ \. ]]; then
            IS_FLOAT_EXPR=1
            break
        fi
    done

    # 2. Generate ASM
    for token in "${RPN_OUTPUT[@]}"; do
        if is_operator "$token"; then
            if [ "$token" == "!" ]; then
                echo "    pop rax"
                echo "    cmp rax, 0"
                echo "    sete al"
                echo "    movzx rax, al"
                echo "    push rax"
            elif [ "$token" == "u-" ]; then
                echo "    pop rax"
                echo "    neg rax"
                echo "    push rax"
            else
                echo "    pop rbx"
                echo "    pop rax"

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
                    "<<")
                        echo "    mov rcx, rbx"
                        echo "    shl rax, cl"
                        ;;
                    ">>")
                        echo "    mov rcx, rbx"
                        echo "    shr rax, cl"
                        ;;
                    "==")
                         echo "    cmp rax, rbx"
                         echo "    sete al"
                         echo "    movzx rax, al"
                         ;;
                    "!=")
                         echo "    cmp rax, rbx"
                         echo "    setne al"
                         echo "    movzx rax, al"
                         ;;
                    "<")
                         echo "    cmp rax, rbx"
                         echo "    setl al"
                         echo "    movzx rax, al"
                         ;;
                    ">")
                         echo "    cmp rax, rbx"
                         echo "    setg al"
                         echo "    movzx rax, al"
                         ;;
                    "<=")
                         echo "    cmp rax, rbx"
                         echo "    setle al"
                         echo "    movzx rax, al"
                         ;;
                    ">=")
                         echo "    cmp rax, rbx"
                         echo "    setge al"
                         echo "    movzx rax, al"
                         ;;
                esac
                echo "    push rax"
            fi
        else
            if [[ "$token" =~ ^[0-9.]+$ ]]; then
                if [[ "$token" =~ \. ]]; then
                     local int_val=${token%.*}
                     echo "    push $int_val"
                else
                     echo "    push $token"
                fi
            elif [[ "$token" =~ ^\" ]]; then
                :
            else
                echo "    push qword [var_$token]"
            fi
        fi
    done
}

# Main Entry Point
compile_expression() {
    local expr="$1"
    tokenize_expression "$expr"
    shunting_yard
    compile_rpn
}
