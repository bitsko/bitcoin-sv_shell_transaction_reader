#!/usr/bin/env bash

# uses whatsonchain api to print information about a transaction to the terminal, colorfully
# if bx bitcoin tool is in path; shows the base58check encoded address

# Example Usage:
# $ bash woc_txread.sh 487d70298bde81604664fd5f3d339491cad78b64702248e5fd4945e7c6f47863

tput_coloring(){
	[[ -z $(command -v tput) ]] && echo "requires tput" && exit 1
	red=$(tput setaf 1)
	white=$(tput setaf 7)
	blue=$(tput setaf 4)
	normal=$(tput sgr0)
	green=$(tput setaf 2)
	bright=$(tput bold)
}

echo_bright(){ echo "${bright}${1}${normal}"; }

echo_blue(){ echo "${bright}${blue}${1}${normal}"; }

echo_red(){ echo "${red}${1}${normal}"; }

curl_var(){
	curl -s --location --request GET "${1}"
}

woc_txhash(){
	jq<<<$(curl_var "${wocurl1}hash/$arrayHash")
}

from_hex(){
	curl_var "${wocurl1}${arrayHash}/out/0/hex"
}

asmtx(){
	node <<- BSVJSASMTX
	let bsv = require('bsv')
	var script = bsv.Script.fromHex('$(from_hex)')
	console.log(script.toAsmString())
	BSVJSASMTX
}

input_check(){
	if [[ $(wc -m<<<"$arrayHash") -ne 65 ]]; then
		echo_red "input not 64 characters"
		exit 1
	fi
}

op_check(){
        if [[ "$f" == OP_DUP ]]; then opdup=1; fi
        if [[ "$f" == OP_HASH160 ]]; then ophash160=1; fi
        if [[ -n "$p2pkh_address" ]]; then p2pkh_address=1; fi
        if [[ "$f" == OP_EQUALVERIFY ]]; then opequal=1; fi
        if [[ "$f" == OP_CHECKSIG ]]; then opchecksig=1; fi
}

set_array(){
	arrayFile_=$(asmtx)
	if [ $? -ne 0 ]; then
	        echo_red "cant connect to api"
	        exit 1
	fi
	arrayFile=$(echo "${arrayFile_}" | sed 's/ /\n/g')
	echo "${bright}------txid: ${green}${arrayHash}${normal}"
}

print_txtype(){
	printf '%s\n' "${white}pos-$line_var-${bright}text: ${green}$text ${normal}${bright}${1}${normal}"
}

array_parser(){
	line_var=1
	p2pkh_print=0
	while read f; do
	        if [[ "$opdup" == 1 ]] && [[ "$ophash160" == 1 ]] && [[ "$line_var" == 3 ]]; then
	        	if [[ $(command -v bx) ]]; then
		        p2pkh_address=$(bx base58check-encode "$f")
	                printf '%s\n' "${bright}pos-$line_var-hex-: ${blue}$f ${normal}${bright}Address: $p2pkh_address${normal}"
			fi
	        else
	                p2pkh_address="${f}"
			printf '%s\n' "${bright}pos-$line_var-hex-: ${blue}$f${normal}"
	        fi
		op_check
	        if [[ $(wc -m<<<"$f") -gt 7 ]]; then
	                if [[ $(wc -m<<<"$f") -lt 100 ]]; then
	                        if [[ $(wc -m<<<"$f") -ne 65 ]]; then
					text=$(xxd -r -p<<<"$f" | strings)
	                	else
					text=' '
				fi
			else
	                        text=$(xxd -r -p<<<"$f" | strings -n 7)
	                fi
	        elif [[ "$f" != 00 ]]; then
	                text=$(xxd -r -p<<<"$f")
	        else
	                text=' '
	        fi
	        if [[ -n "$text" ]]; then
	                if [[ "$text" == 19iG3WTYSsbyos3uJ733yK4zEioi1FesNU ]]; then
	                        print_txtype "D:// Bitcoin Dynamic Content Protocol"
	                elif [[ "$text" == 19HxigV4QyBv3tHpQVcUEQyq1pzZVdoAut ]]; then
	                        print_txtype "B:// Bitcoin Data Protocol"
	                elif [[ "$text" == 1ChDHzdd1H4wSjgGMHyndZm6qxEDGjqpJL ]]; then
	                        print_txtype "B part transaction"
	                elif [[ "$text" == 15DHFxWZJT58f9nhyGnsRBqrgwK4W6h4Up ]]; then
	                        print_txtype "BCat transaction"
	                else
	                        if [[ $(wc -m<<<"$text") -gt 2 ]]; then
	                                printf '%s\n' "${white}pos-$line_var-${bright}text: ${green}$text${normal}"
	                        fi
        	        fi
	        fi
	        line_var=$((line_var + 1))
	if [[ -n "$opdup" ]] && [[ -n "$ophash160" ]] &&  [[ "$p2pkh_address" == 1 ]] &&
	        [[ -n "$opequal" ]] && [[ -n "$opchecksig" ]] && [[ p2pkh_print == 0 ]]; then
	                echo_bright "------type: Pay to Public Key Hash transaction"
			p2pkh_print=1
	fi
	done<<<"$arrayFile"
}

print_vouts(){
	echo_bright "txVouts:"
	vouts=$(woc_txhash "$arrayHash" | jq -r .vout[].scriptPubKey.hex)
	tx_vout=0
	while read -r line; do
	        if [[ $(wc -m<<<"$line") == 51 ]]; then
	                if [[ $(command -v bx) ]]; then
	                        voutaddress=$(bx base58check-encode "$line")
	                else
	                        voutaddress="$line"
	                fi
	                echo "${bright}Vout $tx_vout Address: ${green}${voutaddress}${normal}"
	        else
	                echo_blue "${line}"
	        fi
	tx_vout=$((tx_vout + 1 ))
	done<<<"$vouts"
}

set_variables(){
	wocurl1="https://api.whatsonchain.com/v1/bsv/main/tx/"
	tput_coloring
}

set_variables

if [[ -p "/dev/stdin" ]]; then
        arrayHash="$(cat)"
	arrayHash=$(sed 's/"//g'<<<"$arrayHash")
else
        arrayHash="$1"
	arrayHash=$(sed 's/"//g'<<<"$arrayHash")
        if [[ -z "$1" ]]; then
                echo_red "provide a txid as \$1"
                exit 1
        fi
fi

program_run(){
	input_check
	set_array
	array_parser
	print_vouts
}

unset_vars(){
	unset tput_coloring red white blue normal green bright echo_bright echo_blue echo_red curl_var \
		woc_txhash from_hex asmtx input_check op_check opdup ophash160 p2pkh_address opequal \
		opchecksig set_array arrayFile_ arrayFile print_txtype text vouts tx_vout voutaddress \
		print_vouts set_variables wocurl1 line_var arrayHash program_run
}


program_run || unset_vars
unset_vars
