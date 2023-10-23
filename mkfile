MODSRC=parser.pp generator.pp
MODOBJ=${MODSRC:%.pp=%.o}
MODPPU=${MODSRC:%.pp=%.ppu}

xeger: xeger.p $MODSRC
	fpc -vwn xeger.p

test:VQ: xeger
	for testfile in test/*.in; do
		regex=$(sed -n 1p "$testfile") count=$(sed -n 2p "$testfile")
		outfile=${testfile%.in}.out missfile=${testfile%.in}.miss
		./xeger "$regex" "$count" >"$outfile"
		if ! grep -vE "$regex" "$outfile" >"$missfile"; then
			echo "$testfile PASSED"
		else
			echo "$testfile FAILED"
		fi
	done

clean:V:
	rm -f xeger $MODOBJ $MODPPU xeger.o test/*.out test/*.miss
