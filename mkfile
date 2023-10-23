MODSRC=parser.pp generator.pp
MODOBJ=${MODSRC:%.pp=%.o}
MODPPU=${MODSRC:%.pp=%.ppu}

xeger: xeger.p $MODSRC
	fpc -vwn xeger.p

clean:V:
	rm -f xeger $MODOBJ $MODPPU xeger.o
