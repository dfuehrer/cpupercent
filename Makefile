SRC = cpupercentServer.cpp
DESTDIR=~
PREFIX=/.local

cpupercentServer: $(SRC)
	$(CXX) $(SRC) -o $@

.PHONY: clean install

clean:
	rm -f cpupercentServer $(OBJ)

install: cpupercentServer
	mkdir -p ${DESTDIR}${PREFIX}/bin
	cp -f cpupercentServer ${DESTDIR}${PREFIX}/bin
	chmod 755 ${DESTDIR}${PREFIX}/bin/cpupercentServer

